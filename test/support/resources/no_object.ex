defmodule AshGraphql.Test.NoObject do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    generate_object? false

    queries do
      action :no_object_count, :count
    end
  end

  actions do
    defaults([:read, :create])

    action :count, {:array, :integer} do
      run(fn _input, _context ->
        {:ok, [1, 2, 3, 4, 5]}
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, public?: true)
  end
end
