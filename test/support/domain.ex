# SPDX-FileCopyrightText: 2020 ash_graphql contributors <https://github.com/ash-project/ash_graphql/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGraphql.Test.Domain do
  @moduledoc false

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ],
    otp_app: :ash_graphql

  graphql do
    queries do
      get AshGraphql.Test.Comment, :get_comment, :read
      list AshGraphql.Test.Post, :post_score, :score
    end

    subscriptions do
      pubsub AshGraphql.Test.PubSub

      subscribe AshGraphql.Test.Subscribable, :subscribed_on_domain do
        action_types(:create)
      end

      subscribe AshGraphql.Test.DomainLevelPubsubResource, :domain_pubsub_subscription do
        action_types([:create, :update, :destroy])
      end
    end
  end

  resources do
    resource(AshGraphql.Test.Actor)
    resource(AshGraphql.Test.ActorAgent)
    resource(AshGraphql.Test.Agent)
    resource(AshGraphql.Test.Award)
    resource(AshGraphql.Test.Comment)
    resource(AshGraphql.Test.CompositePrimaryKey)
    resource(AshGraphql.Test.CompositePrimaryKeyNotEncoded)
    resource(AshGraphql.Test.DoubleRelRecursive)
    resource(AshGraphql.Test.DoubleRelToRecursiveParentOfEmbed)
    resource(AshGraphql.Test.MapTypes)
    resource(AshGraphql.Test.Movie)
    resource(AshGraphql.Test.MovieActor)
    resource(AshGraphql.Test.MultitenantPostTag)
    resource(AshGraphql.Test.MultitenantTag)
    resource(AshGraphql.Test.NoGraphql)
    resource(AshGraphql.Test.NoObject)
    resource(AshGraphql.Test.NonIdPrimaryKey)
    resource(AshGraphql.Test.Post)
    resource(AshGraphql.Test.PostTag)
    resource(AshGraphql.Test.RelayPostTag)
    resource(AshGraphql.Test.RelayTag)
    resource(AshGraphql.Test.Review)
    resource(AshGraphql.Test.SponsoredComment)
    resource(AshGraphql.Test.Tag)
    resource(AshGraphql.Test.User)
    resource(AshGraphql.Test.Channel)
    resource(AshGraphql.Test.ChannelSimple)
    resource(AshGraphql.Test.Message)
    resource(AshGraphql.Test.MessageViewableUser)
    resource(AshGraphql.Test.TextMessage)
    resource(AshGraphql.Test.ImageMessage)
    resource(AshGraphql.Test.Subscribable)
    resource(AshGraphql.Test.DomainLevelPubsubResource)
    resource(AshGraphql.Test.ResourceLevelPubsubResource)
    resource(AshGraphql.Test.ErrorHandling)
    resource(AshGraphql.Test.ResourceWithTypeInsideType)
    resource(AshGraphql.Test.Product)
    resource(AshGraphql.Test.ResourceWithUnion)
    resource(AshGraphql.Test.ResourceWithTypedStruct)
    resource(AshGraphql.Test.GenericActionCorrectUsageResource)
    resource(AshGraphql.Test.GenericActionTypedActionsResource)
  end
end
