class CreateNpcDialogues < ActiveRecord::Migration[8.1]
  def change
    create_table :npc_dialogues do |t|
      t.references :npc, null: false, foreign_key: true
      t.string :dialogue_type, null: false
      t.integer :sequence, null: false, default: 0
      t.text :text, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :npc_dialogues, [:npc_id, :dialogue_type, :sequence],
              name: "index_npc_dialogues_on_npc_type_seq"

    add_column :npc_discoveries, :acquainted, :boolean, null: false, default: false
  end
end
