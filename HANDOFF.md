# Animal Rush: handoff notes

Everything done so far, so a new chat (or a Claude Code session on the Mac) can continue.
All code is in this repo: **github.com/davidRomash/RO**, branch **`claude/roblox-game-dev-qlsako`**.

## 1. The game

A Roblox collect-and-race game for kids aged 8 to 13, mostly on phones. It follows the
"Animal Rush Developer Design Document" (a PDF the owner has). Core loop: race on a track,
earn coins by place, hatch eggs, equip up to 3 animals (their speed adds up and each has
a track ability), unlock the next zone.

**What exists now (the MVP from the doc, working in Studio):**
- Plaza hub: fountain, portal arches to zones, egg shop, daily reward chest, global leaderboard.
- 8 base plots in a ring: free plot per player, 3 upgrade levels (more inventory slots), equipped
  animals walk around the base.
- Zones: **Forest** (straight track with logs to jump) and **Beach** (water and sand sections,
  gate 2,500 coins). Desert, Ice World and Volcano show as "Coming soon"; a Volcano landmark is visible.
- Races start from a green start pad; bots fill lineups under 3 players; server checks
  checkpoints in order plus a minimum-time anti-cheat; payouts 100/70/50/30% of the purse.
- 10 animals (5 per zone, Common to Legendary) with abilities: Rabbit speed burst, Cat high jump,
  Fox +20% in the Forest, Bear ignores logs, Panda +25% coins, Crab ignores sand, Turtle shield,
  Frog leap, Dolphin/Shark fast in water. Button abilities: Rabbit, Cat, Frog (key F).
- Eggs: odds shown, pity (Rare+ guaranteed within 20 hatches), Hatch x1/x3, hatch animation,
  5 copies merge into Golden, sell animals, collection index.
- Saving with ProfileStore (session locking). Daily reward, playtime gifts, leaderstats.
- First-minute tutorial: free Rabbit, a yellow arrow points to the Forest portal, then the
  start pad, then the egg stand. First race is tuned so the new player wins and can afford an egg.
- HUD: coins, race info, daily reward, settings, Pets/Eggs/Zones menus, ability button,
  progress bar to the next zone. Mobile scaling and safe areas.
- **Admin:** red 🛠️ panel on the right (admins only: game owner, anyone in Studio, UserIds in
  `src/config/Admins.luau`) plus chat commands starting with `;` (`;help`).

**Placeholders:** animals are built from basic shapes, the map is generated from parts,
there are no sounds or music.

## 2. Code layout

| Path | What |
|---|---|
| `default.project.json` | Rojo mapping + every RemoteEvent/RemoteFunction |
| `src/config` | All balance numbers: Animals, Rarities, Eggs, Zones (tracks), Economy, Sounds, Admins |
| `src/shared` | Layout (all world positions), PetMath, AnimalModel (placeholder models), Util |
| `src/server/Main.server.luau` | Boots services (Init, then Start) |
| `src/server/Services` | Net, DataService, WorldBuilder, PetService, TutorialService, ZoneService, BaseService, EggService, RaceService, RewardService, LeaderboardService, AdminService, Teleport |
| `src/server/Packages/ProfileStore.luau` | Third-party saving library (Apache 2.0) |
| `src/client/Main.client.luau` | Boots controllers |
| `src/client/Controllers` | UIKit, State, Hud, HatchController, PetsMenu, EggMenu, ZonesMenu, SettingsMenu, RaceController, GuideController, PetFollowController, WorldController, AdminPanel |

Rules followed: the server decides everything (coins, hatches, results); remotes only carry
requests and are rate-limited; balance numbers live only in `src/config`.

## 3. How it runs on the owner's Mac

- Project folder: `~/roblox animal rush` (it is **not** a git clone; it was filled from GitHub zips).
- Rojo 7.7.0: `rojo serve` in that folder, then Connect in the Studio Rojo plugin.
  If port 34872 is busy: `pkill rojo` then `rojo serve`.
- Updating from GitHub without git: download
  `https://github.com/davidRomash/RO/archive/refs/heads/claude/roblox-game-dev-qlsako.zip`, then:
  ```bash
  Z="$(ls -t ~/Downloads/RO-claude-roblox-game-dev-qlsako*.zip | head -1)"; rm -rf /tmp/ar && mkdir /tmp/ar && unzip -q "$Z" -d /tmp/ar && cd "$(find ~ -maxdepth 4 -type d -name 'roblox animal rush' -not -path '*/Downloads/*' 2>/dev/null | head -1)" && rm -rf src && cp -R /tmp/ar/*/. . && rojo serve
  ```
  Better: turn the folder into a real clone so `git pull` works.
- The map only exists in Play mode (built at runtime). Saving in Studio needs the place published and
  "Enable Studio Access to API Services" on; otherwise data resets each session.
- **Claude Code on the Mac** is installed, with the Roblox Studio MCP server added:
  `claude mcp add --scope user --transport stdio Roblox_Studio -- "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"`.
  Still to do: `/login` (it showed "Not logged in" and "API Usage Billing"), check `/mcp`,
  then `claude remote-control` in the project folder to chat with it from the Claude app.

## 4. Owner feedback not yet built

1. The map is too big; portals don't excite kids. Show the zones as **floating islands** visible
   from the Plaza.
2. Everything looks cheap: need real models, good VFX, sound effects, original/copyright-free music.
3. **GUI must show from the start.** The menu buttons are hidden until the first hatch (tutorial design); the owner wants them visible immediately. Also a much bigger, nicer GUI.
4. Better daily reward (real chest, animation, streak), animated fountain water.
5. Faster walking in the Plaza/hub and a **dash** (not in races).
6. Pets: different **sizes** (bigger for rarer), **auras**, funny/"brainrot-style" but
   **original** creatures (not copied from Steal a Brainrot or other games).
7. Wants the game to be **original, racing-centred**, not a copy of Steal an Egg.

## 5. Ideas offered, waiting for the owner to pick

1. Ride your creature (race on your pet as a mount).
2. Relay race with your 3 creatures.
3. Creature-only races where you cheer to boost.
4. Mixed races (on foot, riding, wild creatures).
5. The egg runs away: race to catch eggs with legs.
6. Golden egg appears mid-race; carrying it slows you.
7. Eggs hatch after X laps of racing.
8. Winner's egg only 1st place can get.
9. Boss races against a giant wild creature every few minutes.
10. Zone champion creature to beat 3 times.
11. Chase mode: a funny monster chases racers.
12. Crazy tracks (giant's kitchen, moving train, erupting volcano, upside-down).
13. Changing track events (rain, low gravity, speed pads, banana peels).
14. Map voting before each race (players pick the map that suits their team).
15. Random creature traits (Turbo, Tiny, Giant, Lucky, Rainbow).
16. Fusion: combine 2 creatures into a new secret one.
17. Creature XP and evolution at level 10.
18. Silly power-ups (banana peel, sneeze, shrink ray, trampoline).
19. Victory dances on a podium.
20. Spectator betting with in-game coins only.

Suggested combo: **1 + 5 + 9 + 16**. Also offered: a "best map" hint in the Pets menu and a
cheaper Beach. The owner has not chosen yet.

## 6. Suggested build order

1. Quick fixes: show GUI from the start, smaller map, faster hub walking + dash, pet size by
   rarity, auras, better hatch VFX.
2. Floating islands instead of portals, map voting, best-map hint.
3. The owner's picks from the ideas list.
4. Assets (models, icons, music, sounds), then a GUI redesign using them.

## 7. Assets (all CC0 unless noted; the owner imports them in Studio with Import 3D)

- Pets: Kenney Cube Pets 2.0 (cat, bunny, panda, fox + more), Quaternius Animated Fish Bundle
  (shark), poly.pizza for crab/frog/turtle/dolphin, Quaternius Animated Animal Pack. Styles don't mix
  well; for original funny creatures use Higgsfield (image, then image-to-3D) in one consistent style.
- World: Kenney Nature Kit, poly.pizza props.
- VFX: Kenney Particle Pack, Kenney Smoke Particles, Creator Store (verified creators only).
- GUI: Kenney UI Pack / UI Pack Adventure; Higgsfield for custom icons.
- Sound: Kenney Interface Sounds / UI Audio; music from the Creator Store (licensed by Roblox) or Higgsfield.
- Plan once models are imported: put them in `ReplicatedStorage/PetModels`, named like the
  animal (`Rabbit`, `Cat`, ...), and make `AnimalModel.Build` clone them (fall back to shapes).

## 8. Checks used

`rojo sourcemap` + `luau-lsp analyze` with Roblox type definitions pass on all code; `rojo build`
succeeds. The game has been played in Studio by the owner (Rabbit, HUD and admin panel confirmed working).
