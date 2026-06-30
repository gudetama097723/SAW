# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Commands

```bash
# Development
bin/rails s                  # Start server (localhost:3000)
bin/rails c                  # Rails console
bin/rails db:migrate         # Run pending migrations
bin/rails db:seed            # Load CSV seed data
bin/rails db:reset           # Drop + migrate + seed

# Testing
bin/rails test                                            # All tests
bin/rails test test/models/player_test.rb                 # Single file
bin/rails test test/services/battle_service_test.rb

# Code quality
bin/rubocop                  # Linting (Rails Omakase style)
bin/brakeman                 # Security audit
```

## Architecture

Rails 8.1 + Hotwire (Turbo/Stimulus) + SQLite3。ブラウザ上で動くSAOライクなMMORPGシミュレーション。

### レイヤー構造

- **Controllers** (`app/controllers/concerns/game/`): `GameController` は6つのConcernをinclude。`BattleActions`, `FieldActions`, `RestActions`, `ShopActions`, `BaseActions`, `GrowthActions` に分割。ルートは67本のPOSTエンドポイント。
- **Services** (`app/services/`): ゲームロジックの本体。`BattleService`, `FieldService` が中心。サービスは `Result.new(status:, message:)` を返す統一パターン。
- **Catalogs** (`app/services/*_catalog.rb`): CSVをメモリに読み込むシングルトン。ゲームデータ（スキル、ショップ、ドロップ等）の定義はすべてここ経由。
- **Models**: ゲーム状態を保持。複雑な状態（ステータス異常、スキルカウンター等）はJSONカラムに格納。

### コアモデル

- `Player` (`app/models/player.rb`, ~465行): HP/ステータス/レベル/インベントリ/満腹度/睡眠疲労/スキルポイントなどゲーム状態の全体。
- `Battle` / `BattleEnemy`: 戦闘状態。ターン制。
- `Weapon` / `Armor`: 装備。耐久度システムあり（0で破損、スターター武器を除く）。
- `Skill`: プレイヤーが習得したスキルとソードスキルのレベル。

### ゲームデータ (CSV)

`db/seeds/` に23個のCSVファイル。スキル・武器・モブ・場所・レシピ等の定義はすべてCSVで管理。ゲームバランス調整はコード変更不要でCSV編集のみ。

### 主要なゲームメカニクス

**時間システム**: 行動1回につきゲーム内1分進む。満腹度は時間経過で減少。15時間超過で睡眠不足ペナルティ蓄積。月次で拠点の家賃が発生。

**戦闘**: ダメージ = (武器ATK + ステータスボーナス) × (スキル倍率/100) × (弱点/パーツ倍率)。敵はパーツ制（頭・体・脚など）。属性: 斬撃/刺突/打撃。

**スキル熟練度**: 0〜1000スケール。熟練度に応じてソードスキル解放・ダメージ倍率上昇。スキルスロット数はレベルと熟練度で決まる（基本2スロット、最大12）。

**拠点探索**: ルート→フィールドエリア→町の構造。マッピング進捗(0〜100%)で行き先解放。ストロールでNPC施設を発見。

**装備耐久度**: ヒット毎に減少。修理は鍛冶屋でcol消費。強化は+0〜+10。

### DBスキーマの主要テーブル

`players`, `battles`, `battle_enemies`, `weapons`, `armors`, `items`, `skills`, `locations`, `routes`, `field_areas`, `mobs`, `mob_parts`, `npcs`, `npc_discoveries`, `player_route_progresses`, `player_field_area_progresses`, `player_town_discoveries`, `player_bases`, `storage_items`, `weapon_upgrade_recipes`

## 開発上の注意点

- **CSVカタログのキャッシュ**: Catalogクラスはインメモリキャッシュ。CSV変更後はサーバー再起動が必要。
- **フロア実装状況**: 現在フロア1のみ部分実装。100フロア構成の予定。
- **テスト**: `test/` に15以上のテストファイル。システムテスト形式 (Rails標準)。
