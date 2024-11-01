module Turnir::ChatStorage::Types
  struct VkUserFields
    include JSON::Serializable

    property nickColor : Int32
    property isChatModerator : Bool
    property isChannelModerator : Bool
    property roles : Array(Turnir::Parsing::VkMessage::Role)
    property badges : Array(Turnir::Parsing::VkMessage::Badge)

    def initialize(nickColor : Int32, isChatModerator : Bool, isChannelModerator : Bool, roles : Array(Turnir::Parsing::VkMessage::Role), badges : Array(Turnir::Parsing::VkMessage::Badge))
      @nickColor = nickColor
      @isChatModerator = isChatModerator
      @isChannelModerator = isChannelModerator
      @roles = roles
      @badges = badges
    end
  end

  struct ChatUser
    include JSON::Serializable

    property id : Int32
    property username : String
    property vk_fields : VkUserFields?

    def initialize(id : Int32, username : String, vk_fields : VkUserFields? = nil)
      @id = id
      @username = username
      @vk_fields = vk_fields
    end
  end

  struct VkMessageFields
    include JSON::Serializable

    property mentions : Array(Turnir::Parsing::VkMessage::ContentDataMention)

    def initialize(mentions : Array(Turnir::Parsing::VkMessage::ContentDataMention))
      @mentions = mentions
    end
  end
end
