# Flotsam Camera / View / Map-Switch Tweaks

## Background

Flotsam's camera view is fairly limited and zooming feels slow; after reaching the zoom limit it takes several seconds to switch between the world map and the main view, and the map opens at a far default distance. This tool adjusts those camera values stored in the game scene file `level2`, with all values in `config.json` so they can be changed freely or restored anytime.

Supported version: Flotsam `1.0.1f9` (Epic / Steam, Unity `6000.3.26f1`, Mono).

---

## ✅ TL;DR: one-click scripts (recommended)

The default `config.json` already contains a recommended set of values — just download and run.

| Step | Action |
| --- | --- |
| 1 | Click **Code → Download ZIP** at the top of this page and extract it anywhere (not into the game folder) |
| 2 | **Fully quit** Flotsam (including the running game process) |
| 3 | Skip this step if you want the recommended values; otherwise edit `config.json` with Notepad (see the table below) |
| 4 | Double-click **`Apply-Camera-Tweaks.bat`** and wait for “修改完成” (done) |
| 5 | Launch the game |
| 6 | To go back to vanilla: double-click **`Restore-Camera-Tweaks.bat`** |

> If the game is installed in a protected folder such as `Program Files`, right-click `Apply-Camera-Tweaks.bat` and choose **Run as administrator**.
>
> The first run backs up the original `level2` to `backup\`. The restore script depends on it — do not delete it.

### Tunable values

Every value in `config.json` can be changed; write decimals like `180.0`.

| Key | Vanilla | Recommended | Meaning |
| --- | --- | --- | --- |
| `main_camera.pitch_min_degrees` | 27.5 | 12 | Main camera pitch lower limit (smaller = closer to horizontal, sees farther) |
| `main_camera.pitch_max_degrees` | 61.25 | 78 | Main camera pitch upper limit (larger = more top-down) |
| `main_camera.zoom_min_distance` | 15 | 15 | Main camera nearest zoom distance |
| `main_camera.zoom_max_distance_mouse` | 130 | 180 | Main camera farthest zoom distance with mouse (larger = wider view) |
| `main_camera.zoom_max_distance_joystick` | 100 | 180 | Main camera farthest zoom distance with gamepad |
| `main_camera.zoom_speed_mouse` | 7.5 | 13.65 | Main camera mouse zoom speed |
| `main_camera.zoom_speed_joystick` | 1.0 | 1.82 | Main camera gamepad zoom speed |
| `main_camera.switch_wait_seconds` | 0.75 | 0.2 | Wait after reaching the zoom limit before switching to the map (seconds) |
| `main_camera.pan_speed` | 200 | 200 | Main camera pan speed |
| `main_camera.rotate_step_degrees` | 8.75 | 8.75 | Rotation step per input |
| `main_camera.rotate_smoothness` | 0.75 | 0.75 | Rotation smoothing (0–1) |
| `map_camera.zoom_min_distance` | 500 | 800 | Map camera nearest zoom distance |
| `map_camera.zoom_max_distance` | 1500 | 2600 | Map camera farthest zoom distance |
| `map_camera.default_zoom` | 0.3 | 0.0001 | Default zoom when opening the map: `0` = nearest, `1` = farthest |
| `map_camera.zoom_speed_mouse` | 10 | 7.5 | Map camera mouse zoom speed |
| `map_camera.zoom_speed_joystick` | 5 | 3.75 | Map camera gamepad zoom speed |
| `map_camera.switch_wait_seconds` | 1.0 | 0.2 | Wait after reaching the zoom limit before switching back (seconds) |
| `map_camera.fade_seconds` | 0.5 | 0.2 | Map open/close fade duration (seconds) |
| `map_camera.pan_speed_min` / `pan_speed_max` | 200 / 1000 | 200 / 1000 | Map camera pan speed range |
| `game_dir` | empty | empty | Leave empty to auto-detect; set the game root folder (containing `Flotsam.exe`) if detection fails |

> `switch_wait_seconds` maps to the game's `Easing` field, which also affects zoom interpolation smoothing: smaller values switch faster and make zooming feel more direct.

---

## Other options

### Option B: Manual editing (for advanced users)

The camera settings are serialized in `Flotsam_Data\level2` (a Unity SerializedFile) on these components:

| Component | Contents |
| --- | --- |
| `CameraController` (main camera) | pan speed, rotation step/smoothing, pitch limits |
| `CameraZoomController` (main camera, 34027) | zoom range, zoom speed, switch wait (Easing) |
| `CameraZoomController` (map camera, 34352) | map zoom range, default zoom, zoom speed, switch wait |
| `WorldMap` (28728) | map open/close fade duration |

Use tools such as UnityPy or AssetStudio to read and edit those fields, or follow the “original value → new value” byte-replacement logic in `tools\apply.ps1` and implement your own.

### Option C: Change a single value

Edit the corresponding field in `config.json` and run `Apply-Camera-Tweaks.bat` again (no need to restore first — the script always regenerates from the original backup).

---

## Notes

| Item | Detail |
| --- | --- |
| Game version | Verified on Flotsam `1.0.1f9` (Unity `6000.3.26f1`). On other versions the script reports “original data not found” and does not write anything |
| Backup | The first run creates `backup\level2.original`; restoring depends on it, so keep it |
| Epic “Verify files” / game updates | Restore `level2` to vanilla; run `Apply-Camera-Tweaks.bat` again. If it reports missing original data after an update, delete `backup\` and run again |
| Coexistence with the settings-reset fix | This tool only edits `level2` and does not touch game DLLs; it can be used together with [flotsam-epic-settings-fix](https://github.com/MineMahiro/flotsam-epic-settings-fix) |
| Permissions | Run as administrator if the game is in `Program Files` |
| Risk | Unofficial modification — use at your own risk; backing up saves is recommended |

---

## Verification methods

| Check | Method |
| --- | --- |
| View range | In game, zoom the main camera fully out — the visible area should be clearly larger than vanilla |
| Switch delay | Hold the fully zoomed-out state for about 0.2 s — the map should open; zoom the map fully in for about 0.2 s — it should switch back |
| Map default distance | Opening the map should start at the nearest zoom level (distance ≈ 800) |
| Zoom speed | Main camera zoom should feel clearly faster; map zoom slightly slower than vanilla |
| Restore | After running `Restore-Camera-Tweaks.bat`, values should match vanilla |

---

## How it works

- Camera settings are serialized component fields inside `Flotsam_Data\level2` (a Unity SerializedFile), not code constants, so they can be modified without touching game DLLs.
- Map/main-view switching: after the zoom reaches its limit, `CameraZoomController` waits for `_zoomTimer` (initialized from the scene's `Easing` field) → dispatches `CameraMaximumZoom` / `CameraMinimumZoom` → `WorldMapManager` calls `WorldMap.Open()` / `Close()` → fade transition.
- `tools\apply.ps1` locates each field uniquely by its original value sequence (e.g. `0.75, 8.75, 200, 27.5, 61.25`) and replaces only those float bytes, keeping the file size and serialization layout unchanged. The first run backs up the original file to `backup\`; restoring simply copies it back.

## Compatibility

| Item | Value |
| --- | --- |
| Tested version | Flotsam `1.0.1f9` (Epic / Steam, Unity `6000.3.26f1`, Mono) |
| Original `level2` SHA256 | `8A79413A6E6754526256FC283A190BC56C8184F39968AB56D21BAB5275D486D1` |
| Output hash | The script prints the current `level2` SHA256 after each run |
| Locating method | Unique match on the original value sequences; no version check |

## FAQ

Q1: **Do I need to restart my save?**  
A1: No. Fully quit and relaunch the game; only the scene file is modified, not save data.

Q2: **What if it stops working after a game update?**  
A2: Delete the `backup\` folder and run `Apply-Camera-Tweaks.bat` again, or restore vanilla with Epic's “Verify files” first.

Q3: **Does it affect achievements or multiplayer?**  
A3: Only local camera parameters are changed and nothing is written to saves; not verified on other platforms or in multiplayer.

Q4: **The script says it cannot find the game folder (e.g. `Drive ... does not exist`)?**  
A4: The script auto-detects Epic manifests, Steam libraries and common install paths on all drives; if none is found it prompts you to type the game root folder (containing `Flotsam.exe`) and remembers it in `config.json` (`game_dir`). You can also set it manually in advance, e.g. `"game_dir": "D:\\Games\\Flotsam"`.

## Disclaimer

- This repository contains no game files or closed-source artifacts — only scripts, configuration and documentation.
- It only addresses camera view, zoom speed and map-switch behavior.
- It is not affiliated with the game developer or publisher.
- If an official update fixes or changes this behavior, prefer the official version.

## Repository layout

```
flotsam-camera-tweaks/
├─ Apply-Camera-Tweaks.bat      # apply tweaks
├─ Restore-Camera-Tweaks.bat    # restore vanilla
├─ config.json                  # tunable values (recommended defaults)
├─ presets/vanilla.json         # vanilla values for reference
├─ tools/apply.ps1              # patcher
├─ tools/restore.ps1            # restore script
└─ README.md / README.en.md
```

## License

MIT
