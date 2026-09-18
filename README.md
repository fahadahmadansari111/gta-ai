# GTA Vice Prototype (Godot 4.3 + GDScript)

Vice City-style open-world prototype, ported from the Unity source at
`/Users/mahmad/gta-ai` (read-only reference — never edit that tree from here).

**Stack:** Godot 4.3 + GDScript + Compatibility (`gl_compatibility`) renderer —
GLES3 on Android, mid-range 60fps target.

## Folder map

```
project.godot          Project settings (main scene, autoloads, input, layers)
export_presets.cfg     Android (arm64 APK) + Linux desktop presets
icon.svg               Neon palm/city placeholder icon
scenes/                boot.tscn (first load) / main_city.tscn / district_0_0.tscn
scripts/
  core/                boot, game autoload, save, state, signal bus
  missions/ ai/ economy/ world/   gameplay systems
  player/ vehicle/ ui/ mobile/    player, driving, HUD, touch input
data/missions/         M01–M03 JSONs (verbatim copies of Unity ScriptableObjects)
tests/                 GUT tests (see tests/README.md)
Docs/                  Phase1_Checklist.md + Missions.md (reference copies)
.github/workflows/    CI placeholder (owning agent fills real workflow)
Tools/ci/              CI helper scripts (owning agent)
builds/                Export output (gitignored)
```

## How to open

1. Install **Godot 4.3 stable** (matching `config/features`).
2. `Project -> Import...` and select this folder's `project.godot`
   (or `godot --path /Users/mahmad/gta-ai-godot`).
3. Press **F5** — `boot.tscn` loads first, then the main city scene.

## Local Android export

One-time setup:

1. Open the editor, `Editor -> Manage Export Templates...`, install the
   **4.3.stable** templates.
2. Install a JDK + the Android SDK (via Android Studio or `cmdline-tools`);
   set the SDK path under `Editor -> Editor Settings -> Export -> Android`.
3. The debug key is automatic: the editor uses `~/.android/debug.keystore`
   (user `android`). For release builds, supply real credentials via
   `.export_credentials` (gitignored) — never commit keys.

Export:

1. `Project -> Export...`, select the **Android** preset
   (`com.gtaai.vicecity`, arm64-v8a, landscape, versionCode 1).
2. `Export Project` -> `../builds/game.apk` (i.e. `<parent>/builds/`).
3. Install: `adb install -r ../builds/game.apk`, then
   `adb logcat -s godot | tee device.log`.

## CI flow

`.github/workflows/` (placeholder for now) will run on Ubuntu:

1. Headless GDScript tests (GUT, see `tests/README.md`).
2. Linux desktop export smoke using the **Linux Desktop** preset
   (`export_path="../builds/game.x86_64"`) with 4.3.stable templates —
   fails the build if the export errors.

## Test flow

- **GUT** (recommended): add `test_*.gd` under `tests/`, run headless:
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`.
- **Headless script check** (no GUT): `godot --headless --check-only --script <file>`.
- Parity with Unity `Game.Tests`: mission sequencing/timeouts, wanted
  escalate/decay, economy guards, chunk 3×3 set, save roundtrip, state chain.

## Perf budgets (mid-tier device, must hold for sign-off)

| Metric | Budget |
|---|---|
| Frame rate | sustained **60fps** (`Engine.max_fps = 60` in boot) |
| Draw calls | **< 100** (share materials, pool traffic/peds) |
| Triangles/frame | **< 300k** (LOD traffic/props) |
| Textures (world/character) | **≤ 1024px**, ETC2/ASTC + mipmaps |
| Active traffic / peds | **≤ 25** vehicles / **≤ 30** peds (pooled, no per-frame Instantiate) |
| APK (arm64, Medium) | **< 250 MB** |
| GC | no per-frame allocs in hot loop |

Renderer notes: Compatibility/GLES3, MSAA off (`anti_aliasing/msaa_3d=0`),
physics 60 ticks, stretch `canvas_items`. If Jolt is needed later, install the
Jolt extension and set `3d/physics_engine="Jolt Physics 3D"` (currently
`GodotPhysics3D`, as Jolt is not bundled with 4.3).
