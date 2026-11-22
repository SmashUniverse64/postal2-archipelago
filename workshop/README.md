# Steam Workshop upload

Ship **only** these files:

- `Archipelago.u` (compiled mutator; textures and the flare wav are already cooked in)
- `Archipelago.int` (registers `Archipelago.APGameInfo` so New Game → Workshop can see it)
- `preview.png` (required by POSTed; not loaded by the game)

Do not upload `Classes/`, `Textures/`, `Sounds/`, maps, `postal2.apworld`, YAML, or any stock `.u` / `.utx` / `.usx` packages. Steam treats an upload with no INT and no `ws-` map as unplayable.

## Prepare the files

From this repo root, after `make.bat` has produced a current `System\Archipelago.u`:

```text
python pack_release.py
```

That fills `workshop/staging/` with the three files above. Version must match `apworld/postal2/archipelago.json` (currently **1.1.0**).

## Upload

1. Open **POSTed** → Tools → **Upload to Steam Workshop**.
2. Add the three files from `workshop/staging/`.
3. Title: `Postal 2 Archipelago Randomizer`
4. Paste `description.txt` into the description.
5. Visibility: **Private**.
6. Windows. Game **1415** (POSTAL 2). Do **not** require Paradise Lost DLC. If POSTed ticks it, remove it afterward in Steam → item → Owner Controls → Add/Remove Required DLC.
7. Publish, then test on **retail** Postal 2 (Steam Complete): subscribe, New Game → Workshop → Archipelago, with Postal 2 Client listening on `127.0.0.1:23981`.
8. When that works, set the item **Public**.

Workshop saves are flagged cheated. Achievements stay off. Keep this mutator and `postal2.apworld` on the same version so seeds do not desync.
