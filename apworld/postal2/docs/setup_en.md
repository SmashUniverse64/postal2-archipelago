# Postal 2 Archipelago Setup

Unofficial Archipelago world for the original Monday–Friday campaign. Website generate cannot run this world until it is in Archipelago core: generate locally. Hosts can upload a pre-generated zip.

You need **both** pieces on the same version (currently **1.1**): this `postal2.apworld`, and the in-game mutator (`Archipelago.u` + `Archipelago.int`) from Steam Workshop or the matching GitHub Release.

1. Install [Archipelago 0.6.x](https://archipelago.gg).
2. Install this `postal2.apworld` (Launcher → Install APWorld, or copy into `custom_worlds`). Restart the Launcher.
3. Subscribe to the Steam Workshop mutator, **or** copy `Archipelago.u` and `Archipelago.int` into Postal 2's `System` folder (Steam Complete). Pick one mutator source.
4. Copy `postal2.yaml` into Archipelago's `Players` folder. Set `name:` to your slot.
5. Generate locally, then host or join the room.
6. In the Archipelago Launcher, open **Postal 2 Client**. Connect with host:port, slot name (must match the YAML `name`), and password if any. Keep that window open. The client listens on `127.0.0.1:23981`.
7. Start **POSTAL 2**. New Game → Workshop → **Archipelago**. You should see "Postal 2 connected" in the client log. In-game `apconnect` is optional fallback if you did not connect in the client first.
8. Use a **new save**. Old saves remember pickups and will skip the paycheck desk.

Paradise Lost, Apocalypse Weekend as its own campaign, Eternal Damnation, and seasonal overlays are not part of this world. Workshop saves are flagged cheated; achievements stay off.

Moving to a new **0.x** or **1.x** line usually needs a **new seed**. Stay on current **1.1** unless you are generating.

## Versions

### 0.5
Errands are Archipelago unlock items.

### 0.6
Hunt-and-token world.

- Randomized weekday hunts: each map once, about 5–6 maps a day. Monday 2–4 maps. Library, Brewery, and Napalm always on the day they open. Suburbs East Thursday/Friday. Napalm Factory Exterior hunts with the factory interior on Thursday.
- Named caches join the per-map token roll. **Max Vending Items** (`vending_slots`, default 3, max 5).
- Map-enter checks fire on that map’s hunt day only; one enter per map.
- Tora Bora is on the map from the start (no Access item).
- Collected AP tokens despawn after death or loading a save.
- Dropped: Intro visit/tokens, shop/event checks, world Crackola-can piles, and unreachable piles (Home Medkit 15, Home Kevlar 6, Ghetto sky grenades 8–10 and shotgun ammo 9).

### 0.7
Hunt polish and Time Warp extras.

- **Max Tokens Per Map** (`max_tokens`, default 12, range 6–15).
- Token Glow / Token Heartbeat also mark ATM, Crackola, and vending machines that still have checks.
- Time Warp **6–9** return to Library, Burning Library, Brewery, and Napalm after you leave those maps.
- Gimp Trap. Time Warp locks on first Burning Library / Brewery visit, after grabbing napalm, and while wearing the gimp suit.
- Filler weighted toward ammo, medkits, and powerups. Filler/trap world tokens use a greyscale AP logo.
- Trainyard hunts start Tuesday. Church hunts start Wednesday (Tuesday confession still works).
- Drop remaining unreachable Z=0 sky piles.

### 0.8
Combat, catch-up, and Time Warp presentation.

- Weapon pool adds Machine Pistol, Submachine Gun, Sledgehammer, Taser, Baton, Baseball Bat, and Hedge Clippers.
- Optional **Melee Durability** (default on) and Weapon Repair Kit, shown in the ammo HUD slot. Taser is not affected. Leftover filler can roll Repair Kits.
- Loading a save or starting a new game catch-up-syncs AP items and errand completions. Collected tokens strip after catch-up; map token counts match the seed.
- Thrown Time Warp is a colored AP token. When the Forest Christmas-tree godshaft lights (and the angel choir plays), pick it up to warp. Leave it glowing 10 seconds to cancel.
- Gimp Trap travels with the save and restores Dude clothes on the next map (police uniform too if you had it). Brewery exit load zone restores the AP loadout. Burning Library first visit and Napalm after grabbing the tank put you in the gimp suit.
- Greyscale filler/trap tokens with a pulsing grey glow. Hunt maps show `(M)`/`(T)`/`(W)`/`(Th)`/`(F)` after that weekday is reached. Burning Library label.
- Drop Home Grenades 14 and Trainyard Gas Can 3 / Sledgehammer 2. Lucky Ganesh milk can be paid for at Habib’s counter.

### 0.9
First successful playtest through 0.9.46.

**Goal.** Completing the last of the 19 weekday errands starts the Apocalypse and breaks Time Warp, so you walk Home through it. Reaching the trailer plays Friday’s ending cutscene and credits even if you finished on Monday–Thursday.

**Time Warp.** Destination screen is Home plus unlockable warp points: Greenbelt, Main Street, Office Complex, Ghetto, and Tora Bora any day; Trainyard from Tuesday; Napalm Factory Exterior and East Suburbs from Thursday. Keys **6–9** return to Library, Burning Library, Brewery, and Napalm after you leave those maps once. Key **0** returns to Parcel Center on Friday the same way (the building locks down after the first visit). Time Warp is granted at the end of every map load if missing.

**Vending.** Machines show the real Archipelago item name and the scouted price (cash is $5 / $20 / $100). ATF/fast-food machines sell Weapon Repair Kits for $50 when Melee Durability is on. The weapon wheel draws a durability bar on melee icons.

**World checks.** Mapped pickups use place names in hints/spoilers/tracker. YAML **Lootsanity** turns every eligible loot pile into an AP token (blocked piles stay out; hunt days still pick which maps spawn). Map overlay titles match in-game names (Trainyard Area, Industrial Area, Church and Cemetery) with related districts stacked together, including Napalm Factory Exterior over Napalm Factory, and Sewers / Tora Bora to the right of Home. Checkmarks: cyan visited, gold AP tokens done, blue Crackola, magenta ATMs, red vending; a legend sits in the bottom-right. Clearing an area’s last AP token plays one of the Dude’s map-screen errand-complete lines. East Mall’s paired Crackola cabinets share one check. **Hint Flare** is a junk item (also $30 on those vending machines) that fires a harmless noclip rocket from every AP token; cluster bursts use the rocket-launcher explosion, with one boom per flare. Token heartbeat hear-distance is 3000. Dropped Ghetto Glock Ammo 4 (derailed train bridge, cheat-only) and Police Station Catnip 1 (inside a box). Generate a **new seed** after Catnip 1.

**Stability.** Home/Brewery map loads no longer runaway-loop (pickups, weapon selector, inventory, unlock list). Reconnect no longer replays Drop Gun and other traps into the loadout. Token counts match Archipelago’s checked list. Scroll wheel works after errand cutscenes; map travel no longer duplicates Sledge/Molotov. New Game holds you at Monday Home until the Postal 2 Client is connected and your first Monday errand is granted (center prompt only, once per session). Connecting the client while frozen should unfreeze in place; the mutator retries TCP every 2s and asks for catch-up until the Monday starter arrives. Leaving Home or receiving the starter never shows that prompt again, including across map loads. Brewery gimp escape does not grant Dude clothes. Map travel still rehooks TCP, but the client log no longer prints Postal 2 connected/disconnected for those brief drops. Starting without Skip Intro no longer crashes on the Monday errand map if the client is not connected yet. A Piss trap at Monday spawn no longer leaves weapon switching dead until the next map. The overlay-only left hand is kept off the weapon wheel so slot 1 is a single Hands.

**Suicide Bomber Trap.** Spawns the Tuesday/Home suicide-bomber NPC unarmed on walkable ground at least 1000 units from you (search reaches about 4800). They charge until you shoot them or they close in. The blast is grenade-strength (130 damage, 450 radius). Two copies in the trap pool. Generate a **new seed**. Restart Postal 2 Client and Postal 2.

**Melee pool.** Dusters and Bali (butterfly knife) are shuffled unlocks like the other melee weapons, including Random Weapon at the start of the week. World piles stay locked until you receive the item. Generate a **new seed**. Restart Postal 2 Client and Postal 2.

**Extra guns.** Krotchy Grenade, Box Launcher, and Cat Launcher are shuffled unlocks with the other guns, including Random Weapon. World piles stay locked until you receive that gun (Rocket Launcher does not also unlock Box/Cat Launcher). Generate a **new seed**. Restart Postal 2 Client and Postal 2.

### 1.0
Starting day and a shuffled week.

**Starting Day.** YAML `starting_day` is Monday (default), Tuesday, Wednesday, Thursday, Friday, or Random. After the intro (or immediately with Skip Intro) you load into that weekday with one random errand from that day. The seed shuffles the other four days into a random beatable order so checks on one day can hold the next day’s errands. Leftover starting-day chores sit later in that order, so a Monday start can next unlock Thursday (then Tuesday, Friday, Wednesday, for example). Other days unlock when you receive any errand for that day, including Monday if you did not start there. Generate a **new seed** for 1.0.12.

**Hunt waves.** The starting weekday gets 2–4 leftover hunt maps you can enter that day. Each newly unlocked day in the seed’s order opens another wave. Remainders dump on the last day in that order only if the map is actually open that weekday (Monday-last never receives Napalm, Parcel Center, or other Thursday/Friday maps). One-shot story maps still hunt on the day they open. Tokens and the map-visit check only appear if you enter that map on its hunt weekday (Time Warp back if you miss it). The pause map hides locked waves; once a hunt unlocks it stays labeled — gold on that weekday, grey if you cannot collect there right now (wrong day, or the map is closed today). Leftover vanilla piles next to an AP token stay usable (heal, ammo, guns); only the logo is the check. Unreachable Home load-zone pistols (Pistol 8/9 plus Grenades 13 in the same pocket as Kevlar 6) and the Office Complex unbreakable-box cluster (MP5 Ammo 1–5, Glock Ammo 1–5, BoxLauncher) are excluded from the token roll. Every loot pile uses map-place labels in hints/spoilers/tracker, including former named caches (shed shovel, dog-pit rocket, Tora crates), which are ordinary catalog tokens. Restart Postal 2 for 1.0.6 token grab size, 1.0.8 Lootsanity map-screen stability, 1.0.10 Lootsanity map-load, 1.0.13 Time Warp / token heartbeat, 1.0.14 Piss Realism (same save if you leave that option off), 1.0.15 Lootsanity pause-map counts (same save), 1.0.16 Water Bottle junk (**new seed** for bottles in the pool), 1.0.17 Piss Realism regen of one pip per 120 seconds (same save), 1.0.18 YAML `piss_regen` 30–180 default 120 (**new seed** to change the rate), 1.0.19 Always Clinic is no longer a YAML option (Friday clinic is always on; delete `clinic_always` from old YAMLs; same save), 1.0.20 Krotchy Grenade / Box Launcher / Cat Launcher unlocks (**new seed**), 1.0.21 retired named-cache uniques (those piles join the per-map token roll; Brewery gimp stays an event; **new seed**), 1.0.22 map-travel CHECK garbage (`VBUY_GREENBRecBlobs=(`; same save; restart Postal 2 and Postal 2 Client), 1.0.23 East Mall ATF vending glow (ATM on the same kiosk no longer keeps the rainbow after VBUY/VUSE; same save), 1.0.24 location display names (Police Station and Office Complex from in-game screenshots; other maps use More/Another/The Last stacking instead of Place 2 numbering; **new seed**), and 1.0.25 Police Station cop-uniform locker spawn (the token no longer uncovers onto the unreachable roof) plus Evidence Room gimp clothes / flamethrower pulled off the back of the shelf (restart Postal 2; **new seed** for Cop Uniform Locker Room Locker), and 1.0.26 Bates Hotel room names on the Ghetto map (A-1–A-4 upstairs, B-1–B-2 downstairs, Lobby; **new seed**), and 1.0.27 Police Station Evidence Room Shotgun / Locker Room Health Pipe plus Clinic Area Warehouse North Medkit 2 pulled into grab range (restart Postal 2; same save). Generate a **new seed** for 1.0.12 weekday order, 1.0.7 / 1.0.11 / 1.0.24 / 1.0.25 / 1.0.26 place names (and for 1.0.4 blocked piles if you still need those). Generate a **new seed** to turn **Piss Realism** on. **Melee Durability** is now off when the YAML omits it.

**Piss Realism.** YAML `piss_realism` (off by default). Bladder starts at 1/20. Regen seconds is YAML `piss_regen` (default 120, range 30–180). Near 18/20 the Dude uses the Friday clinic “have to pee” lines. At 20/20 he takes 1 damage per second (`GonorrheaDamage`, cannot kill) until he goes. Once he starts peeing he cannot zip up until the meter is under 10. Water bottles are $5 on every vending machine and add 5 instantly; Crackola also adds 5. With the option on, Water Bottles are also junk in the item pool (grey AP tokens, 8 copies plus leftover filler). Restart Postal 2 and Postal 2 Client; pack apworld. Generate a **new seed** for bottles in the pool or to change regen.

**Lootsanity pause map.** Opening the map with Lootsanity no longer runaway-loops remaining-token counts (`CountCatalogLeftForMap`). Counts are cached after catch-up instead of scanning every catalog unique every frame. Restart Postal 2; same save.

### 1.1
First public release. Generate a **new seed**. Delete `lootsanity` from an older `postal2.yaml` before you generate. Restart the Archipelago Launcher after installing the apworld, and restart Postal 2 after replacing the mutator.

**Loot names.** Every token uses a hand-written place name in hints, spoilers, and the tracker.

**Unreachable piles.** Piles outside the map, past a load zone, or clipped out of reach stay out of the token roll.

**Gates.** A few piles only roll when that map's hunt day can reach them. West Mall Toy Store backrooms and the loading dock roll on Thursday (Get Krotchy). West Mall's secret upper platform (Shears and Grenade Launcher) rolls on Friday. Napalm Factory Exterior piles inside the factory gate (Baseball Bat 1, Dynamite 4, 5, and 6) roll on Thursday. That gate locks on Friday after Get Napalm.

**Grab range.** Police Station Evidence Room bottom-shelf tokens are pulled forward so Dude can pick them up.

**Hint flare.** The rocket is larger, and the burst is no longer hidden by the engine's distance cull.

**Lootsanity.** Not a YAML option. Delete `lootsanity` from an older player YAML.

**Debug commands.** Token dump, token boom, item resync, location print, and token screenshots are not in this build. `apconnect`, `apstatus`, and `apdisconnect` stay.

**Death Link.** Off by default. With it on, the Dude dying tells every other player who turned Death Link on. The cause is "The Dude died." A death from them kills the Dude, then the game loads the last save, the same as any other death. Same seed. Restart Postal 2 and the Postal 2 Client.

## Developers

Compile the mutator from POSTed (`Archipelago/make.bat`) if you changed UnrealScript. Pack the world with `python pack_apworld.py` from `Archipelago/apworld`. Stage GitHub Release and Workshop files with `python pack_release.py` from the repo root.
