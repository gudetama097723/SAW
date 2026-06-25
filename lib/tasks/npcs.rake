namespace :npcs do
  desc "Import NPC master data from db/seeds/npcs.csv"
  task import: :environment do
    result = NpcCsvImporter.new.import!
    puts "Imported NPCs: #{result.total} (created: #{result.created}, updated: #{result.updated})"
  end
end
