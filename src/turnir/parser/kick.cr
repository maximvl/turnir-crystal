module Turnir::Parser::Kick
  struct ChatMessage
    include JSON::Serializable
    property message_id : String
    property broadcaster : Broadcaster
    property sender : Sender
    property content : String
  end

  struct Broadcaster
    include JSON::Serializable
    property user_id : Int64
    property username : String
    property channel_slug : String
  end

  struct Sender
    include JSON::Serializable
    property user_id : Int64
    property username : String
    property identity : SenderIdentity
  end

  struct SenderIdentity
    include JSON::Serializable
    property username_color : String
    property badges : Array(Badge)
  end

  struct Badge
    include JSON::Serializable
    property type : String
    property text : String
  end
end
