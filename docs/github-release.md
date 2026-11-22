# Postal 2 Archipelago 1.1

Unofficial Archipelago randomizer for the original Monday–Friday POSTAL 2 campaign, by TheDogNerd.

This is the first public release. Generate a **new seed**. If an older player YAML still has `lootsanity`, delete that line before you generate.

What changed from the 1.0 playtest line: every loot pile has a place name, unreachable piles stay out of the token roll, and a few gated piles only roll on a hunt day when you can reach them (West Mall Toy Store backrooms and loading dock on Thursday, West Mall upper platform on Friday, Napalm Factory Exterior gate piles on Thursday). Evidence Room bottom-shelf tokens sit far enough forward to grab. The hint-flare rocket is larger. Lootsanity is not a YAML option.

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

## Install the mutator

1. Download `Archipelago.u` and `Archipelago.int` from this release.
2. In Steam, right-click **POSTAL 2** → **Manage** → **Browse local files**.
3. Open the `System` folder. Typical path:

   `C:\Program Files (x86)\Steam\steamapps\common\POSTAL2Complete\System`

   If you use another Steam library folder, it is `steamapps\common\POSTAL2Complete\System` on that drive.
4. Copy **both** files into that `System` folder. Replace them if you are updating.
5. Confirm you can see `Archipelago.u` and `Archipelago.int` next to `Postal2.exe`.

Put them in the **main** Postal 2 `System` folder. Do not put them in `Paradise Lost\System`, `ShareThePain\System`, or the POSTed (`POSTAL2Editor`) folder unless you would like to play from the editor version of the game.

Achievements do not pop on Workshop maps/mutators. On first launch, create a **new save**.

## Install the Archipelago world

1. Install [Archipelago 0.6.x](https://archipelago.gg) if you do not have it.
2. Download `postal2.apworld` from this release. Double click the file to install it automatically. If this does not work, in the Archipelago Launcher select **Install APWorld**, or copy the file into Archipelago's `custom_worlds` folder. Restart the Launcher.
3. Download `postal2.yaml`. Edit it to your liking and then copy it into Archipelago's `Players` folder. Set `name:` to your slot. Alternatively, use the Options Creator in the Archipelago launcher to create your YAML.
4. Generate locally, then host or join the room. Hosts can upload a pre-generated zip to the website if they wish to run it there.

## Play

1. Archipelago Launcher → **Postal 2 Client**. Connect with host:port, slot name (same as the YAML `name:`), and password if any. Keep that window open.
2. Start **POSTAL 2**.
3. **New Game** → **Workshop** → **Archipelago**.

   The in-game list is still named Workshop. A local copy in `System` shows up there the same way a subscribed mutator does. You do not need to subscribe on Steam.
4. You should see "Postal 2 connected" in the client log. If the client was not running, New Game holds you at Monday Home until it connects. In-game `apconnect` is an optional fallback.
5. Use a **new save**.

Full setup, Time Warp, AP tokens, and YAML options (including Piss Realism and Melee Durability): see the [README](https://github.com/SmashUniverse64/postal2-archipelago#postal-2-archipelago).

## Updating

Download the new `Archipelago.u` and `Archipelago.int` over the old ones in `System`, and install the matching `postal2.apworld`. Stay on **1.1.0** for this seed line. Archipelago 0.6.8 needs the world version written as 1.1.0. Reinstall `postal2.apworld` and restart the Launcher. Same seeds.

To remove the mutator, delete `Archipelago.u` and `Archipelago.int` from `System`.

## If Archipelago does not appear in New Game

- Both files are in `POSTAL2Complete\System`, not only one of them.
- You launched the main POSTAL 2 exe, not Paradise Lost.
- Steam finished writing the files (copy again if an antivirus quarantined the `.u`).
