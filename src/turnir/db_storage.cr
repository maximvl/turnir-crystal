require "sqlite3"

module Turnir::DbStorage
  extend self

  DB_PATH = "./turnir.sqlite3"
  DB_URL  = "sqlite3://#{DB_PATH}"

  struct Preset
    include JSON::Serializable
    property id : String
    property title : String
    property owner_id : String
    property created_at : Int64
    property updated_at : Int64
    property options : Array(String)

    def initialize(@id : String, @title : String, @owner_id : String, @created_at : Int64, @updated_at : Int64, @options : Array(String))
    end
  end

  def create_tables
    DB.open DB_URL do |db|
      db.exec "create table if not exists presets (id text primary key, title text, owner_id text, created_at integer, updated_at integer, options text)"
      db.exec "create table if not exists loto_winners (id integer primary key, username text, super_game_status text, created_at integer, stream_channel text)"
    end
  end

  def get_preset(id : String) : Preset | Nil
    item = DB.open DB_URL do |db|
      db.query_one? "select id, title, owner_id, created_at, updated_at, options from presets where id = ?", id, as: {String, String, String, Int64, Int64, String}
    end
    if item.nil?
      return nil
    end
    Preset.new(id: item[0], title: item[1], owner_id: item[2], created_at: item[3], updated_at: item[4], options: Array(String).from_json(item[5]))
  end

  def save_preset(preset : Preset)
    DB.open DB_URL do |db|
      db.exec("insert or replace into presets (id, title, owner_id, created_at, updated_at, options) values (?, ?, ?, ?, ?, ?)",
        preset.id, preset.title, preset.owner_id, preset.created_at, preset.updated_at, preset.options.to_json)
    end
  end

  struct LotoWinner
    include JSON::Serializable
    property id : Int64
    property username : String
    property super_game_status : String
    property created_at : Int64
    property stream_channel : String

    def initialize(@id : Int64, @username : String, @super_game_status : String, @created_at : Int64, @stream_channel : String)
    end
  end

  def save_loto_winner(username : String, super_game_status : String, created_at : Int64, stream_channel : String) : Int64
    DB.open DB_URL do |db|
      insert_id = db.scalar("insert into loto_winners (username, super_game_status, created_at, stream_channel) values (?, ?, ?, ?) returning id",
        username, super_game_status, created_at, stream_channel).as(Int64)
      insert_id
    end
  end

  def update_loto_winner_super_game_status(winner_id : Int64, super_game_status : String)
    DB.open DB_URL do |db|
      db.exec("update loto_winners set super_game_status = ? where id = ?", super_game_status, winner_id)
    end
  end

  def get_loto_winners(stream_channel : String) : Array(LotoWinner)
    items = DB.open DB_URL do |db|
      db.query_all("SELECT id, username, super_game_status, created_at, stream_channel FROM loto_winners WHERE stream_channel = ?", stream_channel) do |rs|
        # Map the result set to the expected types
        rs.read(Int32, String, String, Int64, String)
      end
    end
    items.map do |item|
      LotoWinner.new(id: item[0], username: item[1], super_game_status: item[2], created_at: item[3], stream_channel: item[4])
    end
  end
end
