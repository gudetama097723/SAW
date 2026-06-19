class AddSkipStatAllocateConfirmToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :skip_stat_allocate_confirm, :boolean, null: false, default: false
  end
end
