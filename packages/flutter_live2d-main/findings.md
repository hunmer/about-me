# Findings And Decisions

## Package Rename And Publication (2026-09-04)
- The Git worktree was clean before this task.
- `pubspec.yaml` still declares `name: flutter_live2d`; its homepage and repository point to `linh18nd/flutter_live2d`.
- Renaming the Dart package requires updating `package:flutter_live2d/...` imports in README, tests, example code, and runtime package-asset resolution.
- Native method-channel identifiers and native binary/target names are implementation details and do not need to change for the Dart package rename.
- pub.dev currently returns HTTP 404 for `live2d_flutter`, so the package name is available for an initial publication.
- Flutter-generated Windows integration expects a CMake target and public C API header derived from the new package name; Apple CocoaPods integration likewise expects a matching podspec filename and pod name.
- Regeneration confirmed the Windows include directory and CMake target use `live2d_flutter`, while the C API header basename remains `flutter_live2d_plugin_c_api.h` because the configured plugin class is still `FlutterLive2dPluginCApi`.
- The existing `private` Git remote points to `https://github.com/hunmer/flutter_live2d.git`; `origin` still points to the upstream repository.
- `dart pub publish --dry-run` passed with 0 warnings and a 29 MB compressed archive after committing the rename.
- pub.dev accepted `live2d_flutter` version `1.0.3`; its public API immediately reported the expected homepage and repository URL.

## Requirements
- Use the file-based planning workflow requested by the user.
- Continue the package work by adding functional macOS support.
- Prefer the smallest implementation that reuses the existing native renderer and preserves the public Dart API.
- Make the Web example display a real Live2D Cubism model.
- Continue the implementation so the same package renders Live2D models on Windows.
- Keep existing Android/iOS behavior and public Dart API stable.
- Validate each implemented desktop path with a build and an actual rendering signal.

## Research Findings
- Standalone C++ Native SDK 5-r.5 repeatedly loads Mao's model JSON, verifies its texture, creates the MOC/model (`128` parameters, `260` drawables), creates a D3D11 device, initializes the official D3D11 renderer, and obtains a non-null shader. The SDK/model loading path is therefore operational; the remaining smoke failure occurs only after `CubismFramework::Dispose()` completes.
- Official Native SDK D3D11 samples release models and `CubismDeviceInfo_D3D11` before `CubismFramework::Dispose()` and do not call `CleanUp()` during normal shutdown; `CleanUp()` is used before a later `StartUp()` reset. The smoke test should mirror that sequence exactly.
- Replacing the smoke test's `ReleaseDeviceInfo(device)` with the official sample's `ReleaseAllDeviceInfo()` removed the post-Dispose access violation. The final native result is `SHADER_READY=1`, `PASS`, `EXIT code=0`, with OS process exit code `0`. This conclusively separates the Flutter crash from SDK/model validity.
- The failing Flutter trace shows both Dart views start `loadModel` together, while only view 1 reaches native logs and exits inside the global D3D11 device-info shader setup. Since the standalone single-thread renderer passes, cross-view initialization concurrency is the leading plugin-specific hypothesis pending source-level lock inspection.
- Source inspection falsified the cross-view concurrency hypothesis: `FlutterLive2dPlugin::HandleMethodCall` holds `views_mutex_` across `view->LoadModel()`, and the trace shows only view 1 entered native loading before the crash. View 2 is queued behind it. The next comparison must focus on plugin-vs-official Framework/build/object-state differences inside `CubismShader_D3D11::SetupShader()`.
- `CubismShader_D3D11::SetupShader()` is only a wrapper around `GenerateShaders()`. Because the Flutter trace stops before `Live2DPal::LoadFileAsBytes`, the access violation occurs before shader-file I/O, most likely in initial `ReleaseShaderProgram()` state cleanup or due to a class layout/build-definition mismatch.
- SHA-256 comparison confirms vendored and official `CubismShader_D3D11.cpp/.hpp` are byte-identical. The plugin builds Framework as a separate static library but applies Flutter's `apply_standard_settings()` only to the plugin DLL, making MSVC ABI/CRT/iterator-setting divergence a stronger hypothesis than source divergence.
- Generated Visual Studio projects show both the plugin's Framework library and the passing official smoke Framework use `MultiThreadedDebugDLL` (`/MDd`) with Debug runtime checks and disabled optimization. A basic CRT configuration mismatch is therefore not supported by current evidence.
- Directory comparison shows only the two instrumented D3D11 files differ from the official SDK; allocator implementations are equivalent. A differential smoke build against the vendored instrumented Framework is the next sharp test.
- The differential smoke linked the repository's vendored Framework, including all `[DEBUG-WIN-L2D]` D3D11 probes and the same source collection as the plugin. It still completed shader compilation, renderer initialization, `PASS`, and process exit `0`. This rules out the instrumentation and vendored Framework source as the cause and isolates the defect to Flutter plugin D3D device/thread/lifetime setup.
- Plugin source creates a normal multithread-capable D3D11 device; all render-loop and model operations hold `views_mutex_`, so the immediate context is not concurrently used by those paths. The remaining device-level differences from smoke are Debug-layer enablement and explicit feature-level selection, plus Flutter's pre-load shared-handle texture registration/consumption.
- The vendored native smoke was changed to use the plugin's exact Debug-layer flag, feature-level list, and WARP fallback. It selected D3D feature level `11.1`, compiled the shader, and exited `0`. Device creation flags and feature level are ruled out; Flutter texture registration/descriptor consumption is now the primary differing boundary.
- Root cause identified: `FlutterLive2dPlugin::InitializeRuntime()` passed the address of a stack-local `CubismFramework::Option` to `CubismFramework::StartUp()`. Framework stores that pointer verbatim in global `s_option`; after `InitializeRuntime()` returns, the pointer dangles. First D3D11 shader initialization calls `GetLoadFileFunction()`, reads through the dangling pointer, and invokes an invalid function address before `Live2DPal::LoadFileAsBytes` can log. Official samples and both native smoke variants keep `Option` alive for the entire Framework lifetime.
- Plugin shutdown also used the single-device cleanup path that produced the smoke test's post-Dispose access violation. It should mirror the verified official sequence: stop rendering and destroy views, call `ReleaseAllDeviceInfo()`, then `CubismFramework::Dispose()` without a trailing `CleanUp()`.
- User confirmed the fixed Windows build successfully loads the models. All temporary `[DEBUG-WIN-L2D]` logging, Framework probes, first-frame probes, and SEH crash wrapper were then removed; the functional `Option` lifetime and shutdown fixes remain.
- The repository has no `windows/` plugin implementation or Windows registration in `pubspec.yaml`; the previous Windows example build therefore generated no plugin registration.
- The vendored Cubism Framework under `android/src/main/cpp/CubismFramework` already includes its D3D11 renderer sources, so Windows can likely reuse the existing Framework and model behavior instead of introducing a second framework version.
- At the start of the Windows continuation, Git was clean apart from the three planning files updated for this session.
- The Dart controller command contract and native asset extraction are platform-neutral and can be reused unchanged on Windows.
- Flutter Windows has no matching `PlatformViewLink`/`UiKitView` branch in the current widget; a native Windows implementation should expose a Flutter texture ID and render it with `Texture`.
- Android's `Live2DModel` behavior is reusable in principle, but its texture manager, renderer setup, and JNI surface lifecycle are coupled to OpenGL ES and must be adapted to D3D11/Windows plugin APIs.
- The repository contains Cubism Core static libraries only for Android ABIs; there is no Windows COFF `.lib`/`.dll`, and an Android x86_64 ELF archive cannot be linked into a Windows build.
- The D3D11 Framework backend exposes the required native primitives (`StartFrame`, `EndFrame`, `BindTexture`, D3D11 render targets, and device/context-aware renderer creation).
- Flutter 3.44.9 recognizes Visual Studio Community 2022 17.14 and Windows SDK 10.0.26100.0, so the Windows build toolchain is installed even though its executables are not globally on `PATH`.
- The official `Live2D/CubismNativeSamples` latest release is `5-r.5` (published 2026-04-02), matching the vendored Framework line, but its GitHub release has no binary assets.
- The official Cubism SDK for Native download page returns no direct SDK archive link; the proprietary Core package is distributed only through Live2D's license-confirmation download flow.
- No prior Native Samples/SDK checkout exists in the local temporary directory.
- Official `CubismNativeSamples` tag `5-r.5` was cloned at commit `b8024738...` for local D3D11 implementation reference.
- Flutter 3.44 Windows supports GPU textures of type `kFlutterDesktopGpuSurfaceTypeD3d11Texture2D`; the plugin can expose an `ID3D11Texture2D*` directly and avoid per-frame GPU-to-CPU readback.
- The official download page states that downloading or launching the Native SDK constitutes agreement to Live2D's proprietary and open software licenses; this workflow must not accept that legal agreement on the user's behalf.
- For Flutter's `kFlutterDesktopGpuSurfaceTypeD3d11Texture2D`, `FlutterDesktopGpuSurfaceDescriptor.handle` is the `ID3D11Texture2D*`; the descriptor callback may run on Flutter's render thread, so the texture lifetime and synchronization must outlive registration/unregistration.
- The current official D3D11 sample source lives under `Samples/D3D11/Demo/proj.d3d11.cmake/src`.
- The official sample selects Core libraries by architecture/toolset/CRT. For Flutter's Visual Studio 2022 x64 build, the suitable artifact is the x86_64/v143 `Live2DCubismCore_MD.lib` variant (and `MDd` for Debug if supplied).
- The official D3D11 Framework links `d3d11.lib` and `d3dcompiler.lib`; its sample also uses DirectXTK for textures, but this plugin can avoid that dependency by decoding PNGs with its already-vendored `stb_image` and creating D3D11 shader-resource textures directly.
- A clean Flutter 3.44 Windows plugin template was generated outside the repository and confirms the standard C++ registrar/method-channel layout needed here.
- On 2026-09-04 the user explicitly confirmed acceptance of the Live2D license agreements and authorized downloading the Native SDK.
- The official Native download page delegates current package selection to `https://cubism.live2d.com/sdk-native/js/download.js`; the static HTML intentionally contains no SDK archive URL.
- The official selector identifies `CubismSdkForNative-5-r.5.zip` as the latest stable archive dated 2026-04-02, hosted under `https://cubism.live2d.com/sdk-native/bin/`.
- The official D3D11 model loop is `CreateRenderer`/bind texture SRVs, then per frame `StartFrame(context)`, update/draw, and `EndFrame`; this can target the Flutter texture render target without a swap chain.
- The authorized official archive downloaded successfully (27,566,034 bytes; SHA-256 `7FF3A4BBC19C0A8728965AA522AB77EB11B252916453E68A8A78D3B71188BB12`).
- The extracted SDK has the expected nested `CubismSdkForNative-5-r.5/Core` layout and includes Windows x86/x64 Core libraries for Visual Studio toolsets 141/142/143, plus the official Core and Framework license files.
- The repository's vendored Framework matches the official Native SDK `5-r.5` source except for 12 Android-specific lines in `CubismShader_OpenGLES2.cpp`; its D3D11 backend can be reused as-is for Windows.
- Flutter's Windows engine imports GPU surfaces through ANGLE. Because the plugin cannot access the engine's private D3D device, use `kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle` with a `D3D11_RESOURCE_MISC_SHARED` render-target texture rather than passing a cross-device raw `ID3D11Texture2D*`.
- Cubism's D3D11 shaders are loaded at runtime through the Framework file callback from `FrameworkShaders/CubismEffect.fx` and `FrameworkShaders/CubismBlendMode.fx`; CMake must bundle both beside the Windows executable.
- The vendored Framework directory is the SDK's `Framework/src` tree rather than its top-level CMake project, so the Windows CMake target must collect common/D3D11 `.cpp` files and exclude OpenGL, D3D9, Metal, and Vulkan backends.
- Flutter's own Windows external-texture test creates a `DXGI_FORMAT_B8G8R8A8_UNORM` texture with `D3D11_RESOURCE_MISC_SHARED`, validating the planned render-target format and sharing flag.
- The repository ignore rules do not exclude the newly added Windows Core `.lib` files.
- `CubismRenderer::Create` is implemented by the selected renderer backend source itself; compiling only the D3D11 backend supplies the factory without an additional Windows target macro.
- The procm-managed Windows example launches successfully, exposes the Dart VM service, has a responsive native window, and emits no stderr before model loading.
- The example requires its AppBar `Load all` action before either model is loaded.
- The pre-load Windows screenshot shows both Texture-backed views attached and the example UI responsive; Flutter exposes only its top-level pane through Windows UI Automation, so the AppBar action must be exercised by verified window-relative coordinates.
- After model-load termination, both Framework shader files were present in the final runner directory, but Windows Application Event Log contained no crash record; procm only reported `Lost connection to device`, consistent with an assertion/abort or fast native termination.
- Shader loading remains the leading hypothesis because Cubism requests relative `FrameworkShaders/...` paths and file presence does not prove the launched process uses the runner directory as its current working directory.
- Diagnostic output now goes to Flutter stderr, `OutputDebugString`, and `%TEMP%/flutter_live2d_windows.log`, all tagged `[DEBUG-WIN-L2D]`.
- Instrumented boundaries distinguish D3D/framework initialization, view/texture creation, current working directory and every file read, MOC/expression/physics/pose/motion setup, PNG decode/SRV creation, renderer/shader setup, and each stage of the first rendered model frame.
- The user's instrumented reproduction proves all model resources and the 4096x4096 texture load successfully. The process terminates inside the first `CubismRenderer_D3D11::StartFrame`, immediately after Cubism logs `ContextNum has not been set.`
- This falsifies the shader path, model asset, texture decode, and Core ABI hypotheses; the missing D3D11 renderer constant/context setting is the direct cause.
- Official Native Samples call `CubismRenderer_D3D11::SetConstantSettings(BackBufferNum, device)` immediately after `CubismFramework::Initialize()` and explicitly state it must happen before model loading.
- Framework `OnDeviceChanged()` asserts and terminates when the static buffer-set count is zero, exactly matching the user's last log line and fast process exit.
- The official D3D11 sample uses `BackBufferNum = 1`; this matches the plugin's single immediate context and serialized render loop, so the fix uses the same value.
- The second attached log is byte-for-byte identical to the first reproduction (same SHA-256 `902C1F1DC5F1904735DD32FA336D43256D3FEA57CFD3398FD95A1972C63EA018`, VM URL, and texture IDs), so it is not evidence from a post-fix build.
- The current source still contains `SetConstantSettings(1, device)` and the post-fix marker `cubism.renderer.constant-settings.ok bufferSets=1`.
- The third attached log is also byte-for-byte identical to the original (`902C1F1D...EA018`), so no post-fix runtime result has been received yet.
- The example's generated plugin symlink targets the current workspace, and the current Debug plugin DLL contains the post-fix marker, proving the local build artifact includes the fix even though the attachment does not.
- The current `%TEMP%/flutter_live2d_windows.log` is genuinely post-fix (09:45:17): it contains the constant-settings marker and no `ContextNum` error, proving the first fix worked.
- The new process termination occurs after `model.load.renderer.begin` and before `model.load.renderer.ok`, narrowing the remaining fault to `CubismUserModel::CreateRenderer()` / D3D11 renderer initialization rather than assets, textures, or first-frame drawing.
- The post-fix termination again produced no Windows Application event or WER dump, so a native call stack is unavailable; finer renderer initialization markers are the correct available feedback seam.
- Official D3D11 samples invoke the same `CreateRenderer(width, height)` after model setup, so the remaining fault is within this plugin's renderer/device/model state rather than a missing alternate sample API.
- The latest attachment `cc7eb806-.../pasted-text.txt` is again the original pre-fix log with SHA-256 `902C1F1D...EA018`; it cannot validate the current binary.
- The actual `%TEMP%/flutter_live2d_windows.log` remains the authoritative post-fix trace: initialization reaches `model.load.renderer.begin`, then exits before the inherited renderer factory call returns.
- The vendored D3D11 renderer is byte-for-byte identical to the official Native SDK `5-r.5` implementation, so the next probe should identify which official initialization boundary receives incompatible runtime state rather than patching Framework behavior speculatively.
- The renderer factory and D3D11 initialization now have targeted probes for device state, model feature flags, blend targets, drawable/offscreen masks, model counts, base initialization, per-drawable command buffers, and mesh buffers.
- The 10:11 reproduction is new (SHA-256 `6E11477A...A5785`) and crashes while loading the `ren` model for view 2, after `model.load.renderer.begin` but before the first factory probe.
- The actual runner DLL contains both `win.renderer.factory.begin` and D3D11 probe strings, ruling out a stale linked plugin artifact.
- No Application Error event, WER report, or CrashDumps file was produced for this reproduction. Since the first function-body marker is absent, an SEH filter at the exact call boundary is needed to capture the native exception code and module-relative address.
- The 10:23 reproduction reaches the SEH wrapper's `model.load.renderer.call.begin` but emits neither the first Framework `CubismLogInfo` marker nor an SEH exception record. This indicates a CRT fail-fast/abort path rather than a normal structured exception.
- `CubismRenderer_D3D11` and its base constructors contain no assertions; the first potentially terminating operation after the wrapper marker is the formatted Framework probe itself. Renderer probes now bypass `CubismDebug::Print` and send fixed text directly through the registered Core log callback.
- The 11:07 and 11:08 attachments both stop after `win.renderer.device-info.begin`, proving the exit occurs inside `CubismDeviceInfo_D3D11::GetDeviceInfo()`.
- `GetDeviceInfo()` performs a map lookup/insertion, creates `CubismRenderState_D3D11`, then compiles Framework shaders. It previously indexed the same custom `csmMap` three times; the Windows path now inserts/accesses it once and logs each substage.
- Framework shader loading is definitively mis-rooted under `flutter run`: the process CWD is `example/`, `example/FrameworkShaders` does not exist, and the required files are present beside the executable under `runner/Debug/FrameworkShaders`. Relative framework assets now resolve from the executable directory.
- The 11:28 Flutter reproduction reaches `win.device-info.shader.begin` after map insertion and D3D render-state creation, then terminates before the shader file loader is called.
- Per user direction, SDK health will now be tested independently with an official Native SDK `5-r.5` C++ executable, using the official Framework source and Core library rather than the plugin's modified Framework target.
- Flutter copies the plugin DLL into the final runner directory but does not propagate arbitrary directories from the plugin's intermediate target output; D3D11 shaders must also be copied explicitly to `${CMAKE_BINARY_DIR}/runner/<config>/FrameworkShaders`.
- The macOS `Unexpected EOF` at runtime-page line 17578 was caused by Swift interpreting `\n` inside its multiline HTML/JavaScript string as a literal newline inside a JavaScript single-quoted string. The bundled runtime itself is complete; both generated JavaScript error-formatting expressions must emit `\\n` instead.
- The macOS loading path currently emits no listener, HTTP request, JavaScript console, or command-duration logs, so a pending model load cannot reveal its last completed stage.
- The JavaScript runtime has a 60-second readiness timeout, but background WKWebView timers can be throttled; a native dispatch timeout is needed to guarantee the Dart Loading state exits.
- The new runtime readiness timeout reports `HTTP requests=0, last=none` in the integration harness, proving that harness stalls before model downloads begin; normal app logs now distinguish Core download, runtime readiness, and every local resource request.
- The macOS runtime integration test is opt-in with `--dart-define=LIVE2D_MACOS_RUNTIME_TEST=true` because the Flutter test harness does not reliably foreground its WKWebView.
- VS Code could not discover Flutter because `.vscode/settings.json` pointed to missing `.fvm/versions/stable`, the project has no `.fvm` directory or `fvm` command, and the extension process PATH omits Homebrew.
- The SDK manually discovered by the extension at `/Users/Zhuanz/Documents/flutter/flutter` is an older 3.32.8 checkout with a stale Dart 3.8 dev cache, so it should not be used for this workspace.
- The SDK that built the macOS implementation is `/opt/homebrew/Caskroom/flutter/3.29.1/flutter`; its internal version metadata is Flutter 3.44.0 / Dart 3.12.0 and it is configured explicitly for VS Code.
- The current workspace directory has no `.git` metadata, despite prior progress records describing a commit and private remote.
- `pubspec.yaml` registers Android, iOS, and Web only; there is no macOS plugin declaration.
- No root `macos/` plugin directory or `example/macos/` runner was found in the initial file scan.
- The iOS implementation vendors the full Cubism Framework Metal renderer and a Core XCFramework, making it the primary reuse candidate if the binary contains a macOS slice.
- The vendored Core XCFramework contains only `ios-arm64` and `ios-arm64_x86_64-simulator`; it cannot link into a macOS target.
- Directly porting the iOS Metal renderer therefore requires obtaining a separately licensed macOS Cubism Core binary that is not present in this workspace.
- A smaller self-contained route is a macOS `NSView` backed by `WKWebView`, reusing the already verified Cubism Web runtime and the same hosted fixed-version Core script.
- macOS `FlutterPlatformViewFactory` directly returns an `NSView` from `create(withViewIdentifier:arguments:)`; unlike iOS, no separate `FlutterPlatformView` wrapper protocol is required.
- The shared Dart view currently creates platform views only for Android and iOS; macOS needs an `AppKitView` branch while controller method-channel routing can remain unchanged.
- All controller operations already travel through one `flutter_live2d` method channel and include `viewId`; the macOS plugin can implement the same method names without public API changes.
- The iOS plugin's per-view registry, factory callbacks, argument validation, and disposal identity check are reusable architectural patterns even though its UIKit/OpenGL renderer is not.
- The Dart model asset cache already extracts declared assets to an absolute temporary directory on all `dart:io` platforms, which is suitable input for a macOS local-file renderer.
- The macOS baseline build stops with `No macOS desktop project configured`; dependency resolution itself succeeds.
- Flutter 3.44 also warns that the existing iOS plugin lacks Swift Package Manager metadata, but this is non-blocking for CocoaPods and independent of macOS support.
- A generated macOS runner enables App Sandbox but does not include `com.apple.security.network.client`; consumers using the hosted Cubism Core must grant outbound network access.
- Flutter 3.44 macOS CocoaPods plugins depend on `FlutterMacOS`; the generated plugin template now stores source in a SwiftPM-compatible nested path rather than legacy `macos/Classes`.
- The macOS registrar exposes `lookupKeyForAsset(_:fromPackage:)`, so the native view can locate the package's already-declared JS/shader Flutter assets instead of duplicating generated resources under `macos/`.
- The built macOS app contains `flutter_live2d_web.js` under App.framework's package Flutter assets, and its signed Debug entitlements include outbound network access.
- Flutter's macOS `lookupKeyForAsset` already prefixes keys with `Contents/Frameworks/App.framework/Resources/flutter_assets`; resolving the key against `Bundle.main.bundleURL` yields the actual packaged asset path.
- WKWebView executes custom-scheme script resources inconsistently and its Fetch API left same-origin custom-scheme requests pending; standard loopback HTTP is required for the Framework's mix of `fetch` and `Image.src` loading.
- Example model directories range from 5 MB to 19 MB, dominated by texture files, so copying models into a staging directory per view is unnecessarily expensive.
- A normal Release example creates two loopback listeners for its two Live2D views; direct `curl` requests to both returned the expected 465-byte vertex shader.
- The macOS integration-test harness repeatedly reports `Failed to foreground app; open returned 1`, so its hidden WKWebView may suspend runtime timers even though compilation and platform-channel setup succeed.
- `pubspec.yaml` currently registers only Android and iOS plugins.
- `lib/flutter_live2d.dart` unconditionally imports `dart:io`.
- `lib/src/view.dart` evaluates `Platform.isAndroid` / `Platform.isIOS`; the generated Web JavaScript contains an `Unsupported operation: Platform._operatingSystem` throw path.
- A temporary consumer builds successfully for Web and Windows, but none of Web/Windows/macOS/Linux receives a plugin registration.
- The current native model loader requires absolute filesystem paths; Web should instead preserve browser URLs so relative files in `.model3.json` resolve naturally.
- Official Live2D documentation lists a separate Cubism SDK for Web using browser rendering, while Native SDK support is a different implementation family.
- The official Native and Web Framework repositories expose stable tag `5-r.5`; Cubism Core remains under Live2D's proprietary distribution terms.
- The user explicitly selected `Live2D/CubismWebSamples` as the Web reference implementation.
- `CubismWebSamples` tag `5-r.5` uses WebGL2, `ResizeObserver`, `requestAnimationFrame`, and browser `fetch` for model resources.
- Sample `LAppModel.loadAssets()` keeps a model base URL and resolves `.moc3`, textures, motions, expressions, physics, pose, and user data relative to it.
- Sample `LAppSubdelegate` owns one canvas/WebGL context; this maps cleanly to one Flutter `Live2DView` and enables multiple independent views.
- Sample `LAppLive2DManager` contains Demo scene switching that should not be copied; the plugin only needs a per-view model runtime.
- The GitHub Framework repository does not contain Cubism Core. The official sample build expects a separately obtained `Core` directory.
- The official hosted Core script at `https://cubism.live2d.com/sdk-web/cubismcore/live2dcubismcore.min.js` is reachable and its header identifies it as agreement-defined Redistributable Code.
- The sample's full `LAppSubdelegate` and `LAppView` are coupled to Demo background/gear sprites and scene switching; copying them wholesale would add irrelevant behavior.
- `LAppModel` only needs a small host surface contract: canvas, WebGL context, texture manager, framebuffer, shader base URL, and frame time.
- The plugin runtime can normalize pointer coordinates directly and call `model.setDragging`, avoiding the sample's Demo hit-testing and scene-switching UI.
- Live2D's current download metadata identifies `5-r.5` as stable Cubism SDK for Web R5, dated 2026-04-02.
- `https://cubism.live2d.com/sdk-web/core/06/live2dcubismcore.min.js` is the fixed Cubism 5.3 Core URL. It currently hashes identically to the official `core/` Latest URL, but the fixed path prevents future drift.
- npm successfully installs CubismWebFramework from pinned commit `198a3769c26ca3d7b600e932590433badd392edd`, so the Framework source need not be copied into the Flutter package.
- Official download metadata uses `https://cubism.live2d.com/sdk-web/core/` for Latest and `core/06/` for Cubism 5.3; the previously tested `cubismcore/` path is explicitly legacy.
- Public sibling URLs for Core `.d.ts`, `.ts`, and unminified `.js` return 404. esbuild can still bundle Framework/sample TypeScript because it strips types without type-checking Core namespace declarations.
- Current Flutter Web plugin templates use `package:web`, `dart:ui_web`, and a `registerWith(Registrar)` implementation; adopting that path requires a modern Dart SDK constraint.
- The public controller contract can remain unchanged by adding only internal platform lifecycle methods (`initializeView` / `disposeView`) with no-op defaults for native platforms.
- Native asset extraction can be moved behind a conditional import, removing `dart:io` from the shared library while retaining the current Android/iOS behavior.
- Web app assets can be addressed as `assets/<manifest-key>` and normalized against `document.baseURI` inside the JavaScript runtime.
- The pinned Framework source plus WebGL shaders is 72 files / about 732 KB; vendoring this exact revision is acceptable relative to the repository's existing duplicated native Framework sources and makes builds offline/reproducible.
- Framework and Samples use the Live2D Open Software License, while Core uses the Proprietary Software License. Business users above the license threshold may require a Cubism SDK Release License.
- The Framework repository's package metadata has no `name`, causing direct npm installation to use `node_modules/undefined`; vendoring the pinned source is clearer than relying on that package layout.
- The generated example Web app is served successfully by procm at `http://127.0.0.1:8765`.
- Microsoft Edge 148 is available via EdgeCore; Playwright is not preinstalled, so browser QA will use a temporary `playwright-core` installation without changing project dependencies.
- The initial blank browser screenshot came from `flutter run -d web-server` debug mode waiting for its debug-service connection; the persistent server should run in release mode for deterministic browser QA.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Evaluate a WKWebView-backed macOS platform view before adding native Cubism binaries | The required macOS Core slice is absent, while the bundled Web renderer already implements the full controller surface |
| Use a custom WKWebView URL scheme for model and plugin resources | It gives fetch/image requests controlled local-file access without expanding `file://` read access to the filesystem root |
| Use the official Cubism Web Framework/Core where packaging permits | Best compatibility with `.model3.json` and existing Cubism behavior |
| Build Web around an HTML canvas hosted by `HtmlElementView` | Cubism Web renders through WebGL and needs a real browser canvas |
| Resolve Flutter assets to browser asset URLs instead of extracting files | Browsers do not expose application assets as writable filesystem directories |
| Use a per-view browser runtime registry | Matches the existing controller's view-id command model and supports multiple views |
| Extract model/runtime responsibilities from the official sample rather than copying the Demo application | Keeps the shipped bridge small and avoids sample UI/global singleton assumptions |
| Build one TypeScript runtime per canvas and expose a small global JavaScript bridge | Maps directly to Flutter view IDs while keeping rendering code outside Dart |
| Use Flutter's D3D11 GPU surface texture on Windows | Preserves transparent compositing and animation without an expensive CPU readback path |
| Default to official hosted Core path `core/06/live2dcubismcore.min.js` | Avoids silently redistributing a proprietary artifact, pins Cubism 5.3 compatibility, and documents the network requirement |
| Bundle Framework and adapted sample code at a pinned `5-r.5` revision | Makes consumer builds deterministic and avoids runtime Framework CDN dependencies |
| Use current Flutter Web template APIs (`package:web`, `dart:ui_web`) | Avoids deprecated `dart:html`/`dart:js_util` and matches Flutter 3.44 |
| Keep native MethodChannel methods unchanged and add lifecycle hooks with default no-op implementations | Limits regression risk for Android/iOS and existing test mocks |
| Move only filesystem writing behind a conditional import | Removes the Web runtime hazard without rewriting controller/state classes |
| Vendor the pinned Framework source and licenses for the Web build tool | Avoids the upstream package's missing npm name and preserves reproducible builds |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Current Web build succeeds despite being unusable | Verify runtime path and rendered pixels, not build status alone |
| macOS/Linux cannot be built on the current Windows host | Out of scope for this Web-focused implementation |
| `Samples/TypeScript/Demo/README.md` does not exist | Use `CubismWebSamples/README.md`; the Demo files are documented from the repository root |
| Hosted Core type/unminified URLs return 404 | Use the official minified runtime and esbuild transpilation; do not require Core declarations at bundle time |
| Adding lifecycle methods directly to `FlutterLive2dPlatform` breaks classes that use `implements` | Keep lifecycle in a separate internal interface implemented only by the Web backend |
| Passing `HTMLCanvasElement` through `Object?` causes an invalid JS interop runtime check lint | Store canvases in a Web-only registry keyed by Flutter view ID |

## Resources
- https://www.live2d.com/en/sdk/download/native/
- https://github.com/Live2D/CubismNativeSamples/releases/tag/5-r.5
- https://docs.live2d.com/en/cubism-sdk-manual/platform/
- https://www.live2d.com/en/sdk/download/web/
- https://github.com/Live2D/CubismWebFramework
- https://github.com/Live2D/CubismWebSamples
- `C:/Users/Administrator/AppData/Local/Temp/CubismWebSamples-5-r.5/Samples/TypeScript/Demo/src/lappmodel.ts`
- `C:/Users/Administrator/AppData/Local/Temp/CubismWebSamples-5-r.5/Samples/TypeScript/Demo/src/lappsubdelegate.ts`

## Visual/Browser Findings
- Release-mode Edge screenshot shows two independently rendered Mao models over the Flutter gradient background at 1440x1000.
- Both plugin canvases report `loaded=true`, `frames=1`, and 720x651 backing dimensions; there are no console, page, or failed-network errors.
- Direct `WebGL.readPixels` on the default framebuffer returns transparent pixels after browser compositing because drawing-buffer preservation is disabled. The screenshot visibly contains the models, so QA should use screenshot pixel statistics instead of enabling `preserveDrawingBuffer` in production.
- Browser runtime calls for motion, expression, parameter, motion speed, and pause/resume all completed without console/page/network errors.
- Screenshot analysis found 21,872 and 21,504 bright model pixels in the left/right render regions, with over 10,000 near-white pixels per model; both regions materially differ from the dark gradient background.
