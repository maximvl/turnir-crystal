require "http/server"
require "http/client"
require "json"
require "../client/client"
require "../config"
require "./serializers"
require "./utils"

module Turnir::Webserver
  extend self

  URL_MAP = {
    /^\/v2\/turnir-api\/chat_messages$/        => ->get_chat_messages(HTTP::Server::Context),
    /^\/v2\/turnir-api\/chat_messages\/clear$/ => ->clear_messages(HTTP::Server::Context),
    /^\/v2\/turnir-api\/chat_connect$/         => ->connect_to_chat(HTTP::Server::Context),
    /^\/v2\/turnir-api\/chat_connections$/     => ->chat_connections(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets$/              => ->save_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets\/(.+)$/        => ->get_or_update_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/version$/              => ->get_version(HTTP::Server::Context),
    /^\/v2\/turnir-api\/loto_winners$/         => ->get_or_create_loto_winner(HTTP::Server::Context),
    /^\/v2\/turnir-api\/loto_winners\/(.+)$/   => ->update_loto_winner(HTTP::Server::Context),
    /^\/v2\/turnir-api\/stream_info$/          => ->get_stream_info(HTTP::Server::Context),
    /^\/external\/kick-hook$/                  => ->kick_web_hook(HTTP::Server::Context),
  }

  class MethodNotSupported < Exception
  end

  VK_ROLES_URL = "https://api.live.vkvideo.ru/v1/channel/{{channel}}/point/reward/"

  def log(msg)
    print "[WebServer #{Fiber.current}] "
    puts msg
  end

  def gen_random_id(size = 8)
    r = Random.new
    r.urlsafe_base64(size)
  end

  ClientTypes = {
    "vkvideo"  => Turnir::Client::ClientType::VKVIDEO,
    "twitch"   => Turnir::Client::ClientType::TWITCH,
    "nuum"     => Turnir::Client::ClientType::NUUM,
    "goodgame" => Turnir::Client::ClientType::GOODGAME,
    "kick"     => Turnir::Client::ClientType::KICK,
  }

  def get_session_id(context : HTTP::Server::Context)
    cookies = context.request.cookies
    session_id = ""
    if cookies.has_key?("session_id")
      session_id = cookies["session_id"].value
      # log "Session ID: #{session_id}"
    end

    if session_id.empty?
      session_id = gen_random_id
      cookie = HTTP::Cookie.new "session_id", session_id
      cookie.max_age = Time::Span.new(days: 400) # expires in 400 days (in seconds)
      context.response.cookies << cookie
      # log "No session ID"
    end
    session_id
  end

  def get_chat_messages(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)
    context.response.content_type = "application/json"

    query_params = context.request.query_params
    channel = query_params.fetch("channel", nil)
    if channel.nil? || channel.empty?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel is required"}).to_json
      return
    end

    platform = query_params.fetch("platform", nil)
    ts_filter = query_params.fetch("ts", "0").to_i64
    text_filter = query_params.fetch("text_filter", "")

    items = [] of Turnir::ChatStorage::Types::ChatMessage

    client_type = ClientTypes.fetch(platform, nil)
    if client_type.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "platform not supported"}).to_json
      return
    end

    items = Turnir::Client.get_messages(client_type, channel, ts_filter, text_filter.downcase)

    if items.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel not found"}).to_json
      return
    end

    context.response.print ({"chat_messages" => items}).to_json
  end

  def get_version(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)
    context.response.content_type = "application/json"
    context.response.print ({"version" => "1.0", "build_time" => Turnir::Config::BUILD_TIME}).to_json
  end

  def clear_messages(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)

    Turnir::Client.clear_messages(Turnir::Client::ClientType::VKVIDEO)
    Turnir::Client.clear_messages(Turnir::Client::ClientType::TWITCH)

    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def connect_to_chat(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end

    context.response.content_type = "application/json"

    get_session_id(context)

    query_params = context.request.query_params
    channel_name = query_params.fetch("channel", nil)
    if channel_name.nil? || channel_name.empty?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel_name is required"}).to_json
      return
    end

    platform = query_params.fetch("platform", nil)

    supported_platforms = ["vkvideo", "twitch", "nuum", "goodgame", "kick"]
    client_type = ClientTypes.fetch(platform, nil)

    if client_type.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "platform is not supported"}).to_json
      return
    end

    Turnir::Client.ensure_client_running(client_type)
    status = Turnir::Client.subscribe_to_channel_if_not_subscribed(client_type, channel_name)

    context.response.print ({"stream_status" => status.to_s.downcase}).to_json
  end

  def chat_connections(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)

    context.response.content_type = "application/json"
    context.response.print ({"connections" => Turnir::Client.get_connections_statuses}).to_json
  end

  def save_preset(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    session_id = get_session_id(context)

    request = nil
    begin
      context.request.body.try do |data|
        request = Serializers::PresetRequest.from_json(data)
      end
    rescue
      request = nil
    end

    if request.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "text/plain"
      context.response.print "Bad Request body"
      return
    end

    preset = Turnir::DbStorage::Preset.new(
      id: gen_random_id(6),
      owner_id: session_id,
      title: request.title,
      created_at: Time.utc.to_unix,
      updated_at: Time.utc.to_unix,
      options: request.options,
    )
    Turnir::DbStorage.save_preset(preset)

    context.response.content_type = "application/json"
    context.response.print preset.to_json
  end

  def get_or_update_preset(context : HTTP::Server::Context)
    if context.request.method == "GET"
      get_preset(context)
    elsif context.request.method == "POST"
      update_preset(context)
    else
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
  end

  def get_preset(context : HTTP::Server::Context)
    session_id = get_session_id(context)
    preset_id = context.request.path.split('/', remove_empty: true)[-1]
    preset = Turnir::DbStorage.get_preset(preset_id)
    if preset.nil?
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.content_type = "text/plain"
      context.response.print "Not Found"
      return
    end
    context.response.content_type = "application/json"
    context.response.print preset.to_json
  end

  def update_preset(context : HTTP::Server::Context)
    session_id = get_session_id(context)
    preset_id = context.request.path.split('/', remove_empty: true)[-1]
    preset = Turnir::DbStorage.get_preset(preset_id)
    if preset.nil?
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.content_type = "application/json"
      context.response.print ({"error" => "Not found"}).to_json
      return
    end
    if preset.owner_id != session_id
      context.response.status = HTTP::Status::FORBIDDEN
      context.response.content_type = "application/json"
      context.response.print ({"error" => "You are not the owner"}).to_json
      return
    end

    request = nil
    begin
      context.request.body.try do |data|
        request = Serializers::PresetRequest.from_json(data)
      end
    rescue
      request = nil
    end
    if request.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "text/plain"
      context.response.print "Bad Request body"
      return
    end

    preset.title = request.title
    preset.options = request.options
    preset.updated_at = Time.utc.to_unix
    Turnir::DbStorage.save_preset(preset)

    context.response.content_type = "application/json"
    context.response.print preset.to_json
  end

  def get_or_create_loto_winner(context : HTTP::Server::Context)
    session_id = get_session_id(context)
    if context.request.method == "GET"
      query_params = context.request.query_params
      channel = query_params.fetch("channel", nil)
      server = query_params.fetch("server", nil)
      if channel.nil? || server.nil? || channel.empty? || server.empty?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.content_type = "application/json"
        context.response.print ({"error" => "channel, server is required"}).to_json
        return
      end
      stream_channel = "#{server}/#{channel}"
      winners = DbStorage.get_loto_winners(stream_channel, session_id)
      context.response.content_type = "application/json"
      context.response.print ({"winners" => winners}).to_json
    elsif context.request.method == "POST"
      request = nil
      begin
        context.request.body.try do |data|
          request = Serializers::LotoWinnersCreateRequest.from_json(data)
        end
      rescue
        request = nil
      end

      if request.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.content_type = "text/plain"
        context.response.print "Bad Request body"
        return
      end

      client_type = ClientTypes.fetch(request.server, nil)
      if client_type.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.content_type = "application/json"
        context.response.print ({"error" => "server is not supported"}).to_json
        return
      end

      # get timestamp of now - 30 min
      ts_filter = (Time.utc - 30.minutes).to_unix
      messages = Turnir::Client.get_messages(client_type, request.channel, ts_filter, "")
      # check if messages size > 30
      if messages && messages.size < 30 && false
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.content_type = "application/json"
        context.response.print ({"error" => "Bad request"}).to_json
        return
      end

      # stream channel is a string with server and channel separated by slash
      stream_channel = "#{request.server}/#{request.channel}"

      # map of username to id
      inserted_ids = {} of String => Int64

      request.winners.each do |winner|
        insert_id = Turnir::DbStorage.save_loto_winner(
          username: winner.username,
          super_game_status: winner.super_game_status,
          created_at: Time.utc.to_unix,
          stream_channel: stream_channel,
          session_id: session_id,
        )
        inserted_ids[winner.username] = insert_id
      end

      context.response.content_type = "application/json"
      context.response.print ({"ids" => inserted_ids}).to_json
    else
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
  end

  def update_loto_winner(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    session_id = get_session_id(context)

    request = nil
    begin
      context.request.body.try do |data|
        request = Serializers::LotoWinnerUpdateRequest.from_json(data)
      end
    rescue
      request = nil
    end

    if request.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "text/plain"
      context.response.print "Bad Request body"
      return
    end

    client = ClientTypes.fetch(request.server, nil)
    if client.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "application/json"
      context.response.print ({"error" => "server is not supported"}).to_json
      return
    end

    # get timestamp of now - 30 min
    ts_filter = (Time.utc - 30.minutes).to_unix

    messages = Turnir::Client.get_messages(client, request.channel, ts_filter, "")
    # check if messages size > 30
    if messages && messages.size < 30 && false
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "application/json"
      context.response.print ({"error" => "Bad request"}).to_json
      return
    end

    winner_id = context.request.path.split('/', remove_empty: true)[-1]
    winner_id_int = winner_id.to_i

    DbStorage.update_loto_winner_super_game_status(winner_id_int, request.super_game_status, session_id)

    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def get_stream_info(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)
    context.response.content_type = "application/json"

    query_params = context.request.query_params
    channel = query_params.fetch("channel", nil)
    if channel.nil? || channel.empty?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel is required"}).to_json
      return
    end

    platform = query_params.fetch("platform", nil)
    if platform.nil? || platform.empty?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "platform is required"}).to_json
      return
    end

    if platform == "vkvideo"
      roles_url = VK_ROLES_URL.sub("{{channel}}", channel)
      response = HTTP::Client.get(roles_url, headers: HTTP::Headers{"content-type" => "application/json"})
      roles = JSON.parse(response.body)
      context.response.print ({"roles" => roles}).to_json
      return
    end

    context.response.print ({"error" => "platform not supported"}).to_json
  end

  def kick_web_hook(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end

    event_type = context.request.headers["Kick-Event-Type"]?
    if event_type != "chat.message.sent"
      log "Unsupported KICK event type: #{event_type}"
      context.response.status = HTTP::Status::OK
      context.response.content_type = "text/plain"
      context.response.print "unsupported"
      return
    end

    message_id = context.request.headers["Kick-Event-Message-Id"]?
    message_ts = context.request.headers["Kick-Event-Message-Timestamp"]?
    kick_signature = context.request.headers["Kick-Event-Signature"]?

    if message_id.nil? || message_ts.nil? || kick_signature.nil?
      log "Missing KICK headers"
      context.response.status = HTTP::Status::OK
      context.response.content_type = "text/plain"
      context.response.print "missing headers"
      return
    end

    body = context.request.body

    signed_data = "#{message_id}.#{message_ts}.#{body}"

    valid_signature = Utils.verify_kick_signature(
      signed_data,
      kick_signature,
    )

    if !valid_signature
      log "Invalid KICK signature"
      context.response.status = HTTP::Status::OK
      context.response.content_type = "text/plain"
      context.response.print "invalid signature"
      return
    end

    begin
      context.request.body.try do |data|
        Turnir::Client::KickClient.handle_message(data)
      end
    rescue ex : Exception
      log "Failed to handle kick message: #{ex.inspect}"
    end

    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def start
    server = HTTP::Server.new do |context|
      context.response.headers["Access-Control-Allow-Origin"] = "http://localhost:5173"
      context.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      context.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

      start = Time.utc
      path = context.request.path
      method = context.request.method
      query = context.request.query

      url_match = URL_MAP.each.find do |pattern, handler|
        path.match(pattern)
      end
      if url_match
        if context.request.method == "OPTIONS"
          context.response.status = HTTP::Status::OK
          context.response.content_type = "text/plain"
          context.response.print "OK"
          next
        end

        handler = url_match[1]
        begin
          handler.call(context)
        rescue ex : MethodNotSupported
          context.response.status = HTTP::Status::METHOD_NOT_ALLOWED
          context.response.content_type = "text/plain"
          context.response.print "Method Not Allowed "
          context.response.print context.request.method
        rescue ex
          context.response.status = HTTP::Status::INTERNAL_SERVER_ERROR
          context.response.content_type = "text/plain"
          context.response.print "Internal Server Error"
          log "WebServer error: "
          log ex
          log ex.backtrace
          log "for request: "
        end
      else
        context.response.status = HTTP::Status::NOT_FOUND
        context.response.content_type = "text/plain"
        context.response.print "Not Found"
      end
      time_passed = Time.utc - start

      if context.response.status == HTTP::Status::OK && path.ends_with?("/chat_messages")
        next
      end

      if query
        log "> #{method} #{path}?#{query}"
      else
        log "> #{method} #{path}"
      end
      log "< #{context.response.status} (#{time_passed.nanoseconds/100_000}ms)"
    end

    log "Starting webserver"
    ip = Turnir::Config.webserver_ip
    port = Turnir::Config.webserver_port

    address = server.bind_tcp ip, port
    log "Listening on http://#{address}"
    server.listen
  end
end
