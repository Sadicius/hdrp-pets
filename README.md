# HDRP Pets

Advanced and modular pet/companion system for RedM, built on `rsg-core` and `ox_lib`. Supports multi-pet, progression, games, care, inventory, herding, and full localization (es/en).

## Features
- **Multi-pet system:** Summon, dismiss, store, rename, and manage multiple pets per player.
- **Progression:** XP, levels, stats (health, stamina, hunger, thirst, happiness), decay, lifecycle, and veterinary system.
- **Activities:** Mini-games (treasure, bone, buried), hunting, tracking, attacking, hostile/bandit encounters, defensive mode.
- **Care & Inventory:** Feed, water, brush, heal, revive, and persistent saddlebag inventory (via `oxmysql`).
- **Herding & Wandering:** Group follow, advanced herding, and ambient roaming with configurable behaviors.
- **UI & Localization:** Modern ox_lib context menus, notifications, and prompts. Locales in `locales/es.json` and `locales/en.json`.
- **Server-side management:** Shop, trade, item rewards, and persistence.
- **Highly configurable:** All systems, XP, shops, vet, decay, multi-pet, herding, and more via `shared/config/`.

## Requirements
- RedM server with `rsg-core`
- `ox_lib`
- `oxmysql`
- Optional: `ox_target` (for prompts/targeting), `interact-sound` (whistle), map assets in `stream/`

## Installation
1. Copy the resource to your server resources folder.
2. Run the SQL: `installation/hdrp-pets.sql`.
3. Add to your `server.cfg`:

```cfg
ensure ox_lib
ensure oxmysql
ensure rsg-core
ensure hdrp-pets
```

4. Configure `shared/config/` files for pet limits, XP, gameplay toggles, keybinds, shops, prices, vet/decay/lifecycle, multi-pet, herding, and wandering.
5. (Optional) Add shop items and sounds as needed for your server.

## Project Structure
- `client/` — Gameplay, UI, systems (actions, behavior, inventory, pets, herding, wandering, games)
  - `games/` — Mini-games (bandit, bone, buried, hostile, treasure, etc.)
  - `menu/` — UI menus (main, actions, stats, dashboard, achievements, quick actions/care)
  - `stable/` — Stable, call, flee, rename, trade, NPCs
  - `systems/` — Core systems (behavior, prompts, inventory, decay, ambient, attachment, customize, dataview, xp, consumables)
- `server/` — Callbacks, persistence, shop/vet logic, item/trade/reward management
  - `core/` — Validation, database, callbacks
  - `systems/` — Commands, customize, items, management, tracking, trade, lifecycle, veterinary
- `shared/` — Config and shared data
  - `config/` — Attributes, systems, blips, consumables
  - `game/` — Animations, games, retrievable animals, tracking, water types, xp
  - `stable/` — Shop, prices, props, stables
- `installation/` — SQL, shared items, images, sounds
- `locales/` — `es.json`, `en.json` (UI and notification strings)
- `stream/` — Map assets for pet stables

## Commands
- `/pet_menu` — Open pet management menu
- `/pet_find` — Check pet in stable
- `/pet_call` — Summon active pet(s)
- `/pet_flee` — Dismiss active pet(s)
- `/pet_store` — Store pet
- `/pet_revive` — Revive a deceased pet
- `/pet_bone`
- `/pet_hunt` — Toggle hunt mode

## Keybinds (defaults)
- U: Call companion
- F: Send away
- Enter: Saddlebag
- R: Hunt mode
- J: Actions menu
- V: Attack target
- C: Track target

## Exports (client)
```lua
exports['hdrp-pets']:CheckCompanionLevel()
exports['hdrp-pets']:CheckCompanionBondingLevel()
exports['hdrp-pets']:CheckActiveCompanion()          -- ped entity
exports['hdrp-pets']:AttackTarget({ entity })
exports['hdrp-pets']:TrackTarget({ entity })
exports['hdrp-pets']:HuntAnimals({ entity })
exports['hdrp-pets']:TreasureHunt({ entity })
```

## Advanced Configuration
- All gameplay, XP, shop, vet, decay, multi-pet, herding, and wandering settings are in `shared/config/`.
- Add or edit items, prices, and shop props in `shared/stable/`.
- Add new UI/notification/log strings to both `locales/es.json` and `locales/en.json` and use `locale('key')` in code.
- Map assets for pet stables are in `stream/` (YMAPs).

## Changelog
See `CHANGELOG.md` for a full list of changes and version history.

## Credits
HDRP framework by Sadicius. Additional acknowledgments and contributors in `CHANGELOG.md`.
