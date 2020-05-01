# defmodule AshGraphql.GraphqlResource.ResourceTypes do
#   defmacro define_types(name, attributes, relationships) do
#     quote do
#       name = unquote(name)
#       attributes = Enum.map(unquote(attributes), &Map.to_list/1)
#       relationships = Enum.map(unquote(relationships), &Map.to_list/1)

#       defmodule __MODULE__.GraphqlTypes do
#         use Absinthe.Schema.Notation

#         quote do
#           object unquote(String.to_atom(name)) do
#             for attribute <- unquote(attributes) do
#               if attribute[:name] == :id and attribute[:primary_key?] do
#                 field :id, :id
#               else
#                 quote do
#                   field unquote(attribute[:name]), unquote(attribute[:type])
#                 end
#               end
#             end
#           end
#         end
#       end
#     end
#   end
# end
