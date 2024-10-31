require "./types"
require "../parsing/vk_message"

module Turnir::ChatStorage::Types
  struct ChatMessage
    include JSON::Serializable

    property id : Int32
    property ts : Int32
    property message : String
    property user : ChatUser

    def initialize(id : Int32, ts : Int32, message : String, user : ChatUser)
        @id = id
        @ts = ts
        @message = message
        @user = user
    end

    def self.from_vk_message(message : Turnir::Parsing::VkMessage::ChatMessage, text : String, mentions : Array(Turnir::Parsing::VkMessage::ContentDataMention))
      data = message.push.pub.data.data
      created_at = data.createdAt
      message_id = data.id

      author = data.author
      username = author.displayName
      user_id = author.id

      customFields = VkCustomFields.new(
        nickColor: author.nickColor,
        isChatModerator: author.isChatModerator,
        isChannelModerator: author.isChannelModerator,
        roles: author.roles,
        badges: author.badges,
        mentions: mentions,
      )

      user = ChatUser.new(id: user_id, username: username, vk_fields: customFields)
      new(id: message_id, ts: created_at, message: text.downcase, user: user)
    end
  end
end
