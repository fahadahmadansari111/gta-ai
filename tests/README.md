# Tests — Godot headless suite (no addons)

Self-contained GDScript tests. No GUT download required: `tests/test_runner.gd`
(`extends SceneTree`) discovers every `tests/test_*.gd` suite, calls its static
`func run() -> {"passed": int, "failed": int}`, prints per-suite PASS/FAIL plus
totals, and quits with exit code 0 (green) / 1 (red) / 2 (runner error).

## Run

From the repo root:

```bash
godot --headless --script tests/test_runner.gd
# or via wrapper (checks for godot, best-effort --import first):
bash Tools/ci/run_tests.sh
```

Each suite also works through the GUT panel if you install the GUT addon
(`tests/gut_config.json` sets `dirs: tests/`, `prefix: test_`, `suffix: .gd`).

## Suites (Unity EditMode source → Godot file)

| Unity (`gta-ai/.../Tests/EditMode`) | Godot | What it covers |
|---|---|---|
| `MissionRuntimeTests.cs` | `test_mission_runtime.gd` | sequential / out-of-order / timeout / partial-count-false / sticky terminal |
| `WantedSystemTests.cs` | `test_wanted.gd` | escalate / decay / clear / never-negative |
| `EconomyServiceTests.cs` | `test_economy.gd` | no-negative fuzz (500 ops, seed 42) / exact spend |
| `ChunkStreamerTests.cs` | `test_chunk_streamer.gd` | 3x3 interior / corner-4 / evict / diff |
| `SpawnPoolTests.cs` | `test_spawn_pool.gd` | cap / LIFO reuse / 25-actor budget |
| `PlayerMoveMathTests.cs` | `test_player_move.gd` | accel / friction / sprint clamp |
| `VehicleMathTests.cs` | `test_vehicle_math.gd` | top-clamp / brake>coast / steer-fade / drift-order |
| `SaveServiceTests.cs` | `test_save.gd` | roundtrip / version envelope |
| `GameStateTests.cs` | `test_game_state.gd` | BOOT→WASTED invalid / valid chain / signals |
| `SampleMissionsTests.cs` | `test_sample_missions.gd` | M01 JSON playthrough / M01→M02 gating |

## Pattern (mirrors the Unity defensive style)

- An **inline spec model** in each file always runs, so suites verify the
  contract even before the logic scripts land.
- Real logic is loaded with `load("res://scripts/...")` guarded by
  `ResourceLoader.exists()`; integration checks run when the script plus its
  expected snake_case API (`has_method`/`get` probes) resolve, otherwise the
  file prints `SKIP` for that block instead of failing.
- Assumed pure-logic `class_name`s: `Result`, `SignalBus`, `GameState`,
  `SaveService`, `MissionDefinition`, `MissionObjective`, `MissionRuntime`,
  `MissionGraph`, `MissionEvents`, `EconomyService`, `WantedSystem`,
  `ChunkStreamer`, `SpawnPool`, `PlayerStats`, `VehicleTuning`,
  `PlayerMoveMath`, `VehicleMath`.
- Missing-logic contracts for the owning agents: `EconomyService`
  (`add_money`/`spend_money`/`balance`), `WantedSystem`
  (`add_crime`/`add_heat`, `decay(dt[, hiding])`, `clear`, `heat`/`stars`),
  `ChunkStreamer` (`get_active_set(x, z, radius)`, `diff(old, new)`),
  `SpawnPool` (`SpawnPool.new(cap)`, `try_spawn`/`despawn`, `capacity`).
