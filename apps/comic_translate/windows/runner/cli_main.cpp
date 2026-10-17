// Entry point of cts.exe, the console command-line interface.
//
// cts.exe is built from the same sources as the GUI executable and shares its
// engine, Dart code, assets and plugins. It is a console-subsystem program, so
// shells wait for it, stdout/stderr work natively and the exit code set by
// Dart's `exit()` is returned to the caller. The Flutter window is created but
// never shown: the engine is still needed for dart:ui text rendering.

#include <flutter/dart_project.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Marks the Dart entrypoint arguments as a CLI invocation; see lib/main.dart.
constexpr char kCliFlag[] = "--cts-cli";

int wmain(int argc, wchar_t** argv) {
  ::SetConsoleOutputCP(CP_UTF8);
  ::SetConsoleCP(CP_UTF8);

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> arguments = GetCommandLineArguments();
  arguments.insert(arguments.begin(), kCliFlag);
  project.set_dart_entrypoint_arguments(std::move(arguments));

  FlutterWindow window(project, /*visible=*/false);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(640, 480);
  if (!window.Create(L"cts", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Dart terminates the process with exit(code) when the command finishes.
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
