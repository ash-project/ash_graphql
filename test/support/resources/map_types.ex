defmodule AshGraphql.Test.MapTypes do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  attributes do
    uuid_primary_key(:id)

    attribute :attributes, :map do
      constraints(
        fields: [
          foo: [
            type: :string
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
    end

    attribute(:json_map, :map)

    attribute :values, AshGraphql.Test.ConstrainedMap do
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    update :inline do
      argument :inline_values, :map do
        constraints(
          fields: [
            foo: [
              type: :string
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
