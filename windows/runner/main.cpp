#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Set DPI awareness context programmatically to ensure PerMonitorV2 is active
  // even if manifest fails to load.
  HMODULE hUser32 = LoadLibrary(L"user32.dll");
  if (hUser32) {
    typedef BOOL(WINAPI* SetProcessDpiAwarenessContextFn)(DPI_AWARENESS_CONTEXT);
    auto setProcessDpiAwarenessContext =
        reinterpret_cast<SetProcessDpiAwarenessContextFn>(
            GetProcAddress(hUser32, "SetProcessDpiAwarenessContext"));
    if (setProcessDpiAwarenessContext) {
      setProcessDpiAwarenessContext(reinterpret_cast<DPI_AWARENESS_CONTEXT>(-4)); // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    }
    FreeLibrary(hUser32);
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

#ifndef FLAVOR_APP_NAME
#define FLAVOR_APP_NAME "BreakMate"
#endif

  std::string app_name = FLAVOR_APP_NAME;
  std::wstring w_app_name(app_name.begin(), app_name.end());

  if (!window.Create(w_app_name.c_str(), origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
