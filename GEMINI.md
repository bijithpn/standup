# Project Overview

BreakMate is a macOS/Windows menu bar application optimized for performance and fluid desktop interactions.

## Architecture & Performance Standards

### Flutter Engine Reuse (macOS)
- **Engine Group:** The app uses `FlutterEngineGroup` (defined in `AppDelegate.swift`) for spawning overlays and the desktop companion. 
- **Standard:** Never instantiate a raw `FlutterEngine` for secondary windows. Always use `engineGroup.makeEngine` to ensure 10x faster startup and shared memory benefits.

### Asset Management
- **Pre-caching:** All companion animations and tray icons MUST be pre-cached during initial startup or breed changes.
- **Optimization:** Image frame extraction for the system tray uses a **Bounding Box Cache** to avoid redundant pixel scanning.
- **Rules:** Avoid using `BackdropFilter` for full-screen animations. Prefer gradient-based simulations or lower-resolution blurred background buffers for better GPU performance on high-res displays.

### State Synchronization
- **Event Bus:** The "Main" engine and "Companion" engine are synchronized via `CompanionStateChangedEvent`.
- **Constraint:** Logical state (mood, timer status) is managed by the Main engine. Rendering-specific triggers are passed to the Companion engine to ensure consistency.

## Folder Structure

Folder PATH listing for volume Windows
Volume serial number is 242B-F71E
C:.
| .flutter-plugins-dependencies
| .gitignore
| .metadata
| analysis*options.yaml
| devtools_options.yaml
| LICENSE
| pubspec.lock
| pubspec.yaml
| README.md
| structure.txt
|  
+---.dart_tool
| | package_config.json
| | package_graph.json
| | version
| |  
| +---extension_discovery
| | vs_code.json
| |  
| +---flutter_build
| | | dart_plugin_registrant.dart
| | |  
| | +---2fa53976e3a796f06785b39014b2fa2a
| | | .filecache
| | | aot_elf_release.stamp
| | | app.dill
| | | app.so
| | | dart_build.d
| | | dart_build.stamp
| | | dart_build_result.json
| | | flutter_assets.d
| | | gen_dart_plugin_registrant.stamp
| | | gen_localizations.stamp
| | | install_code_assets.d
| | | install_code_assets.stamp
| | | kernel_snapshot_program.d
| | | kernel_snapshot_program.stamp
| | | native_assets.json
| | | outputs.json
| | | release_bundle_windows-x64_assets.stamp
| | | unpack_windows.stamp
| | | windows_aot_bundle.stamp
| | | windows_engine_sources.d
| | |  
| | +---8efc81352b3a61a642f3335701912b94
| | | .filecache
| | | app.dill
| | | dart_build.d
| | | dart_build.stamp
| | | dart_build_result.json
| | | debug_bundle_windows-x64_assets.stamp
| | | flutter_assets.d
| | | gen_dart_plugin_registrant.stamp
| | | gen_localizations.stamp
| | | install_code_assets.d
| | | install_code_assets.stamp
| | | kernel_snapshot_program.d
| | | kernel_snapshot_program.stamp
| | | native_assets.json
| | | outputs.json
| | | unpack_windows.stamp
| | | windows_engine_sources.d
| | |  
| | \---c52d2c3dde1f5f976f9962603b840dc8
| | .filecache
| | app.dill
| | dart_build.d
| | dart_build.stamp
| | dart_build_result.json
| | debug_bundle_windows-x64_assets.stamp
| | flutter_assets.d
| | gen_dart_plugin_registrant.stamp
| | gen_localizations.stamp
| | install_code_assets.d
| | install_code_assets.stamp
| | kernel_snapshot_program.d
| | kernel_snapshot_program.stamp
| | native_assets.json
| | outputs.json
| | unpack_windows.stamp
| | windows_engine_sources.d
| |  
| \---hooks_runner
| +---objective_c
| | +---337ce265dc
| | | | .lock
| | | | dependencies.dependencies_hash_file.json
| | | | hook.dependencies_hash_file.json
| | | | hook.dill
| | | | hook.dill.d
| | | | input.json
| | | | output.json
| | | | stderr.txt
| | | | stdout.txt
| | | |  
| | | \---out
| | +---63dc6ceb2b
| | | | .lock
| | | | dependencies.dependencies_hash_file.json
| | | | hook.dependencies_hash_file.json
| | | | hook.dill
| | | | hook.dill.d
| | | | input.json
| | | | output.json
| | | | stderr.txt
| | | | stdout.txt
| | | |  
| | | \---out
| | \---fa7372492d
| | | .lock
| | | dependencies.dependencies_hash_file.json
| | | hook.dependencies_hash_file.json
| | | hook.dill
| | | hook.dill.d
| | | input.json
| | | output.json
| | | stderr.txt
| | | stdout.txt
| | |  
| | \---out
| \---shared
| \---objective_c
| | .lock
| |  
| \---build
| +---337ce265dc
| +---63dc6ceb2b
| \---fa7372492d
+---.vscode
| launch.json
|  
+---assets
| +---animations
| | +---cats
| | | +---black_cat
| | | | sprite_sheet.png
| | | |  
| | | +---cat_1
| | | | idle.png
| | | | itch.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---cat_2
| | | | idle.png
| | | | itch.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---cat_3
| | | | idle.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---cat_4
| | | | idle.png
| | | | itch.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---cat_5
| | | | idle.png
| | | | itch.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---cat_50
| | | | cat_sheet.png
| | | |  
| | | +---cat_6
| | | | idle.png
| | | | itch.png
| | | | laying.png
| | | | lick_1.png
| | | | lick_2.png
| | | | meow.png
| | | | run.png
| | | | sitting.png
| | | | sleep_1.png
| | | | sleep_2.png
| | | | stretching.png
| | | | walk.png
| | | |  
| | | +---grey_cat
| | | | sprite_sheet.png
| | | |  
| | | +---large_cat
| | | | fall.png
| | | | idle.png
| | | | jump.png
| | | | run.png
| | | |  
| | | +---orange_cat
| | | | sprite_sheet.png
| | | |  
| | | \---pixel_cat
| | | attack.png
| | | hurt.png
| | | idle.png
| | | jump.png
| | | run.png
| | | running jump.png
| | | walk.png
| | |  
| | +---dogs
| | | | collie.png
| | | | corgi.png
| | | | dalmatian.png
| | | | husky.png
| | | | labrador.png
| | | |  
| | | \---goldie
| | | goldie_v02.png
| | | realistic_goldie.png
| | |  
| | \---source
| | +---black_cat
| | | cat_1_9_16x16.aseprite
| | |  
| | +---grey_cat
| | | cat_1_16x16.aseprite
| | |  
| | +---orange_cat
| | | cat_1_6_16x16.aseprite
| | |  
| | +---references
| | | Frame_indexes.png
| | | palette.gpl
| | |  
| | \---with_text
| | cat_16x16_with_text.aseprite
| | cat_16x16_with_text.png
| |  
| +---fonts
| | \---Satoshi
| | \---Fonts
| | Satoshi-Regular.ttf
| |  
| +---icons
| | | tray_icon.png
| | |  
| | \---cat
| | cat_alert.png
| | cat_blink.png
| | cat_idle.png
| | cat_sleeping.png
| | cat_stretch.png
| |  
| \---slideshow
| slide_1.png
| slide_2.png
| slide_3.png
| slide_4.png
| slide_5.png
|  
+---build
| | .last_build_id
| | e526d636a6238c5a01b25d33d78dd941.cache.dill.track.dill
| |  
| +---71d9c423d91612f174110d3009b997cd
| | gen_dart_plugin_registrant.stamp
| | gen_localizations.stamp
| | \_composite.stamp
| |  
| +---flutter_assets
| | | AssetManifest.bin
| | | FontManifest.json
| | | kernel_blob.bin
| | | NativeAssetsManifest.json
| | | NOTICES.Z
| | |  
| | +---assets
| | | +---animations
| | | | +---cats
| | | | | +---black_cat
| | | | | | sprite_sheet.png
| | | | | |  
| | | | | +---cat_1
| | | | | | idle.png
| | | | | | itch.png
| | | | | | laying.png
| | | | | | lick_1.png
| | | | | | lick_2.png
| | | | | | meow.png
| | | | | | run.png
| | | | | | sitting.png
| | | | | | sleep_1.png
| | | | | | sleep_2.png
| | | | | | stretching.png
| | | | | | walk.png
| | | | | |  
| | | | | +---cat_2
| | | | | | idle.png
| | | | | | itch.png
| | | | | | laying.png
| | | | | | lick_1.png
| | | | | | lick_2.png
| | | | | | meow.png
| | | | | | run.png
| | | | | | sitting.png
| | | | | | sleep_1.png
| | | | | | sleep_2.png
| | | | | | stretching.png
| | | | | | walk.png
| | | | | |  
| | | | | +---cat_50
| | | | | | cat_sheet.png
| | | | | |  
| | | | | +---grey_cat
| | | | | | sprite_sheet.png
| | | | | |  
| | | | | +---large_cat
| | | | | | fall.png
| | | | | | idle.png
| | | | | | jump.png
| | | | | | run.png
| | | | | |  
| | | | | +---orange_cat
| | | | | | sprite_sheet.png
| | | | | |  
| | | | | \---pixel_cat
| | | | | attack.png
| | | | | hurt.png
| | | | | idle.png
| | | | | jump.png
| | | | | run.png
| | | | | running%20jump.png
| | | | | walk.png
| | | | |  
| | | | \---dogs
| | | | collie.png
| | | | corgi.png
| | | | dalmatian.png
| | | | husky.png
| | | | labrador.png
| | | |  
| | | +---fonts
| | | | \---Satoshi
| | | | \---Fonts
| | | | Satoshi-Regular.ttf
| | | |  
| | | +---icons
| | | | | tray_icon.png
| | | | |  
| | | | \---cat
| | | | cat_alert.png
| | | | cat_blink.png
| | | | cat_idle.png
| | | | cat_sleeping.png
| | | | cat_stretch.png
| | | |  
| | | \---slideshow
| | | slide_1.png
| | | slide_2.png
| | | slide_3.png
| | | slide_4.png
| | | slide_5.png
| | |  
| | +---fonts
| | | MaterialIcons-Regular.otf
| | |  
| | +---packages
| | | \---cupertino_icons
| | | \---assets
| | | CupertinoIcons.ttf
| | |  
| | \---shaders
| | ink_sparkle.frag
| | stretch_effect.frag
| |  
| +---native_assets
| | \---windows
| \---windows
| \---x64
| | ALL_BUILD.vcxproj
| | ALL_BUILD.vcxproj.filters
| | CMakeCache.txt
| | cmake_install.cmake
| | INSTALL.vcxproj
| | INSTALL.vcxproj.filters
| | install_manifest.txt
| | standup.slnx
| | ZERO_CHECK.vcxproj
| | ZERO_CHECK.vcxproj.filters
| |  
| +---ALL_BUILD.dir
| | +---Debug
| | +---Profile
| | \---Release
| +---CMakeFiles
| | | cmake.check_cache
| | | CMakeConfigureLog.yaml
| | | generate.stamp
| | | generate.stamp.depend
| | | generate.stamp.list
| | | InstallScripts.json
| | | TargetDirectories.txt
| | |  
| | +---38b551de06ec78e356e5fcd54c6fa508
| | | INSTALL_force.rule
| | |  
| | +---4.2.3-msvc3
| | | | CMakeCCompiler.cmake
| | | | CMakeCXXCompiler.cmake
| | | | CMakeDetermineCompilerABI_C.bin
| | | | CMakeDetermineCompilerABI_CXX.bin
| | | | CMakeRCCompiler.cmake
| | | | CMakeSystem.cmake
| | | | VCTargetsPath.txt
| | | | VCTargetsPath.vcxproj
| | | |  
| | | +---CompilerIdC
| | | | | CMakeCCompilerId.c
| | | | | CompilerIdC.exe
| | | | | CompilerIdC.vcxproj
| | | | |  
| | | | +---Debug
| | | | | | CMakeCCompilerId.obj
| | | | | | CompilerIdC.exe.recipe
| | | | | |  
| | | | | \---CompilerIdC.tlog
| | | | | CL.command.1.tlog
| | | | | Cl.items.tlog
| | | | | CL.read.1.tlog
| | | | | CL.write.1.tlog
| | | | | CompilerIdC.lastbuildstate
| | | | | link.command.1.tlog
| | | | | link.read.1.tlog
| | | | | link.secondary.1.tlog
| | | | | link.write.1.tlog
| | | | |  
| | | | \---tmp
| | | +---CompilerIdCXX
| | | | | CMakeCXXCompilerId.cpp
| | | | | CompilerIdCXX.exe
| | | | | CompilerIdCXX.vcxproj
| | | | |  
| | | | +---Debug
| | | | | | CMakeCXXCompilerId.obj
| | | | | | CompilerIdCXX.exe.recipe
| | | | | |  
| | | | | \---CompilerIdCXX.tlog
| | | | | CL.command.1.tlog
| | | | | Cl.items.tlog
| | | | | CL.read.1.tlog
| | | | | CL.write.1.tlog
| | | | | CompilerIdCXX.lastbuildstate
| | | | | link.command.1.tlog
| | | | | link.read.1.tlog
| | | | | link.secondary.1.tlog
| | | | | link.write.1.tlog
| | | | |  
| | | | \---tmp
| | | +---VCTargetsPath
| | | | \---x64
| | | | \---Debug
| | | | | VCTargetsPath.recipe
| | | | |  
| | | | \---VCTargetsPath.tlog
| | | | VCTargetsPath.lastbuildstate
| | | |  
| | | \---x64
| | | \---Debug
| | +---52172aa118c46ceb8c0ef131d7e691d8
| | | INSTALL_force.rule
| | |  
| | +---58a60fb5ac433a0919161cefbb26efa2
| | | INSTALL_force.rule
| | |  
| | +---787532afaf955171433192d88ddad63d
| | | INSTALL_force.rule
| | |  
| | +---871a48650b96a8abc8d098199a5ca4b6
| | | INSTALL_force.rule
| | |  
| | +---9270e774a49d56075e5af8b708d8c264
| | | generate.stamp.rule
| | | INSTALL_force.rule
| | |  
| | +---9b1576c15db2b998c721ed3f0c879b20
| | | INSTALL_force.rule
| | |  
| | +---bfa5754d7fb57428849d71a00dc16334
| | | INSTALL_force.rule
| | |  
| | +---d99684726fe5f3c77adcc0279aad56f2
| | | flutter_windows.dll.rule
| | |  
| | +---e038e696f778d003acb482d4bc3b183a
| | | INSTALL_force.rule
| | |  
| | +---e1f8b226dff345e9795afb8a6cb32208
| | | flutter_assemble.rule
| | | INSTALL_force.rule
| | |  
| | \---pkgRedirects
| +---flutter
| | | cmake_install.cmake
| | | flutter_assemble.vcxproj
| | | flutter_assemble.vcxproj.filters
| | | flutter_wrapper_app.vcxproj
| | | flutter_wrapper_app.vcxproj.filters
| | | flutter_wrapper_plugin.vcxproj
| | | flutter_wrapper_plugin.vcxproj.filters
| | | INSTALL.vcxproj
| | | INSTALL.vcxproj.filters
| | |  
| | +---CMakeFiles
| | | generate.stamp
| | | generate.stamp.depend
| | |  
| | +---Debug
| | | flutter_wrapper_app.lib
| | | flutter_wrapper_app.pdb
| | | flutter_wrapper_plugin.lib
| | | flutter_wrapper_plugin.pdb
| | |  
| | +---flutter_assemble.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---flutter_wrapper_app.dir
| | | +---Debug
| | | | | core_implementations.obj
| | | | | flutter_engine.obj
| | | | | flutter_view_controller.obj
| | | | | flutter_wrapper_app.lib.recipe
| | | | | standard_codec.obj
| | | | |  
| | | | \---flutter*.0561195C.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | flutter*wrapper_app.lastbuildstate
| | | | Lib-link.read.1.tlog
| | | | Lib-link.write.1.tlog
| | | | Lib.command.1.tlog
| | | |  
| | | +---Profile
| | | \---Release
| | | | core_implementations.obj
| | | | flutter_engine.obj
| | | | flutter_view_controller.obj
| | | | flutter_wrapper_app.lib.recipe
| | | | standard_codec.obj
| | | |  
| | | \---flutter*.0561195C.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | flutter*wrapper_app.lastbuildstate
| | | Lib-link.read.1.tlog
| | | Lib-link.write.1.tlog
| | | Lib.command.1.tlog
| | |  
| | +---flutter_wrapper_plugin.dir
| | | +---Debug
| | | | | core_implementations.obj
| | | | | flutter_wrapper_plugin.lib.recipe
| | | | | plugin_registrar.obj
| | | | | standard_codec.obj
| | | | |  
| | | | \---flutter*.FD593DC0.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | flutter*wrapper_plugin.lastbuildstate
| | | | Lib-link.read.1.tlog
| | | | Lib-link.write.1.tlog
| | | | Lib.command.1.tlog
| | | |  
| | | +---Profile
| | | \---Release
| | | | core_implementations.obj
| | | | flutter_wrapper_plugin.lib.recipe
| | | | plugin_registrar.obj
| | | | standard_codec.obj
| | | |  
| | | \---flutter*.FD593DC0.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | flutter*wrapper_plugin.lastbuildstate
| | | Lib-link.read.1.tlog
| | | Lib-link.write.1.tlog
| | | Lib.command.1.tlog
| | |  
| | +---INSTALL.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---Release
| | | flutter_wrapper_app.lib
| | | flutter_wrapper_plugin.lib
| | |  
| | \---x64
| | +---Debug
| | | \---flutter_assemble
| | | | flutter_assemble.recipe
| | | |  
| | | \---flutter_assemble.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | flutter_assemble.lastbuildstate
| | |  
| | \---Release
| | \---flutter_assemble
| | | flutter_assemble.recipe
| | |  
| | \---flutter_assemble.tlog
| | CustomBuild.command.1.tlog
| | CustomBuild.read.1.tlog
| | CustomBuild.write.1.tlog
| | flutter_assemble.lastbuildstate
| |  
| +---INSTALL.dir
| | +---Debug
| | +---Profile
| | \---Release
| +---packages
| | \---Microsoft.Windows.ImplementationLibrary
| | | .signature.p7s
| | | LICENSE
| | | Microsoft.Windows.ImplementationLibrary.nupkg
| | | ThirdPartyNotices.txt
| | |  
| | +---build
| | | \---native
| | | Microsoft.Windows.ImplementationLibrary.targets
| | |  
| | \---include
| | \---wil
| | com.h
| | common.h
| | cppwinrt.h
| | cppwinrt_wrl.h
| | filesystem.h
| | nt_result_macros.h
| | registry.h
| | resource.h
| | result.h
| | result_macros.h
| | result_originate.h
| | rpc_helpers.h
| | safecast.h
| | stl.h
| | token_helpers.h
| | Tracelogging.h
| | traceloggingconfig.h
| | win32_helpers.h
| | winrt.h
| | wistd_config.h
| | wistd_functional.h
| | wistd_memory.h
| | wistd_type_traits.h
| | wrl.h
| |  
| +---plugins
| | +---audioplayers_windows
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | audioplayers_windows.slnx
| | | | audioplayers_windows_plugin.vcxproj
| | | | audioplayers_windows_plugin.vcxproj.filters
| | | | cmake_install.cmake
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---audioplayers_windows_plugin.dir
| | | | +---Debug
| | | | | | audioplayers_windows_plugin.dll.recipe
| | | | | | audioplayers_windows_plugin.ilk
| | | | | | audioplayers_windows_plugin.obj
| | | | | | audio_player.obj
| | | | | | MediaEngineExtension.obj
| | | | | | MediaEngineWrapper.obj
| | | | | | vc145.pdb
| | | | | |  
| | | | | \---audiopla.E1B43044.tlog
| | | | | audioplayers_windows_plugin.lastbuildstate
| | | | | CL.command.1.tlog
| | | | | Cl.items.tlog
| | | | | CL.read.1.tlog
| | | | | CL.write.1.tlog
| | | | | CustomBuild.command.1.tlog
| | | | | CustomBuild.read.1.tlog
| | | | | CustomBuild.write.1.tlog
| | | | | link.command.1.tlog
| | | | | link.read.1.tlog
| | | | | link.secondary.1.tlog
| | | | | link.write.1.tlog
| | | | |  
| | | | +---Profile
| | | | \---Release
| | | | | audioplayers_windows_plugin.dll.recipe
| | | | | audioplayers_windows_plugin.obj
| | | | | audio_player.obj
| | | | | MediaEngineExtension.obj
| | | | | MediaEngineWrapper.obj
| | | | |  
| | | | \---audiopla.E1B43044.tlog
| | | | audioplayers_windows_plugin.lastbuildstate
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | link.command.1.tlog
| | | | link.read.1.tlog
| | | | link.secondary.1.tlog
| | | | link.write.1.tlog
| | | |  
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---Debug
| | | | audioplayers_windows_plugin.dll
| | | | audioplayers_windows_plugin.exp
| | | | audioplayers_windows_plugin.lib
| | | | audioplayers_windows_plugin.pdb
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | \---Release
| | | audioplayers_windows_plugin.dll
| | | audioplayers_windows_plugin.exp
| | | audioplayers_windows_plugin.lib
| | |  
| | +---flutter_acrylic
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | cmake_install.cmake
| | | | flutter_acrylic.slnx
| | | | flutter_acrylic_plugin.vcxproj
| | | | flutter_acrylic_plugin.vcxproj.filters
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---Debug
| | | | flutter_acrylic_plugin.dll
| | | | flutter_acrylic_plugin.exp
| | | | flutter_acrylic_plugin.lib
| | | | flutter_acrylic_plugin.pdb
| | | |  
| | | +---flutter_acrylic_plugin.dir
| | | | +---Debug
| | | | | | flutter_acrylic_plugin.dll.recipe
| | | | | | flutter_acrylic_plugin.ilk
| | | | | | flutter_acrylic_plugin.obj
| | | | | | vc145.pdb
| | | | | |  
| | | | | \---flutter*.C74AE865.tlog
| | | | | CL.command.1.tlog
| | | | | Cl.items.tlog
| | | | | CL.read.1.tlog
| | | | | CL.write.1.tlog
| | | | | CustomBuild.command.1.tlog
| | | | | CustomBuild.read.1.tlog
| | | | | CustomBuild.write.1.tlog
| | | | | flutter*acrylic_plugin.lastbuildstate
| | | | | link.command.1.tlog
| | | | | link.read.1.tlog
| | | | | link.secondary.1.tlog
| | | | | link.write.1.tlog
| | | | |  
| | | | +---Profile
| | | | \---Release
| | | | | flutter_acrylic_plugin.dll.recipe
| | | | | flutter_acrylic_plugin.obj
| | | | |  
| | | | \---flutter*.C74AE865.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | flutter_acrylic_plugin.lastbuildstate
| | | | link.command.1.tlog
| | | | link.read.1.tlog
| | | | link.secondary.1.tlog
| | | | link.write.1.tlog
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | \---Release
| | | flutter_acrylic_plugin.dll
| | | flutter_acrylic_plugin.exp
| | | flutter_acrylic_plugin.lib
| | |  
| | +---jni
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | cmake_install.cmake
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | | jni.slnx
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | \---shared
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | cmake_install.cmake
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | | jni.vcxproj
| | | | jni.vcxproj.filters
| | | | jni_library.slnx
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---Debug
| | | | dartjni.dll
| | | | dartjni.exp
| | | | dartjni.lib
| | | | dartjni.pdb
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---jni.dir
| | | | +---Debug
| | | | | | dartjni.dll.recipe
| | | | | | dartjni.ilk
| | | | | | dartjni.obj
| | | | | | dart_api_dl.obj
| | | | | | global_jni_env.obj
| | | | | | vc145.pdb
| | | | | |  
| | | | | \---jni.tlog
| | | | | CL.command.1.tlog
| | | | | Cl.items.tlog
| | | | | CL.read.1.tlog
| | | | | CL.write.1.tlog
| | | | | CustomBuild.command.1.tlog
| | | | | CustomBuild.read.1.tlog
| | | | | CustomBuild.write.1.tlog
| | | | | jni.lastbuildstate
| | | | | link.command.1.tlog
| | | | | link.read.1.tlog
| | | | | link.secondary.1.tlog
| | | | | link.write.1.tlog
| | | | |  
| | | | +---Profile
| | | | \---Release
| | | | | dartjni.dll.recipe
| | | | | dartjni.obj
| | | | | dart_api_dl.obj
| | | | | global_jni_env.obj
| | | | |  
| | | | \---jni.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | jni.lastbuildstate
| | | | link.command.1.tlog
| | | | link.read.1.tlog
| | | | link.secondary.1.tlog
| | | | link.write.1.tlog
| | | |  
| | | \---Release
| | | dartjni.dll
| | | dartjni.exp
| | | dartjni.lib
| | |  
| | +---screen_retriever_windows
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | cmake_install.cmake
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | | screen_retriever_windows.slnx
| | | | screen_retriever_windows_plugin.vcxproj
| | | | screen_retriever_windows_plugin.vcxproj.filters
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---Debug
| | | | screen_retriever_windows_plugin.dll
| | | | screen_retriever_windows_plugin.exp
| | | | screen_retriever_windows_plugin.lib
| | | | screen_retriever_windows_plugin.pdb
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---Release
| | | | screen_retriever_windows_plugin.dll
| | | | screen_retriever_windows_plugin.exp
| | | | screen_retriever_windows_plugin.lib
| | | |  
| | | \---screen_retriever_windows_plugin.dir
| | | +---Debug
| | | | | screen_retriever_windows_plugin.dll.recipe
| | | | | screen_retriever_windows_plugin.ilk
| | | | | screen_retriever_windows_plugin.obj
| | | | | screen_retriever_windows_plugin_c_api.obj
| | | | | vc145.pdb
| | | | |  
| | | | \---screen_r.C71C00F9.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | link.command.1.tlog
| | | | link.read.1.tlog
| | | | link.secondary.1.tlog
| | | | link.write.1.tlog
| | | | screen_retriever_windows_plugin.lastbuildstate
| | | |  
| | | +---Profile
| | | \---Release
| | | | screen_retriever_windows_plugin.dll.recipe
| | | | screen_retriever_windows_plugin.obj
| | | | screen_retriever_windows_plugin_c_api.obj
| | | |  
| | | \---screen_r.C71C00F9.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | link.command.1.tlog
| | | link.read.1.tlog
| | | link.secondary.1.tlog
| | | link.write.1.tlog
| | | screen_retriever_windows_plugin.lastbuildstate
| | |  
| | +---tray_manager
| | | | ALL_BUILD.vcxproj
| | | | ALL_BUILD.vcxproj.filters
| | | | cmake_install.cmake
| | | | INSTALL.vcxproj
| | | | INSTALL.vcxproj.filters
| | | | tray_manager.slnx
| | | | tray_manager_plugin.vcxproj
| | | | tray_manager_plugin.vcxproj.filters
| | | |  
| | | +---ALL_BUILD.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---CMakeFiles
| | | | generate.stamp
| | | | generate.stamp.depend
| | | |  
| | | +---Debug
| | | | tray_manager_plugin.dll
| | | | tray_manager_plugin.exp
| | | | tray_manager_plugin.lib
| | | | tray_manager_plugin.pdb
| | | |  
| | | +---INSTALL.dir
| | | | +---Debug
| | | | +---Profile
| | | | \---Release
| | | +---Release
| | | | tray_manager_plugin.dll
| | | | tray_manager_plugin.exp
| | | | tray_manager_plugin.lib
| | | |  
| | | \---tray_manager_plugin.dir
| | | +---Debug
| | | | | tray_manager_plugin.dll.recipe
| | | | | tray_manager_plugin.ilk
| | | | | tray_manager_plugin.obj
| | | | | vc145.pdb
| | | | |  
| | | | \---tray_man.75604553.tlog
| | | | CL.command.1.tlog
| | | | Cl.items.tlog
| | | | CL.read.1.tlog
| | | | CL.write.1.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | link.command.1.tlog
| | | | link.read.1.tlog
| | | | link.secondary.1.tlog
| | | | link.write.1.tlog
| | | | tray_manager_plugin.lastbuildstate
| | | |  
| | | +---Profile
| | | \---Release
| | | | tray_manager_plugin.dll.recipe
| | | | tray_manager_plugin.obj
| | | |  
| | | \---tray_man.75604553.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | link.command.1.tlog
| | | link.read.1.tlog
| | | link.secondary.1.tlog
| | | link.write.1.tlog
| | | tray_manager_plugin.lastbuildstate
| | |  
| | \---window_manager
| | | ALL_BUILD.vcxproj
| | | ALL_BUILD.vcxproj.filters
| | | cmake_install.cmake
| | | INSTALL.vcxproj
| | | INSTALL.vcxproj.filters
| | | window_manager.slnx
| | | window_manager_plugin.vcxproj
| | | window_manager_plugin.vcxproj.filters
| | |  
| | +---ALL_BUILD.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---CMakeFiles
| | | generate.stamp
| | | generate.stamp.depend
| | |  
| | +---Debug
| | | window_manager_plugin.dll
| | | window_manager_plugin.exp
| | | window_manager_plugin.lib
| | | window_manager_plugin.pdb
| | |  
| | +---INSTALL.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---Release
| | | window_manager_plugin.dll
| | | window_manager_plugin.exp
| | | window_manager_plugin.lib
| | |  
| | \---window_manager_plugin.dir
| | +---Debug
| | | | vc145.pdb
| | | | window_manager.obj
| | | | window_manager_plugin.dll.recipe
| | | | window_manager_plugin.ilk
| | | | window_manager_plugin.obj
| | | |  
| | | \---window_m.5A974CED.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | link.command.1.tlog
| | | link.read.1.tlog
| | | link.secondary.1.tlog
| | | link.write.1.tlog
| | | window_manager_plugin.lastbuildstate
| | |  
| | +---Profile
| | \---Release
| | | window_manager.obj
| | | window_manager_plugin.dll.recipe
| | | window_manager_plugin.obj
| | |  
| | \---window_m.5A974CED.tlog
| | CL.command.1.tlog
| | Cl.items.tlog
| | CL.read.1.tlog
| | CL.write.1.tlog
| | CustomBuild.command.1.tlog
| | CustomBuild.read.1.tlog
| | CustomBuild.write.1.tlog
| | link.command.1.tlog
| | link.read.1.tlog
| | link.secondary.1.tlog
| | link.write.1.tlog
| | window_manager_plugin.lastbuildstate
| |  
| +---runner
| | | ALL_BUILD.vcxproj
| | | ALL_BUILD.vcxproj.filters
| | | cmake_install.cmake
| | | INSTALL.vcxproj
| | | INSTALL.vcxproj.filters
| | | runner.slnx
| | | standup.vcxproj
| | | standup.vcxproj.filters
| | |  
| | +---ALL_BUILD.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---CMakeFiles
| | | generate.stamp
| | | generate.stamp.depend
| | |  
| | +---Debug
| | | | audioplayers_windows_plugin.dll
| | | | dartjni.dll
| | | | flutter_acrylic_plugin.dll
| | | | flutter_windows.dll
| | | | screen_retriever_windows_plugin.dll
| | | | standup.exe
| | | | standup.pdb
| | | | tray_manager_plugin.dll
| | | | window_manager_plugin.dll
| | | |  
| | | \---data
| | | | icudtl.dat
| | | |  
| | | \---flutter_assets
| | | | AssetManifest.bin
| | | | FontManifest.json
| | | | kernel_blob.bin
| | | | NativeAssetsManifest.json
| | | | NOTICES.Z
| | | |  
| | | +---assets
| | | | +---animations
| | | | | +---cats
| | | | | | +---black_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | +---cat_1
| | | | | | | idle.png
| | | | | | | itch.png
| | | | | | | laying.png
| | | | | | | lick_1.png
| | | | | | | lick_2.png
| | | | | | | meow.png
| | | | | | | run.png
| | | | | | | sitting.png
| | | | | | | sleep_1.png
| | | | | | | sleep_2.png
| | | | | | | stretching.png
| | | | | | | walk.png
| | | | | | |  
| | | | | | +---cat_2
| | | | | | | idle.png
| | | | | | | itch.png
| | | | | | | laying.png
| | | | | | | lick_1.png
| | | | | | | lick_2.png
| | | | | | | meow.png
| | | | | | | run.png
| | | | | | | sitting.png
| | | | | | | sleep_1.png
| | | | | | | sleep_2.png
| | | | | | | stretching.png
| | | | | | | walk.png
| | | | | | |  
| | | | | | +---cat_50
| | | | | | | cat_sheet.png
| | | | | | |  
| | | | | | +---grey_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | +---large_cat
| | | | | | | fall.png
| | | | | | | idle.png
| | | | | | | jump.png
| | | | | | | run.png
| | | | | | |  
| | | | | | +---orange_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | \---pixel_cat
| | | | | | attack.png
| | | | | | hurt.png
| | | | | | idle.png
| | | | | | jump.png
| | | | | | run.png
| | | | | | running%20jump.png
| | | | | | walk.png
| | | | | |  
| | | | | \---dogs
| | | | | collie.png
| | | | | corgi.png
| | | | | dalmatian.png
| | | | | husky.png
| | | | | labrador.png
| | | | |  
| | | | +---fonts
| | | | | \---Satoshi
| | | | | \---Fonts
| | | | | Satoshi-Regular.ttf
| | | | |  
| | | | +---icons
| | | | | | tray_icon.png
| | | | | |  
| | | | | \---cat
| | | | | cat_alert.png
| | | | | cat_blink.png
| | | | | cat_idle.png
| | | | | cat_sleeping.png
| | | | | cat_stretch.png
| | | | |  
| | | | \---slideshow
| | | | slide_1.png
| | | | slide_2.png
| | | | slide_3.png
| | | | slide_4.png
| | | | slide_5.png
| | | |  
| | | +---fonts
| | | | MaterialIcons-Regular.otf
| | | |  
| | | +---packages
| | | | \---cupertino_icons
| | | | \---assets
| | | | CupertinoIcons.ttf
| | | |  
| | | \---shaders
| | | ink_sparkle.frag
| | | stretch_effect.frag
| | |  
| | +---INSTALL.dir
| | | +---Debug
| | | +---Profile
| | | \---Release
| | +---Release
| | | | audioplayers_windows_plugin.dll
| | | | dartjni.dll
| | | | flutter_acrylic_plugin.dll
| | | | flutter_windows.dll
| | | | screen_retriever_windows_plugin.dll
| | | | standup.exe
| | | | tray_manager_plugin.dll
| | | | window_manager_plugin.dll
| | | |  
| | | \---data
| | | | app.so
| | | | icudtl.dat
| | | |  
| | | \---flutter_assets
| | | | AssetManifest.bin
| | | | FontManifest.json
| | | | NativeAssetsManifest.json
| | | | NOTICES.Z
| | | |  
| | | +---assets
| | | | +---animations
| | | | | +---cats
| | | | | | +---black_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | +---cat_1
| | | | | | | idle.png
| | | | | | | itch.png
| | | | | | | laying.png
| | | | | | | lick_1.png
| | | | | | | lick_2.png
| | | | | | | meow.png
| | | | | | | run.png
| | | | | | | sitting.png
| | | | | | | sleep_1.png
| | | | | | | sleep_2.png
| | | | | | | stretching.png
| | | | | | | walk.png
| | | | | | |  
| | | | | | +---cat_2
| | | | | | | idle.png
| | | | | | | itch.png
| | | | | | | laying.png
| | | | | | | lick_1.png
| | | | | | | lick_2.png
| | | | | | | meow.png
| | | | | | | run.png
| | | | | | | sitting.png
| | | | | | | sleep_1.png
| | | | | | | sleep_2.png
| | | | | | | stretching.png
| | | | | | | walk.png
| | | | | | |  
| | | | | | +---cat_50
| | | | | | | cat_sheet.png
| | | | | | |  
| | | | | | +---grey_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | +---large_cat
| | | | | | | fall.png
| | | | | | | idle.png
| | | | | | | jump.png
| | | | | | | run.png
| | | | | | |  
| | | | | | +---orange_cat
| | | | | | | sprite_sheet.png
| | | | | | |  
| | | | | | \---pixel_cat
| | | | | | attack.png
| | | | | | hurt.png
| | | | | | idle.png
| | | | | | jump.png
| | | | | | run.png
| | | | | | running%20jump.png
| | | | | | walk.png
| | | | | |  
| | | | | \---dogs
| | | | | collie.png
| | | | | corgi.png
| | | | | dalmatian.png
| | | | | husky.png
| | | | | labrador.png
| | | | |  
| | | | +---fonts
| | | | | \---Satoshi
| | | | | \---Fonts
| | | | | Satoshi-Regular.ttf
| | | | |  
| | | | +---icons
| | | | | | tray_icon.png
| | | | | |  
| | | | | \---cat
| | | | | cat_alert.png
| | | | | cat_blink.png
| | | | | cat_idle.png
| | | | | cat_sleeping.png
| | | | | cat_stretch.png
| | | | |  
| | | | \---slideshow
| | | | slide_1.png
| | | | slide_2.png
| | | | slide_3.png
| | | | slide_4.png
| | | | slide_5.png
| | | |  
| | | +---fonts
| | | | MaterialIcons-Regular.otf
| | | |  
| | | +---packages
| | | | \---cupertino_icons
| | | | \---assets
| | | | CupertinoIcons.ttf
| | | |  
| | | \---shaders
| | | ink_sparkle.frag
| | | stretch_effect.frag
| | |  
| | \---standup.dir
| | +---Debug
| | | | flutter_window.obj
| | | | generated_plugin_registrant.obj
| | | | main.obj
| | | | overlay_window_plugin.obj
| | | | Runner.res
| | | | standup.exe.recipe
| | | | standup.ilk
| | | | utils.obj
| | | | vc145.pdb
| | | | win32_window.obj
| | | |  
| | | \---standup.tlog
| | | CL.command.1.tlog
| | | Cl.items.tlog
| | | CL.read.1.tlog
| | | CL.write.1.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | link.command.1.tlog
| | | link.read.1.tlog
| | | link.secondary.1.tlog
| | | link.write.1.tlog
| | | rc.command.1.tlog
| | | rc.read.1.tlog
| | | rc.write.1.tlog
| | | standup.lastbuildstate
| | |  
| | +---Profile
| | \---Release
| | | flutter_window.obj
| | | generated_plugin_registrant.obj
| | | main.obj
| | | overlay_window_plugin.obj
| | | Runner.res
| | | standup.exe.recipe
| | | utils.obj
| | | win32_window.obj
| | |  
| | \---standup.tlog
| | CL.command.1.tlog
| | Cl.items.tlog
| | CL.read.1.tlog
| | CL.write.1.tlog
| | CustomBuild.command.1.tlog
| | CustomBuild.read.1.tlog
| | CustomBuild.write.1.tlog
| | link.command.1.tlog
| | link.read.1.tlog
| | link.secondary.1.tlog
| | link.write.1.tlog
| | rc.command.1.tlog
| | rc.read.1.tlog
| | rc.write.1.tlog
| | standup.lastbuildstate
| |  
| +---x64
| | +---Debug
| | | +---ALL_BUILD
| | | | | ALL_BUILD.recipe
| | | | |  
| | | | \---ALL_BUILD.tlog
| | | | ALL_BUILD.lastbuildstate
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | |  
| | | +---INSTALL
| | | | | INSTALL.recipe
| | | | |  
| | | | \---INSTALL.tlog
| | | | CustomBuild.command.1.tlog
| | | | CustomBuild.read.1.tlog
| | | | CustomBuild.write.1.tlog
| | | | INSTALL.lastbuildstate
| | | |  
| | | \---ZERO_CHECK
| | | | ZERO_CHECK.recipe
| | | |  
| | | \---ZERO_CHECK.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | ZERO_CHECK.lastbuildstate
| | |  
| | \---Release
| | +---ALL_BUILD
| | | | ALL_BUILD.recipe
| | | |  
| | | \---ALL_BUILD.tlog
| | | ALL_BUILD.lastbuildstate
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | |  
| | +---INSTALL
| | | | INSTALL.recipe
| | | |  
| | | \---INSTALL.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | INSTALL.lastbuildstate
| | |  
| | \---ZERO_CHECK
| | | ZERO_CHECK.recipe
| | |  
| | \---ZERO_CHECK.tlog
| | CustomBuild.command.1.tlog
| | CustomBuild.read.1.tlog
| | CustomBuild.write.1.tlog
| | ZERO_CHECK.lastbuildstate
| |  
| +---ZERO_CHECK.dir
| | +---Debug
| | +---Profile
| | \---Release
| \---\_deps
| +---nuget-build
| +---nuget-src
| | nuget.exe
| |  
| \---nuget-subbuild
| | ALL_BUILD.vcxproj
| | ALL_BUILD.vcxproj.filters
| | CMakeCache.txt
| | CMakeLists.txt
| | cmake_install.cmake
| | nuget-populate.slnx
| | nuget-populate.vcxproj
| | nuget-populate.vcxproj.filters
| | ZERO_CHECK.vcxproj
| | ZERO_CHECK.vcxproj.filters
| |  
| +---ALL_BUILD.dir
| | \---Debug
| +---CMakeFiles
| | | cmake.check_cache
| | | CMakeConfigureLog.yaml
| | | generate.stamp
| | | generate.stamp.depend
| | | generate.stamp.list
| | | InstallScripts.json
| | | TargetDirectories.txt
| | |  
| | +---3218d51d94140ba61733517607ebee12
| | | generate.stamp.rule
| | | nuget-populate.rule
| | |  
| | +---4.2.3-msvc3
| | | | CMakeSystem.cmake
| | | | VCTargetsPath.txt
| | | | VCTargetsPath.vcxproj
| | | |  
| | | +---VCTargetsPath
| | | | \---x64
| | | | \---Debug
| | | | | VCTargetsPath.recipe
| | | | |  
| | | | \---VCTargetsPath.tlog
| | | | VCTargetsPath.lastbuildstate
| | | |  
| | | \---x64
| | | \---Debug
| | +---63f2a544249a989ff8f0a4cda9b76e87
| | | nuget-populate-complete.rule
| | |  
| | +---a787445901815e7f94d3b0838973ecef
| | | nuget-populate-build.rule
| | | nuget-populate-configure.rule
| | | nuget-populate-copyfile.rule
| | | nuget-populate-download.rule
| | | nuget-populate-install.rule
| | | nuget-populate-mkdir.rule
| | | nuget-populate-patch.rule
| | | nuget-populate-test.rule
| | | nuget-populate-update.rule
| | |  
| | +---Debug
| | | nuget-populate-complete
| | |  
| | +---nuget-populate.dir
| | | Labels.json
| | | Labels.txt
| | |  
| | \---pkgRedirects
| +---nuget-populate-prefix
| | +---src
| | | | nuget.exe
| | | |  
| | | \---nuget-populate-stamp
| | | | download-nuget-populate.cmake
| | | | nuget-populate-patch-info.txt
| | | | nuget-populate-update-info.txt
| | | | nuget-populate-urlinfo.txt
| | | | verify-nuget-populate.cmake
| | | |  
| | | \---Debug
| | | nuget-populate-build
| | | nuget-populate-configure
| | | nuget-populate-copyfile
| | | nuget-populate-done
| | | nuget-populate-download
| | | nuget-populate-install
| | | nuget-populate-mkdir
| | | nuget-populate-patch
| | | nuget-populate-test
| | | nuget-populate-update
| | |  
| | \---tmp
| | nuget-populate-cfgcmd.txt
| | nuget-populate-mkdirs.cmake
| |  
| +---nuget-populate.dir
| | \---Debug
| +---x64
| | \---Debug
| | +---ALL_BUILD
| | | | ALL_BUILD.recipe
| | | |  
| | | \---ALL_BUILD.tlog
| | | ALL_BUILD.lastbuildstate
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | |  
| | +---nuget-populate
| | | | nuget-populate.recipe
| | | |  
| | | \---nuget-populate.tlog
| | | CustomBuild.command.1.tlog
| | | CustomBuild.read.1.tlog
| | | CustomBuild.write.1.tlog
| | | nuget-populate.lastbuildstate
| | |  
| | \---ZERO_CHECK
| | | ZERO_CHECK.recipe
| | |  
| | \---ZERO_CHECK.tlog
| | CustomBuild.command.1.tlog
| | CustomBuild.read.1.tlog
| | CustomBuild.write.1.tlog
| | ZERO_CHECK.lastbuildstate
| |  
| \---ZERO_CHECK.dir
| \---Debug
+---lib
| | main.dart
| |  
| +---app
| | app.dart
| | dependency_injection.dart
| | main_layout.dart
| |  
| +---core
| | +---constants
| | | app_constants.dart
| | |  
| | +---errors
| | | app_exception.dart
| | | error_handler.dart
| | |  
| | +---events
| | | app_events.dart
| | | events.dart
| | | event_bus.dart
| | |  
| | +---ipc
| | | ipc_bridge.dart
| | |  
| | +---native
| | | focus_mode_service.dart
| | | macos_bridge.dart
| | | meeting_detection_service.dart
| | |  
| | +---plugins
| | | windows_overlay_plugin.dart
| | |  
| | +---services
| | | activity_monitor.dart
| | | adaptive_break_service.dart
| | | app_navigation_service.dart
| | | flash.dart
| | | flash_controller.dart
| | | flash_overlay.dart
| | | flash_service.dart
| | | flash_test_widget.dart
| | | floating_window_service.dart
| | | notification_service.dart
| | | overlay_window_service.dart
| | | smart_detection_service.dart
| | | storage_service.dart
| | | timer_engine.dart
| | | window_service.dart
| | |  
| | +---utils
| | | logger.dart
| | | retry_policy.dart
| | | toast.dart
| | |  
| | \---widgets
| | app_button.dart
| |  
| +---features
| | +---analytics
| | | | stats_model.dart
| | | | stats_service.dart
| | | |  
| | | +---presentation
| | | | \---widgets
| | | | productivity_trend_chart.dart
| | | |  
| | | \---widgets
| | | stats_chart.dart
| | |  
| | +---break_overlay
| | | \---presentation
| | | \---widgets
| | | breathing_assistant.dart
| | |  
| | +---break_system
| | | +---application
| | | | break_controller.dart
| | | | strict_mode_controller.dart
| | | |  
| | | +---domain
| | | | break_model.dart
| | | |  
| | | \---presentation
| | | | break_overlay.dart
| | | | flash_overlay.dart
| | | | pre_break_warning_overlay.dart
| | | | standalone_break_overlay.dart
| | | |  
| | | \---widgets
| | | break_activity_graph.dart
| | |  
| | +---companion
| | | +---controllers
| | | | companion_overlay_controller.dart
| | | |  
| | | +---data
| | | | cat_asset_loader.dart
| | | |  
| | | +---domain
| | | | animation_row_config.dart
| | | | cat_animation_state.dart
| | | | cat_state_machine.dart
| | | | cat_theme.dart
| | | |  
| | | +---flame
| | | | companion_component.dart
| | | | companion_game.dart
| | | |  
| | | +---overlay
| | | | companion_overlay_window.dart
| | | |  
| | | \---services
| | | companion_behavior_engine.dart
| | | companion_state_manager.dart
| | | companion_window_controller.dart
| | |  
| | +---flash_overlay
| | | flash_overlay_screen.dart
| | | flash_overlay_service.dart
| | | flash_overlay_widget.dart
| | |  
| | +---menu_bar
| | | | menu_bar_popover.dart
| | | | tray_manager_service.dart
| | | |  
| | | \---controllers
| | | controllers.dart
| | | menu_bar_controller.dart
| | |  
| | +---settings
| | | | break_profile.dart
| | | | exercise_model.dart
| | | | settings_model.dart
| | | | settings_page.dart
| | | | settings_repository.dart
| | | |  
| | | \---widgets
| | | about_section.dart
| | | focus_section.dart
| | | general_section.dart
| | | notifications_section.dart
| | | settings_widgets.dart
| | |  
| | \---wellness
| | \---presentation
| | wellness_articles_page.dart
| |  
| \---shared
| +---theme
| | app_theme.dart
| |  
| \---widgets
| animated_number.dart
| countdown_timer.dart
| pressable_button.dart
| progress_ring.dart
| staggered_fade_in.dart
|  
+---macos
| | .gitignore
| | fix_timer.py
| | Podfile
| | Podfile.lock
| |  
| +---Flutter
| | | Flutter-Debug.xcconfig
| | | Flutter-Release.xcconfig
| | | GeneratedPluginRegistrant.swift
| | |  
| | \---ephemeral
| | Flutter-Generated.xcconfig
| | flutter_export_environment.sh
| | flutter_native_integration.env
| |  
| +---Runner
| | | AppDelegate.swift
| | | CompanionWindowManager.swift
| | | DebugProfile.entitlements
| | | Info.plist
| | | MainFlutterWindow.swift
| | | Release.entitlements
| | |  
| | +---Assets.xcassets
| | | \---AppIcon.appiconset
| | | app_icon_1024.png
| | | app_icon_128.png
| | | app_icon_16.png
| | | app_icon_256.png
| | | app_icon_32.png
| | | app_icon_512.png
| | | app_icon_64.png
| | | Contents.json
| | |  
| | +---Base.lproj
| | | MainMenu.xib
| | |  
| | +---Bridges
| | | FocusModeBridge.swift
| | | MeetingDetectionBridge.swift
| | | OverlayWindowBridge.swift
| | |  
| | \---Configs
| | AppInfo.xcconfig
| | Debug.xcconfig
| | Release.xcconfig
| | Warnings.xcconfig
| |  
| +---Runner.xcodeproj
| | | project.pbxproj
| | |  
| | +---project.xcworkspace
| | | \---xcshareddata
| | | IDEWorkspaceChecks.plist
| | |  
| | \---xcshareddata
| | \---xcschemes
| | Runner.xcscheme
| |  
| +---Runner.xcworkspace
| | | contents.xcworkspacedata
| | |  
| | \---xcshareddata
| | IDEWorkspaceChecks.plist
| |  
| \---RunnerTests
| RunnerTests.swift
|  
\---windows
| .gitignore
| CMakeLists.txt
|  
 +---flutter
| | CMakeLists.txt
| | generated_plugins.cmake
| | generated_plugin_registrant.cc
| | generated_plugin_registrant.h
| |  
 | \---ephemeral
| | flutter_export.h
| | flutter_messenger.h
| | flutter_plugin_registrar.h
| | flutter_texture_registrar.h
| | flutter_windows.dll
| | flutter_windows.dll.exp
| | flutter_windows.dll.lib
| | flutter_windows.dll.pdb
| | flutter_windows.h
| | generated_config.cmake
| | icudtl.dat
| |  
 | +---.plugin_symlinks
| | +---audioplayers_windows
| | | | analysis_options.yaml
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | \---windows
| | | | audioplayers_helpers.h
| | | | audioplayers_windows_plugin.cpp
| | | | audio_player.cpp
| | | | audio_player.h
| | | | CMakeLists.txt
| | | | event_stream_handler.h
| | | | MediaEngineExtension.cpp
| | | | MediaEngineExtension.h
| | | | MediaEngineWrapper.cpp
| | | | MediaEngineWrapper.h
| | | | MediaFoundationHelpers.h
| | | |  
 | | | \---include
| | | \---audioplayers_windows
| | | audioplayers_windows_plugin.h
| | |  
 | | +---flutter_acrylic
| | | | analysis_options.yaml
| | | | CHANGELOG.md
| | | | flutter_acrylic.iml
| | | | LICENSE
| | | | MIGRATIONGUIDE.md
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---example
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---lib
| | | | | | main.dart
| | | | | |  
 | | | | | \---widgets
| | | | | +---macos_action_menu
| | | | | | | description_display.dart
| | | | | | | macos_action_menu.dart
| | | | | | |  
 | | | | | | \---action_list
| | | | | | action_list.dart
| | | | | | action_list_item.dart
| | | | | |  
 | | | | | \---sidebar_frame
| | | | | sidebar_frame.dart
| | | | | top_bar.dart
| | | | |  
 | | | | +---linux
| | | | | | CMakeLists.txt
| | | | | | main.cc
| | | | | | my_application.cc
| | | | | | my_application.h
| | | | | |  
 | | | | | \---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | | generated_plugin_registrant.cc
| | | | | generated_plugin_registrant.h
| | | | |  
 | | | | +---macos
| | | | | | Podfile
| | | | | | Podfile.lock
| | | | | |  
 | | | | | +---Flutter
| | | | | | Flutter-Debug.xcconfig
| | | | | | Flutter-Release.xcconfig
| | | | | | GeneratedPluginRegistrant.swift
| | | | | |  
 | | | | | +---Runner
| | | | | | | AppDelegate.swift
| | | | | | | DebugProfile.entitlements
| | | | | | | Info.plist
| | | | | | | MainFlutterWindow.swift
| | | | | | | Release.entitlements
| | | | | | |  
 | | | | | | +---Assets.xcassets
| | | | | | | \---AppIcon.appiconset
| | | | | | | app_icon_1024.png
| | | | | | | app_icon_128.png
| | | | | | | app_icon_16.png
| | | | | | | app_icon_256.png
| | | | | | | app_icon_32.png
| | | | | | | app_icon_512.png
| | | | | | | app_icon_64.png
| | | | | | | Contents.json
| | | | | | |  
 | | | | | | +---Base.lproj
| | | | | | | MainMenu.xib
| | | | | | |  
 | | | | | | \---Configs
| | | | | | AppInfo.xcconfig
| | | | | | Debug.xcconfig
| | | | | | Release.xcconfig
| | | | | | Warnings.xcconfig
| | | | | |  
 | | | | | +---Runner.xcodeproj
| | | | | | | project.pbxproj
| | | | | | |  
 | | | | | | +---project.xcworkspace
| | | | | | | \---xcshareddata
| | | | | | | IDEWorkspaceChecks.plist
| | | | | | |  
 | | | | | | \---xcshareddata
| | | | | | \---xcschemes
| | | | | | Runner.xcscheme
| | | | | |  
 | | | | | \---Runner.xcworkspace
| | | | | | contents.xcworkspacedata
| | | | | |  
 | | | | | \---xcshareddata
| | | | | IDEWorkspaceChecks.plist
| | | | |  
 | | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | | generated_plugin_registrant.cc
| | | | | generated_plugin_registrant.h
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---lib
| | | | | flutter_acrylic.dart
| | | | | window.dart
| | | | | window_effect.dart
| | | | |  
 | | | | +---macos
| | | | | | macos_blur_view_state.dart
| | | | | | macos_toolbar_style.dart
| | | | | | visual_effect_view_properties.dart
| | | | | |  
 | | | | | \---converters
| | | | | blur_view_state_to_visual_effect_view_state_converter.dart
| | | | | mac_toolbar_style_to_window_toolbar_style_converter.dart
| | | | | window_effect_to_material_converter.dart
| | | | |  
 | | | | \---widgets
| | | | | titlebar_safe_area.dart
| | | | | transparent_macos_bottom_bar.dart
| | | | | transparent_macos_sidebar.dart
| | | | |  
 | | | | \---visual_effect_subview_container
| | | | visual_effect_subview_container.dart
| | | | visual_effect_subview_container_property_storage.dart
| | | | visual_effect_subview_container_resize_event_relay.dart
| | | | visual_effect_subview_container_with_global_key.dart
| | | |  
 | | | +---linux
| | | | | CMakeLists.txt
| | | | | flutter_acrylic_plugin.cc
| | | | |  
 | | | | \---include
| | | | \---flutter_acrylic
| | | | flutter_acrylic_plugin.h
| | | |  
 | | | +---test
| | | | \---widgets
| | | | \---visual_effect_subview_container
| | | | visual_effect_subview_container_property_storage_test.dart
| | | | visual_effect_subview_container_resize_event_relay_test.dart
| | | |  
 | | | \---windows
| | | | CMakeLists.txt
| | | | flutter_acrylic_plugin.cpp
| | | |  
 | | | \---include
| | | \---flutter_acrylic
| | | flutter_acrylic_plugin.h
| | |  
 | | +---jni
| | | | analysis_options.yaml
| | | | CHANGELOG.md
| | | | dart_test.yaml
| | | | ffigen.yaml
| | | | ffigen_exts.yaml
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---android
| | | | | build.gradle
| | | | | consumer-rules.pro
| | | | | README.md
| | | | | settings.gradle
| | | | |  
 | | | | +---.cxx
| | | | | +---Debug
| | | | | | \---59z28201
| | | | | | | hash_key.txt
| | | | | | |  
 | | | | | | +---arm64-v8a
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-1014e5fe329b110b18ba.json
| | | | | | | | cmakeFiles-v1-9b33b58fc6d23fee9ebe.json
| | | | | | | | codemodel-v2-eb2253d4c83890702c09.json
| | | | | | | | directory-.-Debug-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-14T09-12-37-0323.json
| | | | | | | | target-jni-Debug-e59c93aad67bcb5f78ab.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | +---armeabi-v7a
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-c2e4d146b588a1cd776d.json
| | | | | | | | cmakeFiles-v1-9aecbd7df12088489e55.json
| | | | | | | | codemodel-v2-4954ec6d7f55c387f505.json
| | | | | | | | directory-.-Debug-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-14T09-12-42-0158.json
| | | | | | | | target-jni-Debug-3c0d45beb4b9047c9426.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | +---x86
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-ffd17bc53ed8484b06c9.json
| | | | | | | | cmakeFiles-v1-d16eba058a0407d0566b.json
| | | | | | | | codemodel-v2-560abc0fd96a9bcf8d8b.json
| | | | | | | | directory-.-Debug-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-14T09-12-47-0001.json
| | | | | | | | target-jni-Debug-ffb5a3462ad21059eeab.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | \---x86_64
| | | | | | | .ninja_deps
| | | | | | | .ninja_log
| | | | | | | additional_project_files.txt
| | | | | | | android_gradle_build.json
| | | | | | | android_gradle_build_mini.json
| | | | | | | build.ninja
| | | | | | | build_file_index.txt
| | | | | | | CMakeCache.txt
| | | | | | | cmake_install.cmake
| | | | | | | compile_commands.json
| | | | | | | compile_commands.json.bin
| | | | | | | configure_fingerprint.bin
| | | | | | | metadata_generation_command.txt
| | | | | | | prefab_config.json
| | | | | | | symbol_folder_index.txt
| | | | | | |  
 | | | | | | +---.cmake
| | | | | | | \---api
| | | | | | | \---v1
| | | | | | | +---query
| | | | | | | | \---client-agp
| | | | | | | | cache-v2
| | | | | | | | cmakeFiles-v1
| | | | | | | | codemodel-v2
| | | | | | | |  
 | | | | | | | \---reply
| | | | | | | cache-v2-56c0d49554c3a1497a4c.json
| | | | | | | cmakeFiles-v1-be3d443cbeafeaae3fac.json
| | | | | | | codemodel-v2-fd6d3359100ae678f72d.json
| | | | | | | directory-.-Debug-d0094a50bb2071803777.json
| | | | | | | index-2026-04-14T09-12-51-0295.json
| | | | | | | target-jni-Debug-48816420e123f79644dd.json
| | | | | | |  
 | | | | | | \---CMakeFiles
| | | | | | | cmake.check_cache
| | | | | | | CMakeOutput.log
| | | | | | | rules.ninja
| | | | | | | TargetDirectories.txt
| | | | | | |  
 | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | CMakeCCompiler.cmake
| | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | CMakeSystem.cmake
| | | | | | | |  
 | | | | | | | \---CompilerIdC
| | | | | | | | CMakeCCompilerId.c
| | | | | | | | CMakeCCompilerId.o
| | | | | | | |  
 | | | | | | | \---tmp
| | | | | | +---CMakeTmp
| | | | | | \---jni.dir
| | | | | | | dartjni.c.o
| | | | | | |  
 | | | | | | +---include
| | | | | | | dart_api_dl.c.o
| | | | | | |  
 | | | | | | \---third_party
| | | | | | global_jni_env.c.o
| | | | | |  
 | | | | | +---RelWithDebInfo
| | | | | | \---60323i66
| | | | | | | hash_key.txt
| | | | | | |  
 | | | | | | +---arm64-v8a
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-19352ec278ba09d68142.json
| | | | | | | | cmakeFiles-v1-96674bed4371df062f1d.json
| | | | | | | | codemodel-v2-d59f527413e16e8b73ca.json
| | | | | | | | directory-.-RelWithDebInfo-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-19T07-10-13-0875.json
| | | | | | | | target-jni-RelWithDebInfo-7a8e91839f76f0089633.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | +---armeabi-v7a
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-607908097785654fd800.json
| | | | | | | | cmakeFiles-v1-c30a520bbff348f3a625.json
| | | | | | | | codemodel-v2-c4e7783654d4077b217b.json
| | | | | | | | directory-.-RelWithDebInfo-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-19T07-10-18-0404.json
| | | | | | | | target-jni-RelWithDebInfo-683ab7fb5efcaa2b3e44.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | +---x86
| | | | | | | | .ninja_deps
| | | | | | | | .ninja_log
| | | | | | | | additional_project_files.txt
| | | | | | | | android_gradle_build.json
| | | | | | | | android_gradle_build_mini.json
| | | | | | | | build.ninja
| | | | | | | | build_file_index.txt
| | | | | | | | CMakeCache.txt
| | | | | | | | cmake_install.cmake
| | | | | | | | compile_commands.json
| | | | | | | | compile_commands.json.bin
| | | | | | | | configure_fingerprint.bin
| | | | | | | | metadata_generation_command.txt
| | | | | | | | prefab_config.json
| | | | | | | | symbol_folder_index.txt
| | | | | | | |  
 | | | | | | | +---.cmake
| | | | | | | | \---api
| | | | | | | | \---v1
| | | | | | | | +---query
| | | | | | | | | \---client-agp
| | | | | | | | | cache-v2
| | | | | | | | | cmakeFiles-v1
| | | | | | | | | codemodel-v2
| | | | | | | | |  
 | | | | | | | | \---reply
| | | | | | | | cache-v2-e821abce4d2da272f7df.json
| | | | | | | | cmakeFiles-v1-1dc4b15857451c67fe3d.json
| | | | | | | | codemodel-v2-3142483ec838554ae842.json
| | | | | | | | directory-.-RelWithDebInfo-d0094a50bb2071803777.json
| | | | | | | | index-2026-04-19T07-10-22-0735.json
| | | | | | | | target-jni-RelWithDebInfo-ba36c7aa41d6371c1d3c.json
| | | | | | | |  
 | | | | | | | \---CMakeFiles
| | | | | | | | cmake.check_cache
| | | | | | | | CMakeOutput.log
| | | | | | | | rules.ninja
| | | | | | | | TargetDirectories.txt
| | | | | | | |  
 | | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | | CMakeCCompiler.cmake
| | | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | | CMakeSystem.cmake
| | | | | | | | |  
 | | | | | | | | \---CompilerIdC
| | | | | | | | | CMakeCCompilerId.c
| | | | | | | | | CMakeCCompilerId.o
| | | | | | | | |  
 | | | | | | | | \---tmp
| | | | | | | +---CMakeTmp
| | | | | | | \---jni.dir
| | | | | | | | dartjni.c.o
| | | | | | | |  
 | | | | | | | +---include
| | | | | | | | dart_api_dl.c.o
| | | | | | | |  
 | | | | | | | \---third_party
| | | | | | | global_jni_env.c.o
| | | | | | |  
 | | | | | | \---x86_64
| | | | | | | .ninja_deps
| | | | | | | .ninja_log
| | | | | | | additional_project_files.txt
| | | | | | | android_gradle_build.json
| | | | | | | android_gradle_build_mini.json
| | | | | | | build.ninja
| | | | | | | build_file_index.txt
| | | | | | | CMakeCache.txt
| | | | | | | cmake_install.cmake
| | | | | | | compile_commands.json
| | | | | | | compile_commands.json.bin
| | | | | | | configure_fingerprint.bin
| | | | | | | metadata_generation_command.txt
| | | | | | | prefab_config.json
| | | | | | | symbol_folder_index.txt
| | | | | | |  
 | | | | | | +---.cmake
| | | | | | | \---api
| | | | | | | \---v1
| | | | | | | +---query
| | | | | | | | \---client-agp
| | | | | | | | cache-v2
| | | | | | | | cmakeFiles-v1
| | | | | | | | codemodel-v2
| | | | | | | |  
 | | | | | | | \---reply
| | | | | | | cache-v2-c77a23d10b4cc0654e09.json
| | | | | | | cmakeFiles-v1-e6b2a39d963beeaceb89.json
| | | | | | | codemodel-v2-15732fc1c060073211b1.json
| | | | | | | directory-.-RelWithDebInfo-d0094a50bb2071803777.json
| | | | | | | index-2026-04-19T07-10-27-0051.json
| | | | | | | target-jni-RelWithDebInfo-9b3b0507c11cb5b4402a.json
| | | | | | |  
 | | | | | | \---CMakeFiles
| | | | | | | cmake.check_cache
| | | | | | | CMakeOutput.log
| | | | | | | rules.ninja
| | | | | | | TargetDirectories.txt
| | | | | | |  
 | | | | | | +---3.22.1-g37088a8-dirty
| | | | | | | | CMakeCCompiler.cmake
| | | | | | | | CMakeDetermineCompilerABI_C.bin
| | | | | | | | CMakeSystem.cmake
| | | | | | | |  
 | | | | | | | \---CompilerIdC
| | | | | | | | CMakeCCompilerId.c
| | | | | | | | CMakeCCompilerId.o
| | | | | | | |  
 | | | | | | | \---tmp
| | | | | | +---CMakeTmp
| | | | | | \---jni.dir
| | | | | | | dartjni.c.o
| | | | | | |  
 | | | | | | +---include
| | | | | | | dart_api_dl.c.o
| | | | | | |  
 | | | | | | \---third_party
| | | | | | global_jni_env.c.o
| | | | | |  
 | | | | | \---tools
| | | | | +---profile
| | | | | | +---arm64-v8a
| | | | | | | compile_commands.json
| | | | | | |  
 | | | | | | +---armeabi-v7a
| | | | | | | compile_commands.json
| | | | | | |  
 | | | | | | +---x86
| | | | | | | compile_commands.json
| | | | | | |  
 | | | | | | \---x86_64
| | | | | | compile_commands.json
| | | | | |  
 | | | | | \---release
| | | | | +---arm64-v8a
| | | | | | compile_commands.json
| | | | | |  
 | | | | | +---armeabi-v7a
| | | | | | compile_commands.json
| | | | | |  
 | | | | | +---x86
| | | | | | compile_commands.json
| | | | | |  
 | | | | | \---x86_64
| | | | | compile_commands.json
| | | | |  
 | | | | +---.gradle
| | | | | +---8.9
| | | | | | | gc.properties
| | | | | | |  
 | | | | | | +---checksums
| | | | | | | checksums.lock
| | | | | | |  
 | | | | | | +---dependencies-accessors
| | | | | | | gc.properties
| | | | | | |  
 | | | | | | +---expanded
| | | | | | +---fileChanges
| | | | | | | last-build.bin
| | | | | | |  
 | | | | | | +---fileHashes
| | | | | | | fileHashes.lock
| | | | | | |  
 | | | | | | \---vcsMetadata
| | | | | +---buildOutputCleanup
| | | | | | buildOutputCleanup.lock
| | | | | | cache.properties
| | | | | |  
 | | | | | \---vcs-1
| | | | | gc.properties
| | | | |  
 | | | | \---src
| | | | \---main
| | | | | AndroidManifest.xml
| | | | |  
 | | | | \---java
| | | | \---com
| | | | \---github
| | | | \---dart_lang
| | | | \---jni
| | | | JniPlugin.java
| | | |  
 | | | +---bin
| | | | setup.dart
| | | |  
 | | | +---example
| | | | | analysis_options.yaml
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---android
| | | | | | build.gradle
| | | | | | gradle.properties
| | | | | | settings.gradle
| | | | | |  
 | | | | | +---app
| | | | | | | build.gradle
| | | | | | |  
 | | | | | | \---src
| | | | | | +---debug
| | | | | | | AndroidManifest.xml
| | | | | | |  
 | | | | | | +---main
| | | | | | | | AndroidManifest.xml
| | | | | | | |  
 | | | | | | | +---java
| | | | | | | | +---com
| | | | | | | | | \---github
| | | | | | | | | \---dart_lang
| | | | | | | | | \---jni_example
| | | | | | | | | Toaster.java
| | | | | | | | |  
 | | | | | | | | \---io
| | | | | | | | \---flutter
| | | | | | | | \---plugins
| | | | | | | +---kotlin
| | | | | | | | \---dev
| | | | | | | | \---dart
| | | | | | | | \---jni_example
| | | | | | | | MainActivity.kt
| | | | | | | |  
 | | | | | | | \---res
| | | | | | | +---drawable
| | | | | | | | launch_background.xml
| | | | | | | |  
 | | | | | | | +---drawable-v21
| | | | | | | | launch_background.xml
| | | | | | | |  
 | | | | | | | +---mipmap-hdpi
| | | | | | | | ic_launcher.png
| | | | | | | |  
 | | | | | | | +---mipmap-mdpi
| | | | | | | | ic_launcher.png
| | | | | | | |  
 | | | | | | | +---mipmap-xhdpi
| | | | | | | | ic_launcher.png
| | | | | | | |  
 | | | | | | | +---mipmap-xxhdpi
| | | | | | | | ic_launcher.png
| | | | | | | |  
 | | | | | | | +---mipmap-xxxhdpi
| | | | | | | | ic_launcher.png
| | | | | | | |  
 | | | | | | | +---values
| | | | | | | | styles.xml
| | | | | | | |  
 | | | | | | | \---values-night
| | | | | | | styles.xml
| | | | | | |  
 | | | | | | \---profile
| | | | | | AndroidManifest.xml
| | | | | |  
 | | | | | \---gradle
| | | | | \---wrapper
| | | | | gradle-wrapper.properties
| | | | |  
 | | | | +---integration_test
| | | | | on_device_jni_test.dart
| | | | |  
 | | | | +---lib
| | | | | main.dart
| | | | |  
 | | | | +---linux
| | | | | | CMakeLists.txt
| | | | | | main.cc
| | | | | | my_application.cc
| | | | | | my_application.h
| | | | | |  
 | | | | | \---flutter
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---macos
| | | | | | Podfile
| | | | | |  
 | | | | | +---Flutter
| | | | | | Flutter-Debug.xcconfig
| | | | | | Flutter-Release.xcconfig
| | | | | |  
 | | | | | +---Runner
| | | | | | | AppDelegate.swift
| | | | | | | DebugProfile.entitlements
| | | | | | | Info.plist
| | | | | | | MainFlutterWindow.swift
| | | | | | | Release.entitlements
| | | | | | |  
 | | | | | | +---Assets.xcassets
| | | | | | | \---AppIcon.appiconset
| | | | | | | app_icon_1024.png
| | | | | | | app_icon_128.png
| | | | | | | app_icon_16.png
| | | | | | | app_icon_256.png
| | | | | | | app_icon_32.png
| | | | | | | app_icon_512.png
| | | | | | | app_icon_64.png
| | | | | | | Contents.json
| | | | | | |  
 | | | | | | +---Base.lproj
| | | | | | | MainMenu.xib
| | | | | | |  
 | | | | | | \---Configs
| | | | | | AppInfo.xcconfig
| | | | | | Debug.xcconfig
| | | | | | Release.xcconfig
| | | | | | Warnings.xcconfig
| | | | | |  
 | | | | | +---Runner.xcodeproj
| | | | | | | project.pbxproj
| | | | | | |  
 | | | | | | +---project.xcworkspace
| | | | | | | \---xcshareddata
| | | | | | | IDEWorkspaceChecks.plist
| | | | | | |  
 | | | | | | \---xcshareddata
| | | | | | \---xcschemes
| | | | | | Runner.xcscheme
| | | | | |  
 | | | | | \---Runner.xcworkspace
| | | | | | contents.xcworkspacedata
| | | | | |  
 | | | | | \---xcshareddata
| | | | | IDEWorkspaceChecks.plist
| | | | |  
 | | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---java
| | | | | build.gradle.kts
| | | | | gradlew
| | | | | gradlew.bat
| | | | | README.md
| | | | | settings.gradle.kts
| | | | |  
 | | | | +---gradle
| | | | | | libs.versions.toml
| | | | | |  
 | | | | | \---wrapper
| | | | | gradle-wrapper.jar
| | | | | gradle-wrapper.properties
| | | | |  
 | | | | +---src
| | | | | \---main
| | | | | \---java
| | | | | \---com
| | | | | \---github
| | | | | \---dart_lang
| | | | | \---jni
| | | | | JniUtils.java
| | | | | PortCleaner.java
| | | | | PortContinuation.java
| | | | | PortProxyBuilder.java
| | | | |  
 | | | | \---~
| | | | \---dev
| | | | +---native
| | | | | \---native
| | | | | \---pkgs
| | | | | \---jnigen
| | | | | \---example
| | | | | \---pdfbox_plugin
| | | | | \---dart_example
| | | | \---native2
| | | | \---pkgs
| | | | \---jnigen
| | | | \---example
| | | | \---pdfbox_plugin
| | | | \---dart_example
| | | +---lib
| | | | | jni.dart
| | | | | jni_symbols.yaml
| | | | | \_internal.dart
| | | | |  
 | | | | \---src
| | | | | accessors.dart
| | | | | core_bindings.dart
| | | | | errors.dart
| | | | | jarray.dart
| | | | | jclass.dart
| | | | | jimplementer.dart
| | | | | jni.dart
| | | | | jobject.dart
| | | | | jprimitives.dart
| | | | | jreference.dart
| | | | | jvalues.dart
| | | | | kotlin.dart
| | | | | method_invocation.dart
| | | | | primitive_jarrays.dart
| | | | | types.dart
| | | | | version_check.dart
| | | | |  
 | | | | +---build_util
| | | | | build_util.dart
| | | | |  
 | | | | +---lang
| | | | | jboolean.dart
| | | | | jbyte.dart
| | | | | jcharacter.dart
| | | | | jdouble.dart
| | | | | jfloat.dart
| | | | | jinteger.dart
| | | | | jlong.dart
| | | | | jnumber.dart
| | | | | jshort.dart
| | | | | jstring.dart
| | | | | lang.dart
| | | | |  
 | | | | +---nio
| | | | | jbuffer.dart
| | | | | jbyte_buffer.dart
| | | | | nio.dart
| | | | |  
 | | | | +---third_party
| | | | | generated_bindings.dart
| | | | | global_env_extensions.dart
| | | | | jni_bindings_generated.dart
| | | | |  
 | | | | \---util
| | | | jiterator.dart
| | | | jlist.dart
| | | | jmap.dart
| | | | jset.dart
| | | | util.dart
| | | |  
 | | | +---linux
| | | | CMakeLists.txt
| | | |  
 | | | +---src
| | | | | CMakeLists.txt
| | | | | dartjni.c
| | | | | dartjni.h
| | | | | jni_constants.h
| | | | | README.md
| | | | |  
 | | | | +---include
| | | | | | analyze_snapshot_api.h
| | | | | | BUILD.gn
| | | | | | dart_api.h
| | | | | | dart_api_dl.c
| | | | | | dart_api_dl.h
| | | | | | dart_embedder_api.h
| | | | | | dart_native_api.h
| | | | | | dart_tools_api.h
| | | | | | dart_version.h
| | | | | |  
 | | | | | +---bin
| | | | | | dart_io_api.h
| | | | | | native_assets_api.h
| | | | | |  
 | | | | | \---internal
| | | | | dart_api_dl_impl.h
| | | | |  
 | | | | \---third_party
| | | | global_jni_env.c
| | | | global_jni_env.h
| | | |  
 | | | +---test
| | | | | boxed_test.dart
| | | | | debug_release_test.dart
| | | | | exception_test.dart
| | | | | global_env_test.dart
| | | | | isolate_test.dart
| | | | | jarray_test.dart
| | | | | jbyte_buffer_test.dart
| | | | | jlist_test.dart
| | | | | jmap_test.dart
| | | | | jobject_test.dart
| | | | | jset_test.dart
| | | | | jstring_test.dart
| | | | | load_test.dart
| | | | | version_check_test.dart
| | | | |  
 | | | | +---test_util
| | | | | test_util.dart
| | | | |  
 | | | | \---version_check
| | | | fail_major.dart
| | | | fail_minor.dart
| | | | pass.dart
| | | |  
 | | | +---third_party
| | | | jni.h
| | | |  
 | | | +---tool
| | | | | generate_ffi_bindings.dart
| | | | | generate_ide_files.dart
| | | | | generate_jni_bindings.dart
| | | | | generate_primitive_arrays.dart
| | | | |  
 | | | | \---wrapper_generators
| | | | ffigen_util.dart
| | | | generate_c_extensions.dart
| | | | generate_dart_extensions.dart
| | | | generate_helper_functions.dart
| | | | logging.dart
| | | |  
 | | | \---windows
| | | CMakeLists.txt
| | |  
 | | +---package_info_plus
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---android
| | | | | build.gradle
| | | | | gradle.properties
| | | | | settings.gradle
| | | | |  
 | | | | +---.gradle
| | | | | +---8.4
| | | | | | | gc.properties
| | | | | | |  
 | | | | | | +---checksums
| | | | | | | checksums.lock
| | | | | | |  
 | | | | | | +---fileChanges
| | | | | | | last-build.bin
| | | | | | |  
 | | | | | | +---fileHashes
| | | | | | | fileHashes.lock
| | | | | | |  
 | | | | | | \---vcsMetadata
| | | | | +---nb-cache
| | | | | | \---trust
| | | | | | E252A951965A2B776FA60B8860EDDF0AE54EFDB6EA1D15AA8EF7312B50BB1F74
| | | | | |  
 | | | | | \---vcs-1
| | | | | gc.properties
| | | | |  
 | | | | +---gradle
| | | | | \---wrapper
| | | | | gradle-wrapper.properties
| | | | |  
 | | | | \---src
| | | | \---main
| | | | | AndroidManifest.xml
| | | | |  
 | | | | \---kotlin
| | | | \---dev
| | | | \---fluttercommunity
| | | | \---plus
| | | | \---packageinfo
| | | | PackageInfoPlugin.kt
| | | |  
 | | | +---example
| | | | | analysis_options.yaml
| | | | | build.yaml
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---android
| | | | | | build.gradle
| | | | | | gradle.properties
| | | | | | settings.gradle
| | | | | |  
 | | | | | +---app
| | | | | | | build.gradle
| | | | | | |  
 | | | | | | +---gradle
| | | | | | | \---wrapper
| | | | | | | gradle-wrapper.properties
| | | | | | |  
 | | | | | | \---src
| | | | | | +---androidTest
| | | | | | | \---java
| | | | | | | \---io
| | | | | | | \---flutter
| | | | | | | \---plugins
| | | | | | | \---packageinfoexample
| | | | | | | EmbedderV1ActivityTest.java
| | | | | | | MainActivityTest.java
| | | | | | |  
 | | | | | | \---main
| | | | | | | AndroidManifest.xml
| | | | | | |  
 | | | | | | +---java
| | | | | | | \---io
| | | | | | | \---flutter
| | | | | | | \---plugins
| | | | | | \---res
| | | | | | +---mipmap-hdpi
| | | | | | | ic_launcher.png
| | | | | | |  
 | | | | | | +---mipmap-mdpi
| | | | | | | ic_launcher.png
| | | | | | |  
 | | | | | | +---mipmap-xhdpi
| | | | | | | ic_launcher.png
| | | | | | |  
 | | | | | | +---mipmap-xxhdpi
| | | | | | | ic_launcher.png
| | | | | | |  
 | | | | | | \---mipmap-xxxhdpi
| | | | | | ic_launcher.png
| | | | | |  
 | | | | | \---gradle
| | | | | \---wrapper
| | | | | gradle-wrapper.properties
| | | | |  
 | | | | +---integration_test
| | | | | driver.dart
| | | | | package_info_plus_test.dart
| | | | | package_info_plus_web_test.dart
| | | | | package_info_plus_web_test.mocks.dart
| | | | |  
 | | | | +---ios
| | | | | +---Flutter
| | | | | | AppFrameworkInfo.plist
| | | | | | Debug.xcconfig
| | | | | | Release.xcconfig
| | | | | |  
 | | | | | +---Runner
| | | | | | | AppDelegate.swift
| | | | | | | Info.plist
| | | | | | | Runner-Bridging-Header.h
| | | | | | |  
 | | | | | | +---Assets.xcassets
| | | | | | | +---AppIcon.appiconset
| | | | | | | | Contents.json
| | | | | | | | Icon-App-1024x1024@1x.png
| | | | | | | | Icon-App-20x20@1x.png
| | | | | | | | Icon-App-20x20@2x.png
| | | | | | | | Icon-App-20x20@3x.png
| | | | | | | | Icon-App-29x29@1x.png
| | | | | | | | Icon-App-29x29@2x.png
| | | | | | | | Icon-App-29x29@3x.png
| | | | | | | | Icon-App-40x40@1x.png
| | | | | | | | Icon-App-40x40@2x.png
| | | | | | | | Icon-App-40x40@3x.png
| | | | | | | | Icon-App-60x60@2x.png
| | | | | | | | Icon-App-60x60@3x.png
| | | | | | | | Icon-App-76x76@1x.png
| | | | | | | | Icon-App-76x76@2x.png
| | | | | | | | Icon-App-83.5x83.5@2x.png
| | | | | | | |  
 | | | | | | | \---LaunchImage.imageset
| | | | | | | Contents.json
| | | | | | | LaunchImage.png
| | | | | | | LaunchImage@2x.png
| | | | | | | LaunchImage@3x.png
| | | | | | | README.md
| | | | | | |  
 | | | | | | \---Base.lproj
| | | | | | LaunchScreen.storyboard
| | | | | | Main.storyboard
| | | | | |  
 | | | | | +---Runner.xcodeproj
| | | | | | | project.pbxproj
| | | | | | |  
 | | | | | | +---project.xcworkspace
| | | | | | | | contents.xcworkspacedata
| | | | | | | |  
 | | | | | | | \---xcshareddata
| | | | | | | | IDEWorkspaceChecks.plist
| | | | | | | | WorkspaceSettings.xcsettings
| | | | | | | |  
 | | | | | | | \---swiftpm
| | | | | | | \---configuration
| | | | | | \---xcshareddata
| | | | | | \---xcschemes
| | | | | | Runner.xcscheme
| | | | | |  
 | | | | | +---Runner.xcworkspace
| | | | | | | contents.xcworkspacedata
| | | | | | |  
 | | | | | | \---xcshareddata
| | | | | | | IDEWorkspaceChecks.plist
| | | | | | | WorkspaceSettings.xcsettings
| | | | | | |  
 | | | | | | \---swiftpm
| | | | | | \---configuration
| | | | | \---RunnerTests
| | | | | RunnerTests.swift
| | | | |  
 | | | | +---lib
| | | | | main.dart
| | | | |  
 | | | | +---linux
| | | | | | CMakeLists.txt
| | | | | | main.cc
| | | | | | my_application.cc
| | | | | | my_application.h
| | | | | |  
 | | | | | \---flutter
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---macos
| | | | | +---Flutter
| | | | | | Flutter-Debug.xcconfig
| | | | | | Flutter-Release.xcconfig
| | | | | |  
 | | | | | +---Runner
| | | | | | | AppDelegate.swift
| | | | | | | DebugProfile.entitlements
| | | | | | | Info.plist
| | | | | | | MainFlutterWindow.swift
| | | | | | | Release.entitlements
| | | | | | |  
 | | | | | | +---Assets.xcassets
| | | | | | | \---AppIcon.appiconset
| | | | | | | app_icon_1024.png
| | | | | | | app_icon_128.png
| | | | | | | app_icon_16.png
| | | | | | | app_icon_256.png
| | | | | | | app_icon_32.png
| | | | | | | app_icon_512.png
| | | | | | | app_icon_64.png
| | | | | | | Contents.json
| | | | | | |  
 | | | | | | +---Base.lproj
| | | | | | | MainMenu.xib
| | | | | | |  
 | | | | | | \---Configs
| | | | | | AppInfo.xcconfig
| | | | | | Debug.xcconfig
| | | | | | Release.xcconfig
| | | | | | Warnings.xcconfig
| | | | | |  
 | | | | | +---Runner.xcodeproj
| | | | | | | project.pbxproj
| | | | | | |  
 | | | | | | +---project.xcworkspace
| | | | | | | \---xcshareddata
| | | | | | | | IDEWorkspaceChecks.plist
| | | | | | | |  
 | | | | | | | \---swiftpm
| | | | | | | \---configuration
| | | | | | \---xcshareddata
| | | | | | \---xcschemes
| | | | | | Runner.xcscheme
| | | | | |  
 | | | | | +---Runner.xcworkspace
| | | | | | | contents.xcworkspacedata
| | | | | | |  
 | | | | | | \---xcshareddata
| | | | | | | IDEWorkspaceChecks.plist
| | | | | | |  
 | | | | | | \---swiftpm
| | | | | | \---configuration
| | | | | \---RunnerTests
| | | | | RunnerTests.swift
| | | | |  
 | | | | +---web
| | | | | | favicon.png
| | | | | | index.html
| | | | | | manifest.json
| | | | | |  
 | | | | | \---icons
| | | | | Icon-192.png
| | | | | Icon-512.png
| | | | | Icon-maskable-192.png
| | | | | Icon-maskable-512.png
| | | | |  
 | | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---ios
| | | | | package_info_plus.podspec
| | | | |  
 | | | | \---package_info_plus
| | | | | Package.swift
| | | | |  
 | | | | \---Sources
| | | | \---package_info_plus
| | | | | FPPPackageInfoPlusPlugin.m
| | | | | PrivacyInfo.xcprivacy
| | | | |  
 | | | | \---include
| | | | \---package_info_plus
| | | | FPPPackageInfoPlusPlugin.h
| | | |  
 | | | +---lib
| | | | | package_info_plus.dart
| | | | |  
 | | | | \---src
| | | | file_attribute.dart
| | | | file_version_info.dart
| | | | package_info_plus_linux.dart
| | | | package_info_plus_macos.dart
| | | | package_info_plus_web.dart
| | | | package_info_plus_windows.dart
| | | |  
 | | | +---macos
| | | | | package_info_plus.podspec
| | | | |  
 | | | | \---package_info_plus
| | | | | Package.swift
| | | | |  
 | | | | \---Sources
| | | | \---package_info_plus
| | | | | FPPPackageInfoPlusPlugin.m
| | | | | PrivacyInfo.xcprivacy
| | | | |  
 | | | | \---include
| | | | \---package_info_plus
| | | | FPPPackageInfoPlusPlugin.h
| | | |  
 | | | \---test
| | | package_info_plus_linux_test.dart
| | | package_info_plus_windows_test.dart
| | | package_info_test.dart
| | |  
 | | +---path_provider_windows
| | | | AUTHORS
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---example
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---integration_test
| | | | | path_provider_test.dart
| | | | |  
 | | | | +---lib
| | | | | main.dart
| | | | |  
 | | | | +---test_driver
| | | | | integration_test.dart
| | | | |  
 | | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | run_loop.cpp
| | | | | run_loop.h
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---lib
| | | | | path_provider_windows.dart
| | | | |  
 | | | | \---src
| | | | folders.dart
| | | | folders_stub.dart
| | | | guid.dart
| | | | path_provider_windows_real.dart
| | | | path_provider_windows_stub.dart
| | | | win32_wrappers.dart
| | | |  
 | | | \---test
| | | guid_test.dart
| | | path_provider_windows_test.dart
| | |  
 | | +---screen_retriever_windows
| | | | analysis_options.yaml
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | \---windows
| | | | CMakeLists.txt
| | | | screen_retriever_windows_plugin.cpp
| | | | screen_retriever_windows_plugin.h
| | | | screen_retriever_windows_plugin_c_api.cpp
| | | |  
 | | | +---include
| | | | \---screen_retriever_windows
| | | | screen_retriever_windows_plugin_c_api.h
| | | |  
 | | | \---test
| | | screen_retriever_windows_plugin_test.cpp
| | |  
 | | +---shared_preferences_windows
| | | | AUTHORS
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---example
| | | | | AUTHORS
| | | | | LICENSE
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---integration_test
| | | | | shared_preferences_test.dart
| | | | |  
 | | | | +---lib
| | | | | main.dart
| | | | |  
 | | | | +---test_driver
| | | | | integration_test.dart
| | | | |  
 | | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | run_loop.cpp
| | | | | run_loop.h
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---lib
| | | | shared_preferences_windows.dart
| | | |  
 | | | \---test
| | | fake_path_provider_windows.dart
| | | legacy_shared_preferences_windows_test.dart
| | | shared_preferences_windows_async_test.dart
| | |  
 | | +---tray_manager
| | | | analysis_options.yaml
| | | | CHANGELOG.md
| | | | LICENSE
| | | | pubspec.yaml
| | | | README-ZH.md
| | | | README.md
| | | |  
 | | | +---example
| | | | | analysis_options.yaml
| | | | | pubspec.yaml
| | | | | README.md
| | | | |  
 | | | | +---images
| | | | | tray_icon.ico
| | | | | tray_icon.png
| | | | | tray_icon_original.ico
| | | | | tray_icon_original.png
| | | | |  
 | | | | +---lib
| | | | | | main.dart
| | | | | |  
 | | | | | \---pages
| | | | | home.dart
| | | | |  
 | | | | +---linux
| | | | | | CMakeLists.txt
| | | | | | main.cc
| | | | | | my_application.cc
| | | | | | my_application.h
| | | | | |  
 | | | | | \---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | | generated_plugin_registrant.cc
| | | | | generated_plugin_registrant.h
| | | | |  
 | | | | +---macos
| | | | | | Podfile
| | | | | | Podfile.lock
| | | | | |  
 | | | | | +---Flutter
| | | | | | Flutter-Debug.xcconfig
| | | | | | Flutter-Release.xcconfig
| | | | | | GeneratedPluginRegistrant.swift
| | | | | |  
 | | | | | +---Runner
| | | | | | | AppDelegate.swift
| | | | | | | DebugProfile.entitlements
| | | | | | | Info.plist
| | | | | | | MainFlutterWindow.swift
| | | | | | | Release.entitlements
| | | | | | |  
 | | | | | | +---Assets.xcassets
| | | | | | | \---AppIcon.appiconset
| | | | | | | app_icon_1024.png
| | | | | | | app_icon_128.png
| | | | | | | app_icon_16.png
| | | | | | | app_icon_256.png
| | | | | | | app_icon_32.png
| | | | | | | app_icon_512.png
| | | | | | | app_icon_64.png
| | | | | | | Contents.json
| | | | | | |  
 | | | | | | +---Base.lproj
| | | | | | | MainMenu.xib
| | | | | | |  
 | | | | | | \---Configs
| | | | | | AppInfo.xcconfig
| | | | | | Debug.xcconfig
| | | | | | Release.xcconfig
| | | | | | Warnings.xcconfig
| | | | | |  
 | | | | | +---Runner.xcodeproj
| | | | | | | project.pbxproj
| | | | | | |  
 | | | | | | +---project.xcworkspace
| | | | | | | \---xcshareddata
| | | | | | | | IDEWorkspaceChecks.plist
| | | | | | | |  
 | | | | | | | \---swiftpm
| | | | | | | \---configuration
| | | | | | \---xcshareddata
| | | | | | \---xcschemes
| | | | | | Runner.xcscheme
| | | | | |  
 | | | | | \---Runner.xcworkspace
| | | | | | contents.xcworkspacedata
| | | | | |  
 | | | | | \---xcshareddata
| | | | | | IDEWorkspaceChecks.plist
| | | | | |  
 | | | | | \---swiftpm
| | | | | \---configuration
| | | | \---windows
| | | | | CMakeLists.txt
| | | | |  
 | | | | +---flutter
| | | | | CMakeLists.txt
| | | | | generated_plugins.cmake
| | | | | generated_plugin_registrant.cc
| | | | | generated_plugin_registrant.h
| | | | |  
 | | | | \---runner
| | | | | CMakeLists.txt
| | | | | flutter_window.cpp
| | | | | flutter_window.h
| | | | | main.cpp
| | | | | resource.h
| | | | | runner.exe.manifest
| | | | | Runner.rc
| | | | | run_loop.cpp
| | | | | run_loop.h
| | | | | utils.cpp
| | | | | utils.h
| | | | | win32_window.cpp
| | | | | win32_window.h
| | | | |  
 | | | | \---resources
| | | | app_icon.ico
| | | |  
 | | | +---lib
| | | | | tray_manager.dart
| | | | |  
 | | | | \---src
| | | | | tray_listener.dart
| | | | | tray_manager.dart
| | | | |  
 | | | | \---helpers
| | | | sandbox.dart
| | | |  
 | | | +---linux
| | | | | CMakeLists.txt
| | | | | tray_manager_plugin.cc
| | | | |  
 | | | | \---include
| | | | \---tray_manager
| | | | tray_manager_plugin.h
| | | |  
 | | | +---macos
| | | | | tray_manager.podspec
| | | | |  
 | | | | \---Classes
| | | | TrayIcon.swift
| | | | TrayManagerPlugin.swift
| | | | TrayMenu.swift
| | | |  
 | | | +---packages
| | | | \---tray_manager_ffi
| | | | +---lib
| | | | \---test
| | | +---screenshots
| | | | linux.png
| | | | macos.png
| | | | windows.png
| | | |  
 | | | \---windows
| | | | CMakeLists.txt
| | | | tray_manager_plugin.cpp
| | | |  
 | | | \---include
| | | \---tray_manager
| | | tray_manager_plugin.h
| | |  
 | | \---window_manager
| | | analysis_options.yaml
| | | CHANGELOG.md
| | | dart_dependency_validator.yaml
| | | LICENSE
| | | pubspec.yaml
| | | README-ZH.md
| | | README.md
| | |  
 | | +---example
| | | | analysis_options.yaml
| | | | pubspec.yaml
| | | | README.md
| | | |  
 | | | +---images
| | | | tray_icon.ico
| | | | tray_icon.png
| | | | tray_icon_original.ico
| | | | tray_icon_original.png
| | | |  
 | | | +---integration_test
| | | | window_manager_test.dart
| | | |  
 | | | +---lib
| | | | | main.dart
| | | | |  
 | | | | +---pages
| | | | | home.dart
| | | | |  
 | | | | \---utils
| | | | config.dart
| | | |  
 | | | +---linux
| | | | | CMakeLists.txt
| | | | | main.cc
| | | | | my_application.cc
| | | | | my_application.h
| | | | |  
 | | | | \---flutter
| | | | CMakeLists.txt
| | | |  
 | | | +---macos
| | | | | Podfile
| | | | | Podfile.lock
| | | | |  
 | | | | +---Flutter
| | | | | Flutter-Debug.xcconfig
| | | | | Flutter-Release.xcconfig
| | | | | GeneratedPluginRegistrant.swift
| | | | |  
 | | | | +---Runner
| | | | | | AppDelegate.swift
| | | | | | DebugProfile.entitlements
| | | | | | Info.plist
| | | | | | MainFlutterWindow.swift
| | | | | | Release.entitlements
| | | | | |  
 | | | | | +---Assets.xcassets
| | | | | | \---AppIcon.appiconset
| | | | | | app_icon_1024.png
| | | | | | app_icon_128.png
| | | | | | app_icon_16.png
| | | | | | app_icon_256.png
| | | | | | app_icon_32.png
| | | | | | app_icon_512.png
| | | | | | app_icon_64.png
| | | | | | Contents.json
| | | | | |  
 | | | | | +---Base.lproj
| | | | | | MainMenu.xib
| | | | | |  
 | | | | | \---Configs
| | | | | AppInfo.xcconfig
| | | | | Debug.xcconfig
| | | | | Release.xcconfig
| | | | | Warnings.xcconfig
| | | | |  
 | | | | +---Runner.xcodeproj
| | | | | | project.pbxproj
| | | | | |  
 | | | | | +---project.xcworkspace
| | | | | | \---xcshareddata
| | | | | | | IDEWorkspaceChecks.plist
| | | | | | |  
 | | | | | | \---swiftpm
| | | | | | \---configuration
| | | | | \---xcshareddata
| | | | | \---xcschemes
| | | | | Runner.xcscheme
| | | | |  
 | | | | +---Runner.xcworkspace
| | | | | | contents.xcworkspacedata
| | | | | |  
 | | | | | \---xcshareddata
| | | | | | IDEWorkspaceChecks.plist
| | | | | |  
 | | | | | \---swiftpm
| | | | | \---configuration
| | | | \---RunnerTests
| | | | RunnerTests.swift
| | | |  
 | | | +---test
| | | | widget_test.dart
| | | |  
 | | | \---windows
| | | | CMakeLists.txt
| | | |  
 | | | +---flutter
| | | | CMakeLists.txt
| | | |  
 | | | \---runner
| | | | CMakeLists.txt
| | | | flutter_window.cpp
| | | | flutter_window.h
| | | | main.cpp
| | | | resource.h
| | | | runner.exe.manifest
| | | | Runner.rc
| | | | utils.cpp
| | | | utils.h
| | | | win32_window.cpp
| | | | win32_window.h
| | | |  
 | | | \---resources
| | | app_icon.ico
| | |  
 | | +---lib
| | | | window_manager.dart
| | | |  
 | | | \---src
| | | | resize_edge.dart
| | | | title_bar_style.dart
| | | | window_listener.dart
| | | | window_manager.dart
| | | | window_options.dart
| | | |  
 | | | +---utils
| | | | calc_window_position.dart
| | | |  
 | | | \---widgets
| | | drag_to_move_area.dart
| | | drag_to_resize_area.dart
| | | virtual_window_frame.dart
| | | window_caption.dart
| | | window_caption_button.dart
| | |  
 | | +---linux
| | | | CMakeLists.txt
| | | | window_manager_plugin.cc
| | | |  
 | | | \---include
| | | \---window_manager
| | | window_manager_plugin.h
| | |  
 | | +---macos
| | | | window_manager.podspec
| | | |  
 | | | \---window_manager
| | | | Package.swift
| | | |  
 | | | \---Sources
| | | \---window_manager
| | | WindowManager.swift
| | | WindowManagerPlugin.swift
| | |  
 | | +---test
| | | window_manager_test.dart
| | |  
 | | \---windows
| | | CMakeLists.txt
| | | window_manager.cpp
| | | window_manager_plugin.cpp
| | |  
 | | \---include
| | \---window_manager
| | window_manager_plugin.h
| |  
 | \---cpp_client_wrapper
| | binary_messenger_impl.h
| | byte_buffer_streams.h
| | core_implementations.cc
| | engine_method_result.cc
| | flutter_engine.cc
| | flutter_view_controller.cc
| | plugin_registrar.cc
| | readme
| | standard_codec.cc
| | texture_registrar_impl.h
| |  
 | \---include
| \---flutter
| basic_message_channel.h
| binary_messenger.h
| byte_streams.h
| dart_project.h
| encodable_value.h
| engine_method_result.h
| event_channel.h
| event_sink.h
| event_stream_handler.h
| event_stream_handler_functions.h
| flutter_engine.h
| flutter_view.h
| flutter_view_controller.h
| message_codec.h
| method_call.h
| method_channel.h
| method_codec.h
| method_result.h
| method_result_functions.h
| plugin_registrar.h
| plugin_registrar_windows.h
| plugin_registry.h
| standard_codec_serializer.h
| standard_message_codec.h
| standard_method_codec.h
| texture_registrar.h
|  
 \---runner
| CMakeLists.txt
| flutter_window.cpp
| flutter_window.h
| main.cpp
| overlay_window_plugin.cpp
| resource.h
| runner.exe.manifest
| Runner.rc
| utils.cpp
| utils.h
| win32_window.cpp
| win32_window.h
|  
 \---resources
app_icon.ico

## Rules

- Use Flutter best practices
- Use clean architecture
- Avoid unnecessary packages
- Keep widgets reusable
- Prefer Provider for state management
- Maintain null safety
- Separate UI, services, and models

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
