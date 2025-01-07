module Turnir::Parser::Twitch
  struct UserInfo
    include JSON::Serializable
    property color : String | Nil
    property display_name : String | Nil
    property badges : Array(BadgeVersion)

    def initialize(color : String | Nil, display_name : String | Nil, badges : Array(BadgeVersion))
      @color = color
      @display_name = display_name
      @badges = badges
    end
  end

  struct Badge
    include JSON::Serializable
    property name : String
    property version_id : String
  end

  struct BadgeInfo
    include JSON::Serializable
    property name : Badge
    property version_id : String
  end

  struct BadgesResponse
    include JSON::Serializable
    property data : Array(BadgeData)
  end

  struct BadgeData
    include JSON::Serializable
    property set_id : String
    property versions : Array(BadgeVersion)
  end

  struct BadgeVersion
    include JSON::Serializable
    property id : String
    property image_url_4x : String
    property title : String
  end

  struct BroadcasterResponse
    include JSON::Serializable
    property data : Array(BroadcasterData)
  end

  struct BroadcasterData
    include JSON::Serializable
    property id : String
  end
end
