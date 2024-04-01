defmodule AshGraphql.ErrorsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)
      Application.delete_env(:ash_graphql, :policies)

      AshGraphql.TestHelpers.stop_ets()
    end)
  end

  test "errors can be configured to be shown in the root" do
    resp =
      """
      mutation CreatePost($input: CreatePostInput) {
        createPost(input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.RootLevelErrorsSchema,
        variables: %{
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{data: %{"createPost" => nil}, errors: [%{message: message}]} = result

    assert message =~ "confirmation did not match value"
  end

  test "raised errors are by default not shown" do
    assert capture_log(fn ->
             resp =
               """
               mutation CreatePostWithError($input: CreatePostWithErrorInput) {
                 createPostWithError(input: $input) {
                   result{
                     text
                   }
                   errors{
                     message
                   }
                 }
               }
               """
               |> Absinthe.run(AshGraphql.Test.Schema,
                 variables: %{
                   "input" => %{
                     "text" => "foobar"
                   }
                 }
               )

             assert {:ok, result} = resp

             assert %{data: nil, errors: [%{message: message}]} =
                      result

             assert message =~ "Something went wrong."
           end) =~ "Exception raised while resolving query"
  end

  test "raised errors can be configured to be shown" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
      graphql: [show_raised_errors?: true]
    )

    resp =
      """
      mutation CreatePostWithError($input: CreatePostWithErrorInput) {
        createPostWithError(input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createPostWithError" => %{"errors" => [%{"message" => message}]}
             }
           } = result

    assert message =~ "is required"
  end

  test "showing raised errors alongside root errors shows raised errors in the root" do
    Application.put_env(:ash_graphql, AshGraphql.Test.RootLevelErrorsDomain,
      graphql: [show_raised_errors?: true]
    )

    resp =
      """
      mutation CreatePostWithError($input: CreatePostWithErrorInput) {
        createPostWithError(input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.RootLevelErrorsSchema,
        variables: %{
          "input" => %{
            "text" => "foobar"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{"createPostWithError" => nil},
             errors: [
               %{message: message}
             ]
           } = result

    assert message =~ "is required"
  end

  test "a multitenant object cannot be read if tenant is not set" do
    assert capture_log(fn ->
             tenant = "Some Tenant"

             tag =
               AshGraphql.Test.MultitenantTag
               |> Ash.Changeset.for_create(
                 :create,
                 [name: "My Tag4"],
                 tenant: tenant
               )
               |> Ash.create!()

             resp =
               """
               query MultitenantTag($id: ID!) {
                 getMultitenantTag(id: $id) {
                   name
                 }
               }
               """
               |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"id" => tag.id})

             assert {:ok, result} = resp

             assert %{data: %{"getMultitenantTag" => nil}, errors: [%{message: message}]} = result
             assert message =~ "Something went wrong."
           end) =~
             "Queries against the AshGraphql.Test.MultitenantTag resource require a tenant to be specified"
  end

  test "a multitenant object cannot be read without tenant" do
    assert capture_log(fn ->
             tenant = "Some Tenant"

             tag =
               AshGraphql.Test.MultitenantTag
               |> Ash.Changeset.for_create(
                 :create,
                 [name: "My Tag2"],
                 tenant: tenant
               )
               |> Ash.create!()

             resp =
               """
               query MultitenantTag($id: ID!) {
                 getMultitenantTag(id: $id) {
                   name
                 }
               }
               """
               |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"id" => tag.id})

             assert {:ok, result} = resp

             assert %{data: %{"getMultitenantTag" => nil}, errors: [%{message: message}]} = result
             assert message =~ "Something went wrong."
           end) =~
             "Queries against the AshGraphql.Test.MultitenantTag resource require a tenant to be specified"
  end

  test "a multitenant relation cannot be read without tenant" do
    assert capture_log(fn ->
             tenant = "Some Tenant"

             tag =
               AshGraphql.Test.MultitenantTag
               |> Ash.Changeset.for_create(
                 :create,
                 [name: "My Tag3"],
                 tenant: tenant
               )
               |> Ash.create!()

             post =
               AshGraphql.Test.Post
               |> Ash.Changeset.for_create(:create, text: "foo", published: true)
               |> Ash.Changeset.manage_relationship(
                 :multitenant_tags,
                 [tag],
                 on_no_match: {:create, :create_action},
                 on_lookup: :relate
               )
               |> Ash.create!()

             resp =
               """
               query MultitenantPostTag($id: ID!) {
                 getPost(id: $id) {
                   text
                   published
                   multitenantTags {
                     name
                   }
                 }
               }
               """
               |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"id" => post.id})

             assert {:ok, result} = resp

             assert %{
                      data: %{
                        "getPost" => nil
                      },
                      errors: [%{message: message}]
                    } = result

             assert message =~ "Something went wrong."
           end) =~
             "Queries against the AshGraphql.Test.MultitenantTag resource require a tenant to be specified"
  end

  test "unauthorized requests do not show policy breakdowns by default" do
    user =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create,
        name: "My Name"
      )
      |> Ash.create!()

    resp =
      """
      mutation CreateUser($input: CreateUserInput) {
        createUser(input: $input) {
          result{
            name
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"name" => "The Dude"}},
        context: %{actor: user}
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createUser" => %{
                 "errors" => [
                   %{
                     "message" => message
                   }
                 ]
               }
             }
           } = result

    assert message == "forbidden"
  end

  test "unauthorized requests can be configured to show policy breakdowns" do
    Application.put_env(
      :ash_graphql,
      :policies,
      show_policy_breakdowns?: true
    )

    user =
      AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create,
        name: "My Name"
      )
      |> Ash.create!()

    resp =
      """
      mutation CreateUser($input: CreateUserInput) {
        createUser(input: $input) {
          result{
            name
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{"input" => %{"name" => "The Dude"}},
        context: %{actor: user}
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "createUser" => %{
                 "errors" => [
                   %{
                     "message" => message
                   }
                 ]
               }
             }
           } = result

    assert message =~ "Breakdown"
  end

  test "error items are non-nullable" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "CreateUserResult") {
          fields {
            name
            type {
              kind
              ofType {
                kind
                ofType {
                  name
                }
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    errors =
      data["__type"]["fields"]
      |> Enum.find(fn field -> field["name"] == "errors" end)

    assert errors["type"]["kind"] == "LIST"
    assert errors["type"]["ofType"]["kind"] == "NON_NULL"
    assert errors["type"]["ofType"]["ofType"]["name"] == "MutationError"
  end

  test "MutationError fields items are non-nullable" do
    {:ok, %{data: data}} =
      """
      query {
        __type(name: "MutationError") {
          fields {
            name
            type {
              kind
              ofType {
                kind
                ofType {
                  name
                }
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    fields =
      data["__type"]["fields"]
      |> Enum.find(fn field -> field["name"] == "fields" end)

    assert fields["type"]["kind"] == "LIST"
    assert fields["type"]["ofType"]["kind"] == "NON_NULL"
    assert fields["type"]["ofType"]["ofType"]["name"] == "String"
  end

  test "mutation result is non nullable without root level errors" do
    {:ok, %{data: data}} =
      """
      query {
        __schema {
          mutationType {
            name
            fields {
              name
              type {
                kind
                ofType {
                  name
                }
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema)

    create_post_mutation =
      data["__schema"]["mutationType"]["fields"]
      |> Enum.find(fn field -> field["name"] == "createPost" end)

    assert create_post_mutation["type"]["kind"] == "NON_NULL"
    assert create_post_mutation["type"]["ofType"]["name"] == "CreatePostResult"
  end

  test "mutation result is nullable with root level errors" do
    {:ok, %{data: data}} =
      """
      query {
        __schema {
          mutationType {
            name
            fields {
              name
              type {
                name
              }
            }
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.RootLevelErrorsSchema)

    create_post_mutation =
      data["__schema"]["mutationType"]["fields"]
      |> Enum.find(fn field -> field["name"] == "createPost" end)

    assert create_post_mutation["type"]["name"] == "CreatePostResult"
  end
end
