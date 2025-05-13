require "json"

module Turnir::Parser::Youtube

  struct SearchResponse
    include JSON::Serializable
    property items : Array(SearchResponseItem)
  end

  struct SearchResponseItem
    include JSON::Serializable
    property id : SearchItemId
  end

  struct SearchItemId
    include JSON::Serializable
    property kind : String
    property videoId : String
  end

  struct LiveStreamResponse
    include JSON::Serializable
    property items : Array(LiveStreamItem)
  end

  struct LiveStreamItem
    include JSON::Serializable
    property id : String
    property liveStreamingDetails : LiveStreamingDetails
  end

  struct LiveStreamingDetails
    include JSON::Serializable
    property activeLiveChatId : String
  end

  struct ChatResponse
    include JSON::Serializable
    property nextPageToken : String
    property pollingIntervalMillis : Int32
    # property pageInfo : PageInfo
    property items : Array(ChatItem)
  end

  struct ChatItem
    include JSON::Serializable
    property id : String
    property snippet : ChatSnippet
    property authorDetails : AuthorDetails
  end

  struct ChatSnippet
    include JSON::Serializable
    property type : String
    property authorChannelId : String
    property displayMessage : String
    property textMessageDetails : TextMessageDetails
    property publishedAt : String
  end

  struct TextMessageDetails
    include JSON::Serializable
    property messageText : String
  end

  struct AuthorDetails
    include JSON::Serializable
    property channelId : String
    property displayName : String
  end
end
