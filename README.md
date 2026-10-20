# Postal 2 Archipelago

Unofficial [Archipelago](https://archipelago.gg) randomizer for the original Monday–Friday **POSTAL 2** campaign, by **TheDogNerd**.

This is a fan project. It is not affiliated with Running With Scissors or ArchipelagoMW. Paradise Lost, Apocalypse Weekend as its own campaign, Eternal Damnation, and seasonal overlays are out of v1.

**Current version: 1.0.26.** Keep the mutator and the apworld on the same version.

## Two pieces

You need both:

| Piece | Where it ships | What it is |
| --- | --- | --- |
| `postal2.apworld` + `postal2.yaml` + **Postal 2 Client** | GitHub Releases | World logic, YAML, and the Archipelago client |
| `Archipelago.u` + `Archipelago.int` | Steam Workshop (or the same GitHub Release) | In-game mutator |

The mutator only talks to **Postal 2 Client** on `127.0.0.1:23981`. Subscribing on Workshop does nothing until that client is running and connected to your Archipelago room.

Website generate cannot run this world until it is in Archipelago core. Generate locally. Hosts can upload a pre-generated zip.

## Play

1. Install [Archipelago 0.6.x](https://archipelago.gg).
2. Install `postal2.apworld` from [Releases](../../releases) (Launcher → **Install APWorld**, or copy into `custom_worlds`). Restart the Launcher.
3. Subscribe to the Steam Workshop mutator, **or** copy `Archipelago.u` and `Archipelago.int` from the same Release into Postal 2's `System` folder (Steam Complete). Pick one mutator source.
4. Copy `postal2.yaml` into Archipelago's `Players` folder. Set `name:` to your slot.
5. Generate locally, then host or join the room.
6. Launcher → **Postal 2 Client**. Connect with host:port, slot name, and password if any. Keep that window open.
7. Start **POSTAL 2**. New Game → Workshop → **Archipelago**. Use a **new save**.

Full setup, options, and version history: [`apworld/postal2/docs/setup_en.md`](apworld/postal2/docs/setup_en.md). Game tab: [`apworld/postal2/docs/en_Postal 2.md`](apworld/postal2/docs/en_Postal 2.md).

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

Output is `dist/1.0.26/` (`postal2.apworld`, `postal2.yaml`, `Archipelago.u`, `Archipelago.int`) and `workshop/staging/`.

`scan_pickups.py` is a catalog scanner for the SDK `Maps` folder. Do not full-regen `catalog.py` unless you know how location IDs are assigned; inserting mid-list shifts later IDs.

## Scope

- Goal: all 19 weekday errands, then walk Home through the Apocalypse to the trailer.
- Time Warp replaces clock-out. Completing the last errand breaks Time Warp.
- Game name in Archipelago: `Postal 2`. BASE_ID `232000`.

## License

MIT for this project's code and docs. See [LICENSE](LICENSE). You still need a legitimate copy of POSTAL 2.
