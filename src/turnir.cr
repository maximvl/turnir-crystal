require "./turnir/webserver"
require "./turnir/ws_client"

module Turnir
  extend self

  @@websocket_fiber : Fiber | Nil = nil

  def start_webserver
    Webserver.start
  end

  def ensure_websocket_running
    if @@websocket_fiber.nil? || @@websocket_fiber.try &.dead?
      @@websocket_fiber = spawn do
        WSClient.start
      end
    end
  end

  def websocket_watcher
    loop do
      if Turnir::VoteStorage.should_stop_websocket? && @@websocket_fiber
        puts "Stopping websocket"
        WSClient.stop
        @@websocket_fiber = nil
        Turnir::VoteStorage.clear
      end
      sleep 60
    end
  end
end


spawn do
  Turnir.websocket_watcher
end

Turnir.start_webserver
