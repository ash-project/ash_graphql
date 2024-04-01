defprotocol AshGraphql.Error do
  def to_error(exception)
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidChanges do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      vars: Map.new(error.vars),
      fields: List.wrap(error.fields)
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.InvalidQuery do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      vars: Map.new(error.vars),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Page.InvalidKeyset do
  def to_error(error) do
    %{
      message: "Invalid value provided as a keyset for %{key}: %{value}",
      short_message: "invalid keyset",
      vars: Map.merge(Map.new(error.vars), %{value: inspect(error.value), key: error.key}),
      fields: List.wrap(Map.get(error, :key))
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidAttribute do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      vars: Map.new(error.vars),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidArgument do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      vars: Map.new(error.vars),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.InvalidArgument do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      vars: Map.new(error.vars),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.Required do
  def to_error(error) do
    %{
      message: "is required",
      short_message: "is required",
      vars: error.vars,
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.NotFound do
  def to_error(error) do
    %{
      message: "could not be found",
      short_message: "could not be found",
      fields: Map.keys(error.primary_key || %{}),
      vars: error.vars
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.Required do
  def to_error(error) do
    %{
      message: "is required",
      short_message: "is required",
      vars: error.vars,
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Forbidden.Policy do
  def to_error(error) do
    message =
      if Application.get_env(:ash_graphql, :policies)[:show_policy_breakdowns?] ||
           false do
        Ash.Error.Forbidden.Policy.report(error, help_text?: false)
      else
        "forbidden"
      end

    %{
      message: message,
      short_message: "forbidden",
      vars: Map.new(error.vars),
      code: "forbidden",
      fields: []
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Forbidden.ForbiddenField do
  def to_error(_error) do
    %{
      message: "forbidden field",
      short_message: "forbidden field",
      vars: %{},
      code: "forbidden_field",
      fields: []
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Invalid.InvalidPrimaryKey do
  def to_error(error) do
    %{
      message: "invalid primary key provided",
      short_message: "invalid primary key provided",
      fields: [],
      vars: Map.new(error.vars)
    }
  end
end
