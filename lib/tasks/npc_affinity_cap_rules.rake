namespace :npc_affinity_cap_rules do
  desc "Import NPC affinity cap rules from db/seeds/npc_affinity_cap_rules.csv"
  task import: :environment do
    result = NpcAffinityCapRuleCsvImporter.new.import!
    puts "Imported NPC affinity cap rules: #{result.total} (created: #{result.created}, updated: #{result.updated})"
  end
end
