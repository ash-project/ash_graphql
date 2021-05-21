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
      list :post_score, :score
      list :paginated_posts, :paginated
    end

    managed_relationships do
      managed_relationship :with_comments, :comments

      managed_relationship :with_comments_and_tags, :comments,
        type_name: :create_post_comment_with_tag

      managed_relationship :with_comments_and_tags, :tags,
        lookup_with_primary_key?: false,
        lookup_identities: [:name]
    end

    mutations do
      create :create_post, :create_confirm
      create :upsert_post, :upsert, upsert?: true

      create :create_post_with_comments, :with_comments
      create :create_post_with_comments_and_tags, :with_comments_and_tags

      update :update_post, :update
      update :update_best_post, :update, read_action: :best_post, identity: false

      destroy :archive_post, :archive
      destroy :delete_post, :destroy
      destroy :delete_best_post, :destroy, read_action: :best_post, identity: false
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

    create :with_comments_and_tags do
      argument(:comments, {:array, :map})
      argument(:tags, {:array, :map}, allow_nil?: false)

      change(manage_relationship(:comments, on_lookup: :relate, on_no_match: :create))
      change(manage_relationship(:tags, on_lookup: :relate, on_no_match: :create))
    end

    read :paginated do
      pagination(required?: true, offset?: true, countable: true)
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

    read :score do
      argument(:score, :float, allow_nil?: true)

      filter(expr(score == ^arg(:score)))
    end

    read :best_post do
      filter(expr(best == true))
    end

    update(:update)
    destroy(:destroy, primary?: true)

    destroy :archive do
      soft? true
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:text, :string)
    attribute(:published, :boolean, default: false)
    attribute(:foo, AshGraphql.Test.Foo)
    attribute(:status, AshGraphql.Test.Status)
    attribute(:status_enum, AshGraphql.Test.StatusEnum)
    attribute(:best, :boolean)
    attribute(:score, :float)
    attribute(:embed, AshGraphql.Test.Embed)
  end

  calculations do
    calculate(:static_calculation, :string, AshGraphql.Test.StaticCalculation)
  end

  relationships do
    has_many(:comments, AshGraphql.Test.Comment)
    has_many(:paginated_comments, AshGraphql.Test.Comment, read_action: :paginated)

    many_to_many(:tags, AshGraphql.Test.Tag,
      through: AshGraphql.Test.PostTag,
      source_field_on_join_table: :post_id,
      destination_field_on_join_table: :tag_id
    )
  end
end
