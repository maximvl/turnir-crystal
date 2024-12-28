require "./types"
require "../parsing/vk_message"

module Turnir::ChatStorage::Types
  struct ChatMessage
    include JSON::Serializable

    property id : Int32
    property ts : Int64
    property message : String
    property user : ChatUser
    property vk_fields : VkMessageFields | Nil
    property channel : String

    def initialize(id : Int32, ts : Int64, message : String, channel : String, user : ChatUser, vkFields : VkMessageFields | Nil = nil)
        @id = id
        @ts = ts
        @message = message
        @user = user
        @vk_fields = vkFields
        @channel = channel
    end

    def self.from_vk_message(message : Turnir::Parsing::VkMessage::ChatMessage, text : String, mentions : Array(Turnir::Parsing::VkMessage::ContentDataMention))
      data = message.push.pub.data.data
      created_at = data.createdAt
      message_id = data.id

      author = data.author
      username = author.displayName
      user_id = author.id

      customFields = VkUserFields.new(
        nickColor: author.nickColor,
        isChatModerator: author.isChatModerator,
        isChannelModerator: author.isChannelModerator,
        roles: author.roles,
        badges: author.badges,
      )

      user = ChatUser.new(id: user_id.to_s(), username: username, vk_fields: customFields)
      vkFields = VkMessageFields.new(mentions)
      new(id: message_id, ts: created_at, message: text, user: user, vkFields: vkFields, channel: message.push.channel)
    end

    def self.from_nuum_message(message : Turnir::Parsing::NuumMessage::Event, channel : String)

      # convert date "2024-12-26T23:14:59.859Z" to int
      created_at = Time.parse(message.timestamp, "%Y-%m-%dT%H:%M:%S.%LZ", Time::Location::UTC).to_unix

      username = message.author.login
      user_id = message.author.id

      text = message.eventData.text.strip()

      user = ChatUser.new(id: user_id.to_s(), username: username)
      new(id: message.id, ts: created_at, message: text, user: user, channel: channel)
    end
  end
end
