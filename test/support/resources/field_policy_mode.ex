# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.FieldPolicyModeOrg do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type(:field_policy_mode_org)
  end

  actions do
    default_accept(:*)

    defaults([:create, :read])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true, allow_nil?: false)
  end

  policies do
    policy action_type(:create) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(actor_attribute_equals(:can_read_org, true))
    end
  end
end

defmodule AshGraphql.Test.FieldPolicyMode do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type(:field_policy_mode)
    field_policy_mode(:materialized)

    queries do
      get(:get_field_policy_mode, :read)
    end
  end

  actions do
    default_accept(:*)

    defaults([:create, :read])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :visible, :string do
      public?(true)
      allow_nil?(false)
      default("visible")
    end

    attribute :secret, :string do
      public?(true)
      allow_nil?(false)
      default("secret")
    end

    attribute(:maybe_secret, :string, public?: true)
  end

  relationships do
    belongs_to :org, AshGraphql.Test.FieldPolicyModeOrg do
      public?(true)
      allow_nil?(false)
      allow_forbidden_field?(true)
      authorize_read_with(:error)
    end
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :secret do
      forbid_if(always())
    end

    field_policy :maybe_secret do
      authorize_if(actor_attribute_equals(:can_read_secret, true))
    end

    field_policy :* do
      authorize_if(always())
    end
  end
end

defmodule AshGraphql.Test.FieldPolicyNullableMode do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type(:field_policy_nullable_mode)
    field_policy_mode(:nullable)

    queries do
      get(:get_field_policy_nullable_mode, :read)
    end
  end

  actions do
    default_accept(:*)

    defaults([:create, :read])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :visible, :string do
      public?(true)
      allow_nil?(false)
      default("visible")
    end

    attribute :secret, :string do
      public?(true)
      allow_nil?(false)
      default("secret")
    end
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :secret do
      forbid_if(always())
    end

    field_policy :* do
      authorize_if(always())
    end
  end
end
