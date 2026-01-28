# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

# Test resources for testing generic action mutation errors
# These resources have real generic actions that can be misused in mutation blocks

defmodule AshGraphql.Test.GenericActionErrorTestResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :generic_action_error_test_resource

    mutations do
      # These are WRONG - trying to use generic actions in typed mutation blocks
      # This should trigger our error message
      create :wrong_create_with_generic, :random_action
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    # Real generic action (type: :action) - similar to :random in Post
    action :random_action, :struct do
      constraints(instance_of: __MODULE__)
      allow_nil? true

      run(fn _input, _ ->
        __MODULE__
        |> Ash.Query.limit(1)
        |> Ash.read_one()
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end

defmodule AshGraphql.Test.GenericActionErrorTestResourceUpdate do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :generic_action_error_test_resource_update

    mutations do
      # Wrong usage - generic action in update block
      update :wrong_update_with_generic, :count_action
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    action :count_action, :integer do
      run(fn _input, _ ->
        __MODULE__
        |> Ash.count()
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end

defmodule AshGraphql.Test.GenericActionErrorTestResourceDestroy do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :generic_action_error_test_resource_destroy

    mutations do
      # Wrong usage - generic action in destroy block
      destroy :wrong_destroy_with_generic, :random_action
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    action :random_action, :struct do
      constraints(instance_of: __MODULE__)
      allow_nil? true

      run(fn _input, _ ->
        __MODULE__
        |> Ash.Query.limit(1)
        |> Ash.read_one()
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end

defmodule AshGraphql.Test.GenericActionCorrectUsageResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :generic_action_correct_usage_resource

    mutations do
      # CORRECT usage - generic actions in action blocks
      action(:correct_random, :random_action)
      action(:correct_count, :count_action)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    action :random_action, :struct do
      constraints(instance_of: __MODULE__)
      allow_nil? true

      run(fn _input, _ ->
        __MODULE__
        |> Ash.Query.limit(1)
        |> Ash.read_one()
      end)
    end

    action :count_action, :integer do
      run(fn _input, _ ->
        __MODULE__
        |> Ash.count()
      end)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end

defmodule AshGraphql.Test.GenericActionTypedActionsResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :generic_action_typed_actions_resource

    mutations do
      # CORRECT usage - typed actions in their respective blocks
      create :correct_create, :create
      update :correct_update, :update
      destroy :correct_destroy, :destroy
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end
