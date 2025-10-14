# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

alias AshGraphql.Test.PubSub
alias AshGraphql.Test.Schema

{:ok, _pubsub} = PubSub.start_link()
{:ok, _absinthe_sub} = Absinthe.Subscription.start_link(PubSub)

# Application.put_env(:ash_graphql, :simulate_subscription_processing_time, 1000)
:ok

admin = %{
  id: 0,
  role: :admin
}

create_mutation = """
mutation CreateSubscribable($input: CreateSubscribableInput) {
    createSubscribable(input: $input) {
      result{
        id
        text
      }
      errors{
        message
      }
    }
  }
"""

AshGraphql.Subscription.Batcher.start_link()

Benchee.run(
  %{
    "1 mutation" => fn _input ->
      Absinthe.run(create_mutation, Schema,
        variables: %{"input" => %{"text" => "foo"}},
        context: %{actor: admin}
      )
    end
  },
  inputs: %{
    "25 same subscribers" => {25, :same},
    "500 same subscribers" => {500, :same},
    "50 mixed subscribers" => {25, [:same, :different]},
    "1000 mixed subscribers" => {500, [:same, :different]}
  },
  after_scenario: fn _ ->
    count = fn counter ->
      receive do
        _msg ->
          1 + counter.(counter)
      after
        0 -> 0
      end
    end

    AshGraphql.Subscription.Batcher.drain()

    IO.puts("Received #{count.(count)} messages")
  end,
  before_scenario: fn {input, types} ->
    Application.put_env(PubSub, :notifier_test_pid, self())

    if :different in List.wrap(types) do
      Enum.each(1..input, fn i ->
        actor = %{
          id: i,
          role: :admin
        }

        {:ok, %{"subscribed" => _topic}} =
          Absinthe.run(
            """
            subscription {
              subscribableEvents {
                created {
                  id
                  text
                }
                updated {
                  id
                  text
                }
                destroyed
              }
            }
            """,
            Schema,
            context: %{actor: actor, pubsub: PubSub}
          )
      end)
    end

    if :same in List.wrap(types) do
      Enum.each(1..input, fn _i ->
        actor = %{
          id: -1,
          role: :admin
        }

        {:ok, %{"subscribed" => _topic}} =
          Absinthe.run(
            """
            subscription {
              subscribableEvents {
                created {
                  id
                  text
                }
                updated {
                  id
                  text
                }
                destroyed
              }
            }
            """,
            Schema,
            context: %{actor: actor, pubsub: PubSub}
          )
      end)
    end
  end
)

AshGraphql.Subscription.Batcher.drain()
