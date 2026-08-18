# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.DeprecationTest do
  use ExUnit.Case

  alias AshGraphql.Test.Schema

  test "deprecations are exposed for every generated root operation" do
    assert {:ok, %{data: data}} =
             Absinthe.run(
               """
               query {
                 __schema {
                   queryType {
                     fields(includeDeprecated: true) {
                       name
                       isDeprecated
                       deprecationReason
                     }
                   }
                   mutationType {
                     fields(includeDeprecated: true) {
                       name
                       isDeprecated
                       deprecationReason
                     }
                   }
                   subscriptionType {
                     fields(includeDeprecated: true) {
                       name
                       isDeprecated
                       deprecationReason
                     }
                   }
                 }
                 groupType: __type(name: "ContentQueryGroup") {
                   fields(includeDeprecated: true) {
                     name
                     isDeprecated
                     deprecationReason
                   }
                 }
               }
               """,
               Schema
             )

    query_fields = data["__schema"]["queryType"]["fields"]
    mutation_fields = data["__schema"]["mutationType"]["fields"]
    subscription_fields = data["__schema"]["subscriptionType"]["fields"]
    grouped_query_fields = data["groupType"]["fields"]

    assert_deprecation(query_fields, "deprecatedGetPost", nil)
    assert_deprecation(query_fields, "deprecatedPostCount", "Use `postCount` instead.")

    assert_deprecation(
      query_fields,
      "deprecatedDomainGetComment",
      "Use `getComment` instead."
    )

    assert_deprecation(
      mutation_fields,
      "deprecatedCreatePost",
      "Use `createPost` instead."
    )

    assert_deprecation(mutation_fields, "deprecatedRandomPost", nil)

    assert_deprecation(
      subscription_fields,
      "subscribableEvents",
      "Use `subscribedOnDomain` instead."
    )

    assert_deprecation(subscription_fields, "subscribedOnDomain", nil)
    assert_deprecation(grouped_query_fields, "gqDeprecatedStats", nil)

    assert %{
             "isDeprecated" => false,
             "deprecationReason" => nil
           } = field(query_fields, "getPost")
  end

  test "deprecated operations are omitted from introspection by default" do
    assert {:ok, %{data: %{"__type" => %{"fields" => fields}}}} =
             Absinthe.run(
               """
               query {
                 __type(name: "RootQueryType") {
                   fields {
                     name
                   }
                 }
               }
               """,
               Schema
             )

    names = Enum.map(fields, & &1["name"])

    assert "getPost" in names
    refute "deprecatedGetPost" in names
    refute "deprecatedPostCount" in names
    refute "deprecatedDomainGetComment" in names
  end

  test "SDL includes deprecated directives with and without reasons" do
    sdl = Absinthe.Schema.to_sdl(Schema)

    assert sdl =~ ~r/deprecatedGetPost\([^)]*\): Post @deprecated\n/s

    assert sdl =~
             ~s|deprecatedPostCount(published: Boolean): Int! @deprecated(reason: "Use `postCount` instead.")|
  end

  defp assert_deprecation(fields, name, reason) do
    assert %{
             "isDeprecated" => true,
             "deprecationReason" => ^reason
           } = field(fields, name)
  end

  defp field(fields, name) do
    Enum.find(fields, &(&1["name"] == name))
  end
end
