require "sqlite3"

module Turnir::DbStorage
  extend self

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
    DB.open "sqlite3://./turnir.sqlite3" do |db|
      db.exec "create table if not exists presets (id text primary key, title text, owner_id text, created_at integer, updated_at integer, options text)"
    end
  end

  def get_preset(id : String) : Preset | Nil
    item = DB.open "sqlite3://./turnir.sqlite3" do |db|
      db.query_one? "select id, title, owner_id, created_at, updated_at, options from presets where id = ?", id, as: {String, String, String, Int64, Int64, String}
    end
    if item.nil?
      return nil
    end
    Preset.new(id: item[0], title: item[1], owner_id: item[2], created_at: item[3], updated_at: item[4], options: Array(String).from_json(item[5]))
  end

  def save_preset(preset : Preset)
    DB.open "sqlite3://./turnir.sqlite3" do |db|
      db.exec("insert or replace into presets (id, title, owner_id, created_at, updated_at, options) values (?, ?, ?, ?, ?, ?)",
              preset.id, preset.title, preset.owner_id, preset.created_at, preset.updated_at, preset.options.to_json)
    end
  end
end
