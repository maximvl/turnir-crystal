module Turnir::Parsing::NuumMessage
  struct EventsResponse
    include JSON::Serializable
    property result : Array(Event)
  end

  struct Event
    include JSON::Serializable
    property id : Int32
    property eventType : String
    property timestamp : String
    property eventData : EventData
    property author : Author
  end

  struct EventData
    include JSON::Serializable
    property type : String
    property text : String
  end

  struct Author
    include JSON::Serializable
    property id : Int32
    property login : String
    property isSubscriber : Bool
  end

  struct ChannelResponse
    include JSON::Serializable
    property result : ChannelInfo
  end

  struct ChannelInfo
    include JSON::Serializable
    property channel : Channel
    property media_container : MediaContainer
  end

  struct Channel
    include JSON::Serializable
    property channel_id : Int32
    property channel_name : String
    property channel_is_live : Bool
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
