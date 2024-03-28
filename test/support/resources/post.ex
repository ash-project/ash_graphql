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
  use Ash.Resource.Calculation

  def calculate(posts, _, _) do
    Enum.map(posts, fn post ->
      post.text1 <> post.text2
    end)
  end

  def load(_, _, _), do: [:text1, :text2]
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

  def load(posts, _opts, %{domain: domain}) do
    posts = domain.load!(posts, :tags)

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
          |> Ash.read!()

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
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  require Ash.Query

  policies do
    policy always() do
      authorize_if(always())
    end

    policy action(:count) do
      authorize_if(actor_present())
    end
  end

  graphql do
    type :post

    attribute_types integer_as_string_in_domain: :string
    attribute_input_types integer_as_string_in_domain: :string
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
      action(:post_count, :count)
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

      update :update_post_with_hidden_input, :update do
        hide_inputs([:score])
      end

      destroy :archive_post, :archive
      destroy :delete_post, :destroy
      destroy :delete_best_post, :destroy, read_action: :best_post, identity: false
      destroy :delete_post_with_error, :destroy_with_error

      # this is a mutation just for testing
      action(:random_post, :random)
    end
  end

  actions do
    default_accept(:*)

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

    action :count, :integer do
      argument(:published, :boolean)

      run(fn input, _ ->
        query =
          if input.arguments[:published] do
            Ash.Query.filter(__MODULE__, published == true)
          else
            __MODULE__
          end

        input.domain.count(query)
      end)
    end

    action :random, :struct do
      constraints(instance_of: __MODULE__)
      argument(:published, :boolean)
      allow_nil? true

      run(fn input, _ ->
        __MODULE__
        |> Ash.Query.limit(1)
        |> input.domain.read_one()
      end)
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

    attribute(:text, :string, public?: true)
    attribute(:published, :boolean, default: false, public?: true)
    attribute(:foo, AshGraphql.Test.Foo, public?: true)
    attribute(:status, AshGraphql.Test.Status, public?: true)
    attribute(:status_enum, AshGraphql.Test.StatusEnum, public?: true)

    attribute(:enum_with_ash_graphql_description, AshGraphql.Test.EnumWithAshGraphqlDescription,
      public?: true
    )

    attribute(:enum_with_ash_description, AshGraphql.Test.EnumWithAshDescription, public?: true)
    attribute(:best, :boolean, public?: true)
    attribute(:score, :float, public?: true)
    attribute(:integer_as_string_in_domain, :integer, public?: true)
    attribute(:embed, AshGraphql.Test.Embed, public?: true)
    attribute(:text1, :string, public?: true)
    attribute(:text2, :string, public?: true)
    attribute(:visibility, :atom, constraints: [one_of: [:public, :private]], public?: true)

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
      ],
      public?: true
    )

    attribute(:embed_foo, Foo, public?: true)

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
      ],
      public?: true
    )

    attribute(:embed_union_new_type_list, {:array, AshGraphql.Types.EmbedUnionNewTypeUnnested},
      public?: true
    )

    attribute(:embed_union_new_type, AshGraphql.Types.EmbedUnionNewType, public?: true)
    attribute(:embed_union_unnested, AshGraphql.Types.EmbedUnionNewTypeUnnested, public?: true)
    attribute(:enum_new_type, AshGraphql.Types.EnumNewType, public?: true)
    attribute(:string_new_type, AshGraphql.Types.StringNewType, public?: true)

    attribute :required_string, :string do
      allow_nil? false
      default("test")
      public?(true)
    end

    create_timestamp(:created_at, public?: true)
  end

  calculations do
    calculate(:static_calculation, :string, AshGraphql.Test.StaticCalculation, public?: true)
    calculate(:full_text, :string, FullTextCalculation, public?: true)

    calculate(:text_1_and_2, :string, expr(text1 <> ^arg(:separator) <> text2)) do
      public?(true)

      argument :separator, :string do
        allow_nil? false
        default(" ")
      end
    end

    calculate(
      :post_comments,
      {:array, UnionRelation},
      fn records, _ ->
        # This is very inefficient, do not copy this pattern into your own app!!!
        values =
          Enum.map(records, fn record ->
            [
              SponsoredComment |> Ash.read!(),
              Comment |> Ash.read!()
            ]
            |> List.flatten()
            |> Stream.filter(&(&1.post_id == record.id))
            |> Enum.map(&%Ash.Union{type: UnionRelation.struct_to_name(&1), value: &1})
          end)

        {:ok, values}
      end,
      public?: true
    )
  end

  aggregates do
    count(:comment_count, :comments, public?: true)
    max(:latest_comment_at, [:comments], :timestamp, public?: true)

    first :latest_comment_type, [:comments], :type do
      public?(true)
      sort(timestamp: :desc)
    end
  end

  relationships do
    belongs_to(:author, AshGraphql.Test.User) do
      public?(true)
      attribute_writable?(true)
    end

    has_many(:comments, AshGraphql.Test.Comment, public?: true)
    has_many(:sponsored_comments, AshGraphql.Test.SponsoredComment, public?: true)
    has_many(:paginated_comments, AshGraphql.Test.Comment, read_action: :paginated, public?: true)

    many_to_many(:tags, AshGraphql.Test.Tag,
      through: AshGraphql.Test.PostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id,
      public?: true
    )

    many_to_many(:multitenant_tags, AshGraphql.Test.MultitenantTag,
      through: AshGraphql.Test.MultitenantPostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id,
      public?: true
    )

    many_to_many(:relay_tags, AshGraphql.Test.RelayTag,
      through: AshGraphql.Test.RelayPostTag,
      source_attribute_on_join_resource: :post_id,
      destination_attribute_on_join_resource: :tag_id,
      public?: true
    )

    has_many :related_posts, AshGraphql.Test.Post do
      public?(true)
      manual(RelatedPosts)
      no_attributes?(true)
    end

    has_one(:no_graphql, AshGraphql.Test.NoGraphql, public?: true)
  end
end
