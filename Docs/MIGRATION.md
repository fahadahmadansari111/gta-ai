# Migration — Unity (`gta-ai`) → Godot (`gta-ai-godot`)

## Engine mapping

| Unity | Godot | Notes |
|---|---|---|
| `MonoBehaviour` | `Node` / `Node3D` / `CharacterBody3D` | Scene-tree nodes; `_ready()` ≈ `Start()`, `_process(dt)`/`_physics_process(dt)` ≈ `Update()` |
| `ScriptableObject` (e.g. `MissionDefinitionSO`) | `Resource` (e.g. `VehicleTuning`) | Plain-data scripts; mission JSON parsed at runtime instead of Inspector assets |
| Input System package | `InputMap` (`Input.is_action_pressed`) | Actions defined in `project.godot`, no package install |
| URP (`URP_Mobile.asset`) | Compatibility renderer (`rendering/renderer/rendering_method="gl_compatibility"`) | Mobile-first GLES3 path, no SRP asset tuning |
| Addressables / additive scenes | `ResourceLoader.load()` / `change_scene_to_file()` / `add_child(load(...).instantiate())` | Built-in async loading, no package |
| `PlayerPrefs` (`PlayerPrefsStore`) | `ConfigFile` / `FileAccess` (`user://`) | `SaveService` wraps an in-memory store; swap backend per platform |
| `UnityEngine.TestTools` / NUnit EditMode | `tests/test_runner.gd` (`extends SceneTree`) | Zero-addon headless asserts: `godot --headless --script tests/test_runner.gd` |
| `game-ci/unity-builder` + `UNITY_LICENSE` | `godot --headless --export-release` | **No license secrets** — Godot + templates are free; debug keystore auto-generated |

## API changes (PascalCase → snake_case)

Pure-logic ports keep the Unity semantics; only naming/shape changes:

| Area | Unity (C#) | Godot (GDScript) |
|---|---|---|
| Result | `Result<T>.IsOk / .Value / .Error` | `Result.is_ok / .value / .error`, `Result.ok(v)` / `Result.fail(msg)` |
| Game state | `GameStateMachine.TransitionTo(s)`, states `Boot…GameOver` | `GameState.set_phase(p)` (alias `transition_to`), `can_transition_to(p)`; phases `BOOT, FREE_ROAM, MISSION, PAUSED, BUSTED, WASTED` (`GameOver` → `WASTED`/`BUSTED`) |
| Save | `SaveService.Save/Load`, `{version, data}` envelope, `CurrentVersion = 1` | `save_value/load_value/has/delete/clear`, `save_game/load_game` (return `Result`), `CURRENT_VERSION = 1`, same `{version, data}` JSON envelope |
| Missions | `MissionRuntime.Start/Update/AdvanceOnEvent/Fail`, `CurrentObjectiveIndex`, `MissionStatus` | `start/update/advance_on_event/fail`, `current_index`, `elapsed_seconds`, `Status.{INACTIVE, ACTIVE, PASSED, FAILED}`; events are Dictionaries via `MissionEvents.arrived/kill/collect/deliver/checkpoint` |
| Objectives | `GoToObjective`, `CollectObjective`, … classes | `MissionObjective` with `Kind.{GO_TO, KILL, COLLECT, DELIVER, SURVIVE, RACE_CHECKPOINT}`, `from_dict`/`kind_from_string` |
| Graph | `MissionGraph.Register/CanStart(id, completed)` | `register/can_start(id, external_completed)`, plus `mark_completed/available` |
| Economy | `EconomyService.AddMoney/SpendMoney/Balance` | `add_money/spend_money/balance` (never negative; insufficient spend returns `false`) |
| Wanted | `WantedSystem.AddCrime/Decay/Clear`, `Stars/Heat` | `add_crime/add_heat`, `decay(dt[, hiding])`, `clear`, `stars/heat`, levels 0–5 |
| Streaming | `ChunkStreamer.GetActiveSet/Diff`, `SpawnPool.TrySpawn/Despawn` | `get_active_set/diff`, `try_spawn/despawn`, `active_count/capacity/is_full` |
| Locomotion | `PlayerMoveMath.MoveStep/SprintMultiplier/ClampSpeed` | `PlayerMoveMath.move_step/sprint_multiplier/clamp_speed` (`Vector2` XZ, returns `{pos, vel}`) |
| Vehicle | `VehicleMath.ComputeSpeed/ComputeSteerAngle/ApplyDrift`, `VehicleArcadeTuning.ValidatedCopy()` | `compute_speed/compute_steer_angle/apply_drift`, `VehicleTuning.validated_copy()/validate()` |

Signals: C# `OnStateChanged` event → Godot `phase_changed` / `state_changed` signals
(`GameState`), `wasted` (`PlayerStats`).

## Tests

Unity EditMode (`Tests/Game.Tests.csproj`, 97 tests) → Godot (`tests/`, same
semantics, spec-model + real-probe pattern). See `tests/README.md` for the
file-by-file mapping and `Docs/Missions.md` for the M01–M03 chain.

## Open + export locally

```bash
# Open: Godot 4.3 → Import → select this folder (creates .godot/ cache).
# Run tests (no editor needed):
godot --headless --script tests/test_runner.gd

# Android export (needs export_presets.cfg "Android" preset + SDK):
# 1. Editor → Project → Install Android Build Template (once).
# 2. Editor → Project → Export… → Android → Export Release, or headless:
godot --headless --export-release "Android" builds/game.apk
```

CI (`.github/workflows/`): `tests.yml` runs the headless suite on every
push/PR; `android.yml` gates the APK/AAB export on green tests, caches the
~1GB export templates, auto-generates the debug keystore, and uploads
artifacts for 14 days. Device check mirrors Unity (`adb install`, `adb logcat`)
minus the license setup — see `Docs/Phase1_Wiring.md` in the Unity repo for the
M01 playthrough script.
