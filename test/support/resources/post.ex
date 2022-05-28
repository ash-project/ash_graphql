defmodule SetMetadata do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      {:ok, Ash.Resource.put_metadata(result, :foo, "bar")}
    end)
  end
end

defmodule RaiseResourceError do
  @moduledoc false
  use Ash.Resource.Change

  def change(_changeset, _, _) do
    raise Ash.Error.Changes.Required, field: :foo, type: :attribute
  end
end

defmodule FullTextCalculation do
  @moduledoc false
  use Ash.Calculation

  def calculate(posts, _, _) do
    Enum.map(posts, fn post ->
      post.text1 <> post.text2
    end)
  end

  def select(_, _, _), do: [:text1, :text2]
end

defmodule AfterActionRaiseResourceError do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.after_action(changeset, fn _changeset, _record ->
      {:error, %Ash.Error.Query.NotFound{}}
    end)
  end
end

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
      list :paginated_posts_without_limit, :paginated_without_limit
      list :paginated_posts_limit_not_required, :paginated_limit_not_required
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
      create :simple_create_post, :create
      create :create_post_with_error, :create_with_error
      create :create_post, :create_confirm
      create :upsert_post, :upsert, upsert?: true

      create :create_post_with_comments, :with_comments
      create :create_post_with_comments_and_tags, :with_comments_and_tags

      update :update_post, :update
      update :update_post_confirm, :update_confirm
      update :update_best_post, :update, read_action: :best_post, identity: false

      destroy :archive_post, :archive
      destroy :delete_post, :destroy
      destroy :delete_best_post, :destroy, read_action: :best_post, identity: false
      destroy :delete_post_with_error, :destroy_with_error
    end
  end

  actions do
    create :create do
      primary?(true)
      metadata(:foo, :string)
      argument(:author_id, :uuid)

      change(SetMetadata)
      change(set_attribute(:author_id, arg(:author_id)))
    end

    create :create_with_error do
      change(RaiseResourceError)
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
      pagination(required?: true, offset?: true, countable: true, default_limit: 20)
    end

    read :paginated_without_limit do
      pagination(required?: true, offset?: true, countable: true)
    end

    read :paginated_limit_not_required do
      pagination(required?: false, offset?: true, countable: true)
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

    update :update, primary?: true

    update :update_confirm do
      argument(:confirmation, :string)
      validate(confirm(:text, :confirmation))
    end

    destroy(:destroy, primary?: true)

    destroy :archive do
      soft?(true)
      change(set_attribute(:deleted_at, &DateTime.utc_now/0))
    end

    destroy :destroy_with_error do
      change(AfterActionRaiseResourceError)
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
    attribute(:text1, :string)
    attribute(:text2, :string)
  end

  calculations do
    calculate(:static_calculation, :string, AshGraphql.Test.StaticCalculation)
    calculate(:full_text, :string, FullTextCalculation)
  end

  relationships do
    belongs_to(:author, AshGraphql.Test.User)

    has_many(:comments, AshGraphql.Test.Comment)
    has_many(:paginated_comments, AshGraphql.Test.Comment, read_action: :paginated)

    many_to_many(:tags, AshGraphql.Test.Tag,
      through: AshGraphql.Test.PostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id
    )

    many_to_many(:multitenant_tags, AshGraphql.Test.MultitenantTag,
      through: AshGraphql.Test.MultitenantPostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id
    )

    many_to_many(:relay_tags, AshGraphql.Test.RelayTag,
      through: AshGraphql.Test.RelayPostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id
    )
  end
end
