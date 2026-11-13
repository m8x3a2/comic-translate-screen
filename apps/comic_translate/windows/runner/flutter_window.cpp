#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shlobj.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

// UTF-8 from Dart to the UTF-16 Windows wants.
std::wstring Wide(const std::string& utf8) {
  const int n = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring wide(n > 0 ? n - 1 : 0, L'\0');
  if (n > 1) {
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), n);
  }
  return wide;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool visible)
    : project_(project), visible_(visible) {}

FlutterWindow::~FlutterWindow() {
  if (big_icon_ != nullptr) DestroyIcon(big_icon_);
  if (small_icon_ != nullptr) DestroyIcon(small_icon_);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "comic_translate/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setFullScreen") {
          const auto* on = std::get_if<bool>(call.arguments());
          if (on == nullptr) {
            result->Error("bad_args", "setFullScreen expects a bool");
            return;
          }
          SetFullScreen(*on);
          result->Success(flutter::EncodableValue(full_screen_));
        } else if (call.method_name() == "isFullScreen") {
          result->Success(flutter::EncodableValue(full_screen_));
        } else if (call.method_name() == "setTitle") {
          const auto* title = std::get_if<std::string>(call.arguments());
          if (title == nullptr) {
            result->Error("bad_args", "setTitle expects a string");
            return;
          }
          SetWindowTextW(GetHandle(), Wide(*title).c_str());
          result->Success();
        } else if (call.method_name() == "setIcon") {
          const auto* which = std::get_if<std::string>(call.arguments());
          if (which == nullptr) {
            result->Error("bad_args", "setIcon expects a string");
            return;
          }
          result->Success(flutter::EncodableValue(SetIcon(Wide(*which))));
        } else if (call.method_name() == "refreshShellIcons") {
          // Shortcuts got a new icon: Explorer redraws them now, not later.
          SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (!visible_) {
    return true;
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

// As Chromium's FullscreenHandler: restore from maximized first, drop the
// frame, cover the monitor; on exit put everything back.
void FlutterWindow::SetFullScreen(bool full_screen) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || full_screen == full_screen_) {
    return;
  }
  if (full_screen) {
    was_maximized_ = IsZoomed(hwnd) != 0;
    if (was_maximized_) {
      SendMessage(hwnd, WM_SYSCOMMAND, SC_RESTORE, 0);
    }
    saved_style_ = GetWindowLong(hwnd, GWL_STYLE);
    saved_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);
    GetWindowRect(hwnd, &saved_rect_);
    SetWindowLong(hwnd, GWL_STYLE,
                  saved_style_ & ~(WS_CAPTION | WS_THICKFRAME));
    SetWindowLong(hwnd, GWL_EXSTYLE,
                  saved_ex_style_ & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE |
                                      WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                   &monitor);
    const RECT& r = monitor.rcMonitor;
    SetWindowPos(hwnd, nullptr, r.left, r.top, r.right - r.left,
                 r.bottom - r.top,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  } else {
    SetWindowLong(hwnd, GWL_STYLE, saved_style_);
    SetWindowLong(hwnd, GWL_EXSTYLE, saved_ex_style_);
    const RECT& r = saved_rect_;
    SetWindowPos(hwnd, nullptr, r.left, r.top, r.right - r.left,
                 r.bottom - r.top,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    if (was_maximized_) {
      SendMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
    }
  }
  full_screen_ = full_screen;
}

bool FlutterWindow::SetIcon(const std::wstring& which) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return false;
  }
  const UINT dpi = GetDpiForWindow(hwnd);
  const int big_px = GetSystemMetricsForDpi(SM_CXICON, dpi);
  const int small_px = GetSystemMetricsForDpi(SM_CXSMICON, dpi);
  HICON new_big = nullptr;
  HICON new_small = nullptr;
  if (which == L"green" || which == L"blue" || which == L"navy" ||
      which.empty()) {
    HINSTANCE module = GetModuleHandle(nullptr);
    LPCWSTR id = MAKEINTRESOURCE(which == L"navy"   ? IDI_NAVY_ICON
                                 : which == L"blue" ? IDI_BLUE_ICON
                                                    : IDI_APP_ICON);
    new_big = static_cast<HICON>(
        LoadImageW(module, id, IMAGE_ICON, big_px, big_px, LR_DEFAULTCOLOR));
    new_small = static_cast<HICON>(
        LoadImageW(module, id, IMAGE_ICON, small_px, small_px, LR_DEFAULTCOLOR));
  } else {
    new_big = static_cast<HICON>(LoadImageW(nullptr, which.c_str(), IMAGE_ICON,
                                            big_px, big_px, LR_LOADFROMFILE));
    new_small = static_cast<HICON>(LoadImageW(
        nullptr, which.c_str(), IMAGE_ICON, small_px, small_px, LR_LOADFROMFILE));
  }
  if (new_big == nullptr || new_small == nullptr) {
    if (new_big != nullptr) DestroyIcon(new_big);
    if (new_small != nullptr) DestroyIcon(new_small);
    return false;
  }
  SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(new_big));
  SendMessage(hwnd, WM_SETICON, ICON_SMALL,
              reinterpret_cast<LPARAM>(new_small));
  if (big_icon_ != nullptr) DestroyIcon(big_icon_);
  if (small_icon_ != nullptr) DestroyIcon(small_icon_);
  big_icon_ = new_big;
  small_icon_ = new_small;
  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      // Page list, page and text panel need room side by side.
      const UINT dpi = GetDpiForWindow(hwnd);
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = MulDiv(1024, dpi, 96);
      info->ptMinTrackSize.y = MulDiv(640, dpi, 96);
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
