# Missions — Vice City Sample Chain (M01–M03)

Sample Vice City-style mission content for `/Users/mahmad/gta-ai`. No Unity required:
definitions are plain JSON under `Assets/_Game/ScriptableObjects/Missions/`, validated by
`Assets/_Game/Scripts/Tests/EditMode/SampleMissionsTests.cs` against the pure-C# runtime
(`Game.Runtime.Missions`: `MissionDefinition`, `MissionObjective`, `MissionRuntime`, `MissionGraph`).

## Mission table

| ID | File | Title | Objectives | Reward (money) | Requires | Time limit |
|----|------|-------|------------|----------------|----------|------------|
| M01_Neon_Delivery | `Assets/_Game/ScriptableObjects/Missions/M01_Neon_Delivery.json` | Neon Delivery | GoTo `neon_strip_pickup` → Collect `neon_package` x1 → Deliver `malibu_club_dropoff` | 500 | — (starter) | 300s |
| M02_Beach_Chase | `Assets/_Game/ScriptableObjects/Missions/M02_Beach_Chase.json` | Beach Chase | RaceCheckpoint 0 → RaceCheckpoint 1 → Kill `beach_rival` x2 | 750 | M01_Neon_Delivery | 240s |
| M03_Docks_Collection | `Assets/_Game/ScriptableObjects/Missions/M03_Docks_Collection.json` | Docks Collection | GoTo `viceport_docks_gate` → Collect `cargo_crate` x3 → Deliver `boatyard_warehouse` | 1200 | M02_Beach_Chase | 420s |

Unlock chain: **M01 → M02 → M03** via `startCondition.requiredMissionId`.
`MissionGraph.CanStart(id, completedIds)` returns true only when the required predecessor is complete.

## JSON schema (matches `MissionDefinition` C# property names, camelCase)

```json
{
  "id": "M01_Neon_Delivery",
  "title": "Neon Delivery",
  "description": "...",
  "objectives": [
    { "type": "GoTo", "targetId": "neon_strip_pickup", "radius": 3.0 },
    { "type": "Collect", "itemId": "neon_package", "count": 1 },
    { "type": "Deliver", "destinationId": "malibu_club_dropoff", "vehicleId": null },
    { "type": "Kill", "targetId": "beach_rival", "count": 2 },
    { "type": "RaceCheckpoint", "checkpointIndex": 0 }
  ],
  "rewards": { "money": 500 },
  "startCondition": { "requiredMissionId": null },
  "timeLimitSec": 300
}
```

Objective `type` values map 1:1 to `MissionObjective.ObjectiveType` discriminators in
`Assets/_Game/Scripts/Runtime/Missions/MissionObjective.cs`:
`GoTo` (`targetId`, `radius`), `Kill` (`targetId`, `count`), `Collect` (`itemId`, `count`),
`Deliver` (`destinationId`, `vehicleId?`), `RaceCheckpoint` (`checkpointIndex`).
Parsing is case-insensitive (same convention as `SaveService`'s `PropertyNameCaseInsensitive = true`).

## Objective flow diagrams (text)

M01 — Neon Delivery (Ocean Drive → Malibu Club):
```
[START] --ArrivedEvent(neon_strip_pickup)--> [GoTo done]
        --CollectEvent(neon_package x1)-----> [Collect done]
        --DeliverEvent(malibu_club_dropoff)-> [PASSED +$500, unlocks M02]
   (any out-of-order / foreign event is ignored by MissionRuntime)
   (elapsed >= 300s without passing => Failed)
```

M02 — Beach Chase (Vice Beach boardwalk → pier):
```
[START] --CheckpointEvent(0)--> [CP0 done]
        --CheckpointEvent(1)--> [CP1 done]   (CP1 before CP0 is ignored: strict order)
        --KillEvent(beach_rival) x2 --> [PASSED +$750, unlocks M03]
   (elapsed >= 240s without passing => Failed)
```

M03 — Docks Collection (Viceport Docks → boatyard warehouse):
```
[START] --ArrivedEvent(viceport_docks_gate)--> [GoTo done]
        --CollectEvent(cargo_crate) x3 -------> [Collect done]
        --DeliverEvent(boatyard_warehouse)----> [PASSED +$1200]
   (elapsed >= 420s without passing => Failed)
```

Chain gating (`MissionGraph`):
```
completed={}                  => CanStart(M01)=T, CanStart(M02)=F, CanStart(M03)=F
completed={M01}               => CanStart(M01)=F (already done), CanStart(M02)=T, CanStart(M03)=F
completed={M01,M02}           => CanStart(M03)=T
completed={M01,M02,M03}       => all F (all done)
```

## How to add M04

1. **Copy JSON.** Duplicate `M03_Docks_Collection.json` → `M04_<Name>.json` in
   `Assets/_Game/ScriptableObjects/Missions/`. Set a unique `id` (e.g. `M04_Havana_Nights`),
   new `title`/`description`, 2–4 `objectives` using the types above, `rewards.money`,
   `startCondition.requiredMissionId` = `"M03_Docks_Collection"` (or null for a side mission),
   and a positive `timeLimitSec`.
2. **Register in MissionGraph.** There is no asset registry — just construct the graph with the
   new definition wherever missions are wired up:
   ```csharp
   var graph = new MissionGraph(new[] { m01, m02, m03, m04 });
   // or: graph.Register(m04);
   bool unlocked = graph.CanStart("M04_Havana_Nights", new[] { "M01_Neon_Delivery", "M02_Beach_Chase", "M03_Docks_Collection" });
   ```
   Parse the JSON with the same `ParseMission` helper used in `SampleMissionsTests.cs`
   (`System.Text.Json` + `type` discriminator → `GoToObjective`/`KillObjective`/`CollectObjective`/
   `DeliverObjective`/`RaceCheckpointObjective`).
3. **Add test.** In `SampleMissionsTests.cs`, embed the M04 JSON string, extend the gating test
   (`CanStart(M04)` false before M03, true after), and add a `MissionRuntime` playthrough test
   feeding the matching events (`ArrivedEvent`/`KillEvent`/`CollectEvent`/`DeliverEvent`/
   `CheckpointEvent`) in order until `Status == Passed`. Run:
   ```
   export PATH="$HOME/.dotnet:$PATH" && dotnet test Tests/Game.Tests.csproj --verbosity minimal
   ```

## Verification

```
export PATH="$HOME/.dotnet:$PATH" && dotnet test Tests/Game.Tests.csproj --verbosity minimal
```
All tests (existing EditMode suite + 6 new `SampleMissionsTests`) must pass.
