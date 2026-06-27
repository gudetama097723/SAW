namespace :npc_dialogues do
  desc "Import NPC dialogue data from db/seeds/npc_dialogues.csv"
  task import: :environment do
    result = NpcDialogueCsvImporter.new.import!
    puts "Imported NPC dialogues: #{result.total} (created: #{result.created}, updated: #{result.updated})"
  end
end
