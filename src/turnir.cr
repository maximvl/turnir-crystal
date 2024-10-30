require "./turnir/webserver"
require "./turnir/ws_client"
require "./turnir/db_storage"

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
      if Turnir::ChatStorage.should_stop_websocket? && @@websocket_fiber
        puts "Stopping websocket"
        WSClient.stop
        @@websocket_fiber = nil
        Turnir::ChatStorage.clear
      end
      sleep 60.seconds
    end
  end
end

Turnir::DbStorage.create_tables
# puts Turnir::DbStorage.save_preset Turnir::DbStorage::Preset.new(id: "tmp", title: "test", owner_id: "123", created_at: Time.utc.to_unix, updated_at: Time.utc.to_unix, options: ["1","2","3"])
# puts Turnir::DbStorage.get_preset "tmp"
# exit 0


spawn do
  Turnir.websocket_watcher
end

Turnir.start_webserver
