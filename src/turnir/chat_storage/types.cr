require "json"
require "../parser/vk.cr"
require "../parser/twitch"

module Turnir::ChatStorage::Types
  struct VkUserFields
    include JSON::Serializable

    property nickColor : Int32
    property isChatModerator : Bool
    property isChannelModerator : Bool
    property roles : Array(Turnir::Parser::Vk::Role)
    property badges : Array(Turnir::Parser::Vk::Badge)

    def initialize(nickColor : Int32, isChatModerator : Bool, isChannelModerator : Bool, roles : Array(Turnir::Parser::Vk::Role), badges : Array(Turnir::Parser::Vk::Badge))
      @nickColor = nickColor
      @isChatModerator = isChatModerator
      @isChannelModerator = isChannelModerator
      @roles = roles
      @badges = badges
    end
  end

  struct ChatUser
    include JSON::Serializable

    property id : String
    property username : String
    property vk_fields : VkUserFields?
    property twitch_fields : Turnir::Parser::Twitch::UserInfo?

    def initialize(id : String, username : String, vk_fields : VkUserFields? = nil, twitch_fields : Turnir::Parser::Twitch::UserInfo? = nil)
      @id = id
      @username = username
      @vk_fields = vk_fields
      @twitch_fields = twitch_fields
    end
  end

  struct VkMessageFields
    include JSON::Serializable

    property mentions : Array(Turnir::Parser::Vk::ContentDataMention)

    def initialize(mentions : Array(Turnir::Parser::Vk::ContentDataMention))
      @mentions = mentions
    end
  end
end
