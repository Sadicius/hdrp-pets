# 🐾 HDRP-PETS
- Advanced and modular pet/companion system for RedM, built on `rsg-core` and `ox_lib`. Supports multi-pet, progression, games, care, inventory, herding, and full localization (es/en).

## Features
- 🐕 **Multi-Pet**: Manage up to 10 active pets simultaneously
- 📈 **Full Progression**: XP, levels, stats, and life cycle
- 🎮 **7+ Mini-Games**: Treasure hunts, races, fights, hunting, and more
- 🏥 **Veterinary System**: Vaccinations, diseases, surgeries
- 🔄 **Breeding**: Breed pets with pedigrees
- 🌍 **Localization**: Spanish and English included

### Veterinary System
- **Medical Checkups**: Disease Diagnosis
- **Vaccination**: 30-Day Protection
- **Diseases**: Anemia, Arthritis, Colic, Pneumonia, etc.

- **Surgeries**: Sterilization and Treatments
- **Revival**: Resuscitates Deceased Pets

### Reproduction System
- Breeding between compatible pets
- Realistic gestation period
- Tracked genealogy (parents/offspring)
- Cooldown between litters
- Optional sterilization

### AI Behavior
- **Defensive Mode**: Attacks when the player is attacked
- **Wandering**: Free movement around the player
- **Herding**: Herd control with 20+ formations
- **Ambient**: Automatic actions (drink, eat, rest)

---

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

### Project Structure
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

### Advanced Configuration
- All gameplay, XP, shop, vet, decay, multi-pet, herding, and wandering settings are in `shared/config/`.
- Add or edit items, prices, and shop props in `shared/stable/`.
- Add new UI/notification/log strings to both `locales/es.json` and `locales/en.json` and use `locale('key')` in code.
- Map assets for pet stables are in `stream/` (YMAPs).
  
---

## Main Configuration
- 📁 shared/main.lua

```lua
Config.Debug = false -- Debug mode
Config.MaxActivePets = 10 -- Maximum active pets
Config.EnableTarget = true -- Use ox_target
Config.EnablePrompts = true -- Show prompts
Config.DistanceSpawn = 20.0 -- Spawn distance
Config.MaxCallDistance = 100.0 -- Maximum call distance
Config.FollowDistance = 3 -- Follow distance
```

### Pet Attributes
- 📁 shared/config/attributes.lua

```lua
Config.PetAttributes = {
  RaiseAnimal = true, -- Requires feeding for XP
  DefensiveMode = true, -- Attacks when player is in combat
  NoFear = false, -- Disables fear on horses
  
  Starting = { -- Initial stats
    Hunger = 75,
    Thirst = 75,
    Happiness = 75,
    Health = 100
  },
  
  AutoDecay = {
    Enabled = false, -- Automatic decay
    Interval = 60000, -- Interval in ms
    Amount = 1 -- Amount per tick
  }
```
### Enabled Systems
- 📁 shared/config/systems.lua
  
```lua
Config.Systems = {
  Ambient = { Enabled = true }, -- Environmental behavior
  Wandering = { Enabled = true }, -- Free movement
  Herding = { -- Herding system
    Enabled = true,
    MaxAnimals = 10,
    Distance = 15.0
    
    },
  Reproduction = { Enabled = true }, -- Pet breeding
  Veterinary = { Enabled = true }, -- Veterinary system
}
```

### Stables
- 📁 shared/stable/stables.lua

```lua
Config.Stables = {
  valentine = {
    name = "Valentine Stable",
    coords = vector3(-365.5, 770.5, 115.0),
    npc = { model = "s_m_m_stowner_01", ... },
  },
  -- ... more stables
}
```
---

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

--- 

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

## Callbaks (server)
```lua
-- Get Pets
RSGCore.Functions.TriggerCallback('hdrp-pets:server:getallcompanions', function(companions)
-- List of all the player's pets
end)

RSGCore.Functions.TriggerCallback('hdrp-pets:server:getcompanionbyid', function(companion)
-- Data of a specific pet
end, companionid)
```

---

## Changelog
- See `CHANGELOG.md` for a full list of changes and version history.
- 🤝 Contribute
- Contributions are welcome. Please:

## Fork the repository
- Create a branch for your feature (git checkout -b feature/new-feature)
- Commit your changes (git commit -m 'Add new feature')
- Push to the branch (git push origin feature/new-feature)
- Open a Pull Request

## Credits
- HDRP framework by Sadicius. Additional acknowledgments and contributors in `CHANGELOG.md`.

<img width="500" height="500" alt="qrcode" src="https://github.com/user-attachments/assets/d79129e4-ad53-44af-8cab-cdd6383271a6" />
