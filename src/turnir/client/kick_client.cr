require "json"
require "http/client"

require "../parser/kick"

module Turnir::Client::KickClient
  extend self

  @@stop = Atomic(Int32).new(0)

  def log(msg)
    print "[KICK] "
    puts msg
  end

  @@storage : Turnir::ChatStorage::Storage | Nil = nil
  @@channels_map = {} of String => String

  def start(sync_channel : Channel(Nil), storage : Turnir::ChatStorage::Storage, channels_map : Hash(String, String))
    log "Starting Kick"

    @@storage = storage
    @@channels_map = channels_map

    @@stop.set(0)

    sync_channel.send(nil)
    loop do
      # Simulate some work
      sleep 60.seconds

      # Check if the sync_channel is closed
      if sync_channel.closed?
        log "Sync channel closed, exiting..."
        break
      end
      # Check if the stop flag is set
      if @@stop.get == 1
        log "Stopping Kick client"
        break
      end
    end
  end

  def handle_message(msg : IO)
    begin
      parsed = Turnir::Parser::Kick::ChatMessage.from_json(msg)
      if parsed
        # Process the parsed message
        log "Parsed message: #{parsed}"
        msg = Turnir::ChatStorage::Types::ChatMessage.from_kick_message(parsed)
        @@storage.try { |s|
          s.add_message(msg)
        }
      else
        log "Failed to parse message: #{msg}"
      end
    rescue ex : Exception
      log "Error while parsing message: #{ex.inspect}"
      log "Failed to parse message: #{msg.inspect}"
    end
  end

  def subscribe_to_channel(channel_name : String)
    log "Subscribing to channel: #{channel_name}"
    @@channels_map[channel_name] = channel_name

    response = HTTP::Client.post("https://api.kick.com/public/v1/events/subscriptions",
      headers: HTTP::Headers{
        "Authorization" => "Bearer #{Turnir::Config::KICK_OAUTH_TOKEN}",
        "Content-Type" => "application/json",
      },
      body: {
        "broadcaster_user_id": channel_name,
        "events": [{
          "name": "chat:read",
          "version": 1,
        }],
        "method": "webhook",
      }.to_json
    )
    if response.status_code != 200
      log "Failed to subscribe to channel: #{response.status_code} #{response.body}"
      return
    end
  end

  def stop
    @@stop.set(1)
  end

end
