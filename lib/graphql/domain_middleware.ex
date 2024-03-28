defmodule AshGraphql.Graphql.DomainMiddleware do
  @moduledoc false
  def set_domain(resolution, domain) do
    Map.update!(resolution, :context, &Map.put(&1, :domain, domain))
  end
end
