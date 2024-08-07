defmodule AshGraphql.Resource.Info do
  @moduledoc "Introspection helpers for AshGraphql.Resource"

  alias Spark.Dsl.Extension

  @doc "The queries exposed for the resource"
  def queries(resource, domain_or_domains \\ []) do
    module =
      if is_atom(resource) do
        resource
      else
        Spark.Dsl.Extension.get_persisted(resource, :module)
      end

    domain_or_domains
    |> List.wrap()
    |> Enum.flat_map(&AshGraphql.Domain.Info.queries/1)
    |> Enum.filter(&(&1.resource == module))
    |> Enum.concat(Extension.get_entities(resource, [:graphql, :queries]))
  end

  @doc "The mutations exposed for the resource"
  def mutations(resource, domain_or_domains \\ []) do
    module =
      if is_atom(resource) do
        resource
      else
        Spark.Dsl.Extension.get_persisted(resource, :module)
      end

    domain_or_domains
    |> List.wrap()
    |> Enum.flat_map(&AshGraphql.Domain.Info.mutations/1)
    |> Enum.filter(&(&1.resource == module))
    |> Enum.concat(Extension.get_entities(resource, [:graphql, :mutations]) || [])
  end

  @doc "The subscriptions exposed for the resource"
  def subscriptions(resource) do
    Extension.get_entities(resource, [:graphql, :subscriptions]) || []
  end

  def subscription_pubsub(resource) do
    Extension.get_opt(resource, [:graphql, :subscriptions], :pubsub)
  end

  @doc "Wether or not to encode the primary key as a single `id` field when reading and getting"
  def encode_primary_key?(resource) do
    Extension.get_opt(resource, [:graphql], :encode_primary_key?, true)
  end

  @doc "The managed_relationship configurations"
  def managed_relationships(resource) do
    Extension.get_entities(resource, [:graphql, :managed_relationships]) || []
  end

  def managed_relationships_auto?(resource) do
    Extension.get_opt(resource, [:graphql, :managed_relationships], :auto?, true)
  end

  @doc "The managed_relationshi configuration for a given action/argument"
  def managed_relationship(resource, action, argument) do
    resource
    |> Extension.get_entities([:graphql, :managed_relationships])
    |> List.wrap()
    |> Enum.find(fn managed_relationship ->
      managed_relationship.argument == argument.name and
        managed_relationship.action == action.name
    end)
    |> then(fn managed_relationship ->
      if managed_relationship && managed_relationship.ignore? do
        nil
      else
        if managed_relationships_auto?(resource) do
          managed_relationship || default_managed_relationship(action, argument)
        else
          managed_relationship
        end
      end
    end)
  end

  defp default_managed_relationship(action, argument) do
    if Enum.any?(Map.get(action, :changes, []), fn
         %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
           opts[:argument] == argument.name

         _ ->
           nil
       end) && map_type?(argument.type) do
      %AshGraphql.Resource.ManagedRelationship{
        argument: argument.name,
        action: action,
        types: [],
        type_name: nil,
        lookup_with_primary_key?: true,
        lookup_identities: []
      }
    end
  end

  defp map_type?({:array, type}), do: map_type?(type)
  defp map_type?(Ash.Type.Map), do: true
  defp map_type?(:map), do: true
  defp map_type?(_), do: false

  @doc "The graphql type of the resource"
  def type(resource) do
    Extension.get_opt(resource, [:graphql], :type, nil)
  end

  @doc "Wether or not to derive a filter input for the resource automatically"
  def derive_filter?(resource) do
    Extension.get_opt(resource, [:graphql], :derive_filter?, true)
  end

  @doc "Wether or not to derive a sort input for the resource automatically"
  def derive_sort?(resource) do
    Extension.get_opt(resource, [:graphql], :derive_sort?, true)
  end

  @doc "Graphql type overrides for the resource"
  def attribute_types(resource) do
    Extension.get_opt(resource, [:graphql], :attribute_types, [])
  end

  @doc "Graphql nullability overrides for the resource"
  def nullable_fields(resource) do
    Extension.get_opt(resource, [:graphql], :nullable_fields, [])
  end

  @doc "The field name to place the keyset of a result in"
  def keyset_field(resource) do
    Extension.get_opt(resource, [:graphql], :keyset_field, nil)
  end

  @doc "Graphql field name (attribute/relationship/calculation/arguments) overrides for the resource"
  def field_names(resource) do
    Extension.get_opt(resource, [:graphql], :field_names, [])
  end

  @doc "Fields to hide from the graphql domain"
  def hide_fields(resource) do
    Extension.get_opt(resource, [:graphql], :hide_fields, [])
  end

  @doc "Fields to show in the graphql domain"
  def show_fields(resource) do
    Extension.get_opt(resource, [:graphql], :show_fields, nil)
  end

  @doc "Wether or not a given field will be shown"
  def show_field?(resource, field) do
    hide_fields = hide_fields(resource)
    show_fields = show_fields(resource) || [field]

    field not in hide_fields and field in show_fields
  end

  @doc "Which relationships should be included in the generated type"
  def relationships(resource) do
    Extension.get_opt(resource, [:graphql], :relationships, nil) ||
      resource |> Ash.Resource.Info.public_relationships() |> Enum.map(& &1.name)
  end

  @doc "Pagination configuration for list relationships"
  def paginate_relationship_with(resource) do
    Extension.get_opt(resource, [:graphql], :paginate_relationship_with, [])
  end

  @doc "Graphql argument name overrides for the resource"
  def argument_names(resource) do
    Extension.get_opt(resource, [:graphql], :argument_names, [])
  end

  @doc "Graphql attribute input type overrides for the resource"
  def attribute_input_types(resource) do
    Extension.get_opt(resource, [:graphql], :attribute_input_types, [])
  end

  @doc "Graphql argument type overrides for the resource"
  def argument_input_types(resource) do
    Extension.get_opt(resource, [:graphql], :argument_input_types, [])
  end

  @doc "The delimiter for a resource with a composite primary key"
  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:graphql], :primary_key_delimiter, "-")
  end

  @doc "Wether or not an object should be generated, or if one with the type name for this resource should be used."
  def generate_object?(resource) do
    Extension.get_opt(resource, [:graphql], :generate_object?, true)
  end

  @doc "Fields that may be filtered on"
  def filterable_fields(resource) do
    Extension.get_opt(resource, [:graphql], :filterable_fields, nil)
  end

  @doc "May the specified field be filtered on?"
  def filterable_field?(resource, field_name) do
    filterable_fields = AshGraphql.Resource.Info.filterable_fields(resource)

    is_nil(filterable_fields) or field_name in filterable_fields
  end
end
