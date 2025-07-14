defmodule AshGraphql.DomainPubsubValidationTest do
  use ExUnit.Case, async: false

  describe "domain pubsub validation during compilation" do
    test "raises error when resource has subscriptions but no pubsub and domain has no pubsub" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule TestResourceWithoutPubsub do
          use Ash.Resource,
            domain: TestDomainWithoutPubsub,
            extensions: [AshGraphql.Resource]

          graphql do
            type :test_resource_without_pubsub

            subscriptions do
              subscribe(:test_subscription) do
                action_types([:create])
              end
            end
          end

          actions do
            default_accept(:*)
            defaults([:create])
          end

          attributes do
            uuid_primary_key(:id)
          end
        end

        defmodule TestDomainWithoutPubsub do
          use Ash.Domain, extensions: [AshGraphql.Domain]

          graphql do
            subscriptions do
            end
          end

          resources do
            resource(TestResourceWithoutPubsub)
          end
        end
      end
    end

    test "raises error when domain has subscriptions but no pubsub and resource has no pubsub" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule TestResourceWithoutPubsub2 do
          use Ash.Resource,
            domain: TestDomainWithoutPubsub2,
            extensions: [AshGraphql.Resource]

          graphql do
            type :test_resource_without_pubsub2

            subscriptions do
              subscribe(:test_subscription) do
                action_types([:create])
              end
            end
          end

          actions do
            default_accept(:*)
            defaults([:create])
          end

          attributes do
            uuid_primary_key(:id)
          end
        end

        defmodule TestDomainWithoutPubsub2 do
          use Ash.Domain, extensions: [AshGraphql.Domain]

          graphql do
            subscriptions do
              subscribe TestResourceWithoutPubsub2, :test_subscription do
                action_types([:create])
              end
            end
          end

          resources do
            resource(TestResourceWithoutPubsub2)
          end
        end
      end
    end

    test "succeeds when domain has pubsub and resource has no pubsub" do
      defmodule TestResourceWithoutPubsub3 do
        use Ash.Resource, domain: TestDomainWithPubsub3, extensions: [AshGraphql.Resource]

        graphql do
          type :test_resource_without_pubsub3

          subscriptions do
            subscribe(:test_subscription) do
              action_types([:create])
            end
          end
        end

        actions do
          default_accept(:*)
          defaults([:create])
        end

        attributes do
          uuid_primary_key(:id)
        end
      end

      defmodule TestDomainWithPubsub3 do
        use Ash.Domain, extensions: [AshGraphql.Domain]

        graphql do
          subscriptions do
            pubsub AshGraphql.Test.PubSub
          end
        end

        resources do
          resource(TestResourceWithoutPubsub3)
        end
      end

      assert TestDomainWithPubsub3
      assert TestResourceWithoutPubsub3
    end

    test "succeeds when resource has pubsub and domain has no pubsub" do
      defmodule TestResourceWithPubsub4 do
        use Ash.Resource, domain: TestDomainWithoutPubsub4, extensions: [AshGraphql.Resource]

        graphql do
          type :test_resource_with_pubsub4

          subscriptions do
            pubsub AshGraphql.Test.PubSub

            subscribe(:test_subscription) do
              action_types([:create])
            end
          end
        end

        actions do
          default_accept(:*)
          defaults([:create])
        end

        attributes do
          uuid_primary_key(:id)
        end
      end

      defmodule TestDomainWithoutPubsub4 do
        use Ash.Domain, extensions: [AshGraphql.Domain]

        graphql do
          subscriptions do
          end
        end

        resources do
          resource(TestResourceWithPubsub4)
        end
      end

      assert TestDomainWithoutPubsub4
      assert TestResourceWithPubsub4
    end
  end
end
