module Turnir::Parser::Goodgame
  struct ChatEvent
    include JSON::Serializable
    property type : String
    property data : JSON::Any
  end

  struct MessageData
    include JSON::Serializable
    property user_id : Int32
    property user_name : String
    property message_id : Int64
    property timestamp : Int64
    property text : String
    property channel_id : String
  end

  struct JoinData
    include JSON::Serializable
    property channel_key : String
    property channel_id : String
  end

  struct ChannelInfo
    include JSON::Serializable
    property id : Int32
  end
end
