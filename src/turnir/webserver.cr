require "http/server"
require "json"
require "./ws_client"
require "./vote_storage"

module Turnir::Webserver
  extend self

  URL_MAP = {
    /^\/v2\/turnir-api\/votes$/ => ->get_votes(HTTP::Server::Context),
    /^\/v2\/turnir-api\/votes\/reset$/ => ->reset_votes(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets$/ => ->create_preset(HTTP::Server::Context),
    /^\/v2\/turnir-api\/presets\/(.+)$/ => ->get_or_update_preset(HTTP::Server::Context),
  }

  class MethodNotSupported < Exception
  end

  def log(msg)
    print "[WebServer #{Fiber.current}] "
    puts msg
  end

  def get_votes(context : HTTP::Server::Context)
    if context.request.method != "GET"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    query_params = context.request.query_params
    ts_filter = query_params.fetch("ts", "0").to_i
    Turnir.ensure_websocket_running
    context.response.content_type = "application/json"
    items = Turnir::VoteStorage.get_votes(ts_filter)
    context.response.print items.to_json
  end

  def reset_votes(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    Turnir::VoteStorage.clear
    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def create_preset(context : HTTP::Server::Context)
    if context.request.method != "POST"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def get_or_update_preset(context : HTTP::Server::Context)
    if context.request.method != "GET" && context.request.method != "PUT"
      raise MethodNotSupported.new("Method #{context.request.method} not supported")
    end
    context.response.content_type = "application/json"
    context.response.print ({"status" => "ok"}).to_json
  end

  def start
    server = HTTP::Server.new do |context|
      start = Time.utc
      path = context.request.path
      method = context.request.method
      query = context.request.query
      log "> #{method} #{path}?#{query}"

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
    ip = ENV.fetch("IP", "127.0.0.1")
    port = ENV.fetch("PORT", "8080").to_i

    address = server.bind_tcp ip, port
    log "Listening on http://#{address}"
    server.listen
  end
end
