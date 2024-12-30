require "./types"
require "../parser/vk"
require "../parser/nuum"
require "../parser/goodgame"

module Turnir::ChatStorage::Types
  struct ChatMessage
    include JSON::Serializable

    property id : Int64
    property ts : Int64
    property message : String
    property user : ChatUser
    property vk_fields : VkMessageFields | Nil
    property channel : String

    def initialize(id : Int64, ts : Int64, message : String, channel : String, user : ChatUser, vkFields : VkMessageFields | Nil = nil)
        @id = id
        @ts = ts
        @message = message
        @user = user
        @vk_fields = vkFields
        @channel = channel
    end

    def self.from_vk_message(message : Turnir::Parser::Vk::ChatMessage, text : String, mentions : Array(Turnir::Parser::Vk::ContentDataMention))
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

    def self.from_nuum_message(message : Turnir::Parser::Nuum::Event, channel : String)

      # convert date "2024-12-26T23:14:59.859Z" to int
      created_at = Time.parse(message.timestamp, "%Y-%m-%dT%H:%M:%S.%LZ", Time::Location::UTC).to_unix

      username = message.author.login
      user_id = message.author.id

      text = message.eventData.text.strip()

      user = ChatUser.new(id: user_id.to_s(), username: username)
      new(id: message.id, ts: created_at, message: text, user: user, channel: channel)
    end

    def self.from_goodgame_message(message : Turnir::Parser::Goodgame::ChatMessage)
      data = message.data
      created_at = data.timestamp
      message_id = data.message_id

      username = data.user_name
      user_id = data.user_id
      channel_id = data.channel_id

      user = ChatUser.new(id: user_id.to_s(), username: username)
      new(id: message_id, ts: created_at, message: data.text, user: user, channel: channel_id)
    end
  end
end
