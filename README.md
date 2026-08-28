# dj-backbling

Melee weapons in your inventory sit on your back like Fortnite back blings. Every player on the server sees the same weapons, in the same slots, and they disappear from the back while you have that weapon in your hands.

This is a from-scratch take on the Renewed Weaponscarry idea, built only for melee / backbling-style carry.

## Why this approach

- **Local props + statebags** — objects are created on each client, not as networked entities. That works with OneSync, entity lockdown, and filter-request-control.
- **Server-owned state** — inventory is read on the server when ox / QB / ESX is present, then written to a player statebag. Clients never have to trust each other for what is on someone's back.
- **Stacked slots** — up to three melee weapons at once (right of spine, left of spine, lower diagonal) so two bats do not occupy the same space.
- **No required dependencies** — ox_inventory, ox_lib, QB, Qbox, qs-inventory, and ESX are optional. Without them it falls back to native GTA weapons.

## Install

1. Drop this folder in `resources` as `djfivem-backbling` (or rename it).
2. Add to `server.cfg`:

```
ensure djfivem-backbling
```

Put it **after** your inventory resource.

3. Restart the server (or `ensure djfivem-backbling`).

If you use a clothing / appearance menu, hide backbling while the camera is on the ped:

```lua
exports['djfivem-backbling']:setVisible(false) -- open
exports['djfivem-backbling']:setVisible(true)  -- close
```

Use your actual resource folder name in the export.

## Adding your weapons

Vanilla GTA melee is already configured. These custom melee weapons are included:

| Item | Preset | Back slot preference |
| --- | --- | --- |
| `WEAPON_FORTNITEPICKAXE` | long | primary (highest priority) |
| `WEAPON_HEARTBAT` | long | primary / secondary |
| `WEAPON_ANGELBAT` | long | primary / secondary |
| `WEAPON_DEVILBAT` | long | primary / secondary |
| `WEAPON_CRAYONBAT` | long | primary / secondary |
| `WEAPON_BANANABAT` | long | primary / secondary |
| `WEAPON_BROOM` | long | primary / secondary |
| `WEAPON_RAKE` | long | primary / secondary |
| `WEAPON_SLURPAXE` | medium | secondary |
| `WEAPON_FORK` | small | tertiary |

The client resolves each addon model from `weapons.meta` (`GetWeapontypeModel`) and also tries `w_me_<name>`. If a prop does not appear, set `model` in `config.lua` to the exact ydr name from the weapon pack.

Add more names the same way:

```lua
['weapon_katana'] = { model = 'w_me_katana', preset = 'katana' },
['weapon_sledgehammer'] = { model = 'w_me_sledgehammer', preset = 'long' },
```

| Field | Meaning |
| --- | --- |
| key | Inventory item name **or** weapon spawn code (case-insensitive) |
| `model` | ydr / prop name. Optional for real weapons |
| `preset` | `long` (bats, cues) · `medium` (machete, crowbar) · `small` (knives) · `katana` (over-shoulder) |
| `bone` `pos` `rot` | Full placement override (from the in-game editor) |
| `slot` | Force `primary` / `secondary` / `tertiary` |
| `enabled = false` | Skip this item |

`Config.AutoMelee = true` also shows any other `GROUP_MELEE` weapon in inventory using a guessed preset. Blacklist entries (knuckles, unarmed) are ignored.

If an ox_inventory item stores a custom ydr in metadata, it is read from `Config.ModelMetadataKey` (default `model`).

## Live placement editor

1. Hold the melee you want to place (or preview it even if you do not have it).
2. `/backbling weapon_bat`
3. Nudge it until it sits clean on the back.
4. Press **ENTER** — the Lua snippet is printed in F8 (and copied if ox_lib is started).
5. Paste that snippet into `Config.Weapons`.
6. Restart the resource.

| Key | Action |
| --- | --- |
| Arrow keys | Left / right and off the back |
| Page Up / Down | Up / down |
| Q / E | Yaw |
| Numpad 8 / 5 | Pitch |
| Numpad 7 / 9 | Roll |
| Numpad 4 / 6 | Yaw |
| Shift / Ctrl | Fine / coarse steps |
| `[` `]` | Cycle attach bone |
| ENTER | Copy offsets |
| DELETE | Reset |
| F7 | Close editor |

`/backbling` with no arguments edits the first carried melee (or a bat preview). `/backbling close` exits. `/backblingrefresh` forces an inventory resync.

On a live server, set `Config.Editor.allowEveryone = false` and:

```
add_ace group.admin backbling.editor allow
```

## Inventory support

| System | How weapons are detected |
| --- | --- |
| ox_inventory | Server `GetInventoryItems` + client update events + swap hook |
| qb / qbx / ps / lj | `PlayerData.items` |
| qs-inventory | qs export, then QB data |
| ESX | loadout + inventory |
| none of the above | `HasPedGotWeapon` |

Equipped melee is hidden from the back for **everyone**, not just you.

## Exports

```lua
exports['djfivem-backbling']:setVisible(false)
exports['djfivem-backbling']:refresh()
exports['djfivem-backbling']:getWeapons()
exports['djfivem-backbling']:openEditor('weapon_bat')
```

Server:

```lua
exports['djfivem-backbling']:refresh(source)
```

## Notes

- Props are **not** networked. Other players still see them because every client spawns the same local objects from the statebag.
- Vehicles, death, first-person (local only), invisibility, and cutscenes hide the props.
- Female freemode peds get `Config.FemaleOffset` so weapons sit off the spine instead of clipping.
- Keep `Config.MaxVisible` at 3 unless you add more slots in `Config.Slots`.
