namespace :npc_affinity_rules do
  desc "Import NPC affinity rules from db/seeds/npc_affinity_rules.csv"
  task import: :environment do
    result = NpcAffinityRuleCsvImporter.new.import!
    puts "Imported NPC affinity rules: #{result.total} (created: #{result.created}, updated: #{result.updated})"
  end
end
