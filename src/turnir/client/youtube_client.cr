require "json"
require "http/client"

require "../parser/youtube"

module Turnir::Client::YoutubeClient
  extend self

  @@stop_flag = Atomic(Int32).new(0)

  struct ChannelConfig
    property next_page_token : String | Nil = nil
    property polling_timeout : Float64 = Turnir::Config::YOUTUBE_POLL_SECS
  end

  @@channels_config = {} of String => ChannelConfig

  def log(msg)
    print "[YT] "
    puts msg
  end

  @@channels_map = {} of String => String
  @@out_of_credits = Atomic(Int32).new(0)

  def start(sync_channel : Channel(Nil), storage : Turnir::ChatStorage::Storage, channels_map : Hash(String, String))
    log "Starting Youtube polling"

    @@channels_map = channels_map
    @@channels_map.clear

    @@stop_flag.set(0)

    processed_messages_ids = Set(String).new

    sync_channel.send(nil)
    loop do
      # Simulate some work
      sleep Turnir::Config::YOUTUBE_POLL_SECS.seconds

      # Check if the sync_channel is closed
      if sync_channel.closed?
        log "Sync channel closed, exiting..."
        break
      end
      # Check if the stop flag is set
      if @@stop_flag.get == 1
        log "Stopping Youtube client"
        break
      end

      @@channels_map.each do |channel_name, chat_id|
        # log "Fetching chat messages for channel: #{channel_name}"
        channel_config = @@channels_config[channel_name] || ChannelConfig.new
        next_page_token = channel_config.next_page_token
        polling_timeout = channel_config.polling_timeout

        response = fetch_chat_messages(chat_id, next_page_token)
        if response.nil?
          log "Failed to fetch chat messages for channel: #{channel_name}"
          if @@out_of_credits.get == 1
            log "Out of credits, stopping polling 10 mins"
            sleep 10.minutes
          end
          next
        end
        channel_config.next_page_token = response.nextPageToken
        channel_config.polling_timeout = response.pollingIntervalMillis / 1000
        if @@channels_config[channel_name].nil?
          @@channels_config[channel_name] = channel_config
        end

        response.items.each do |message|
          if processed_messages_ids.includes?(message.id)
            next
          end
          log "Message #{message.authorDetails.displayName}: #{message.snippet.displayMessage}"

          # Store the message in the storage
          msg = Turnir::ChatStorage::Types::ChatMessage.from_youtube_message(message, chat_id)
          storage.add_message(msg)
          processed_messages_ids.add(message.id)
        end
      end
    end
  end

  def stop
    @@stop_flag.set(1)
  end

  def subscribe_to_channel(channel_name : String)
    if @@channels_map.has_key?(channel_name)
      log "Already subscribed to channel: #{channel_name}"
      return
    end

    if @@out_of_credits.get == 1
      log "Out of credits, cannot subscribe to channel: #{channel_name}"
      return
    end

    log "Subscribing to channel: #{channel_name}"
    video_id = fetch_live_video_id(channel_name)
    if video_id.nil?
      log "Failed to fetch live video ID for channel: #{channel_name}"
      return
    end
    chat_id = fetch_live_chat_id(video_id: video_id)
    if chat_id.nil?
      log "Failed to fetch live chat ID for video: #{video_id}"
      return
    end
    log "Subscribing to chat ID: #{chat_id}"
    @@channels_map[channel_name] = chat_id
    Turnir::Client.on_subscribe(
      Turnir::Client::ClientType::YOUTUBE,
      channel_name,
    )
  end

  def fetch_live_video_id(channel_name : String) : String | Nil
    log "Fetching live video ID for channel: #{channel_name}"
    params = {
      "part"      => "snippet",
      "eventType" => "live",
      "type"      => "video",
      "q"         => channel_name,
      "key"       => Turnir::Config::YOUTUBE_API_KEY,
    }
    uri = URI.parse("https://www.googleapis.com/youtube/v3/search")
    uri.query = URI::Params.encode(params)
    response = HTTP::Client.get(
      uri.to_s,
    )
    if response.status_code == 200
      begin
        parsed = Turnir::Parser::Youtube::SearchResponse.from_json(response.body)
        if parsed.items.size > 0
          return parsed.items[0].id.videoId
        else
          log "No live video found for channel: #{channel_name}"
          return nil
        end
      rescue ex
        log "Failed to parse response: #{ex.inspect} #{response.body}"
        return nil
      end
    elsif response.status_code == 403
      # log "Access denied to live video: #{response.status_code} #{response.body}"
      @@out_of_credits.set(1)
      return nil
    else
      log "Failed to fetch live video ID: #{response.status_code} #{response.body}"
      return nil
    end
  end

  def fetch_live_chat_id(video_id : String)
    log "Fetching live chat ID for video: #{video_id}"
    params = {
      "part" => "liveStreamingDetails",
      "id"   => video_id,
      "key"  => Turnir::Config::YOUTUBE_API_KEY,
    }
    uri = URI.parse("https://www.googleapis.com/youtube/v3/videos")
    uri.query = URI::Params.encode(params)
    response = HTTP::Client.get(
      uri.to_s,
    )
    if response.status_code == 200
      begin
        parsed = Turnir::Parser::Youtube::LiveStreamResponse.from_json(response.body)
        if parsed.items.size > 0
          return parsed.items[0].liveStreamingDetails.activeLiveChatId
        else
          log "No live chat found for video: #{video_id}"
          return nil
        end
      rescue ex
        log "Failed to parse response: #{ex.inspect} #{response.body}"
        return nil
      end
    elsif response.status_code == 403
      # log "Access denied to live chat: #{response.status_code} #{response.body}"
      @@out_of_credits.set(1)
      return nil
    else
      log "Failed to fetch live chat ID: #{response.status_code} #{response.body}"
      return nil
    end
  end

  def fetch_chat_messages(chat_id : String, page_token : String | Nil = nil)
    # log "Fetching chat messages for chat ID: #{chat_id}"
    params = {
      "part"       => "snippet,authorDetails",
      "liveChatId" => chat_id,
      "key"        => Turnir::Config::YOUTUBE_API_KEY,
    }
    if page_token
      params["pageToken"] = page_token
    end
    uri = URI.parse("https://www.googleapis.com/youtube/v3/liveChat/messages")
    uri.query = URI::Params.encode(params)
    response = HTTP::Client.get(
      uri.to_s,
    )
    if response.status_code == 200
      @@out_of_credits.set(0)
      begin
        parsed = Turnir::Parser::Youtube::ChatResponse.from_json(response.body)
        return parsed
      rescue ex
        log "Failed to parse response: #{ex.inspect} #{response.body}"
        return nil
      end
    elsif response.status_code == 403
      # log "Access denied to chat messages: #{response.status_code} #{response.body}"
      @@out_of_credits.set(1)
      return nil
    else
      log "Failed to fetch chat messages: #{response.status_code} #{response.body}"
      return nil
    end
  end
end
