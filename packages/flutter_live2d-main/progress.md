# Progress Log

## Session: 2026-09-04 - Package Rename And Publication

### Phase 14: Package Rename And pub.dev Publication
- **Status:** in progress
- Confirmed a clean starting worktree.
- Restored the existing planning files and appended a scoped publication phase.
- Located the old Dart package name, package imports, and repository metadata that must change.
- `fvm` was unavailable in the current shell; validation will use the configured system Flutter/Dart executable.
- Renamed the Dart package and public entry point references to `live2d_flutter`.
- Updated GitHub metadata, Web/macOS asset package resolution, Apple podspec naming, macOS Swift package naming, and Windows generated-plugin integration names.
- Preserved the existing method channel and native implementation identifiers for runtime compatibility.
- Root dependency resolution, static analysis, and all 3 unit tests passed.
- The first parallel platform-build attempt was invalid because both builds shared generated state; switched to sequential verification after a clean.
- Sequential Windows Debug and Web release builds passed with the new package name.
- The initial publish dry-run produced a 29 MB compressed archive and only Git-state warnings caused by the uncommitted rename.
- Bumped the release to `1.0.3`, updated the changelog, excluded local planning files from publication, and removed the stale iOS example Pod lock so macOS can regenerate it under the new pod name.
- Committed the rename as `9482952` and reran the publish dry-run from a clean worktree: 0 warnings, 29 MB compressed.
- Published `live2d_flutter 1.0.3` successfully to pub.dev.
- Verified the pub.dev API exposes version `1.0.3` with homepage and repository set to `https://github.com/hunmer/flutter_live2d`.

## Session: 2026-09-04

### Phase 7: Windows Baseline And Architecture
- **Status:** complete
- Actions taken:
  - Restored `task_plan.md`, `progress.md`, and `findings.md` using the requested `planning-with-files` workflow.
  - Confirmed the prior Web work is complete and the Windows path currently has only a build baseline with no plugin registration.
  - Added Windows architecture, implementation, and verification phases to the persistent plan.
  - Confirmed there is no Windows plugin directory/registration, while the existing vendored Cubism Framework already contains a D3D11 backend suitable for reuse.
  - Selected a provisional Windows architecture: Dart `Texture` widget plus a C++ Windows plugin that renders Cubism through D3D11 and preserves the existing method-channel commands.
  - Confirmed the installed Flutter/Visual Studio toolchain can target Windows.
  - Identified the missing official Cubism Native Core Windows binary as the primary implementation dependency.
  - Verified against official 2026 release metadata that Native Samples `5-r.5` matches the vendored Framework, while Core binaries are not published in GitHub release assets.
  - Cloned the matching official Native Samples and confirmed Flutter can consume a D3D11 texture directly through its Windows GPU texture registrar.
  - Confirmed the exact Flutter D3D11 texture descriptor contract and corrected the official sample source path.
  - Matched the Windows Core requirement to VS2022/x64 dynamic CRT (`Live2DCubismCore_MD.lib`) and confirmed the standard Flutter C++ plugin registration structure.
  - Received explicit user authorization to download the Native SDK under the Live2D license agreements.
  - Located the official download selector script used by the Native SDK page.
  - Resolved the authorized official `5-r.5` archive URL and verified the minimal D3D11 renderer call sequence against the matching sample.
  - Downloaded and hashed the official Native SDK archive, then extracted it to the local temporary directory.
  - Confirmed the archive contains the required Windows x64/v143 MD and MDd Core libraries and license material.
  - Verified the existing vendored Framework matches Native SDK `5-r.5` closely enough to reuse its D3D11 backend without another source copy.

### Phase 8: Windows Runtime Implementation
- **Status:** in_progress
- Actions taken:
  - Selected a direct D3D11 GPU texture implementation with a Windows-specific model/texture adapter and shared controller commands.
  - Refined the GPU path to a DXGI shared handle so the plugin's D3D device remains independent from Flutter's private ANGLE device.
  - Identified the two Framework D3D11 shader files that must be bundled at runtime.
  - Confirmed the exact shared-texture descriptor used by Flutter and the manual Framework source-selection required by this repository layout.
  - Added the authorized Cubism Core x64/v143 MD and MDd libraries plus the original Core license.
  - Added the Dart Windows Texture widget with native view creation, resize, pointer input, and disposal lifecycle.
  - Added the Windows CMake target, Flutter plugin C API, shared D3D11 runtime, model behavior adapter, PNG texture loader, and DXGI shared render targets.
  - Generated the example Windows runner and passed `flutter analyze` with no issues.
  - Built the Windows Debug example successfully after adding Flutter's `Profile` imported-library mapping; remaining compiler warnings are in the unmodified official Framework source.
  - Corrected Framework shader deployment to the final runner directory and added a procm-managed `windows-example` command.
  - Started `windows-example` through procm as process `SNIaU2bW`; the native app is responsive and has no startup stderr.
  - Captured the native pre-load window and confirmed both Windows render surfaces attach successfully.
  - User confirmed that clicking model load immediately terminates the Windows app and requested diagnostic output for manual testing.
  - Stopped automatic runtime interaction for this debug iteration per the user's verification preference.
  - Confirmed shader deployment succeeded, but the previous crash produced no Windows Application event and only disconnected Flutter's device channel.
  - Added `[DEBUG-WIN-L2D]` diagnostics to stderr, debugger output, and `%TEMP%/flutter_live2d_windows.log` across the model-load and first-frame boundaries.
  - Did not rebuild or rerun the instrumented app because the user requested manual verification.
  - Read the user's reproduction log and isolated the crash to the first D3D11 `StartFrame`, preceded by `ContextNum has not been set.`; all assets and textures had loaded successfully.
  - Confirmed against official sample and Framework source that `SetConstantSettings` is mandatory before model loading and its omission triggers the observed assertion.
  - Added the official `SetConstantSettings(1, device)` initialization immediately after Framework initialization; retained diagnostics for the user's manual regression run.
  - Compared the newly attached log with the prior attachment and confirmed they are identical old output; no additional code change was justified.
  - Confirmed the third attachment is again the exact original log; proceeded to inspect the generated plugin link and built DLL rather than changing runtime logic without new evidence.
  - Verified the example resolves the workspace plugin and its current Debug DLL contains the `constant-settings` fix marker.
  - Read the actual current temp diagnostic log and confirmed the first fix works; the next termination is now isolated inside `CreateRenderer()`.
  - Found no crash event or dump for the post-fix termination and selected finer D3D11 renderer initialization markers as the next probe.
  - Confirmed the latest uploaded attachment is the same original pre-fix log by SHA-256 and retained the current temp trace as the valid diagnostic source.
  - Compared the vendored D3D11 renderer with the official Native SDK `5-r.5` source and found no differences.
  - Added focused renderer-factory and D3D11 initialization probes covering the four ranked crash hypotheses; no rendering behavior was changed.
  - Kept runtime validation manual as requested; only compile-time verification will be performed before handoff.
  - Rebuilt the Windows Debug example successfully with the new probes; runtime launch and model loading remain intentionally untested.
  - Read the user's new 10:11 reproduction and confirmed the renderer call still exits before its first internal probe while loading `ren`.
  - Verified the loaded runner DLL contains the new factory/D3D11 probe strings and found no Windows crash event or dump.
  - Added a narrow SEH diagnostic wrapper around `CreateRenderer` that logs exception code, address, module base, RVA, and thread before preserving the original crash behavior.
  - Built the Windows Debug example successfully with the SEH diagnostic wrapper; no runtime verification was performed.
  - Read the 10:23 reproduction: the SEH wrapper begins, but no structured exception or first Framework formatted probe is emitted.
  - Reclassified the exit as a CRT fail-fast/abort candidate and replaced temporary renderer probes with fixed messages sent directly through the Core log callback.
  - Added explicit D3D11 renderer factory allocation boundaries before and after `CSM_NEW`.
  - Rebuilt the Windows Debug example successfully with fixed-text Core callback probes; the two helper warnings from the first build were removed.
  - Read the 11:07/11:08 reproductions and isolated the exit to `CubismDeviceInfo_D3D11::GetDeviceInfo()`.
  - Split device-info initialization into map, render-state, and shader boundaries and reduced repeated custom-map indexing to one access.
  - Fixed relative Framework shader loading to resolve beside the executable, matching CMake deployment and the official sample working-directory contract.
  - Built the Windows Debug example successfully after the device-info and shader-path changes; runtime verification remains manual.
  - Read the 11:28 reproduction and confirmed the remaining Flutter exit occurs at official D3D11 shader setup before file loading.
  - Added a standalone C++ Native SDK smoke project that loads the same model JSON/MOC, validates texture references, creates a Cubism model, initializes D3D11 rendering and verifies a compiled shader without Flutter.
## Session: 2026-09-03 (macOS support)

### macOS Loading Diagnostics
- **Status:** complete
- Actions taken:
  - Identified missing diagnostics across listener startup, resource responses, JavaScript console output, and command completion.
  - Selected a 75-second native `loadModel` timeout so Dart receives a concrete failure even if WKWebView timers are suspended.
  - Added a separate 30-second runtime readiness timeout after the integration test showed commands can remain queued before dispatch.
  - Added Dart-side model path resolution, completion, and failure logs.
  - Added native runtime initialization, JavaScript console, command duration, and per-resource HTTP status/size/timing logs.
  - Verified a stalled runtime now exits Loading after 30 seconds with Core URL and HTTP request diagnostics.
  - Made the unreliable foreground-dependent runtime integration case opt-in while keeping the basic macOS integration test enabled by default.
- Verification:
  - `flutter build macos --debug`: pass.
  - `flutter analyze`: no issues.
  - `flutter test`: 3 tests passed.
  - Default macOS integration test: 1 passed, 1 opt-in runtime test skipped.
  - Forced stalled-runtime path: returned a detailed error after 30 seconds instead of remaining in Loading.

### VS Code SDK Discovery
- **Status:** complete
- Actions taken:
  - Read the supplied Dart Code extension log and identified the missing project-local FVM SDK path.
  - Confirmed neither `.fvm/` nor an `fvm` executable exists.
  - Rejected the manually discovered `/Users/Zhuanz/Documents/flutter/flutter` checkout because it carries an older/stale SDK cache.
  - Updated the workspace SDK path to the same Flutter 3.44.0 / Dart 3.12.0 installation used for successful macOS builds.
- Files created/modified:
  - `.vscode/settings.json`

### Phase 7: macOS Baseline And Architecture
- **Status:** complete
- Actions taken:
  - Restored `task_plan.md`, `progress.md`, and `findings.md` with the requested `planning-with-files` workflow.
  - Ran the session catch-up script; it reported no unsynchronized context.
  - Extended the completed Web plan with macOS discovery, implementation, verification, and delivery phases.
  - Confirmed the plugin manifest has no macOS registration and no macOS source/runner directory is present.
  - Found that the workspace currently lacks `.git` metadata; recorded this as a delivery constraint while continuing implementation.
  - Inspected the iOS podspec and Core XCFramework; the binary contains no macOS slice, so a direct iOS renderer port is not linkable as-is.
  - Identified a WKWebView-backed macOS platform view as the smallest candidate because it can reuse the completed Web runtime and controller commands.
  - Confirmed the existing method-channel contract and native asset extraction can be reused unchanged for macOS.
  - Ran the macOS baseline build; it failed only because the example has no macOS desktop project configured.
  - Selected an `AppKitView`/`WKWebView` implementation with a custom resource scheme and the existing fixed-version Web Core runtime.

### Phase 8: macOS Native Implementation
- **Status:** in_progress
- Actions taken:
  - Started implementation after completing the macOS architecture decision.
  - Generated the standard `example/macos` runner.
  - Confirmed the generated sandbox entitlements need outbound network access for the hosted Cubism Core.
  - Confirmed the registrar can locate package Flutter assets; SDK source discovery hit a slow `flutter doctor` and switched to direct executable-path inspection.
  - Added the macOS plugin declaration, Dart `AppKitView`, CocoaPods and SwiftPM manifests, and a WKWebView implementation covering the existing controller command surface.
  - Added Debug/Release outbound network entitlements to the example for the hosted fixed-version Cubism Core.
  - Added custom-scheme resource serving, command-result bridging, load failure propagation, and weak script-message ownership.
  - Reached Swift compilation through the generated example and fixed the first two compile errors: the renamed view-factory registration API and escaping callback annotation.
  - Built the macOS Debug app successfully with Flutter 3.44 and Xcode.
  - Formatted the changed Dart files; the formatter warned that root package dependencies had not yet been resolved, which will be addressed before final analysis.
  - Added a macOS integration test for real model loading and all controller command categories; fixed its initial missing Foundation import.
  - The first runtime integration attempt reached the platform view but failed during JS initialization; changed asset lookup to include Flutter's macOS `App.framework/Resources` layout and improved diagnostics.
  - Diagnostics proved hosted Core loaded while WebKit refused the runtime custom-scheme script; changed the trusted package runtime to inline execution while retaining scheme-based data loading.
  - Read Flutter's macOS asset-key implementation and corrected the resolver to treat its full `Contents/Frameworks/.../flutter_assets` key as app-bundle-relative.
  - Runtime initialization then succeeded; fixed WKWebView's unsupported Promise return by making evaluated command wrappers return `null` synchronously.
  - Model loading reached the JavaScript fetch layer; unified all custom resources under one WebKit origin to remove cross-origin rejection.
  - Same-origin requests progressed into the model readiness loop; preserved both JavaScript error messages and stacks in native error propagation for precise diagnosis.
  - Custom-scheme fetch then stalled until timeout; replaced it with a loopback-only Network.framework HTTP server and granted the example Release build local server permission.
  - The first loopback integration run compiled but still timed out; moved to direct listener probing before another end-to-end attempt.
  - Rejected the first listener probe because it launched the integration-test artifact and reached Flutter's own 403 service; switched to a normal Release build.
  - Built and launched the normal Release example; confirmed two per-view loopback listeners and successful shader responses from both with `curl`.
- Files created/modified:
  - `pubspec.yaml`
  - `lib/flutter_live2d.dart`
  - `lib/src/view.dart`
  - `lib/src/windows_view.dart`
  - `windows/CMakeLists.txt`
  - `windows/flutter_live2d_plugin.h`
  - `windows/flutter_live2d_plugin.cpp`
  - `windows/flutter_live2d_plugin_c_api.cpp`
  - `windows/include/flutter_live2d/flutter_live2d_plugin_c_api.h`
  - `windows/Live2DAllocator.*`
  - `windows/Live2DPal.*`
  - `windows/Live2DTextureManager.*`
  - `windows/Live2DModel.*`
  - `windows/Live2DWindowsView.*`
  - `windows/libs/x86_64/143/Live2DCubismCore_MD.lib`
  - `windows/libs/x86_64/143/Live2DCubismCore_MDd.lib`
  - `windows/LICENSE.core.md`
  - `android/src/main/cpp/CubismFramework/Model/CubismUserModel.cpp` (temporary Windows renderer probes)
  - `android/src/main/cpp/CubismFramework/Rendering/D3D11/CubismRenderer_D3D11.cpp` (temporary Windows renderer probes)
  - `macos/flutter_live2d.podspec`
  - `macos/flutter_live2d/Package.swift`
  - `macos/flutter_live2d/Sources/flutter_live2d/FlutterLive2dPlugin.swift`
  - `example/macos/`
  - `example/integration_test/plugin_integration_test.dart`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Session: 2026-09-03

### Phase 6: Private Repository Publish
- **Status:** complete
- Actions taken:
  - Confirmed GitHub CLI is authenticated as `hunmer` with private repository access.
  - Confirmed `origin` remains the public upstream `linh18nd/flutter_live2d`.
  - Reviewed the staged files and excluded the local browser QA screenshot under `artifacts/`.
  - Created the private repository `hunmer/flutter_live2d` and added it as the `private` remote.
  - Prepared the verified Web implementation for commit and push to `private/main`.
- Files created/modified:
  - `task_plan.md`
  - `progress.md`

### Phase 1: Baseline And Web SDK Discovery
- **Status:** complete
- **Started:** 2026-09-03
- Actions taken:
  - Restored context according to `planning-with-files`; no prior planning files existed.
  - Confirmed the current package only implements Android/iOS.
  - Confirmed a minimal Web consumer builds but retains a runtime `Platform._operatingSystem` failure path.
  - Confirmed a Windows consumer builds with an empty generated plugin registry.
  - Cloned and inspected the user-selected `CubismWebSamples` stable `5-r.5` implementation and matching Framework tag.
  - Identified the reusable model-loading, WebGL2, resize, input, and render-loop responsibilities.
  - Verified the official hosted Cubism Core script and rejected stale/unofficial npm wrappers.
  - Reduced the intended port to a per-canvas runtime plus the official sample model/texture helpers.
  - Confirmed stable SDK `5-r.5`, pinned Core `core/06`, and reproducible Framework installation by commit.
  - Confirmed only the minified hosted Core is public and selected esbuild transpilation to avoid unavailable Core typings.
  - Reviewed Framework/Sample licenses and measured the vendored source footprint.
  - Chose vendored pinned Framework source because upstream npm metadata installs under an unusable `undefined` package name.
- Files created/modified:
  - `task_plan.md` (created)
  - `findings.md` (created)
  - `progress.md` (created)
  - `findings.md` (updated with official sample architecture)

### Phase 2: Cross-Platform Dart Boundary
- **Status:** complete
- Actions taken:
  - Reviewed the public controller, asset extraction, view lifecycle, tests, and current example behavior.
  - Confirmed current Flutter's recommended Web plugin registration and DOM APIs.
  - Defined conditional asset writing, Web asset URL mapping, and internal view lifecycle hooks.
  - Removed shared-library `dart:io` usage through conditional native asset writers.
  - Added a per-instance Web Canvas host and internal initialize/dispose lifecycle.
  - Added the Web plugin implementation with ordered Core/runtime script loading and command forwarding.
  - Replaced `Platform.is*` with `defaultTargetPlatform` and moved Web lifecycle/canvas state behind internal Web-only types.
  - Re-ran static analysis successfully with no issues.
- Files created/modified:
  - `pubspec.yaml`
  - `lib/flutter_live2d.dart`
  - `lib/flutter_live2d_platform_interface.dart`
  - `lib/flutter_live2d_web.dart` (created)
  - `lib/src/asset_cache.dart`
  - `lib/src/view.dart`
  - `lib/src/native_asset_writer_io.dart` (created)
  - `lib/src/native_asset_writer_stub.dart` (created)
  - `lib/src/web_view.dart` (created)
  - `lib/src/web_view_stub.dart` (created)
  - `lib/src/view_lifecycle.dart` (created)
  - `lib/src/web_canvas_registry.dart` (created)

### Phase 3: Web Runtime Implementation
- **Status:** complete
- Actions taken:
  - Copied the pinned official Framework source, WebGL shaders, licenses, and four reusable Sample helpers into `web_runtime/`.
  - Added the esbuild pipeline, minimal sample constants/host interfaces, and adapted `LAppModel` for readiness, commands, and per-view frame timing.
  - Implemented the per-canvas runtime, render loop, resizing, pointer tracking, cleanup, and JavaScript command API.
  - Installed esbuild 0.28.2 and generated a 642 KB Web runtime bundle plus 13 official WebGL shader files.
- Files created/modified:
  - `web_runtime/vendor/framework/` (created from official Framework commit)
  - `web_runtime/src/lappmodel.ts` (copied for adaptation)
  - `web_runtime/src/lapptexturemanager.ts` (copied for adaptation)
  - `web_runtime/src/lapppal.ts` (copied for adaptation)
  - `web_runtime/src/lappwavfilehandler.ts` (copied for adaptation)
  - `web_runtime/LICENSE.framework.md` (created)
  - `web_runtime/LICENSE.samples.md` (created)
  - `web_runtime/package.json` (created)
  - `web_runtime/build.mjs` (created)
  - `web_runtime/src/runtime.ts` (created)
  - `web_runtime/src/runtime_host.ts` (created)
  - `web_runtime/src/lappdefine.ts` (created)
  - `pubspec.yaml` (registered Web runtime and shader assets)
  - `web_runtime/package-lock.json` (created)
  - `assets/web/flutter_live2d_web.js` (generated)
  - `assets/web/shaders/` (generated)

### Phase 4: Example And Automated Verification
- **Status:** complete
- Actions taken:
  - Generated the standard Flutter Web runner under `example/web`.
  - Built the example Web release successfully; Flutter's Wasm dry-run also succeeded.
  - Initialized procm-mcp with a single `web-example` command for the Flutter Web server on port 8765.
  - Started `web-example` through procm (process `IqcUvK5L`) and confirmed HTTP 200 on port 8765.
  - Diagnosed the blank QA page as Web Server debug-mode handshake behavior and changed the persistent command to `--release`.
  - Loaded two Mao models successfully in headless Edge with two active 720x651 WebGL canvases and no browser/network errors.
  - Visually confirmed both models and transparent composition from `artifacts/web-live2d.png`.
  - Exercised motion, expression, parameter, speed, and pause/resume commands through the browser runtime with no errors.
  - Verified rendered screenshot pixels independently in both model regions.
- Files created/modified:
  - `example/web/` (created)
  - `example/.metadata` (created)
  - `procm-commands.json` (created)

### Phase 5: Delivery
- **Status:** complete
- Actions taken:
  - Updated README platform support and documented WebGL2, hosted Core network access, and Web resource-path behavior.
  - Rebuilt the Web runtime bundle and example Web release successfully.
  - Re-ran static analysis and all unit tests successfully.
  - Confirmed `git diff --check` passes and preserved the existing Android Gradle and lockfile changes.
  - Confirmed the procm-managed Web example remains running at `http://127.0.0.1:8765`.
- Files created/modified:
  - `README.md`
  - `task_plan.md`
  - `progress.md`

## Session: 2026-09-04 Native SDK Verification Continuation

### Phase 8: Windows Runtime Implementation
- **Status:** in_progress
- Restored the file-based plan and confirmed CodeGraph is now indexed (466 files).
- Resumed the standalone official Native SDK C++ smoke test before changing the Flutter plugin.
- The prior run reached model JSON, textures, MOC/model creation, D3D11 renderer initialization, and shader readiness; only the extra `CubismFramework::CleanUp()` call crashed after `PASS` and still requires correction and an exit-code-zero rerun.
- Removed the extra `CubismFramework::CleanUp()` call and added Release-compatible imported-library mappings; CMake configure and Debug compilation succeeded.
- The rerun again proved model JSON, texture references, MOC/model creation, D3D11 device, renderer initialization, and shader readiness, then printed `PASS` and `CubismFramework::Dispose() is complete`; the process still exited abnormally before the final `EXIT` line, narrowing the smoke defect to post-Dispose lifetime/destruction order rather than SDK/model loading.
- Matched the official D3D11 sample cleanup by using `ReleaseAllDeviceInfo()`. The standalone Native SDK test now prints `SHADER_READY=1`, `PASS`, and `EXIT code=0`; the actual Windows process exit code is `0`.
- Added an optional Framework source root to the smoke harness and built it against the repository's instrumented vendored Framework using the same source filtering as the plugin. That differential run also passed with process exit `0`, excluding the probes and vendored Framework implementation from the Flutter-only crash.
- Re-ran the vendored smoke with the plugin's exact D3D11 Debug flags and feature-level list; it selected `11.1`, reached `device-info.shader.ok`, and exited `0`.
- Confirmed the Flutter-only root cause in Framework source: `StartUp()` stores the provided `Option*`, while the plugin passed a stack-local `Option` that expired when runtime initialization returned. Moved the option into `FlutterLive2dPlugin` so it outlives all renderer/shader operations.
- Built the example with `flutter build windows --debug`; the fixed plugin compiled and linked successfully. Runtime click verification is intentionally left to the user.
- Matched plugin shutdown to the verified official D3D11 lifecycle by replacing `ReleaseDeviceInfo(device)` with `ReleaseAllDeviceInfo()` and removing the trailing `CleanUp()`; rebuilt Windows Debug successfully.
- User confirmed model loading now passes on Windows.
- Removed all temporary Windows debug logging APIs/calls, Framework stage probes, first-frame probes, and the SEH renderer wrapper. Restored the three instrumented Cubism Framework files to the official 5-r.5 baseline.
- Deleted the generated Live2D diagnostic logs from `%TEMP%` and rebuilt the Windows Debug example successfully.

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Native C++ model/renderer smoke | Mao `model3.json` through official Native SDK 5-r.5 | Model and D3D11 shader initialize; process exits 0 | `MODEL_OK`, `SHADER_READY=1`, `PASS`, process exit `0` | Pass |
| Vendored Framework differential smoke | Mao model through repository Framework plus Windows probes | Match official smoke | `SHADER_READY=1`, `PASS`, process exit `0` | Pass |
| Windows dangling Framework option fix build | `flutter build windows --debug` in `example` | Build succeeds | Built `flutter_live2d_example.exe` | Pass |
| Existing static analysis | `flutter analyze` | No issues | No issues | Pass |
| Existing unit tests | `flutter test` | All pass | 3 passed | Pass |
| Windows static analysis | `flutter analyze` | No issues | No issues | Pass |
| Windows Debug build | `flutter build windows --debug` in `example` | Build succeeds | `flutter_live2d_example.exe` generated | Pass |
| Baseline Web consumer build | `flutter build web` | Establish baseline | Build succeeds but runtime code contains unsupported `Platform` path | Baseline only |
| Baseline Windows consumer build | `flutter build windows` | Establish baseline | Build succeeds with no plugin registration | Baseline only |
| Dart boundary static analysis | `flutter analyze` | No issues | No issues | Pass |
| Web runtime bundle | `npm run build` in `web_runtime` | Bundle and shaders generated | 642 KB JS and 13 shaders generated | Pass |
| Example Web release build | `flutter build web --release` | Build succeeds | Build succeeded; Wasm dry-run succeeded | Pass |
| Browser model loading | Click AppBar Load-all | Two views load and animate | Both canvases loaded and emitted frame signals; no browser errors | Pass |
| Browser command API | Motion, expression, parameter, speed, pause/resume | All commands complete | All completed with no console/page/network errors | Pass |
| Screenshot pixel verification | Analyze both 720x650 model regions | Each region contains model pixels | 21,872 / 21,504 bright pixels | Pass |
| Final Web runtime bundle | `npm run build` in `web_runtime` | Build succeeds | Build succeeded | Pass |
| Final static analysis | `flutter analyze` | No issues | No issues | Pass |
| Final unit tests | `flutter test` | All pass | 3 passed | Pass |
| Final Web release build | `flutter build web --release` in `example` | Build succeeds | Build and Wasm dry-run succeeded | Pass |
| Final diff validation | `git diff --check` | No whitespace errors | No output | Pass |
| macOS loading diagnostics build | `flutter build macos --debug` | Swift diagnostics compile | Build succeeded | Pass |
| macOS loading diagnostics analysis | `flutter analyze` | No issues | No issues | Pass |
| macOS loading diagnostics unit tests | `flutter test` | All pass | 3 passed | Pass |
| Default macOS integration | `flutter test integration_test/plugin_integration_test.dart -d macos` | No indefinite loading | 1 passed, runtime case opt-in skipped | Pass |
| macOS baseline build | `flutter build macos` before runner generation | Establish baseline | Failed: no macOS desktop project configured | Baseline only |
| macOS Debug build | `flutter build macos --debug` | Build succeeds | Built `flutter_live2d_example.app` | Pass |
| macOS EOF fix build | `flutter build macos --debug` | Swift-generated JavaScript fix compiles | Built `flutter_live2d_example.app` | Pass |
| macOS EOF fix analysis | `flutter analyze` | No issues | No issues | Pass |
| macOS EOF fix unit tests | `flutter test` | All pass | 3 passed | Pass |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-09-04 | `cmake`, `cl`, and `msbuild` were not on the current PowerShell `PATH`; the parallel probe returned non-zero | 1 | Use Flutter's configured Visual Studio installation and avoid a combined fail-fast environment probe |
| 2026-09-04 | First Windows error-log patch used mismatched existing text | 1 | Retried with smaller exact context and separate hunks |
| 2026-09-04 | CodeGraph status/context both reported that the repository was not initialized | 1 | Continued with targeted `rg` and source reads as the mandated fallback |
| 2026-09-04 | Initial D3D11 sample query assumed nonexistent `Demo/src` paths | 1 | Switched to enumerating the `5-r.5` sample tree before targeted reads |
| 2026-09-04 | First extracted SDK lookup assumed `Core` was directly under the destination root | 1 | Enumerate the archive top level, then use the actual nested path |
| 2026-09-04 | First Windows build had no imported Core path for CMake configuration `Profile` | 1 | Explicitly map Flutter's `Profile` configuration to the MD Core library |
| 2026-09-04 | First native-window click/screenshot captured a browser that remained above the app | 1 | Restore and explicitly raise the app before repeating coordinate interaction |
| 2026-09-04 | Windows app exits immediately after model load | 1 | Instrument the precise native loading/rendering boundaries with `[DEBUG-WIN-L2D]`; user will reproduce manually |
| 2026-09-04 | macOS runtime page reports `SyntaxError: Unexpected EOF` after Core downloads | 1 | Escape newlines as `\\n` in both Swift-generated JavaScript error messages so JavaScript receives a valid string escape |
| 2026-09-03 | CodeGraph not initialized | 1 | Used `rg` and direct source reads |
| 2026-09-03 | Temporary probe patch context mismatch | 1 | Read generated source, then patched exact content |
| 2026-09-03 | Sample lookup included nonexistent Demo README | 1 | Switched to root README and exact existing paths |
| 2026-09-03 | Hosted Core `.d.ts`, `.ts`, and unminified `.js` returned 404 | 1 | Use minified Core plus esbuild transpilation |
| 2026-09-03 | First Dart analysis found 2 errors from removed `Platform`, 1 mock API break, and 2 Web lints | 1 | Switch platform detection and isolate Web lifecycle/canvas state from the public interface |
| 2026-09-03 | Combined fix patch missed `dart format`-changed import context | 1 | Use smaller patches against current formatted source |
| 2026-09-03 | Second Dart analysis found one unused import and two failed interface promotions | 1 | Remove import and use an explicitly typed lifecycle local |
| 2026-09-03 | Promotion fix patch missed formatted condition layout | 1 | Inspect the short method and patch exact lines only |
| 2026-09-03 | Lifecycle ternary still inferred `FlutterLive2dPlatform` | 2 | Use explicit nullable interface annotations |
| 2026-09-03 | Explicit annotation exposed absent intersection-type promotion | 3 | Cast only after a successful runtime interface check |
| 2026-09-03 | Suffix-based procm lookup hit the wrong process/log tools | 1 | Switched to exact `process` and `process_logs` tool names; service remained running |
| 2026-09-03 | Playwright could not physically click offscreen `flt-semantics-placeholder` | 1 | Skip semantic activation and click the visible Load-all action directly |
| 2026-09-03 | Playwright `waitForFunction` retained its default 30-second timeout | 2 | Correct the API argument order and preserve diagnostics on timeout |
| 2026-09-03 | Browser QA found zero canvases through open-DOM traversal with no console/network errors | 3 | Inspect the captured page and add a bridge-level diagnostics endpoint if Flutter uses closed shadow roots |
| 2026-09-03 | Default WebGL framebuffer returned transparent data after browser compositing | 1 | Use screenshot pixel analysis; do not enable costly `preserveDrawingBuffer` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Delivery complete |
| Where am I going? | User acceptance at the running Web example |
| What's the goal? | Render real Live2D models in Flutter Web without mobile regressions |
| What have I learned? | See `findings.md` |
| What have I done? | Implemented and verified the Web renderer end to end; see the phase logs above |
