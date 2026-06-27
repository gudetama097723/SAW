class CreateQuestSystem < ActiveRecord::Migration[8.1]
  def change
    create_table :npc_quests do |t|
      t.references :npc, null: false, foreign_key: true
      t.string  :code,                        null: false
      t.string  :name,                        null: false
      t.text    :description
      t.text    :start_conditions_json,       null: false, default: "{}"
      t.text    :completion_conditions_json,  null: false, default: "{}"
      t.text    :reward_data,                 null: false, default: "{}"
      t.boolean :repeatable,                  null: false, default: false
      t.integer :sort_order,                  null: false, default: 0
      t.boolean :active,                      null: false, default: true
      t.timestamps
    end
    add_index :npc_quests, :code, unique: true
    add_index :npc_quests, [:npc_id, :sort_order]

    create_table :player_quests do |t|
      t.references :player,    null: false, foreign_key: true
      t.references :npc_quest, null: false, foreign_key: true
      t.string  :status,          null: false, default: "active"
      t.integer :completed_count, null: false, default: 0
      t.datetime :accepted_at
      t.datetime :completed_at
      t.text    :progress_data,   null: false, default: "{}"
      t.timestamps
    end
    add_index :player_quests, [:player_id, :npc_quest_id], unique: true
    add_index :player_quests, [:player_id, :status]

    add_column :npc_discoveries, :affinity, :integer, null: false, default: 0
  end
end
