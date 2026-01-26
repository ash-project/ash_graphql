# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.AfterTransactionMnesia do
  @moduledoc false
  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    data_layer: Ash.DataLayer.Mnesia,
    extensions: [AshGraphql.Resource]

  graphql do
    type :after_transaction_mnesia

    mutations do
      create :create_after_transaction_mnesia, :create
      create :create_after_transaction_mnesia_with_error, :create_with_error
      update :update_after_transaction_mnesia, :update
      update :update_after_transaction_mnesia_with_error, :update_with_error
      destroy :destroy_after_transaction_mnesia, :destroy
      destroy :destroy_after_transaction_mnesia_with_error, :destroy_with_error
    end
  end

  mnesia do
    table(:after_transaction_mnesia_table)
  end

  actions do
    default_accept(:*)
    defaults([:read])

    create :create do
      primary?(true)
      change(AshGraphql.Test.AfterTransactionChange)
    end

    create :create_with_error do
      accept([:name, :value])
      change(AshGraphql.Test.AfterTransactionChange)
      change(AshGraphql.Test.AfterActionErrorChange)
    end

    update :update do
      primary?(true)
      require_atomic?(false)
      change(AshGraphql.Test.AfterTransactionChange)
    end

    update :update_with_error do
      accept([:name, :value])
      require_atomic?(false)
      change(AshGraphql.Test.AfterTransactionChange)
      change(AshGraphql.Test.AfterActionErrorChange)
    end

    destroy :destroy do
      primary?(true)
      require_atomic?(false)
      change(AshGraphql.Test.AfterTransactionChange)
    end

    destroy :destroy_with_error do
      require_atomic?(false)
      change(AshGraphql.Test.AfterTransactionChange)
      change(AshGraphql.Test.AfterActionErrorChange)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:value, :string, public?: true)
  end
end
