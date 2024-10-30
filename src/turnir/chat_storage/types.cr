module Turnir::ChatStorage::Types
  struct VkCustomFields
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
    vk_fields : VkCustomFields?

    def initialize(id : Int32, username : String, vk_fields : VkCustomFields? = nil)
      @id = id
      @username = username
      @vk_fields = vk_fields
    end
  end
end
