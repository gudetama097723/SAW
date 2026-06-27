class NpcQuestService
  Result = Struct.new(:status, :message, keyword_init: true)

  # ─── 状態取得 ──────────────────────────────────────────────────

  # このNPCから受注可能なクエスト一覧（NpcQuest[]）
  # trigger_affinity が設定された自動発動クエストは除外する
  def self.available_quests(player, npc)
    quests = npc.npc_quests.active.ordered.where(trigger_affinity: nil)
    pq_map = player.player_quests
                   .where(npc_quest_id: quests.map(&:id))
                   .index_by(&:npc_quest_id)

    quests.select do |quest|
      pq = pq_map[quest.id]
      next false if pq&.active?
      next false if pq&.completed? && !quest.repeatable?
      start_conditions_met?(player, quest, npc: npc)
    end
  end

  # このNPCで受注中のPlayerQuest一覧（PlayerQuest[]、npc_quest をプリロード済み）
  def self.active_quests(player, npc)
    player.player_quests
          .joins(:npc_quest)
          .where(npc_quests: { npc_id: npc.id }, status: "active")
          .includes(:npc_quest)
  end

  # ─── アクション ────────────────────────────────────────────────

  def self.accept_quest!(player, quest)
    return Result.new(status: :error, message: "そのクエストは存在しません。") unless quest

    pq = player.player_quests.find_by(npc_quest: quest)
    return Result.new(status: :error, message: "そのクエストはすでに受注中です。") if pq&.active?
    return Result.new(status: :error, message: "そのクエストはすでに完了済みです。") if pq&.completed? && !quest.repeatable?

    npc = quest.npc
    unless start_conditions_met?(player, quest, npc: npc)
      return Result.new(status: :error, message: "クエストの受注条件を満たしていません。")
    end

    if pq&.completed? && quest.repeatable?
      pq.update!(status: "active", accepted_at: Time.current, completed_at: nil, progress_data: "{}")
    else
      player.player_quests.create!(npc_quest: quest, status: "active", accepted_at: Time.current)
    end

    Result.new(status: :ok, message: "クエスト「#{quest.name}」を受注した！")
  end

  def self.complete_quest!(player, quest)
    pq = player.player_quests.find_by(npc_quest: quest, status: "active")
    return Result.new(status: :error, message: "そのクエストは受注していません。") unless pq

    unless completion_conditions_met?(player, quest)
      return Result.new(status: :error, message: "クエストの達成条件がまだ揃っていません。")
    end

    reward_message = nil
    ActiveRecord::Base.transaction do
      consume_quest_items!(player, quest.completion_conditions)
      reward_message = apply_quest_reward!(player, quest.reward)
      pq.update!(
        status: "completed",
        completed_at: Time.current,
        completed_count: pq.completed_count.to_i + 1
      )
    end

    affinity_gain = quest.reward["affinity"].to_i
    affinity_gain = 2 if affinity_gain <= 0
    discovery = player.npc_discoveries.find_by(npc: quest.npc)
    new_affinity = discovery&.increment_affinity!(affinity_gain).to_i
    trigger_msg = check_affinity_triggers!(player, quest.npc, new_affinity)

    Result.new(status: :ok, message: "クエスト「#{quest.name}」達成！#{reward_message}#{trigger_msg}")
  end

  # ─── 条件チェック ──────────────────────────────────────────────

  def self.start_conditions_met?(player, quest, npc: nil)
    cond = quest.start_conditions
    return true if cond.blank?

    resolved_npc = npc || quest.npc
    level_met?(player, cond["level"]) &&
      affinity_met?(player, resolved_npc, cond["affinity"]) &&
      items_met?(player, cond["items"]) &&
      skills_met?(player, cond["skills"])
  end

  def self.completion_conditions_met?(player, quest)
    cond = quest.completion_conditions
    return true if cond.blank?

    level_met?(player, cond["level"]) &&
      items_met?(player, cond["items"])
  end

  # ─── 表示用サマリー ────────────────────────────────────────────

  def self.start_conditions_summary(quest)
    cond = quest.start_conditions
    parts = []

    if (level = cond["level"]).present?
      min = level.is_a?(Hash) ? level["min"].to_i : level.to_i
      parts << "Lv.#{min}以上"
    end

    if (aff = cond["affinity"]).present?
      min = aff.is_a?(Hash) ? aff["min"].to_i : aff.to_i
      parts << "親密度#{min}以上"
    end

    Array(cond["skills"]).each { |s| parts << "「#{s}」習得" }

    Array(cond["items"]).each do |e|
      name = e.is_a?(Hash) ? e["name"] : e
      qty  = e.is_a?(Hash) ? e["quantity"].to_i : 1
      parts << "#{name}×#{[qty, 1].max}所持"
    end

    parts.empty? ? "なし" : parts.join(" / ")
  end

  def self.completion_conditions_summary(quest)
    cond = quest.completion_conditions
    parts = []

    if (level = cond["level"]).present?
      min = level.is_a?(Hash) ? level["min"].to_i : level.to_i
      parts << "Lv.#{min}以上"
    end

    Array(cond["items"]).each do |e|
      name = e.is_a?(Hash) ? e["name"] : e
      qty  = e.is_a?(Hash) ? e["quantity"].to_i : 1
      parts << "#{name}×#{[qty, 1].max}"
    end

    parts.empty? ? "なし" : parts.join(" / ")
  end

  def self.reward_summary(quest)
    r = quest.reward
    parts = []
    parts << "#{r["col"]}コル"   if r["col"].to_i.positive?
    parts << "#{r["exp"]}EXP"   if r["exp"].to_i.positive?
    parts << "親密度+#{r["affinity"]}" if r["affinity"].to_i.positive?
    Array(r["items"]).each do |e|
      name = e.is_a?(Hash) ? e["name"] : e
      qty  = e.is_a?(Hash) ? e["quantity"].to_i : 1
      parts << "#{name}×#{[qty, 1].max}"
    end
    Array(r["skills"]).each { |s| parts << "スキル「#{s}」" if s.present? }
    parts.empty? ? "なし" : parts.join(" / ")
  end

  # 親密度が上昇した際、閾値に達した自動発動クエストを処理して報酬を付与する
  def self.check_affinity_triggers!(player, npc, new_affinity)
    return "" if new_affinity <= 0

    triggered = npc.npc_quests
                   .where(active: true)
                   .where("trigger_affinity IS NOT NULL AND trigger_affinity <= ?", new_affinity)

    messages = []
    triggered.each do |quest|
      pq = player.player_quests.find_by(npc_quest: quest)
      next if pq&.completed? && !quest.repeatable?

      ActiveRecord::Base.transaction do
        reward_message = apply_quest_reward!(player, quest.reward)
        if pq
          pq.update!(
            status: "completed",
            completed_at: Time.current,
            completed_count: pq.completed_count.to_i + 1
          )
        else
          player.player_quests.create!(
            npc_quest: quest,
            status: "completed",
            accepted_at: Time.current,
            completed_at: Time.current,
            completed_count: 1
          )
        end
        description = quest.description.presence || "#{npc.name}との絆が深まった！"
        messages << " [levelup]【親密度#{quest.trigger_affinity}達成】#{description}#{reward_message}[/levelup]"
      end
    end

    messages.join
  end

  # ─── private ───────────────────────────────────────────────────

  def self.level_met?(player, condition)
    return true if condition.blank?
    min = condition.is_a?(Hash) ? condition["min"].to_i : condition.to_i
    player.effective_level >= min
  end
  private_class_method :level_met?

  def self.affinity_met?(player, npc, condition)
    return true if condition.blank?
    min = condition.is_a?(Hash) ? condition["min"].to_i : condition.to_i
    return true if min <= 0
    player.npc_discoveries.find_by(npc: npc)&.affinity.to_i >= min
  end
  private_class_method :affinity_met?

  def self.items_met?(player, condition)
    Array(condition).all? do |entry|
      name = entry.is_a?(Hash) ? entry["name"] : entry
      qty  = entry.is_a?(Hash) ? entry["quantity"].to_i : 1
      next false if name.blank?
      player.items.where(name: name).sum(:quantity).to_i >= [qty, 1].max
    end
  end
  private_class_method :items_met?

  def self.skills_met?(player, condition)
    required = Array(condition).filter_map(&:presence)
    return true if required.empty?
    player.skills.where(name: required).count == required.uniq.size
  end
  private_class_method :skills_met?

  def self.consume_quest_items!(player, conditions)
    Array(conditions["items"]).each do |entry|
      next unless entry.is_a?(Hash) && entry["consume"]
      name = entry["name"].to_s.strip
      qty  = entry["quantity"].to_i
      next if name.blank? || qty <= 0

      item = player.items.find_by(name: name)
      next unless item

      new_qty = item.quantity.to_i - qty
      new_qty <= 0 ? item.destroy! : item.update!(quantity: new_qty)
    end
  end
  private_class_method :consume_quest_items!

  def self.apply_quest_reward!(player, reward)
    messages = []

    col = reward["col"].to_i
    if col.positive?
      player.col = player.col.to_i + col
      messages << "#{col}コルを入手した。"
    end

    exp = reward["exp"].to_i
    if exp.positive?
      level_before = player.effective_level
      player.gain_exp!(exp)
      messages << "#{exp}EXPを獲得した。"
      if player.effective_level > level_before
        messages << "[levelup]レベル#{player.effective_level}に上昇！振り分けポイント +#{(player.effective_level - level_before) * 3}[/levelup]"
      end
    end

    Array(reward["items"]).each do |item_reward|
      category = item_reward["category"].presence || "drop"
      unique   = item_reward["unique_item"].to_s.downcase == "true"
      qty      = (item_reward["quantity"].presence || 1).to_i
      item     = ItemService.add_item!(player, item_reward["name"], category, qty, unique: unique)
      item.save!
      messages << "#{item_reward["name"]}を#{qty}個入手した。"
    end

    Array(reward["skills"]).each do |skill_name|
      next if skill_name.blank?
      next if player.skills.exists?(name: skill_name)
      player.skills.create!(name: skill_name, proficiency: 0, skill_exp: 0)
      messages << "スキル「#{skill_name}」を習得した。"
    end

    player.save!
    messages.join
  end
  private_class_method :apply_quest_reward!
end
