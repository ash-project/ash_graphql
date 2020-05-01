defmodule AshGraphql.TestSchema do
  use Absinthe.Schema
  # filename: myapp/schema.ex
  @desc "An item"
  object :item do
    field :id, :id
    field :name, :string
  end

  # Example data
  @items %{
    "foo" => %{id: "foo", name: "Foo"},
    "bar" => %{id: "bar", name: "Bar"}
  }

  query do
    field :item, :item do
      arg :id, non_null(:id)

      resolve fn %{id: item_id}, _ ->
        {:ok, @items[item_id]}
      end
    end

    field :items, non_null(list_of(non_null(:item))) do
      resolve fn ->
        {:ok, @items}
      end
    end
  end

  mutation do
    field :create_item, type: :item do
      arg :id, non_null(:id)
    end
  end
end
