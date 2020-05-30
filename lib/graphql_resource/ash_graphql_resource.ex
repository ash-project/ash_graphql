defmodule AshGraphql.GraphqlResource do
  defmacro __using__(_) do
    quote do
      @extensions AshGraphql.GraphqlResource
    end
  end

  @doc false
  def before_compile_hook(_env) do
    quote do
      :ok
    end
  end
end
