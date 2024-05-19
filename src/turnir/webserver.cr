require "http/server"
require "json"
require "./ws_client"
require "./vote_storage"
require "./config"

module Turnir::Webserver
  extend self

  URL_MAP = {
    /^\/v2\/turnir-api\/votes$/ => ->get_votes(HTTP::Server::Context),
    /^\/v2\/turnir-api\/votes\/reset$/ => ->reset_votes(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets$/ => ->save_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets\/(.+)$/ => ->get_or_update_preset(HTTP::Server::Context),
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

  def get_votes(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    get_session_id(context)
    query_params = context.request.query_params
    ts_filter = query_params.fetch("ts", "0").to_i
    Turnir.ensure_websocket_running
    context.response.content_type = "application/json"
    items = Turnir::VoteStorage.get_votes(ts_filter)
    context.response.print ({"poll_votes" => items}).to_json
  end

  def reset_votes(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    Turnir::VoteStorage.clear
    context.response.content_type = "application/json"
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
