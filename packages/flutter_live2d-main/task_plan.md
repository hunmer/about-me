# Task Plan: Flutter Live2D Cross-Platform Rendering

## Goal
Make the existing `flutter_live2d` public API render Live2D models correctly on Web, macOS, and Windows without regressing Android or iOS.

## Current Phase
Phase 14: Package Rename And pub.dev Publication

## Phases

### Phase 1: Baseline And Web SDK Discovery
- [x] Confirm current Web compile/runtime behavior
- [x] Select a distributable Cubism Web runtime and verify its API/licensing boundary
- [x] Record concrete integration constraints in `findings.md`
- **Status:** complete

### Phase 2: Cross-Platform Dart Boundary
- [x] Replace unconditional `dart:io`/`Platform` usage with conditional implementations
- [x] Add a Web surface lifecycle that preserves `Live2DViewController`
- [x] Define Web asset URL resolution and command transport
- **Status:** complete

### Phase 3: Web Runtime Implementation
- [x] Add the Web plugin declaration and browser renderer bridge
- [x] Load a `.model3.json` model and referenced resources
- [x] Implement motion, expression, parameter, pause/resume, resize, pointer input, and disposal
- **Status:** complete

### Phase 4: Example And Automated Verification
- [x] Add/generate the example Web runner as needed
- [x] Run formatting, analysis, unit tests, and Web release build
- [x] Start the example through the persistent process manager
- [x] Verify nonblank animated rendering and basic controls
- **Status:** complete

### Phase 5: Delivery
- [x] Review diffs and preserve unrelated user changes
- [x] Update README/platform notes and planning records
- [x] Provide concise acceptance steps and remaining risks
- **Status:** complete

### Phase 6: Private Repository Publish
- [x] Review the exact commit contents
- [x] Create a local commit
- [x] Create a private repository under the authenticated GitHub account
- [x] Push the current branch and verify the remote
- **Status:** complete

### Phase 7: Windows Baseline And Architecture
- [x] Inspect the current native plugin, example, and Windows runner structure
- [x] Identify the smallest viable Cubism Native integration path for Windows
- [x] Record implementation and licensing constraints in `findings.md`
- **Status:** complete

### Phase 8: Windows Runtime Implementation
- [x] Verify the official Native SDK and example model in a standalone C++ process
- [x] Add Windows plugin registration and native rendering surface
- [x] Preserve the existing `Live2DViewController` command contract
- [x] Load packaged model resources and handle resize/input/disposal
- **Status:** complete

### Phase 9: Windows Verification And Delivery
- [ ] Build and run the example on Windows through the persistent process manager
- [ ] Verify real model rendering and controller operations
- [ ] Run analysis/tests, review diffs, and update documentation
- **Status:** pending

### Phase 10: macOS Baseline And Architecture
- [x] Inspect the current native plugin, public API, example, and generated macOS runner state
- [x] Build the current macOS baseline and capture concrete failures
- [x] Select the smallest implementation compatible with the existing native code
- **Status:** complete

### Phase 11: macOS Native Implementation
- [x] Register the macOS plugin and platform view
- [x] Load model resources and implement the existing controller commands
- [x] Handle resize, input, lifecycle, and resource cleanup
- [x] Fix VS Code SDK discovery for the current macOS workspace
- [x] Add macOS model-loading and resource-download diagnostics
- **Status:** complete

### Phase 12: macOS Verification
- [x] Run formatting, analysis, and unit tests
- [x] Build the macOS example
- [ ] Launch the rebuilt macOS example
- [ ] Verify rendered pixels and representative controller commands
- **Status:** in_progress

### Phase 13: macOS Delivery
- [ ] Review diffs and preserve unrelated user changes
- [ ] Update platform documentation and planning records
- [ ] Provide concise acceptance steps and remaining risks
- **Status:** pending

### Phase 14: Package Rename And pub.dev Publication
- [x] Rename the Dart package to `live2d_flutter` and update package imports/references
- [x] Change package repository metadata to `https://github.com/hunmer/flutter_live2d`
- [x] Run formatting, analysis, tests, and the initial `dart pub publish --dry-run`
- [x] Publish the current version to pub.dev and verify the result
- **Status:** complete

## Key Questions
1. Can the official Cubism Web Core and Framework be packaged without a runtime CDN dependency?
2. How should Flutter asset directories map to browser URLs while preserving relative model references?
3. Can the existing controller contract remain unchanged for all supported Web commands?
4. What browser-side signal proves the model rendered rather than only the page loading?
5. Which existing native Cubism implementation can be reused for Windows with the fewest platform-specific changes?
6. How should a Windows native rendering surface integrate with Flutter while preserving the current controller API?
7. Can the existing iOS Objective-C++ renderer be shared or minimally adapted for macOS?
8. Which macOS graphics/view lifecycle differences require platform-specific code?
9. Does the example already contain a macOS runner, and what deployment target is required?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Preserve the public `Live2DView` and `Live2DViewController` API | Avoid Android/iOS consumer regressions |
| Use conditional Dart implementations | Web cannot use the native filesystem/platform-view path |
| Treat real rendered pixels as the acceptance bar | A successful Web build alone does not prove Live2D support |
| Pin Framework commit `198a3769...` and Core path `core/06` | Both correspond to the stable Cubism 5.3-compatible line and avoid `Latest` drift |
| Render Windows through a Flutter DXGI shared-handle GPU texture | Windows desktop has no equivalent native platform-view widget; a shared D3D11 texture avoids CPU readback and does not require access to Flutter's private D3D device |
| Reuse the existing vendored Framework's D3D11 backend | It matches official Native SDK `5-r.5` except for an Android-only OpenGL shader customization |
| Ship the authorized x64/v143 MD/MDd Core libraries | They match Flutter's VS2022 dynamic CRT Debug/Release configurations |
| Implement macOS with `AppKitView` hosting `WKWebView` | The workspace lacks a macOS Cubism Core binary, while the verified Web runtime already covers rendering and all controller commands |
| Serve plugin/model files through a custom WKWebView URL scheme | Supports absolute temporary model directories without relying on fragile cross-directory `file://` access |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Native command timeout did not fire because `loadModel` was still queued before runtime readiness | 1 | Add an independent 30-second runtime initialization timeout and Dart-side stage logs |
| macOS runtime page reported `SyntaxError: Unexpected EOF` after Core downloaded | 1 | Escape newlines in Swift-generated JavaScript strings so WebKit receives `\\n` rather than a literal line break inside quotes |
| Manual listener probe launched the integration-test build and hit its Flutter service (403), not the Live2D server | 1 | Build and launch the normal Release example before probing listeners |
| Listener probe assigned zsh's read-only `status` variable | 1 | Use a task-specific exit-code variable in subsequent shell checks |
| Loopback HTTP version still left model loading pending until the test timeout | 1 | Probe the native listener directly with `lsof` and `curl` before changing WebKit behavior |
| Loopback transport patch missed formatter-adjusted Swift context | 1 | Split the change into exact view, server, and manifest patches |
| Custom-scheme model fetch remained pending until the 90-second integration timeout | 2 | Replace non-HTTP fetch transport with a loopback-only native HTTP server; avoid duplicating 5-19 MB model trees |
| WKWebView runtime initialized but model `fetch` failed with `TypeError: Load failed` | 1 | Put page, model, and shader custom URLs under one `flutter-live2d://local` origin and route by path |
| WKWebView rejected the async command wrapper's Promise result as unsupported | 1 | End evaluated scripts with synchronous `null`; receive real results through the existing script-message bridge |
| Asset-resolver patch had an invalid hunk terminator | 1 | Reapply as exact per-file hunks |
| WKWebView loaded hosted Core but did not execute runtime from the custom scheme (`runtime=undefined`) | 2 | Inline the trusted bundled JS in the private runtime page; reserve the custom scheme for fetched data resources |
| macOS runtime page could not call `FlutterLive2DWeb.createView` despite bundled assets | 1 | Resolve package assets inside the standard `App.framework/Resources` location and add global-object diagnostics |
| macOS integration test did not compile because `defaultTargetPlatform` was not imported | 1 | Import `package:flutter/foundation.dart` in the test |
| Integration-test planning patch used an outdated progress-log insertion point | 1 | Read the current log and apply a smaller exact-context patch |
| First macOS build found renamed Swift registrar API and a non-escaping queued callback | 1 | Use `registrar.register(_:withId:)` and mark the stored error callback `@escaping` |
| Dart format paths were resolved from `example/` instead of package root | 1 | Run formatting from the package root before the next verification stage |
| `flutter doctor -v` did not finish within 30 seconds during SDK discovery | 1 | Stop the exact diagnostic processes and use the executable symlink directly |
| SDK root calculation resolved the symlink's parent instead of the symlink target | 2 | Use `realpath` on the Flutter executable before deriving the root |
| Flutter source path inferred from version output did not contain `platform_view.dart` | 1 | Resolve the active Flutter executable path before reading Dart SDK sources |
| Temporary Flutter 3.44 macOS plugin template did not place Swift under legacy `macos/Classes` | 1 | Locate the generated SwiftPM-style source path with `rg --files` before reading it |
| Phase transition planning patch used progress-file context against `findings.md` | 1 | Split the update into exact per-file patches |
| `flutter build macos` reports `No macOS desktop project configured` | 1 | Generate the standard macOS runner after confirming the plugin architecture |
| Current workspace directory has no `.git` metadata | 1 | Continue with filesystem-level change tracking and verify whether repository metadata exists nearby |
| CodeGraph was not initialized during prior exploration | 1 | Used targeted `rg` and source reads |
| Initial temporary probe patch did not match generated `main.dart` | 1 | Read the generated file and applied a targeted patch |
| Sample inspection referenced a nonexistent Demo README | 1 | Use the repository root README and exact existing files |
| Official Core host has no public `.d.ts`, `.ts`, or unminified `.js` siblings | 1 | Bundle Framework with esbuild transpilation, which does not require Core type declarations |
| First Dart analysis reported two missing `Platform` references, a JS interop runtime check, one unused import, and mock interface breakage | 1 | Use `defaultTargetPlatform`; move Web lifecycle to an internal interface and Web-only canvas registry |
| Combined fix patch did not match formatted conditional-import lines | 1 | Read formatted files and apply smaller exact-context patches |
| Second Dart analysis did not promote platform type after a compound condition | 1 | Store an explicit nullable `Live2DViewLifecycle` local and call through it |
| Promotion fix patch missed formatter-adjusted line wrapping | 1 | Patch only exact current lines in the affected method |
| Lifecycle ternary inferred the original platform type | 2 | Add an explicit `Live2DViewLifecycle?` type annotation |
| Explicit lifecycle annotation still lacked an intersection-type promotion | 3 | Cast to the internal interface after the runtime `is` check |
| Procm tool lookup by suffix selected `batch-process` and `clear-process-logs` | 1 | Use exact MCP tool names for process status and logs |
| First Playwright run timed out clicking Flutter's offscreen accessibility placeholder | 1 | Bypass the semantics placeholder and click the visible AppBar action by coordinates |
| Second Playwright run used the timeout object as `waitForFunction` argument | 2 | Pass `null` as the function argument and timeout as the third parameter; always emit diagnostics |
| Third Playwright run could not discover plugin canvases through DOM traversal | 3 | Inspect screenshot and use Flutter-rendered status or runtime diagnostics instead of assuming open shadow roots |
| WebGL default-framebuffer `readPixels` returned transparent data after compositing | 1 | Keep the performant default and validate rendered output from the page screenshot plus runtime frame signals |
| Windows environment probe found `cmake`, `cl`, and `msbuild` absent from the current PowerShell `PATH` | 1 | Locate Flutter's configured Visual Studio toolchain and build through `flutter build windows` instead of assuming global tools |
| First Windows error-log patch used mismatched existing text | 1 | Retry with smaller exact context and separate hunks |
| CodeGraph tools were connected but the repository index was not initialized | 1 | Confirmed the prior-session limitation and continued with targeted `rg`/source reads per repository instructions |
| Official Native Samples D3D11 source was queried with an outdated directory layout | 1 | List the cloned tag's actual tree and target the current `Samples/D3D11/Demo/proj.win.cmake` structure |
| Extracted Native SDK was queried as if `Core` were at the extraction root | 1 | Enumerate the archive's actual top-level directory before selecting Windows Core libraries |
| First Windows build lacked an imported Core location for Flutter's `Profile` CMake configuration | 1 | Map `Profile` explicitly to `Live2DCubismCore_MD.lib` and retry generation |
| First Windows coordinate click/capture was covered by the foreground browser | 1 | Restore and raise the app with `ShowWindow` and a temporary topmost `SetWindowPos` before interaction |
| Windows process exits immediately after the example loads models | 1 | Diagnostics proved D3D11 renderer context settings were never initialized before first `StartFrame`; initialize them per the official sample |
| After setting D3D11 constants, Windows exits inside `CreateRenderer()` | 2 | Use the new temp-file trace plus Windows crash metadata to isolate the renderer initialization substage before another fix |
| Broad recursive `rg` under `%TEMP%` encountered unrelated access-denied directories | 1 | Query the known extracted SDK path directly; its D3D11 renderer matches the vendored source |
| Linked renderer probes produced no first function-body marker before exit | 3 | Broaden diagnosis: add an SEH filter at the exact call boundary and capture exception code plus module RVA for symbol resolution |
| First fixed-text probe patch had mismatched expected strings | 1 | Split the edit into exact small patches before replacing the remaining D3D11 probes |
| Broad official D3D11 sample grep exceeded the 10-second command timeout | 1 | Read the known shader implementation and sample CMake files directly |
| `fvm` is not available in the current PowerShell PATH | 1 | Use the configured system Flutter/Dart executable for validation |
| PowerShell terminated a broad `rg` pattern at an embedded quoted literal | 1 | Re-run the read-only search with a single-quoted regex |
| Parallel Windows/Web builds raced on `example/.dart_tool` and Web saw the stale `flutter_live2d` registrant | 1 | Clean the example and run platform builds sequentially |
| `git check-ignore` returned its normal no-match exit code during a parallel read batch | 1 | Re-run while explicitly normalizing the no-match status |
| `dart pub publish --dry-run` reported renamed tracked paths and a dirty worktree | 1 | Remove empty old directories, exclude internal planning files, commit the rename, and re-run dry-run from a clean snapshot |
| Native smoke still exited abnormally after removing `CleanUp()` | 2 | Loading and shader checks pass; compare object/allocator destruction order against the official sample before declaring the SDK test complete |
| Native smoke used single-device cleanup and crashed after Framework Dispose | 3 | Match the official D3D11 sample with `ReleaseAllDeviceInfo()`; smoke now prints `EXIT code=0` and the OS process exit code is `0` |
| Vendored Framework cannot be added as a standalone CMake subdirectory | 1 | Its CMake files expect an Android parent target; make the smoke harness collect the same vendored `.cpp` files as the Windows plugin instead |
| Flutter plugin crashes before shader file loading | 4 | Framework retained a pointer to a stack-local `Option`; store it as a plugin member for the complete Framework lifetime. Windows Debug build now passes; user runtime verification remains pending |

## Notes
- Existing user modifications in Android Gradle settings and `example/pubspec.lock` must be preserved.
- External documentation content belongs in `findings.md`, not this repeatedly read plan.
