defmodule AshGraphql.NotationTest.DomainNotation do
  use AshGraphql.Notation,
    domains: [AshGraphql.Test.Domain],
    relay_ids?: true
end

defmodule AshGraphql.NotationTest.DomainSchema do
  use Absinthe.Schema

  import_types(AshGraphql.NotationTest.DomainNotation)

  query do
    AshGraphql.NotationTest.DomainNotation.import_queries()
  end

  mutation do
    AshGraphql.NotationTest.DomainNotation.import_mutations()
  end

  subscription do
    AshGraphql.NotationTest.DomainNotation.import_subscriptions()
  end
end

defmodule DecimalResourceOne do
  use Ash.Resource,
    domain: AshGraphql.NotationTest.DecimalDomainOne,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :decimal_resource_one

    queries do
      get :get_decimal_resource_one, :read
    end
  end

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:amount, :decimal, public?: true)
  end
end

defmodule DecimalResourceTwo do
  use Ash.Resource,
    domain: AshGraphql.NotationTest.DecimalDomainTwo,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource]

  graphql do
    type :decimal_resource_two

    queries do
      get :get_decimal_resource_two, :read
    end
  end

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:amount, :decimal, public?: true)
  end
end

defmodule AshGraphql.NotationTest.DecimalDomainOne do
  use Ash.Domain,
    extensions: [AshGraphql.Domain],
    otp_app: :ash_graphql

  resources do
    resource(AshGraphql.NotationTest.DecimalResourceOne)
  end
end

defmodule AshGraphql.NotationTest.DecimalDomainTwo do
  use Ash.Domain,
    extensions: [AshGraphql.Domain],
    otp_app: :ash_graphql

  resources do
    resource(AshGraphql.NotationTest.DecimalResourceTwo)
  end
end

defmodule AshGraphql.NotationTest.DecimalNotationOne do
  use AshGraphql.Notation,
    domains: [AshGraphql.NotationTest.DecimalDomainOne]
end

defmodule AshGraphql.NotationTest.DecimalNotationTwo do
  use AshGraphql.Notation,
    domains: [AshGraphql.NotationTest.DecimalDomainTwo]
end

defmodule AshGraphql.NotationTest.DecimalSchema do
  use Absinthe.Schema

  import_types(AshGraphql.NotationTest.DecimalNotationOne)
  import_types(AshGraphql.NotationTest.DecimalNotationTwo)

  query do
    AshGraphql.NotationTest.DecimalNotationOne.import_queries()
    AshGraphql.NotationTest.DecimalNotationTwo.import_queries()
  end
end
