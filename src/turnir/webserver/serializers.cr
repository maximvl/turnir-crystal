module Turnir::Webserver::Serializers
  struct PresetRequest
    include JSON::Serializable
    getter title : String
    getter options : Array(String)
  end

  struct LotoWinnerCreate
    include JSON::Serializable
    getter username : String
    getter super_game_status : String
  end

  struct LotoWinnersCreateRequest
    include JSON::Serializable
    getter server : String
    getter channel : String
    getter winners : Array(LotoWinnerCreate)
  end

  struct LotoWinnerUpdateRequest
    include JSON::Serializable
    getter super_game_status : String
    getter server : String
    getter channel : String
  end
end
