require "json"

module Turnir::Parser::Vk
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
    property type : String
    property data : PubDataData
  end

  struct PubDataData
    include JSON::Serializable
    property id : Int32
    property createdAt : Int32
    property author : Author
    property data : Array(ContentDataMention | ContentDataText | IgnoredData)
  end

  struct ContentDataText
    include JSON::Serializable
    property type : String
    property content : String
  end

  struct ContentDataMention
    include JSON::Serializable
    property type : String
    property id : Int32
    property displayName : String
  end

  struct IgnoredData
    include JSON::Serializable
  end

  struct Author
    include JSON::Serializable
    property id : Int32
    property displayName : String
    property nickColor : Int32
    property isChatModerator : Bool
    property isChannelModerator : Bool
    property roles : Array(Role)
    property badges : Array(Badge)
  end

  struct Role
    include JSON::Serializable
    property id : String
    property name : String
    property largeUrl : String
    property priority : Int32
  end

  struct Badge
    include JSON::Serializable
    property id : String
    property name : String
    property largeUrl : String
    property achievement : Achievement
  end

  struct Achievement
    include JSON::Serializable
    property name : String
    property type : String
  end
end
