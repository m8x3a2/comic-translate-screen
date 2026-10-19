#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // When |visible| is false the window is never shown; this is used by the
  // console CLI (cts.exe), which needs the engine (dart:ui text rendering,
  // plugins) but no UI.
  explicit FlutterWindow(const flutter::DartProject& project,
                         bool visible = true);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Full screen (F11): no frame, covering the whole monitor and the taskbar.
  // The window's style, position and maximized state come back on exit.
  void SetFullScreen(bool full_screen);

  // The project to run.
  flutter::DartProject project_;

  // Whether the window is shown after the first frame.
  bool visible_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // "comic_translate/window": full screen on and off from Dart.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  bool full_screen_ = false;
  bool was_maximized_ = false;
  LONG saved_style_ = 0;
  LONG saved_ex_style_ = 0;
  RECT saved_rect_{};
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
