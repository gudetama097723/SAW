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

ActiveRecord::Schema[8.1].define(version: 2026_06_25_220000) do
  create_table "armors", force: :cascade do |t|
    t.integer "agility_bonus", default: 0, null: false
    t.string "armor_type", null: false
    t.datetime "created_at", null: false
    t.integer "defense", default: 0, null: false
    t.boolean "discardable", default: true, null: false
    t.boolean "equipped", default: false, null: false
    t.boolean "favorite", default: false, null: false
    t.integer "hp_bonus", default: 0, null: false
    t.string "name", null: false
    t.integer "player_base_id"
    t.integer "player_id"
    t.boolean "protected_from_death_penalty", default: false, null: false
    t.string "rarity", default: "common", null: false
    t.string "slot", null: false
    t.text "status_resistance_data", default: "{}", null: false
    t.integer "strength_bonus", default: 0, null: false
    t.boolean "unique_item", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 0, null: false
    t.index ["player_base_id"], name: "index_armors_on_player_base_id"
    t.index ["player_id"], name: "index_armors_on_player_id"
  end

  create_table "battle_enemies", force: :cascade do |t|
    t.text "battle_effects", default: "{}", null: false
    t.integer "battle_id", null: false
    t.datetime "created_at", null: false
    t.integer "enemy_hp", null: false
    t.integer "enemy_level", default: 1, null: false
    t.integer "enemy_max_hp"
    t.integer "mob_id", null: false
    t.text "part_states", default: "{}", null: false
    t.integer "position", default: 1, null: false
    t.text "status_effects", default: "{}", null: false
    t.text "status_values", default: "{}", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id"], name: "index_battle_enemies_on_battle_id"
    t.index ["mob_id"], name: "index_battle_enemies_on_mob_id"
  end

  create_table "battles", force: :cascade do |t|
    t.boolean "ambush"
    t.datetime "created_at", null: false
    t.integer "enemy_hp"
    t.integer "mob_id", null: false
    t.text "part_states", default: "{}", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["mob_id"], name: "index_battles_on_mob_id"
    t.index ["player_id"], name: "index_battles_on_player_id"
  end

  create_table "field_areas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "encounter_rate", default: 30, null: false
    t.integer "end_distance", null: false
    t.string "name", null: false
    t.integer "required_mapping_to_enter_next", default: 30, null: false
    t.integer "required_mapping_to_reach_town", default: 0, null: false
    t.integer "rest_safety", default: 70, null: false
    t.integer "route_id", null: false
    t.integer "start_distance", null: false
    t.datetime "updated_at", null: false
    t.index ["route_id", "start_distance", "end_distance"], name: "index_field_areas_on_route_and_distance"
    t.index ["route_id"], name: "index_field_areas_on_route_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "category", default: "misc", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "discardable", default: true, null: false
    t.text "eat_effect_data", default: "{}", null: false
    t.boolean "food", default: false, null: false
    t.string "name"
    t.integer "player_id", null: false
    t.boolean "protected_from_death_penalty", default: false, null: false
    t.integer "quantity"
    t.boolean "quest_item", default: false, null: false
    t.integer "satiety_restore", default: 0, null: false
    t.integer "tastiness", default: 0, null: false
    t.boolean "unique_item", default: false, null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 8, scale: 2, default: "0.1", null: false
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
    t.string "weak_attack_attribute"
    t.boolean "weakness", default: false, null: false
    t.index ["mob_id"], name: "index_mob_parts_on_mob_id"
  end

  create_table "mobs", force: :cascade do |t|
    t.integer "agility", default: 1, null: false
    t.integer "atk"
    t.string "boss_type", default: "normal", null: false
    t.integer "col_max", default: 3, null: false
    t.integer "col_min", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "durability", default: 0, null: false
    t.integer "exp_reward", default: 10, null: false
    t.integer "field_area_id"
    t.integer "flee_rate", default: 0, null: false
    t.integer "hp"
    t.integer "level", default: 1, null: false
    t.string "name"
    t.string "rarity"
    t.text "reward_data", default: "{}", null: false
    t.integer "route_id"
    t.text "status_attack_data", default: "{}", null: false
    t.text "status_threshold_data", default: "{}", null: false
    t.datetime "updated_at", null: false
    t.string "weak_attack_attribute"
    t.index ["field_area_id"], name: "index_mobs_on_field_area_id"
    t.index ["route_id"], name: "index_mobs_on_route_id"
  end

  create_table "npcs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "dungeon_key"
    t.string "facility_key"
    t.integer "field_area_id"
    t.integer "location_id"
    t.text "metadata_json", default: "{}", null: false
    t.string "name", null: false
    t.string "npc_type", default: "general", null: false
    t.string "placement_type", null: false
    t.string "position_key"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_npcs_on_code", unique: true
    t.index ["field_area_id"], name: "index_npcs_on_field_area_id"
    t.index ["location_id"], name: "index_npcs_on_location_id"
    t.index ["placement_type", "dungeon_key"], name: "index_npcs_on_placement_type_and_dungeon_key"
    t.index ["placement_type", "facility_key"], name: "index_npcs_on_placement_type_and_facility_key"
    t.index ["placement_type", "field_area_id"], name: "index_npcs_on_placement_type_and_field_area_id"
    t.index ["placement_type", "location_id"], name: "index_npcs_on_placement_type_and_location_id"
  end

  create_table "player_bases", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "base_type", default: "home", null: false
    t.datetime "created_at", null: false
    t.integer "location_id", null: false
    t.integer "player_id", null: false
    t.integer "rent", default: 0, null: false
    t.boolean "rent_overdue", default: false, null: false
    t.integer "storage_limit", default: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_player_bases_on_location_id"
    t.index ["player_id"], name: "index_player_bases_on_player_id"
  end

  create_table "player_boss_kills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "defeated", default: false, null: false
    t.datetime "defeated_at"
    t.boolean "found", default: false, null: false
    t.integer "mob_id", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["mob_id"], name: "index_player_boss_kills_on_mob_id"
    t.index ["player_id", "mob_id"], name: "index_player_boss_kills_unique", unique: true
    t.index ["player_id"], name: "index_player_boss_kills_on_player_id"
  end

  create_table "player_field_area_progresses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "field_area_id", null: false
    t.integer "mapping_progress", default: 0, null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["field_area_id"], name: "index_player_field_area_progresses_on_field_area_id"
    t.index ["player_id", "field_area_id"], name: "index_player_area_progress_unique", unique: true
    t.index ["player_id"], name: "index_player_field_area_progresses_on_player_id"
  end

  create_table "player_route_progresses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "progress", default: 0, null: false
    t.boolean "reached_destination", default: false, null: false
    t.boolean "returning", default: false, null: false
    t.integer "route_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "route_id"], name: "index_player_route_progresses_on_player_id_and_route_id", unique: true
    t.index ["player_id"], name: "index_player_route_progresses_on_player_id"
    t.index ["route_id"], name: "index_player_route_progresses_on_route_id"
  end

  create_table "player_town_discoveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "found_blacksmith", default: false, null: false
    t.boolean "found_inn", default: false, null: false
    t.boolean "found_item_shop", default: false, null: false
    t.boolean "found_restaurant", default: false, null: false
    t.integer "location_id", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_player_town_discoveries_on_location_id"
    t.index ["player_id", "location_id"], name: "index_player_town_discoveries_on_player_id_and_location_id", unique: true
    t.index ["player_id"], name: "index_player_town_discoveries_on_player_id"
  end

  create_table "player_treasure_chests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "found", default: false, null: false
    t.boolean "ignored", default: false, null: false
    t.boolean "inspected", default: false, null: false
    t.text "inspection_result"
    t.boolean "opened", default: false, null: false
    t.datetime "opened_at"
    t.integer "player_id", null: false
    t.integer "treasure_chest_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "treasure_chest_id"], name: "index_player_treasure_unique", unique: true
    t.index ["player_id"], name: "index_player_treasure_chests_on_player_id"
    t.index ["treasure_chest_id"], name: "index_player_treasure_chests_on_treasure_chest_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "agility", default: 1, null: false
    t.integer "awake_minutes_since_sleep", default: 0, null: false
    t.integer "base_col", default: 0, null: false
    t.text "battle_effects", default: "{}", null: false
    t.text "buff_effects", default: "{}", null: false
    t.integer "col"
    t.datetime "created_at", null: false
    t.integer "current_day", default: 1, null: false
    t.integer "current_month", default: 1, null: false
    t.integer "current_time", default: 480
    t.integer "exp", default: 0, null: false
    t.integer "field_position", default: 0, null: false
    t.integer "field_route_id"
    t.integer "floor"
    t.boolean "found_blacksmith", default: false, null: false
    t.boolean "found_inn", default: false, null: false
    t.boolean "found_item_shop", default: false, null: false
    t.boolean "found_restaurant", default: false, null: false
    t.integer "hp"
    t.text "injury_states", default: "{}", null: false
    t.integer "level", default: 1, null: false
    t.integer "location_id"
    t.integer "max_hp", default: 100, null: false
    t.string "name"
    t.decimal "satiety", precision: 8, scale: 3, default: "100.0", null: false
    t.text "skill_counters", default: "{}", null: false
    t.integer "skill_slot_bonus", default: 0, null: false
    t.integer "skill_slots", default: 3, null: false
    t.boolean "skip_stat_allocate_confirm", default: false, null: false
    t.integer "stat_points", default: 0, null: false
    t.text "status_effects", default: "{}", null: false
    t.text "status_values", default: "{}", null: false
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
    t.integer "distance", default: 100, null: false
    t.integer "from_location_id", null: false
    t.decimal "mapping_difficulty", precision: 4, scale: 2, default: "1.0", null: false
    t.string "name", default: "名もなき道", null: false
    t.integer "to_location_id", null: false
    t.integer "travel_time"
    t.datetime "updated_at", null: false
    t.index ["from_location_id"], name: "index_routes_on_from_location_id"
    t.index ["to_location_id"], name: "index_routes_on_to_location_id"
  end

  create_table "skills", force: :cascade do |t|
    t.boolean "capstone_slot_awarded", default: false, null: false
    t.datetime "created_at", null: false
    t.text "learn_condition_data", default: "{}", null: false
    t.string "name"
    t.integer "player_id", null: false
    t.integer "proficiency"
    t.string "skill_category", default: "general", null: false
    t.integer "skill_exp", default: 0, null: false
    t.text "sword_skill_levels", default: "{}", null: false
    t.datetime "updated_at", null: false
    t.boolean "weapon_skill", default: false, null: false
    t.index ["player_id"], name: "index_skills_on_player_id"
  end

  create_table "storage_items", force: :cascade do |t|
    t.string "category", default: "misc", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "player_base_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["player_base_id", "name", "category"], name: "index_storage_items_on_player_base_id_and_name_and_category", unique: true
    t.index ["player_base_id"], name: "index_storage_items_on_player_base_id"
  end

  create_table "treasure_chests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discovery_type", default: "fixed", null: false
    t.integer "field_area_id"
    t.integer "hazard_level", default: 0, null: false
    t.string "hazard_type", default: "normal", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "required_mapping", default: 0, null: false
    t.boolean "respawnable", default: false, null: false
    t.text "reward_data", default: "{}", null: false
    t.integer "route_id", null: false
    t.datetime "updated_at", null: false
    t.index ["field_area_id"], name: "index_treasure_chests_on_field_area_id"
    t.index ["route_id"], name: "index_treasure_chests_on_route_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "weapon_evolution_rules", force: :cascade do |t|
    t.string "blacksmith_location_name"
    t.datetime "created_at", null: false
    t.integer "required_enhancement_level", default: 10, null: false
    t.integer "required_floor"
    t.text "required_materials_data", default: "{}", null: false
    t.integer "required_player_level", default: 1, null: false
    t.string "source_weapon_name", null: false
    t.string "target_weapon_name", null: false
    t.datetime "updated_at", null: false
    t.index ["source_weapon_name"], name: "index_weapon_evolution_rules_on_source_weapon_name"
  end

  create_table "weapon_upgrade_recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "required_col", default: 0, null: false
    t.text "required_materials_data", default: "{}", null: false
    t.integer "target_level", null: false
    t.datetime "updated_at", null: false
    t.string "weapon_name"
    t.string "weapon_type"
    t.index ["weapon_name", "weapon_type", "target_level"], name: "index_weapon_upgrade_recipes_lookup"
  end

  create_table "weapons", force: :cascade do |t|
    t.integer "agility_bonus", default: 0, null: false
    t.integer "agility_ratio", default: 30, null: false
    t.text "attack_attributes", default: "斬撃", null: false
    t.integer "attack_power", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "critical_rate", default: 5, null: false
    t.text "description"
    t.boolean "discardable", default: true, null: false
    t.integer "drop_rate", default: 0, null: false
    t.integer "durability", default: 10, null: false
    t.text "enhancement_data", default: "{}", null: false
    t.integer "enhancement_level", default: 0, null: false
    t.boolean "equipped", default: false, null: false
    t.boolean "favorite", default: false, null: false
    t.integer "hp_bonus", default: 0, null: false
    t.integer "max_durability", default: 10, null: false
    t.integer "mob_id"
    t.string "name", null: false
    t.integer "part_break_power", default: 100, null: false
    t.integer "player_base_id"
    t.integer "player_id"
    t.boolean "protected_from_death_penalty", default: false, null: false
    t.string "rarity", default: "common", null: false
    t.text "status_resistance_data", default: "{}", null: false
    t.integer "strength_bonus", default: 0, null: false
    t.integer "strength_ratio", default: 70, null: false
    t.boolean "unique_item", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "weapon_type", null: false
    t.decimal "weight", precision: 8, scale: 2, default: "5.0", null: false
    t.index ["mob_id"], name: "index_weapons_on_mob_id"
    t.index ["player_base_id"], name: "index_weapons_on_player_base_id"
    t.index ["player_id"], name: "index_weapons_on_player_id"
  end

  add_foreign_key "armors", "player_bases", column: "player_base_id"
  add_foreign_key "armors", "players"
  add_foreign_key "battle_enemies", "battles"
  add_foreign_key "battle_enemies", "mobs"
  add_foreign_key "battles", "mobs"
  add_foreign_key "battles", "players"
  add_foreign_key "field_areas", "routes"
  add_foreign_key "items", "players"
  add_foreign_key "mob_parts", "mobs"
  add_foreign_key "mobs", "field_areas"
  add_foreign_key "mobs", "routes"
  add_foreign_key "npcs", "field_areas"
  add_foreign_key "npcs", "locations"
  add_foreign_key "player_bases", "locations"
  add_foreign_key "player_bases", "players"
  add_foreign_key "player_boss_kills", "mobs"
  add_foreign_key "player_boss_kills", "players"
  add_foreign_key "player_field_area_progresses", "field_areas"
  add_foreign_key "player_field_area_progresses", "players"
  add_foreign_key "player_route_progresses", "players"
  add_foreign_key "player_route_progresses", "routes"
  add_foreign_key "player_town_discoveries", "locations"
  add_foreign_key "player_town_discoveries", "players"
  add_foreign_key "player_treasure_chests", "players"
  add_foreign_key "player_treasure_chests", "treasure_chests"
  add_foreign_key "players", "locations"
  add_foreign_key "players", "users"
  add_foreign_key "rests", "players"
  add_foreign_key "routes", "locations", column: "from_location_id"
  add_foreign_key "routes", "locations", column: "to_location_id"
  add_foreign_key "skills", "players"
  add_foreign_key "storage_items", "player_bases", column: "player_base_id"
  add_foreign_key "treasure_chests", "field_areas"
  add_foreign_key "treasure_chests", "routes"
  add_foreign_key "weapons", "mobs"
  add_foreign_key "weapons", "player_bases", column: "player_base_id"
  add_foreign_key "weapons", "players"
end
