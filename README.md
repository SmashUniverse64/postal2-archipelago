# Postal 2 Archipelago

Unofficial [Archipelago](https://archipelago.gg) randomizer for the original Monday–Friday **POSTAL 2** campaign, by **TheDogNerd**.

Fan project. Not affiliated with Running With Scissors or ArchipelagoMW. v1 is the original week only: Paradise Lost, Apocalypse Weekend as its own campaign, Eternal Damnation, and seasonal overlays stay out.

**Current version: 1.0.27.** Keep the mutator and the apworld on the same version.

**Goal:** finish all 19 weekday errands, then walk Home through the Apocalypse to the trailer.

On New Game you load into YAML **Starting Day** (Monday by default, or Tuesday–Friday / Random) with one random errand for that day. The seed shuffles the other four weekdays into a beatable order. Other days unlock when you receive an errand for that day. New Game holds you at Home until Postal 2 Client is connected and that first errand arrives.

## Time Warp

Clock-out is gone. You always have **Time Warp**.

Open it for a day menu of **unlocked** errands. Keys **1–5** pick a weekday, then a destination: **Home** plus unlockable warp points (Greenbelt, Main Street, Office Complex, Ghetto, and Tora Bora any day; Trainyard from Tuesday; Napalm Factory Exterior and East Suburbs from Thursday). Throw Time Warp on the ground. When the light shaft appears, pick it up to warp. Leave it for ten seconds and the warp cancels.

Keys **6–0** return to Library, Burning Library, Brewery, Napalm Factory, and Parcel Center after you have left those maps once (same throw-and-pick-up). Parcel Center’s key **0** is Friday; the building locks down after the first visit.

Each hunt map is assigned one weekday. AP tokens and the map-visit check spawn only if you enter that map on that day, so Time Warp back if you miss it. Completing the last of the 19 errands starts the Apocalypse and **breaks Time Warp**. Walk Home to the trailer to send the goal, even if you finished on Monday–Thursday.

## AP tokens

World pickups that are Archipelago locations appear as an **AP token** (the Archipelago logo). Useful items keep the color logo. Filler and traps use a greyscale logo.

Which piles become tokens is chosen **per seed** from a catalog of real loot in the maps. **Max Tokens Per Map** (`max_tokens`, default 12, range 6–15) is the cap; each hunt map rolls 6 through that number. Each chosen pile is its own named check (`Main Street - Shotgun Stereo House Bedroom`). Leftover vanilla piles next to a token stay usable (heal, ammo, guns); only the logo is the check. Piles past load zones or inside unbreakable boxes are never tokens.

**Lootsanity** turns every eligible catalog pile into a token. **Token Glow** and **Token Heartbeat** mark remaining checks (heartbeat gets faster and louder as you near a token). **Hint Flare** (junk; also $30 on ATF/fast-food machines) fires a harmless noclip rocket from every AP token on the current map so you can see and hear them.

Map-visit checks fire once per map, on that map’s hunt day. Kickable ATMs, Crackola machines, and opening ATF/food vending menus are checks too when those YAML options are on. Vending machines can stock Archipelago parcels with real item names and scouted prices.

The pause map uses in-game area names. Checkmarks: cyan visited, gold AP tokens done, blue Crackola, magenta ATMs, red vending. Clearing an area’s last AP token plays one of the Dude’s map-screen errand-complete lines. In Postal 2 Client, `/tracker` lists unchecked locations currently in logic.

## YAML options

Edit `postal2.yaml` before you generate. **Melee Durability** and **Piss Realism** are off unless you turn them on. A new seed is required to change them.

### Melee Durability (`melee_durability`)

Melee weapons wear down on connecting hits. The weapon wheel draws a durability bar on those icons. Activate a **Weapon Repair Kit** from inventory to restore the melee you are holding to full. Picking up a second copy of a melee you already own restores 30 durability. Spare Ammo can also restore 30 on a damaged melee. The Taser does not wear. ATF and fast-food machines sell kits for $50. Repair Kits are junk (grey AP tokens).

### Piss Realism (`piss_realism`)

The bladder starts at 1 out of 20. **Piss Regen Seconds** (`piss_regen`, default 120, range 30–180) is seconds per pip. Near 18/20 the Dude uses the Friday clinic “have to pee” lines. At 20/20 he takes 1 damage per second until he goes (cannot kill). Once he starts peeing he cannot zip up until the meter is under 10. Water bottles are $5 at every vending machine and add 5; Crackola also adds 5. Water Bottles are junk in the item pool when this option is on. The Friday clinic errand is always available.

### Other knobs

Starting Day, Shuffle Weapons, Random Weapon, Max Tokens Per Map, Lootsanity, Token Glow, Token Heartbeat, Vending / Crackola / ATM sanity, traps, Death Link. With Shuffle Weapons on you start unarmed; Dusters, Bali, Krotchy Grenade, Box Launcher, and Cat Launcher sit in the unlock pools with the other weapons.

Full setup, options, and version history: [`apworld/postal2/docs/setup_en.md`](apworld/postal2/docs/setup_en.md). Game tab: [`apworld/postal2/docs/en_Postal 2.md`](apworld/postal2/docs/en_Postal 2.md).

## Two pieces

You need both:

| Piece | Where it ships | What it is |
| --- | --- | --- |
| `postal2.apworld` + `postal2.yaml` + **Postal 2 Client** | GitHub Releases | World logic, YAML, and the Archipelago client |
| `Archipelago.u` + `Archipelago.int` | Steam Workshop (or the same GitHub Release) | In-game mutator |

The mutator talks to **Postal 2 Client** on `127.0.0.1:23981`. Subscribing on Workshop waits until that client is running and connected to your Archipelago room.

Website generate cannot run this world until it is in Archipelago core. Generate locally. Hosts can upload a pre-generated zip.

## Play

1. Install [Archipelago 0.6.x](https://archipelago.gg).
2. Install `postal2.apworld` from [Releases](../../releases) (Launcher → **Install APWorld**, or copy into `custom_worlds`). Restart the Launcher.
3. Subscribe to the Steam Workshop mutator, **or** install `Archipelago.u` and `Archipelago.int` from [Releases](../../releases) with no Workshop (copy both into Postal 2's `System` folder). Pick one mutator source. Manual steps: [`docs/github-release.md`](docs/github-release.md).
4. Copy `postal2.yaml` into Archipelago's `Players` folder. Set `name:` to your slot.
5. Generate locally, then host or join the room.
6. Launcher → **Postal 2 Client**. Connect with host:port, slot name, and password if any. Keep that window open.
7. Start **POSTAL 2**. New Game → Workshop → **Archipelago**. Use a **new save**.

## Requirements

- POSTAL 2 on Steam (Complete). Windows.
- Archipelago 0.6.x (developed against 0.6.7).
- A new save. Workshop saves are flagged cheated; achievements stay off.

## Steam Workshop

Workshop title: **Postal 2 Archipelago Randomizer**.

Upload **only** the compiled mutator: `Archipelago.u`, `Archipelago.int`, and a preview image. Do not upload UnrealScript, textures, sounds, maps, or stock game packages.

Steps live in [`workshop/README.md`](workshop/README.md). Paste [`workshop/description.txt`](workshop/description.txt) into the Workshop dialog. Start the item **private**, test on retail Postal 2, then set it public. Do not mark Paradise Lost as required DLC.

## Developers

This folder is the git root. Do not put the POSTAL 2 SDK or Steam game tree in git.

- Mutator source: `Classes/`, `Textures/`, `Sounds/`, `Archipelago.int`, `make.bat`
- World source: `apworld/postal2/`
- Pack the apworld (also copies into `C:\ProgramData\Archipelago\custom_worlds` when that folder exists):

```text
cd apworld
python pack_apworld.py
```

- Compile the mutator from POSTed (deletes `System\Archipelago.u`, runs `UCC make`, copies `Archipelago.int` into `System`):

```text
make.bat
```

- Stage GitHub Release files plus a Workshop copy:

```text
python pack_release.py
```

Output is `dist/1.0.27/` (`postal2.apworld`, `postal2.yaml`, `Archipelago.u`, `Archipelago.int`) and `workshop/staging/`.

`scan_pickups.py` is a catalog scanner for the SDK `Maps` folder. Do not full-regen `catalog.py` unless you know how location IDs are assigned; inserting mid-list shifts later IDs.

Game name in Archipelago: `Postal 2`. BASE_ID `232000`.

## License

MIT for this project's code and docs. See [LICENSE](LICENSE). You still need a legitimate copy of POSTAL 2.
