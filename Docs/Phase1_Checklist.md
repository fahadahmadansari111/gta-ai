# Phase 1 Checklist — URP Mobile + Perf Budgets + Device Tests

> Source of truth for Phase-1 "done". AI agents: keep pure logic Unity-free
> (`Runtime/Core|Economy|Missions`) and verify with `dotnet test` (see `Tests/`
> + `Tools/CI/TestRunner.cs`) before touching engine/scene work.

## 1. URP Mobile Settings (Unity 6 LTS 6000.0+, URP 17.0.3)

Apply in Editor (see also `ProjectSettings/URP_Mobile_Notes.md`):

- [ ] Create URP asset `Assets/_Game/Art/URP_Mobile.asset` (Universal Renderer):
  - [ ] **HDR: Off** (no HDR on mobile)
  - [ ] **MSAA: 1x (Disabled)** — max 2x on low-end only
  - [ ] Render Scale **0.8–1.0** (drive via Adaptive Performance / Dynamic Resolution)
  - [ ] Shadows: **1 cascade**, 1024 max, soft shadows **off** on Low tier
  - [ ] Post-processing: **Off** or minimal (no Bloom / SSAO on mobile)
  - [ ] Fog: **Linear** enabled, tuned per scene
  - [ ] **SRP Batcher: Enabled**
- [ ] Quality levels `Low / Medium / High` (Medium = default mobile):
  - [ ] Pixel Light Count: **1**, Texture Quality Full/Half, Anisotropic Per-Texture
  - [ ] VSync Count: **0** (frame rate driven by script)
- [ ] Player Settings:
  - [ ] Color Space: **Linear**; `Application.targetFrameRate = 60`
  - [ ] Adaptive Performance **Enabled** (`com.unity.adaptiveperformance` + provider)
  - [ ] Android Graphics APIs: Vulkan / GLES3 (Auto); iOS: Metal
  - [ ] Scripting Backend **IL2CPP**, API Compatibility **.NET Standard 2.1**
  - [ ] Active Input Handling: **Input System Package (New)**
- [ ] Adaptive Performance scalers bound to URP Render Scale (CPU + GPU + resolution)
- [ ] Assign in `Edit > Project Settings > Graphics` → `URP_Mobile.asset`; verify
      Quality, URP Global Settings, baked NavMesh before Play.

## 2. Perf Budgets (must hold on mid-tier device, Development Build + Profiler)

| Metric | Budget | Where to check |
|---|---|---|
| Draw calls (Frame Debugger / Profiler Rendering) | **< 100** | URP + SRP Batcher on; share materials; pool traffic/peds |
| Triangles per frame | **< 300k** | Profiler Rendering; LOD traffic/props |
| Textures (world / character) | **≤ 1024px** max | Import settings; compress (ASTC/ETC2); mipmaps on |
| Pooled traffic | **≤ 25 active** vehicles | `World/` spawner pool; no per-frame Instantiate |
| Pooled pedestrians | **≤ 30 active** (recommended) | `AI/` FSM pool; NavMesh agents reused |
| APK (Android, IL2CPP, Medium) | **< 250 MB** | `Build Report`; strip engine code; compress textures/meshes |
| Frame rate | sustained **60fps** mid-tier | Profiler + Adaptive Performance scaler |
| GC | no per-frame allocs in hot loop | Deep Profile; pool vectors/events |

Failing a budget blocks Phase-1 sign-off — record device + build ID + screenshot.

## 3. Manual Device Test Steps

### A. Unity Device Simulator (no device needed)
1. `Window > Device Simulator` → pick mid-tier Android preset.
2. Open `Assets/_Game/Scenes/Main_City.unity` (create if missing), Press Play.
3. Verify: touch joystick moves player, camera follows, missions advance,
   wanted level shows, no console errors, Stats < budgets (§2).

### B. Android on-device (`adb`)
1. `File > Build Settings > Android > Switch Platform`; set IL2CPP + bundle id.
2. Build Development APK: `Build And Run` or `Build` → `Builds/gta-ai.apk`.
3. Install + launch:
   ```bash
   adb install -r Builds/gta-ai.apk
   adb logcat -s Unity | tee device.log
   ```
4. Play 5 min: drive/walk, spawn traffic, trigger mission + wanted, pause/resume.
5. Pass criteria: installs clean, no crash/ANR, 60fps sustained (Profiler over USB),
   `device.log` has no exceptions.

### C. Profiler pass (USB)
1. `Window > Analysis > Profiler` → connect Android player (Development Build +
   Autoconnect Profiler).
2. Record 60 s gameplay; capture: CPU (main/render), Rendering (draw calls/tris),
   Memory (total + GC alloc), Battery/Thermal.
3. Save `.data` + screenshot into `Docs/Phase1_Profiler/` (create on demand).

## 4. AI-Verifiable Tests (no Unity needed)

```bash
./Tools/CI/run_tests.sh
# with dotnet 8: dotnet test Tests/Game.Tests.csproj
# offline fallback: dotnet run --project Tools/CI/TestRunner.csproj
# in Unity: -runTests -testPlatform EditMode (Game.Tests asmdef)
```

Coverage (EditMode + dotnet mirror):
- [ ] `MissionRuntimeTests` — sequential completion; timeout fail
- [ ] `WantedSystemTests` — escalate on heat; decay to zero
- [ ] `EconomyServiceTests` — spend guards; balance never negative
- [ ] `ChunkStreamerTests` — active set always 3×3; eviction
- [ ] `SaveServiceTests` — save/load roundtrip; missing-key default
- [ ] `GameStateTests` — valid chain; invalid rejected

CI: `.github/workflows/tests.yml` runs `dotnet test` on Ubuntu, falling back to
the self-contained runner when NuGet restore is unavailable.

## 5. Sign-off

- [ ] All §1 boxes checked in-Editor
- [ ] All §2 budgets met on device (attach Profiler evidence)
- [ ] §3 A+B+C executed, logs saved
- [ ] `dotnet test` (or fallback runner) green in CI
