defmodule AshGraphql.Notation do
  @moduledoc """
  Provides Absinthe.Schema.Notation helpers for Ash domains.
  """

  alias AshGraphql.Builder
  alias AshGraphql.Notation.Builder, as: NotationBuilder

  defmacro __using__(opts) do
    context = Builder.compile_context(opts)

    quote bind_quoted: [
            action_middleware: Macro.escape(context.action_middleware),
            all_domains: Macro.escape(context.all_domains),
            ash_resources: Macro.escape(context.ash_resources),
            auto_generate_sdl_file?: context.auto_generate_sdl_file?,
            auto_import_types: Macro.escape(context.auto_import_types),
            define_relay_types?: context.define_relay_types?,
            domains: Macro.escape(context.domains),
            domains_with_resources: Macro.escape(context.domains_with_resources),
            generate_sdl_file: context.generate_sdl_file,
            relay_ids?: context.relay_ids?
          ],
          location: :keep,
          generated: true do
      use Absinthe.Schema.Notation

      @after_compile AshGraphql.Codegen

      @generate_sdl_file generate_sdl_file
      @auto_generate_sdl_file? auto_generate_sdl_file?

      @ash_resources ash_resources
      @all_domains all_domains

      def generate_sdl_file, do: @generate_sdl_file
      def auto_generate_sdl_file?, do: @auto_generate_sdl_file?
      def ash_graphql_schema?, do: true

      Enum.each(@ash_resources, &Code.ensure_compiled!/1)

      if auto_import_types do
        Code.eval_quoted(auto_import_types, [], __ENV__)
      end

      for resource <- @ash_resources do
        resource
        |> AshGraphql.Resource.global_unions(@all_domains)
        |> Enum.map(&elem(&1, 1))
        |> Enum.map(fn attribute ->
          if function_exported?(attribute.type, :graphql_type, 1) do
            attribute.type.graphql_type(attribute.constraints)
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.each(fn type_name ->
          def unquote(:"resolve_gql_union_#{type_name}")(%Ash.Union{type: type}, _) do
            :"#{unquote(type_name)}_#{type}"
          end

          def unquote(:"resolve_gql_union_#{type_name}")(value, _) do
            value.__union_type__
          end
        end)
      end

      schema = __MODULE__
      env = __ENV__

      Module.put_attribute(__MODULE__, :ash_graphql_type_identifiers, [])

      {query_containers, mutation_containers, subscription_containers} =
        Enum.reduce(domains, {[], [], []}, fn {domain, resources, first?},
                                              {query_acc, mutation_acc, subscription_acc} ->
          domain_queries =
            AshGraphql.Domain.queries(
              domain,
              @all_domains,
              resources,
              action_middleware,
              schema,
              relay_ids?
            )

          relay_queries =
            if first? and define_relay_types? and relay_ids? do
              AshGraphql.relay_queries(domains_with_resources, @all_domains, schema, env)
            else
              []
            end

          query_fields = relay_queries ++ domain_queries

          query_acc =
            NotationBuilder.add_container(
              __MODULE__,
              schema,
              env,
              domain,
              :query,
              query_fields,
              query_acc
            )

          mutation_fields =
            AshGraphql.Domain.mutations(
              domain,
              @all_domains,
              resources,
              action_middleware,
              schema,
              relay_ids?
            )

          mutation_acc =
            NotationBuilder.add_container(
              __MODULE__,
              schema,
              env,
              domain,
              :mutation,
              mutation_fields,
              mutation_acc
            )

          subscription_fields =
            AshGraphql.Domain.subscriptions(
              domain,
              @all_domains,
              resources,
              action_middleware,
              schema,
              relay_ids?
            )

          subscription_acc =
            NotationBuilder.add_container(
              __MODULE__,
              schema,
              env,
              domain,
              :subscription,
              subscription_fields,
              subscription_acc
            )

          managed_relationship_types =
            Process.get(:managed_relationship_requirements, [])
            |> AshGraphql.Resource.managed_relationship_definitions(schema)
            |> Enum.uniq_by(& &1.identifier)

          Enum.each(managed_relationship_types, fn definition ->
            NotationBuilder.put_definition(__MODULE__, definition)
          end)

          type_definitions =
            if first? do
              embedded_types =
                AshGraphql.get_embedded_types(@ash_resources, @all_domains, schema, relay_ids?)

              global_maps =
                AshGraphql.global_maps(@ash_resources, @all_domains, schema, env)

              global_enums =
                AshGraphql.global_enums(@ash_resources, @all_domains, schema, env)

              global_unions =
                AshGraphql.global_unions(@ash_resources, @all_domains, schema, env)

              Enum.uniq_by(
                AshGraphql.Domain.global_type_definitions(schema, env) ++
                  AshGraphql.Domain.type_definitions(
                    domain,
                    @all_domains,
                    resources,
                    schema,
                    env,
                    true,
                    define_relay_types?,
                    relay_ids?
                  ) ++
                  global_maps ++
                  global_enums ++
                  global_unions ++
                  embedded_types,
                & &1.identifier
              )
            else
              AshGraphql.Domain.type_definitions(
                domain,
                @all_domains,
                resources,
                schema,
                env,
                false,
                false,
                relay_ids?
              )
            end

          Enum.each(type_definitions, fn definition ->
            NotationBuilder.put_definition(__MODULE__, definition)
          end)

          {query_acc, mutation_acc, subscription_acc}
        end)

      query_containers = Enum.reverse(query_containers)
      mutation_containers = Enum.reverse(mutation_containers)
      subscription_containers = Enum.reverse(subscription_containers)

      @ash_graphql_query_containers query_containers
      @ash_graphql_mutation_containers mutation_containers
      @ash_graphql_subscription_containers subscription_containers

      def query_containers, do: @ash_graphql_query_containers
      def mutation_containers, do: @ash_graphql_mutation_containers
      def subscription_containers, do: @ash_graphql_subscription_containers

      defmacro import_queries do
        NotationBuilder.import_macro_ast(@ash_graphql_query_containers)
      end

      defmacro import_mutations do
        NotationBuilder.import_macro_ast(@ash_graphql_mutation_containers)
      end

      defmacro import_subscriptions do
        NotationBuilder.import_macro_ast(@ash_graphql_subscription_containers)
      end
    end
  end
end
