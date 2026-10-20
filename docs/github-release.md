# Postal 2 Archipelago 1.0.26

Unofficial Archipelago randomizer for the original Monday–Friday POSTAL 2 campaign, by TheDogNerd.

This release is the **manual install**. You do not need the Steam Workshop. Copy two files into Postal 2's `System` folder, then install the apworld in Archipelago.

Keep every file from this same release. Mixing this mutator with a different `postal2.apworld` will desync.

## Files

| File | Where it goes |
| --- | --- |
| `Archipelago.u` | Postal 2 `System` folder |
| `Archipelago.int` | Postal 2 `System` folder (same place as the `.u`) |
| `postal2.apworld` | Archipelago (Launcher → Install APWorld) |
| `postal2.yaml` | Archipelago `Players` folder |

You need **all four**. The `.u` and `.int` are the in-game mutator. The apworld and YAML are the Archipelago world. The mutator talks to **Postal 2 Client** on `127.0.0.1:23981`.

## Install the mutator (no Workshop)

1. Download `Archipelago.u` and `Archipelago.int` from this release.
2. In Steam, right-click **POSTAL 2** → **Manage** → **Browse local files**.
3. Open the `System` folder. Typical path:

   `C:\Program Files (x86)\Steam\steamapps\common\POSTAL2Complete\System`

   If you use another Steam library, it is `steamapps\common\POSTAL2Complete\System` on that drive.
4. Copy **both** files into that `System` folder. Replace them if you are updating.
5. Confirm you can see `Archipelago.u` and `Archipelago.int` next to `Postal2.exe`.

Put them in the **main** Postal 2 `System` folder. Do not put them in `Paradise Lost\System`, `ShareThePain\System`, or the POSTed (`POSTAL2Editor`) folder unless you only play from the editor.

Steam may flag Workshop saves as cheated. Achievements stay off. Use a **new save**.

## Install the Archipelago world

1. Install [Archipelago 0.6.x](https://archipelago.gg) if you do not have it.
2. Download `postal2.apworld` from this release. In the Archipelago Launcher, **Install APWorld**, or copy the file into Archipelago's `custom_worlds` folder. Restart the Launcher.
3. Download `postal2.yaml`. Copy it into Archipelago's `Players` folder. Set `name:` to your slot.
4. Generate locally, then host or join the room. Website generate cannot run this world yet. Hosts can upload a pre-generated zip.

## Play

1. Archipelago Launcher → **Postal 2 Client**. Connect with host:port, slot name (same as the YAML `name:`), and password if any. Keep that window open.
2. Start **POSTAL 2** (the Steam game, not POSTed).
3. **New Game** → **Workshop** → **Archipelago**.

   The in-game list is still named Workshop. A local copy in `System` shows up there the same way a subscribed mutator does. You do not need to subscribe on Steam.
4. You should see "Postal 2 connected" in the client log. If the client was not running, New Game holds you at Monday Home until it connects. In-game `apconnect` is an optional fallback.
5. Use a **new save**.

Full setup, Time Warp, AP tokens, and YAML options (including Piss Realism and Melee Durability): see the [README](https://github.com/SmashUniverse64/postal2-archipelago#postal-2-archipelago).

## Updating

Download the new `Archipelago.u` and `Archipelago.int` over the old ones in `System`, and install the matching `postal2.apworld`. Stay on **1.0.26** for this seed line.

To remove the mutator, delete `Archipelago.u` and `Archipelago.int` from `System`.

## If Archipelago does not appear in New Game

- Both files are in `POSTAL2Complete\System`, not only one of them.
- You launched the main POSTAL 2 exe, not Paradise Lost.
- Steam finished writing the files (copy again if an antivirus quarantined the `.u`).
