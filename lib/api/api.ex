defmodule AshGraphql.Api do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @mix_ins AshGraphql.Api
      @authorize Keyword.get(opts, :authorize?, true)
      @max_complexity Keyword.get(opts, :max_complexity, 50)
    end
  end

  def before_compile_hook(_env) do
    quote do
      use AshGraphql.Api.Schema, resources: @resources, api: __MODULE__

      def graphql_authorize? do
        @authorize
      end

      def graphql_max_complexity() do
        @max_complexity
      end
    end
  end
end
