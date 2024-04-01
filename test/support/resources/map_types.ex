defmodule AshGraphql.Test.MapTypes do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  attributes do
    uuid_primary_key(:id)

    attribute :attributes, :map do
      constraints(
        fields: [
          foo: [
            type: :string,
            allow_nil?: false
          ],
          bar: [
            type: :integer
          ],
          baz: [
            type: :map
          ]
        ]
      )

      allow_nil? false
      public?(true)
    end

    attribute(:json_map, :map, public?: true)

    attribute :values, AshGraphql.Test.ConstrainedMap do
      public?(true)
    end
  end

  actions do
    default_accept(:*)

    defaults([:create, :read, :update, :destroy])

    update :inline do
      argument :inline_values, :map do
        constraints(
          fields: [
            foo: [
              type: :string,
              allow_nil?: false
            ],
            bar: [
              type: :integer
            ]
          ]
        )
      end
    end

    update :module do
      argument(:module_values, AshGraphql.Test.ConstrainedMap)
    end
  end

  graphql do
    type :map_types

    queries do
      list :list_map_types, :read
    end

    mutations do
      update :inline_update_map_types, :inline
      update :module_update_map_types, :module
    end
  end
end
