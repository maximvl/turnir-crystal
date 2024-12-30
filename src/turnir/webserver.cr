require "http/server"
require "json"
require "./client/client"
require "./config"

module Turnir::Webserver
  extend self

  URL_MAP = {
    /^\/v2\/turnir-api\/chat_messages$/ => ->get_chat_messages(HTTP::Server::Context),
    /^\/v2\/turnir-api\/chat_messages\/clear$/ => ->clear_messages(HTTP::Server::Context),
    /^\/v2\/turnir-api\/chat_connect$/ => ->connect_to_chat(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets$/ => ->save_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets\/(.+)$/ => ->get_or_update_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/version$/ => ->get_version(HTTP::Server::Context),
  }

  class MethodNotSupported < Exception
  end

  struct PresetRequest
    include JSON::Serializable
    getter title : String
    getter options : Array(String)
  end

  def log(msg)
    print "[WebServer #{Fiber.current}] "
    puts msg
  end

  def gen_random_id(size = 8)
    r = Random.new
    r.urlsafe_base64(size)
  end

  def get_session_id(context : HTTP::Server::Context)
    cookies = context.request.cookies
    if cookies.has_key?("session_id")
      session_id = cookies["session_id"].value
      # log "Session ID: #{session_id}"
    else
      session_id = gen_random_id
      cookie = HTTP::Cookie.new "session_id", session_id
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
    if channel.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel is required"}).to_json
      return
    end

    platform = query_params.fetch("platform", nil)
    if platform.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "platform is required"}).to_json
      return
    end

    ts_filter = query_params.fetch("ts", "0").to_i
    text_filter = query_params.fetch("text_filter", "")

    items = [] of Turnir::ChatStorage::Types::ChatMessage
    if platform == "vkvideo"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::VK)
      channel_id = Turnir::Client::ChannelMapper.get_vk_channel(channel)
      if channel_id.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.print ({"error" => "channel not found"}).to_json
        return
      end

      items = Turnir::Client.get_messages(Turnir::Client::ClientType::VK, channel_id, ts_filter, text_filter.downcase)
    end

    if platform == "twitch"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::TWITCH)
      items = Turnir::Client.get_messages(Turnir::Client::ClientType::TWITCH, channel, ts_filter, text_filter.downcase)
    end

    if platform == "nuum"
      channel_id = Turnir::Client::ChannelMapper.get_nuum_channel(channel)
      if channel_id.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.print ({"error" => "channel not found"}).to_json
        return
      end

      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::NUUM)
      items = Turnir::Client.get_messages(Turnir::Client::ClientType::NUUM, channel_id, ts_filter, text_filter.downcase)
    end

    if platform == "goodgame"
      channel_id = Turnir::Client::ChannelMapper.get_goodgame_channel(channel)
      if channel_id.nil?
        context.response.status = HTTP::Status::BAD_REQUEST
        context.response.print ({"error" => "channel not found"}).to_json
        return
      end

      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::GOODGAME)
      items = Turnir::Client.get_messages(Turnir::Client::ClientType::GOODGAME, channel_id, ts_filter, text_filter.downcase)
    end

    context.response.print ({"chat_messages" => items}).to_json
  end

  def get_version(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    context.response.content_type = "application/json"
    context.response.print ({"version" => "1.0", "build_time" => Turnir::Config::BUILD_TIME }).to_json
  end

  def clear_messages(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end

    Turnir::Client.clear_messages(Turnir::Client::ClientType::VK)
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
    if channel_name.nil?
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "channel_name is required"}).to_json
      return
    end

    platform = query_params.fetch("platform", nil)

    supported_platforms = ["vkvideo", "twitch", "nuum", "goodgame"]
    if supported_platforms.includes?(platform) == false
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.print ({"error" => "platform is not supported"}).to_json
      return
    end

    if platform == "vkvideo"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::VK)
      Turnir::Client.subscribe_to_channel(Turnir::Client::ClientType::VK, channel_name)
    end

    if platform == "twitch"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::TWITCH)
      Turnir::Client.subscribe_to_channel(Turnir::Client::ClientType::TWITCH, channel_name)
    end

    if platform == "nuum"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::NUUM)
      Turnir::Client.subscribe_to_channel(Turnir::Client::ClientType::NUUM, channel_name)
    end

    if platform == "goodgame"
      Turnir::Client.ensure_client_running(Turnir::Client::ClientType::GOODGAME)
      Turnir::Client.subscribe_to_channel(Turnir::Client::ClientType::GOODGAME, channel_name)
    end

    context.response.print ({"status" => "ok"}).to_json
  end

  def save_preset(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    session_id = get_session_id(context)

    request = nil
    begin
      context.request.body.try do |data|
        request = PresetRequest.from_json(data)
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
        request = PresetRequest.from_json(data)
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

  def start
    server = HTTP::Server.new do |context|

      context.response.headers["Access-Control-Allow-Origin"] = "http://localhost:5173"
      context.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      context.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

      start = Time.utc
      path = context.request.path
      method = context.request.method
      query = context.request.query

      if query
        log "> #{method} #{path}?#{query}"
      else
        log "> #{method} #{path}"
      end

      url_match = URL_MAP.each.find do |pattern, handler|
        path.match(pattern)
      end
      if url_match
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
          log "WebServer Error: "
          log ex
          log ex.backtrace
        end
      else
        context.response.status = HTTP::Status::NOT_FOUND
        context.response.content_type = "text/plain"
        context.response.print "Not Found"
      end
      time_passed = Time.utc - start
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
