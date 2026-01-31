# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.ResponseMetadata.Domain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end

defmodule AshGraphql.Test.ResponseMetadata.CustomDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end

defmodule AshGraphql.Test.ResponseMetadata.DisabledDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end

defmodule AshGraphql.Test.ResponseMetadata.RaisingDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end

defmodule AshGraphql.Test.ResponseMetadata.EmptyMapDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end

defmodule AshGraphql.Test.ResponseMetadata.NonMapDomain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
    end
  end

  resources do
  end
end
