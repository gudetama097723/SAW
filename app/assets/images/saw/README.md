# SAW Visual Assets

画像はこの配下に種類別で配置します。ファイル形式は `webp`, `png`, `jpg`, `jpeg`, `gif` の順で自動検出されます。

## Naming

- 背景: `backgrounds/<location-name-key>.webp`
- NPC: `npcs/<npc-code>.webp`
- Mob: `mobs/<mob-name-key>.webp`
- アイテム: `items/<item-name-key>.webp`
- 武器: `weapons/<weapon-name-key>.webp`
- 防具: `armors/<armor-name-key>.webp`
- スキル: `skills/<skill-key-or-name-key>.webp`
- UI素材: `ui/<ui-key>.webp`

キーは表示名を NFKC 正規化し、英数字以外を `_` に置き換えた小文字です。例: `floor_1`, `beginning_town_guide`。

画像が存在しない場合はプレースホルダーが表示されるため、データ追加と画像制作は別々に進められます。
