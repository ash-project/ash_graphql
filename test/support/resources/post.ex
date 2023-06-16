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

defmodule ReturnResourceError do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.add_error(
      changeset,
      Ash.Error.Changes.InvalidAttribute.exception(
        message: "%{var}",
        vars: [var: "hello"],
        field: :foo
      )
    )
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

defmodule RelatedPosts do
  @moduledoc false
  use Ash.Resource.ManualRelationship
  require Ash.Query

  def load(posts, _opts, %{api: api}) do
    posts = api.load!(posts, :tags)

    {
      :ok,
      posts
      |> Enum.map(fn post ->
        tag_ids =
          post.tags
          |> Enum.map(& &1.id)

        other_posts =
          AshGraphql.Test.Post
          |> Ash.Query.filter(tags.id in ^tag_ids)
          |> Ash.Query.filter(id != ^post.id)
          |> api.read!()

        {post.id, other_posts}
      end)
      |> Map.new()
    }
  end
end

defmodule AshGraphql.Test.Post do
  @moduledoc false
  alias AshGraphql.Test.Comment
  alias AshGraphql.Test.SponsoredComment

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  require Ash.Query

  graphql do
    type :post

    attribute_types integer_as_string_in_api: :string
    attribute_input_types integer_as_string_in_api: :string
    field_names text_1_and_2: :text1_and2
    keyset_field :keyset

    queries do
      get :get_post, :read
      list :post_library, :library
      list :post_score, :score
      list :paginated_posts, :paginated
      list :keyset_paginated_posts, :keyset_paginated
      list :paginated_posts_without_limit, :paginated_without_limit
      list :paginated_posts_limit_not_required, :paginated_limit_not_required
    end

    managed_relationships do
      managed_relationship :with_comments, :comments
      managed_relationship :update_with_comments, :comments, lookup_with_primary_key?: true

      managed_relationship :with_comments_and_tags, :comments,
        lookup_with_primary_key?: true,
        type_name: :create_post_comment_with_tag

      managed_relationship :with_comments_and_tags, :tags,
        lookup_with_primary_key?: false,
        lookup_identities: [:name]
    end

    mutations do
      create :simple_create_post, :create
      create :create_post_with_error, :create_with_error
      create :create_post_with_required_error, :create_with_required_error
      create :create_post, :create_confirm
      create :upsert_post, :upsert, upsert?: true

      create :create_post_with_comments, :with_comments
      create :create_post_with_comments_and_tags, :with_comments_and_tags

      update :update_post, :update
      update :update_post_with_comments, :update_with_comments
      update :update_post_confirm, :update_confirm
      update :update_best_post, :update, read_action: :best_post, identity: false
      update :update_best_post_arg, :update, read_action: :best_post_arg, identity: false

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

    create :create_with_required_error do
      change(ReturnResourceError)
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
      argument(:sponsored_comments, {:array, :map})

      change(manage_relationship(:comments, type: :direct_control))
      change(manage_relationship(:sponsored_comments, type: :direct_control))
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

    read :keyset_paginated do
      pagination(
        required?: true,
        keyset?: true,
        countable: true,
        default_limit: 20
      )
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

    read :best_post_arg do
      argument(:best, :boolean, allow_nil?: false)

      prepare(fn query, _ ->
        Ash.Query.filter(query, best == ^query.arguments.best)
      end)
    end

    update :update, primary?: true

    update :update_with_comments do
      argument(:comments, {:array, :map})
      argument(:sponsored_comments, {:array, :map})

      change(manage_relationship(:comments, type: :direct_control))
      change(manage_relationship(:sponsored_comments, type: :direct_control))
    end

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
    attribute(:integer_as_string_in_api, :integer)
    attribute(:embed, AshGraphql.Test.Embed)
    attribute(:text1, :string)
    attribute(:text2, :string)
    attribute(:visibility, :atom, constraints: [one_of: [:public, :private]])

    attribute(:simple_union, :union,
      constraints: [
        types: [
          int: [
            type: :integer
          ],
          string: [
            type: :string
          ]
        ]
      ]
    )

    attribute(:embed_foo, Foo)

    attribute(:embed_union, :union,
      constraints: [
        types: [
          foo: [
            type: Foo,
            tag: :type,
            tag_value: :foo
          ],
          bar: [
            type: Bar,
            tag: :type,
            tag_value: :bar
          ]
        ]
      ]
    )

    attribute(:embed_union_new_type_list, {:array, AshGraphql.Types.EmbedUnionNewTypeUnnested})
    attribute(:embed_union_new_type, AshGraphql.Types.EmbedUnionNewType)
    attribute(:embed_union_unnested, AshGraphql.Types.EmbedUnionNewTypeUnnested)
    attribute(:enum_new_type, AshGraphql.Types.EnumNewType)
    attribute(:string_new_type, AshGraphql.Types.StringNewType)

    attribute :required_string, :string do
      allow_nil? false
      default("test")
    end

    create_timestamp(:created_at, private?: false)
  end

  calculations do
    calculate(:static_calculation, :string, AshGraphql.Test.StaticCalculation)
    calculate(:full_text, :string, FullTextCalculation)

    calculate(:text_1_and_2, :string, expr(text1 <> ^arg(:separator) <> text2)) do
      argument :separator, :string do
        allow_nil? false
        default(" ")
      end
    end

    calculate(:post_comments, {:array, UnionRelation}, fn record, _ ->
      # This is very inefficient, do not copy this pattern into your own app!!!
      values =
        [
          SponsoredComment |> AshGraphql.Test.Api.read!(),
          Comment |> AshGraphql.Test.Api.read!()
        ]
        |> List.flatten()
        |> Stream.filter(&(&1.post_id == record.id))
        |> Enum.map(&%Ash.Union{type: UnionRelation.struct_to_name(&1), value: &1})

      {:ok, values}
    end)
  end

  aggregates do
    count(:comment_count, :comments)
  end

  relationships do
    belongs_to(:author, AshGraphql.Test.User)

    has_many(:comments, AshGraphql.Test.Comment)
    has_many(:sponsored_comments, AshGraphql.Test.SponsoredComment)
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

    has_many :related_posts, AshGraphql.Test.Post do
      manual(RelatedPosts)
      no_attributes?(true)
    end
  end
end
