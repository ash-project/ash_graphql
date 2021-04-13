defprotocol AshGraphql.Error do
  def to_error(exception)
end

defimpl AshGraphql.Error, for: Ash.Error.Query.InvalidQuery do
  def to_error(error) do
    %{
      message: Exception.message(error),
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidAttribute do
  def to_error(error) do
    %{
      message: Exception.message(error),
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.InvalidArgument do
  def to_error(error) do
    %{
      message: Exception.message(error),
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.InvalidArgument do
  def to_error(error) do
    %{
      message: Exception.message(error),
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Changes.Required do
  def to_error(error) do
    %{
      message: "is required",
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.NotFound do
  def to_error(error) do
    %{
      message: "could not be found",
      fields: Map.keys(error.primary_key || %{}),
      code: Ash.ErrorKind.code(error)
    }
  end
end

defimpl AshGraphql.Error, for: Ash.Error.Query.Required do
  def to_error(error) do
    %{
      message: "is required",
      code: Ash.ErrorKind.code(error),
      fields: [error.field]
    }
  end
end
