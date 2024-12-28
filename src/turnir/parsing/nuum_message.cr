module Turnir::Parsing::NuumMessage
  struct ChatMessage
    include JSON::Serializable
    property push : Push
  end

  struct Push
    include JSON::Serializable
    property channel : String
    property pub : Pub
  end

  struct Pub
    include JSON::Serializable
    property data : PubData
  end

  struct PubData
    include JSON::Serializable
    property id : Int32
    property type : String
    property createdAt : String
    property data : PubDataData
    property author : Author
  end

  struct PubDataData
    include JSON::Serializable
    property type : String
    property text : String
  end

  struct Author
    include JSON::Serializable
    property userId : Int32
    property login : String
    property isSubscriber : Bool
  end

  struct ChannelResponse
    include JSON::Serializable
    property result : ChannelInfo
  end

  struct ChannelInfo
    include JSON::Serializable
    property channel_id : Int32
    property channel_is_live : Bool
    property media_container : MediaContainer
  end

  struct MediaContainer
    include JSON::Serializable
    property media_container_id : Int32
    property media_container_type : String
  end

  struct ChatResponse
    include JSON::Serializable
    property result : ChatInfo
  end

  struct ChatInfo
    include JSON::Serializable
    property id : Int32
  end
end
