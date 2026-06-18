# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_18_134500) do
  create_table "armors", force: :cascade do |t|
    t.integer "agility_bonus", default: 0, null: false
    t.string "armor_type", null: false
    t.datetime "created_at", null: false
    t.integer "defense", default: 0, null: false
    t.boolean "equipped", default: false, null: false
    t.integer "hp_bonus", default: 0, null: false
    t.string "name", null: false
    t.integer "player_id", null: false
    t.string "rarity", default: "common", null: false
    t.string "slot", null: false
    t.integer "strength_bonus", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 0, null: false
    t.index ["player_id"], name: "index_armors_on_player_id"
  end

  create_table "battle_enemies", force: :cascade do |t|
    t.integer "battle_id", null: false
    t.datetime "created_at", null: false
    t.integer "enemy_hp", null: false
    t.integer "mob_id", null: false
    t.text "part_states", default: "{}", null: false
    t.integer "position", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id"], name: "index_battle_enemies_on_battle_id"
    t.index ["mob_id"], name: "index_battle_enemies_on_mob_id"
  end

  create_table "battles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "enemy_hp"
    t.integer "mob_id", null: false
    t.text "part_states", default: "{}", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["mob_id"], name: "index_battles_on_mob_id"
    t.index ["player_id"], name: "index_battles_on_player_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "category", default: "misc", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "player_id", null: false
    t.integer "quantity"
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_items_on_player_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "danger_level"
    t.integer "floor"
    t.integer "mapping_progress", default: 0, null: false
    t.string "name"
    t.boolean "safe_area"
    t.datetime "updated_at", null: false
  end

  create_table "mob_parts", force: :cascade do |t|
    t.string "break_effect"
    t.datetime "created_at", null: false
    t.integer "damage_multiplier", default: 80, null: false
    t.string "drop_item_name"
    t.integer "drop_rate", default: 0, null: false
    t.integer "max_durability", default: 10, null: false
    t.integer "mob_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.boolean "weakness", default: false, null: false
    t.index ["mob_id"], name: "index_mob_parts_on_mob_id"
  end

  create_table "mobs", force: :cascade do |t|
    t.integer "agility", default: 1, null: false
    t.integer "atk"
    t.datetime "created_at", null: false
    t.integer "durability", default: 0, null: false
    t.integer "exp_reward", default: 10, null: false
    t.integer "hp"
    t.integer "level", default: 1, null: false
    t.string "name"
    t.string "rarity"
    t.datetime "updated_at", null: false
  end

  create_table "players", force: :cascade do |t|
    t.integer "agility", default: 1, null: false
    t.integer "col"
    t.datetime "created_at", null: false
    t.integer "current_time", default: 480
    t.integer "exp", default: 0, null: false
    t.integer "floor"
    t.boolean "found_blacksmith", default: false, null: false
    t.boolean "found_inn", default: false, null: false
    t.boolean "found_item_shop", default: false, null: false
    t.integer "hp"
    t.integer "level", default: 1, null: false
    t.integer "location_id"
    t.integer "max_hp", default: 100, null: false
    t.string "name"
    t.integer "skill_slot_bonus", default: 0, null: false
    t.integer "skill_slots", default: 3, null: false
    t.integer "stat_points", default: 0, null: false
    t.integer "strength", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["location_id"], name: "index_players_on_location_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "rests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_rests_on_player_id"
  end

  create_table "routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "danger_level"
    t.integer "from_location_id", null: false
    t.integer "to_location_id", null: false
    t.integer "travel_time"
    t.datetime "updated_at", null: false
    t.index ["from_location_id"], name: "index_routes_on_from_location_id"
    t.index ["to_location_id"], name: "index_routes_on_to_location_id"
  end

  create_table "skills", force: :cascade do |t|
    t.boolean "capstone_slot_awarded", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "player_id", null: false
    t.integer "proficiency"
    t.integer "skill_exp", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_skills_on_player_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "weapons", force: :cascade do |t|
    t.integer "agility_bonus", default: 0, null: false
    t.integer "attack_power", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "critical_rate", default: 5, null: false
    t.integer "drop_rate", default: 0, null: false
    t.integer "durability", default: 10, null: false
    t.boolean "equipped", default: false, null: false
    t.integer "hp_bonus", default: 0, null: false
    t.integer "max_durability", default: 10, null: false
    t.integer "mob_id"
    t.string "name", null: false
    t.integer "player_id"
    t.string "rarity", default: "common", null: false
    t.integer "strength_bonus", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "weapon_type", null: false
    t.index ["mob_id"], name: "index_weapons_on_mob_id"
    t.index ["player_id"], name: "index_weapons_on_player_id"
  end

  add_foreign_key "armors", "players"
  add_foreign_key "battle_enemies", "battles"
  add_foreign_key "battle_enemies", "mobs"
  add_foreign_key "battles", "mobs"
  add_foreign_key "battles", "players"
  add_foreign_key "items", "players"
  add_foreign_key "mob_parts", "mobs"
  add_foreign_key "players", "locations"
  add_foreign_key "players", "users"
  add_foreign_key "rests", "players"
  add_foreign_key "routes", "locations", column: "from_location_id"
  add_foreign_key "routes", "locations", column: "to_location_id"
  add_foreign_key "skills", "players"
  add_foreign_key "weapons", "mobs"
  add_foreign_key "weapons", "players"
end
