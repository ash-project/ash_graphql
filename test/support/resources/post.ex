defmodule AshGraphql.Test.Post do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :post

    queries do
      get :get_post, :read
      list :post_library, :library
    end

    managed_relationships do
      managed_relationship(:with_comments, :comments)
    end

    mutations do
      create :create_post, :create_confirm
      create :upsert_post, :upsert, upsert?: true

      create :create_post_with_comments, :with_comments

      update :update_post, :update
      destroy :delete_post, :destroy
    end
  end

  actions do
    create :create do
      primary?(true)
    end

    create :upsert do
      argument(:id, :uuid)

      change(AshGraphql.Test.ForceChangeId)
    end

    create :create_confirm do
      argument(:confirmation, :string)
      validate(confirm(:text, :confirmation))
    end

    create :with_comments do
      argument(:comments, {:array, :map})

      change(manage_relationship(:comments, type: :direct_control))
    end

    read(:read, primary?: true)

    read :library do
      argument(:published, :boolean, default: true)

      filter(
        expr do
          published == ^arg(:published)
        end
      )
    end

    update(:update)
    destroy(:destroy)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string)
    attribute(:published, :boolean, default: false)
    attribute(:foo, AshGraphql.Test.Foo)
    attribute(:status, AshGraphql.Test.Status)
  end

  calculations do
    calculate(:static_calculation, :string, AshGraphql.Test.StaticCalculation)
  end

  relationships do
    has_many(:comments, AshGraphql.Test.Comment)
  end
end
