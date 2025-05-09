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
      db.exec "create table if not exists loto_winners (id integer primary key, username text, super_game_status text, created_at integer, stream_channel text, session_id text)"
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
    property session_id : String

    def initialize(@id : Int64, @username : String, @super_game_status : String, @created_at : Int64, @stream_channel : String, @session_id : String = "")
    end
  end

  def save_loto_winner(username : String, super_game_status : String, created_at : Int64, stream_channel : String, session_id : String) : Int64
    DB.open DB_URL do |db|
      # Proper schema verification
      column_names = [] of String
      db.query("PRAGMA table_info(loto_winners)") do |rs|
        rs.each do
          # Skip first column (cid)
          rs.read(Int32) # cid
          name = rs.read(String)
          rs.read(String)  # type
          rs.read(Int32)   # notnull
          rs.read(String?) # dflt_value
          rs.read(Int32)   # pk
          column_names << name
        end
      end

      unless column_names.size == 6
        raise "Table schema mismatch. Found #{column_names.size} columns: #{column_names.inspect}"
      end

      # Perform the insert
      db.query_one(
        <<-SQL,
        INSERT INTO loto_winners
          (username, super_game_status, created_at, stream_channel, session_id)
        VALUES (?, ?, ?, ?, ?)
        RETURNING id
        SQL
        username,
        super_game_status,
        created_at,
        stream_channel,
        session_id,
        as: Int64
      )
    rescue e : DB::Error
      raise "Failed to save loto winner: #{e.message}\n" +
            "Table columns: #{column_names.inspect}\n" +
            "Values: #{[username, super_game_status, created_at, stream_channel, session_id].inspect}"
    end
  end

  def update_loto_winner_super_game_status(winner_id : Int64, super_game_status : String, session_id : String)
    DB.open DB_URL do |db|
      db.exec("update loto_winners set super_game_status = ? where id = ? and session_id = ?", super_game_status, winner_id, session_id)
    end
  end

  def get_loto_winners(stream_channel : String, session_id : String) : Array(LotoWinner)
    items = DB.open DB_URL do |db|
      db.query_all("SELECT id, username, super_game_status, created_at, stream_channel FROM loto_winners WHERE stream_channel = ? and (session_id = ? or session_id = '')", stream_channel, session_id) do |rs|
        # Map the result set to the expected types
        rs.read(Int32, String, String, Int64, String)
      end
    end
    items.map do |item|
      LotoWinner.new(id: item[0], username: item[1], super_game_status: item[2], created_at: item[3], stream_channel: item[4])
    end
  end
end
