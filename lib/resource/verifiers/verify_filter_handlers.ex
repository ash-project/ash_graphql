# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Resource.Verifiers.VerifyFilterHandlers do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Transformer

  @allowed_types [:id, :string, :integer]

  def verify(dsl) do
    resource = Transformer.get_persisted(dsl, :module)
    filter_handlers = AshGraphql.Resource.Info.filter_handlers(dsl)

    if is_nil(filter_handlers) do
      :ok
    else
      if not is_list(filter_handlers) do
        raise Spark.Error.DslError,
          module: resource,
          message: """
          Invalid value for `filter_handlers`: #{inspect(filter_handlers)}.

          `filter_handlers` must be a keyword list, for example:

              filter_handlers [
                id: [type: :id, handler: {MyMod, :my_fun, [:my_type]}]
              ]
          """
      end

      Enum.each(filter_handlers, fn
        {field, config} when is_atom(field) and is_list(config) ->
          validate_handler_config(resource, field, config)

        other ->
          raise Spark.Error.DslError,
            module: resource,
            message: """
            Invalid entry `#{inspect(other)}` in `filter_handlers`.

            Each entry must be a field name and keyword config, for example:

                id: [type: :id, handler: {MyMod, :my_fun, [:my_type]}]
            """
      end)

      :ok
    end
  end

  defp validate_handler_config(resource, field, config) do
    if !Ash.Resource.Info.attribute(resource, field) do
      raise Spark.Error.DslError,
        module: resource,
        path: [:graphql, :filter_handlers],
        message: """
        Unknown attribute `#{inspect(field)}` in `filter_handlers`.
        """
    end

    if !AshGraphql.Resource.Info.filterable_field?(resource, field) do
      raise Spark.Error.DslError,
        module: resource,
        path: [:graphql, :filter_handlers],
        message: """
        Field `#{inspect(field)}` in `filter_handlers` must also be filterable.
        """
    end

    type = Keyword.get(config, :type)

    if type not in @allowed_types do
      raise Spark.Error.DslError,
        module: resource,
        path: [:graphql, :filter_handlers],
        message: """
        Invalid type `#{inspect(type)}` for field `#{inspect(field)}` in `filter_handlers`.

        Allowed types are: #{Enum.map_join(@allowed_types, ", ", &inspect/1)}
        """
    end

    case Keyword.get(config, :handler) do
      {module, function, extra_args}
      when is_atom(module) and is_atom(function) and is_list(extra_args) ->
        :ok

      other ->
        raise Spark.Error.DslError,
          module: resource,
          path: [:graphql, :filter_handlers],
          message: """
          Invalid handler `#{inspect(other)}` for field `#{inspect(field)}` in `filter_handlers`.

          Handlers must be MFA tuples, for example `{MyMod, :my_fun, [:extra_arg]}`.
          """
    end
  end
end
