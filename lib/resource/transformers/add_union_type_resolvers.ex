defmodule AshGraphql.Resource.Transformers.AddUnionTypeResolvers do
  # Set the computation of resolving union types as functions
  @moduledoc false
  use Spark.Dsl.Transformer

  def after?(_), do: true

  # sobelow_skip ["DOS.BinToAtom"]
  def transform(dsl_state) do
    dsl_state
    |> AshGraphql.Resource.get_auto_unions()
    |> Enum.concat(dsl_state |> AshGraphql.Resource.global_unions() |> Enum.map(&elem(&1, 1)))
    |> Enum.map(fn attribute ->
      if Ash.Type.NewType.new_type?(attribute.type) do
        cond do
          function_exported?(attribute.type, :graphql_type, 0) ->
            attribute.type.graphql_type()

          function_exported?(attribute.type, :graphql_type, 1) ->
            attribute.type.graphql_type(attribute.constraints)

          true ->
            AshGraphql.Resource.atom_enum_type(dsl_state, attribute.name)
        end
      else
        AshGraphql.Resource.atom_enum_type(dsl_state, attribute.name)
      end
    end)
    |> Enum.uniq()
    |> Enum.reduce(
      {:ok, dsl_state},
      fn type_name, {:ok, dsl_state} ->
        {:ok,
         Spark.Dsl.Transformer.eval(
           dsl_state,
           [],
           quote do
             # sobelow_skip ["DOS.BinToAtom"]
             def unquote(:"resolve_gql_union_#{type_name}")(%Ash.Union{type: type}, _) do
               # sobelow_skip ["DOS.BinToAtom"]
               :"#{unquote(type_name)}_#{type}"
             end

             def unquote(:"resolve_gql_union_#{type_name}")(value, _) do
               value.__union_type__
             end
           end
         )}
      end
    )
  end
end
