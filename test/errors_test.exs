# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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

  describe "when root level errors are enabled" do
    test "errors that occur are shown at the root level" do
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

    test "the root level errors field is not present when no errors occur" do
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
              "confirmation" => "foobar"
            }
          }
        )

      assert {:ok, result} = resp

      assert %{
               data: %{
                 "createPost" => %{
                   "result" => %{"text" => "foobar"},
                   "errors" => []
                 }
               }
             } = result

      refute Map.has_key?(result, :errors)
    end
  end

  test "raised errors are by default not shown" do
    defmodule TestLoggerHandler do
      def log(log_event, %{config: %{test_pid: test_pid}}) do
        send(test_pid, {:log_event, log_event})
      end
    end

    :logger.add_handler(
      TestLoggerHandler,
      TestLoggerHandler,
      %{level: :error, config: %{test_pid: self()}}
    )

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

    assert_receive {
      :log_event,
      %{
        level: :error,
        msg: _msg,
        meta: %{
          crash_reason: {
            %Ash.Error.Invalid{errors: [%Ash.Error.Changes.Required{}]},
            [_ | _] = _stacktrace
          }
        }
      }
    }
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

  test "error items are a non-nullable list of non-nullables" do
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
                  kind
                  ofType {
                    name
                  }
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

    assert errors == %{
             "name" => "errors",
             "type" => %{
               "kind" => "NON_NULL",
               "ofType" => %{
                 "kind" => "LIST",
                 "ofType" => %{
                   "kind" => "NON_NULL",
                   "ofType" => %{"name" => "MutationError"}
                 }
               }
             }
           }
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

  defmodule DomainLevelErrorHandler do
    # Allow error messages to remain un-interpolated (the opposite of the default error handler)
    def handle_error(error, _context) do
      error
    end
  end

  test "default error handler is not also applied when an error handler is defined on domain" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
      graphql: [error_handler: {DomainLevelErrorHandler, :handle_error, []}]
    )

    resp =
      """
      mutation CreatePostWithLengthConstraint($input: CreatePostWithLengthConstraintInput) {
        createPostWithLengthConstraint(input: $input) {
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
            "text" => "too long"
          }
        }
      )

    assert {:ok, %{data: %{"createPostWithLengthConstraint" => %{"errors" => [errors]}}}} = resp
    assert %{"message" => message} = errors
    assert message == "must have length of no more than %{max}"
  end

  test "errors can be intercepted at resource level" do
    variables = %{
      "input" => %{
        "name" => "name"
      }
    }

    document =
      """
      mutation CreateErrorHandling($input: CreateErrorHandlingInput!) {
        createErrorHandling(input: $input) {
          result {
            name
          }
          errors{
            message
          }
        }
      }
      """

    Absinthe.run(document, AshGraphql.Test.Schema, variables: variables)

    %{data: %{"createErrorHandling" => %{"errors" => [error]}}} =
      Absinthe.run!(document, AshGraphql.Test.Schema, variables: variables)

    assert error["message"] =~ "replaced!"
  end

  test "errors carry action in context" do
    create_variables = %{
      "input" => %{
        "name" => "name"
      }
    }

    create_document =
      """
      mutation CreateErrorHandling($input: CreateErrorHandlingInput!) {
        createErrorHandling(input: $input) {
          result {
            id
            name
          }
          errors{
            message
          }
        }
      }
      """

    %{data: %{"createErrorHandling" => %{"result" => %{"id" => id}}}} =
      Absinthe.run!(create_document, AshGraphql.Test.Schema, variables: create_variables)

    update_variables = %{
      "id" => id,
      "input" => %{
        "name" => "new_name"
      }
    }

    update_document =
      """
      mutation UpdateErrorHandling($id: ID!, $input: UpdateErrorHandlingInput!) {
        updateErrorHandling(id: $id, input: $input) {
          result {
            name
          }
          errors{
            message
          }
        }
      }
      """

    %{data: %{"updateErrorHandling" => %{"errors" => [error]}}} =
      Absinthe.run!(update_document, AshGraphql.Test.Schema, variables: update_variables)

    assert error["message"] == "replaced! update"
  end

  test "errors are transformed into correct responses" do
    message = "incorrect email"

    errors =
      AshGraphql.Errors.to_errors(
        [
          Ash.Error.Query.InvalidQuery.exception(
            field: :email,
            message: message
          )
        ],
        %{},
        AshGraphql.Test.Domain,
        nil,
        nil
      )

    assert [
             %{
               code: "invalid_query",
               message: message,
               fields: [:email],
               vars: %{},
               short_message: message,
               path: ["email"]
             }
           ] == errors
  end

  describe "path field" do
    test "path field is included in error responses with camelCase field name" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Changes.InvalidArgument.exception(
              field: :variant_key,
              message: "invalid value"
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          ["input", "override"]
        )

      assert [
               %{
                 code: "invalid_argument",
                 message: "invalid value",
                 fields: [:variant_key],
                 path: ["input", "override", "variantKey"]
               }
             ] = errors
    end

    test "path field converts snake_case to camelCase" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :user_name,
              message: "invalid"
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "userName"]
               }
             ] = errors
    end

    test "path field respects graphql field name overrides (field_names/1)" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :text_1_and_2,
              message: "invalid"
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          nil,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:text_1_and_2],
                 # post.ex has: field_names text_1_and_2: :text1_and2
                 path: ["input", "text1And2"]
               }
             ] = errors
    end

    test "path maps each Ash.Error.path segment using DSL mappings (stepwise)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :user_name,
          message: "invalid"
        )
        |> Ash.Error.set_path([:text_1_and_2])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          nil,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 # Ash.Error.path was [:text_1_and_2] which is mapped via field_names to :text1_and2
                 # then camelCased to "text1And2"
                 path: ["input", "text1And2", "userName"]
               }
             ] = errors
    end

    test "path stepwise mapping supports list index segments (integers)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :user_name,
          message: "invalid"
        )
        |> Ash.Error.set_path([:text_1_and_2, 0])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          nil,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "text1And2", "0", "userName"]
               }
             ] = errors
    end

    test "path building does not crash when resource/action are nil" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :user_name,
              message: "invalid"
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "userName"]
               }
             ] = errors
    end

    test "path field is nil when no path information is available" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Forbidden.Policy.exception(
              vars: %{}
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          nil
        )

      assert [
               %{
                 code: "forbidden",
                 fields: [],
                 path: nil
               }
             ] = errors
    end

    test "path field appears in GraphQL mutation error response" do
      resp =
        """
        mutation CreatePost($input: CreatePostInput) {
          createPost(input: $input) {
            result {
              text
            }
            errors {
              message
              code
              fields
              path
            }
          }
        }
        """
        |> Absinthe.run(AshGraphql.Test.Schema,
          variables: %{
            "input" => %{
              "text" => "foobar",
              "confirmation" => "foobar2"
            }
          }
        )

      assert {:ok, result} = resp

      assert %{
               data: %{
                 "createPost" => %{
                   "errors" => [error]
                 }
               }
             } = result

      assert %{"code" => _, "message" => _, "fields" => _, "path" => path} = error
      assert is_list(path) or is_nil(path)
    end

    test "path field is included in MutationError schema" do
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

      path_field =
        data["__type"]["fields"]
        |> Enum.find(fn field -> field["name"] == "path" end)

      assert path_field != nil
      assert path_field["name"] == "path"
      assert path_field["type"]["kind"] == "LIST"
      assert path_field["type"]["ofType"]["kind"] == "NON_NULL"
      assert path_field["type"]["ofType"]["ofType"]["name"] == "String"
    end

    test "path handles Ash error path with string segments" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :user_name,
          message: "invalid"
        )
        |> Ash.Error.set_path(["input", "foo", "bar"])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          nil,
          nil
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "foo", "bar", "userName"]
               }
             ] = errors
    end

    test "path is built from ash path only when error has no :fields (no field name appended)" do
      # Forbidden has fields: [] in error map; path should be resolved segments only.
      error =
        Ash.Error.Forbidden.Policy.exception(vars: %{})
        |> Ash.Error.set_path([:input])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          nil
        )

      assert [
               %{
                 code: "forbidden",
                 path: ["input"]
               }
             ] = errors
    end

    test "path building does not crash when action name is invalid (action_struct nil)" do
      errors =
        AshGraphql.Errors.to_errors(
          [
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :user_name,
              message: "invalid"
            )
          ],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          :nonexistent_action,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "userName"]
               }
             ] = errors
    end

    test "path resolves union argument and variant segment (composite type)" do
      # ResourceWithUnion has action_with_union_arg with argument :union_arg (Union type).
      # Union has variants member_map, member_string, etc. Path [:union_arg, :member_map]
      # should resolve to ["unionArg", "memberMap"].
      error =
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :value,
          message: "invalid"
        )
        |> Ash.Error.set_path([:union_arg, :member_map])

      action = Ash.Resource.Info.action(AshGraphql.Test.ResourceWithUnion, :action_with_union_arg)

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.ResourceWithUnion,
          action,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:value],
                 path: ["input", "unionArg", "memberMap", "value"]
               }
             ] = errors
    end

    test "path with string segment in Ash path is resolved (camelCase)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :name, message: "invalid")
        |> Ash.Error.set_path([:union_arg, "member_map"])

      action = Ash.Resource.Info.action(AshGraphql.Test.ResourceWithUnion, :action_with_union_arg)

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.ResourceWithUnion,
          action,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:name],
                 path: ["input", "unionArg", "memberMap", "name"]
               }
             ] = errors
    end

    test "path when error has no :fields (path from segments only)" do
      error =
        Ash.Error.Forbidden.Policy.exception(vars: %{})
        |> Ash.Error.set_path([:override])

      action = Ash.Resource.Info.action(AshGraphql.Test.Post, :create_confirm)

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          action,
          ["input"]
        )

      assert [
               %{
                 code: "forbidden",
                 fields: [],
                 path: ["input", "override"]
               }
             ] = errors
    end

    test "path resolves union argument and variant segment (composite)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :name, message: "invalid")
        |> Ash.Error.set_path([:union_arg, :member_map])

      action = Ash.Resource.Info.action(AshGraphql.Test.ResourceWithUnion, :action_with_union_arg)

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.ResourceWithUnion,
          action,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:name],
                 path: ["input", "unionArg", "memberMap", "name"]
               }
             ] = errors
    end

    test "path resolves map-with-fields composite (nested argument type)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :foo_bar, message: "required")
        |> Ash.Error.set_path([:module_values])

      action = Ash.Resource.Info.action(AshGraphql.Test.MapTypes, :module)

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.MapTypes,
          action,
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:foo_bar],
                 path: ["input", "moduleValues", "fooBar"]
               }
             ] = errors
    end

    test "path with list index then field (array-of-composite)" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :user_name, message: "invalid")
        |> Ash.Error.set_path([:text_1_and_2, 0])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          Ash.Resource.Info.action(AshGraphql.Test.Post, :create_confirm),
          ["input"]
        )

      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "text1And2", "0", "userName"]
               }
             ] = errors
    end

    test "path with unknown segment type falls back to name resolution" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :user_name, message: "invalid")
        |> Ash.Error.set_path([:text_1_and_2, :unknown_segment])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          Ash.Resource.Info.action(AshGraphql.Test.Post, :create_confirm),
          ["input"]
        )

      # unknown_segment not in schema; falls back to camelCase
      assert [
               %{
                 code: "invalid_attribute",
                 fields: [:user_name],
                 path: ["input", "text1And2", "unknownSegment", "userName"]
               }
             ] = errors
    end

    test "multiple errors with different paths each get correct path" do
      e1 =
        Ash.Error.Changes.InvalidAttribute.exception(field: :user_name, message: "invalid")
        |> Ash.Error.set_path([])

      e2 =
        Ash.Error.Changes.InvalidAttribute.exception(field: :text_1_and_2, message: "invalid")
        |> Ash.Error.set_path([])

      errors =
        AshGraphql.Errors.to_errors(
          [e1, e2],
          %{},
          AshGraphql.Test.Domain,
          AshGraphql.Test.Post,
          Ash.Resource.Info.action(AshGraphql.Test.Post, :create_confirm),
          ["input"]
        )

      assert [
               %{path: ["input", "userName"]},
               %{path: ["input", "text1And2"]}
             ] = errors
    end

    test "path uses only resolution path when Ash path is empty and no field" do
      error =
        Ash.Error.Forbidden.Policy.exception(vars: %{})
        |> Ash.Error.set_path([])

      errors =
        AshGraphql.Errors.to_errors(
          [error],
          %{},
          AshGraphql.Test.Domain,
          nil,
          nil,
          ["input", "nested"]
        )

      assert [%{code: "forbidden", fields: [], path: ["input", "nested"]}] = errors
    end
  end
end
