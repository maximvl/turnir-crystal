require "json"

module Turnir::WSClient
  struct ChatMessage
    include JSON::Serializable
    property push : Push
  end

  struct Push
    include JSON::Serializable
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
    property data : Array(ContentData)
  end

  struct Author
    include JSON::Serializable
    property id : Int32
    property displayName : String
  end

  struct ContentData
    include JSON::Serializable
    property type : String
    property content : String
  end
end
