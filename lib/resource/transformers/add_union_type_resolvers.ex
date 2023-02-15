defmodule AshGraphql.Resource.Transformers.AddUnionTypeResolvers do
  @moduledoc "Set the computation of resolving union types as functions"
  use Spark.Dsl.Transformer

  def after?(_), do: true

  # sobelow_skip ["DOS.BinToAtom"]
  def transform(dsl_state) do
    dsl_state
    |> AshGraphql.Resource.get_auto_unions()
    |> Enum.reduce(
      {:ok, dsl_state},
      fn attribute, {:ok, dsl_state} ->
        type_name = AshGraphql.Resource.atom_enum_type(dsl_state, attribute.name)

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
           end
         )}
      end
    )
  end
end
