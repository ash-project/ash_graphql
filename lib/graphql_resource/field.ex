defmodule AshGraphql.GraphqlResource.Field do
  defstruct [:name, :action, :type]

  def new(name, action, opts) do
    if opts[:type] && opts[:type] not in [:read, :get] do
      raise "Can only specify `read` or `get` for `type`"
    end

    %__MODULE__{
      name: name,
      action: action,
      type: opts[:type] || :read
    }
  end
end
