defmodule AshGraphql.Resource.Transformers.ValidateCompatibleNames do
  # Ensures that all field names are valid or remapped to something valid exist
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def after_compile?, do: true

  def transform(dsl) do
    field_names = AshGraphql.Resource.Info.field_names(dsl)
    argument_names = AshGraphql.Resource.Info.argument_names(dsl)
    resource = Transformer.get_persisted(dsl, :module)

    dsl
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(Ash.Resource.Info.public_aggregates(dsl))
    |> Enum.concat(Ash.Resource.Info.public_calculations(dsl))
    |> Enum.concat(Ash.Resource.Info.public_relationships(dsl))
    |> Enum.filter(&AshGraphql.Resource.Info.show_field?(resource, &1.name))
    |> Enum.each(fn field ->
      name = field_names[field.name] || field.name

      if invalid_name?(name) do
        raise_invalid_name_error(resource, field, name)
      end
    end)

    dsl
    |> Transformer.get_entities([:graphql, :queries])
    |> Enum.concat(Transformer.get_entities(dsl, [:graphql, :mutations]))
    |> Enum.map(& &1.action)
    |> Enum.uniq()
    |> Enum.each(fn action ->
      action = Ash.Resource.Info.action(dsl, action)

      Enum.each(action.arguments, fn argument ->
        name = argument_names[action.name][argument.name] || argument.name

        if invalid_name?(name) do
          raise_invalid_argument_name_error(resource, action, argument.name, name)
        end
      end)
    end)

    {:ok, dsl}
  end

  defp invalid_name?(name) do
    Regex.match?(~r/_+\d/, to_string(name))
  end

  defp raise_invalid_name_error(resource, field, name) do
    path =
      case field do
        %Ash.Resource.Relationships.BelongsTo{} -> [:relationships, :belongs_to, field.name]
        %Ash.Resource.Relationships.HasMany{} -> [:relationships, :has_many, field.name]
        %Ash.Resource.Relationships.HasOne{} -> [:relationships, :has_one, field.name]
        %Ash.Resource.Relationships.ManyToMany{} -> [:relationships, :many_to_many, field.name]
        %Ash.Resource.Calculation{} -> [:calculations, field.name]
        %Ash.Resource.Aggregate{} -> [:aggregates, field.name]
        %Ash.Resource.Attribute{} -> [:attributes, field.name]
      end

    raise Spark.Error.DslError,
      module: resource,
      path: path,
      message: """
      Name #{name} is invalid.

      Due to issues in the underlying tooling with camel/snake case conversion of names that
      include underscores immediately preceding integers, a different name must be provided to
      use in the graphql. To do so, add a mapping in your configured field_names, i.e

          graphql do
            ...

            field_names #{name}: :#{make_name_better(name)}

            ...
          end


      For more information on the underlying issue, see: https://github.com/absinthe-graphql/absinthe/issues/601
      """
  end

  defp raise_invalid_argument_name_error(resource, action, argument_name, name) do
    path = [:actions, action.type, action.name, :argument, argument_name]

    raise Spark.Error.DslError,
      module: resource,
      path: path,
      message: """
      Name #{name} is invalid.

      Due to issues in the underlying tooling with camel/snake case conversion of names that
      include underscores immediately preceding integers, a different name must be provided to
      use in the graphql. To do so, add a mapping in your configured argument_names, i.e

          graphql do
            ...

            argument_names #{action.name}: [#{argument_name}: :#{make_name_better(name)}]

            ...
          end


      For more information on the underlying issue, see: https://github.com/absinthe-graphql/absinthe/issues/601
      """
  end

  defp make_name_better(name) do
    name
    |> to_string()
    |> String.replace(~r/_+\d/, fn v ->
      String.trim_leading(v, "_")
    end)
  end
end
