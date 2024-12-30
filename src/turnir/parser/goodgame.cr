module Turnir::Parser::Goodgame
  struct ChatMessage
    include JSON::Serializable
    property type : String
    property data : Data
  end

  struct Data
    include JSON::Serializable
    property user_id : Int32
    property user_name : String
    property message_id : Int64
    property timestamp : Int64
    property text : String
    property channel_id : String
  end

  struct ChannelInfo
    include JSON::Serializable
    property id : Int32
  end
end
