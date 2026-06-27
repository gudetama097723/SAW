namespace :npc_quests do
  desc "Import NPC quest definitions from db/seeds/npc_quests.csv"
  task import: :environment do
    result = NpcQuestCsvImporter.new.import!
    puts "Imported NPC quests: #{result.total} (created: #{result.created}, updated: #{result.updated})"
  end
end
