#include "flutter_window.h"

#include <windowsx.h>

#include <fstream>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  drag_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "nappycat/widget",
          &flutter::StandardMethodCodec::GetInstance());
  drag_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "drag") {
          ::ReleaseCapture();
          ::SendMessage(GetHandle(), WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        } else if (call.method_name() == "resize") {
          ::ReleaseCapture();
          ::SendMessage(GetHandle(), WM_NCLBUTTONDOWN, HTBOTTOMRIGHT, 0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
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
    case WM_WINDOWPOSCHANGING:
      // Desktop-widget mode: refuse every raise so the card stays glued to
      // the desktop layer, under normal application windows.
      if (g_pin_to_desktop) {
        reinterpret_cast<WINDOWPOS*>(lparam)->hwndInsertAfter = HWND_BOTTOM;
      }
      break;
    case WM_NCCALCSIZE:
      // Widget mode: eat the THICKFRAME's visual frame — client area covers
      // the whole window, only the resize behavior remains.
      if (g_pin_to_desktop && wparam) {
        return 0;
      }
      break;
    case WM_GETMINMAXINFO:
      if (g_pin_to_desktop) {
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize = {260, 340};
      }
      break;
    case WM_NCHITTEST: {
      // Movable widget: the top strip (and Ctrl+anywhere) acts as a grab
      // handle; the rest of the card stays tappable for the letter reveal.
      if (!g_pin_to_desktop) break;
      LRESULT hit = ::DefWindowProc(hwnd, message, wparam, lparam);
      if (hit == HTCLIENT) {
        POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        RECT rc;
        ::GetWindowRect(hwnd, &rc);
        const bool ctrl_held = (::GetKeyState(VK_CONTROL) & 0x8000) != 0;
        if (ctrl_held || pt.y - rc.top < 28) {
          return HTCAPTION;
        }
      }
      return hit;
    }
    case WM_EXITSIZEMOVE:
      // Remember where they parked the cat.
      if (g_pin_to_desktop) {
        RECT rc;
        ::GetWindowRect(hwnd, &rc);
        wchar_t local_app_data[MAX_PATH];
        if (::GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data,
                                      MAX_PATH) > 0) {
          std::wstring dir = std::wstring(local_app_data) + L"\\NappyCat";
          ::CreateDirectoryW(dir.c_str(), nullptr);
          std::ofstream f(dir + L"\\widget_pos.txt", std::ios::trunc);
          if (f) {
            f << rc.left << " " << rc.top << " " << (rc.right - rc.left)
              << " " << (rc.bottom - rc.top);
          }
        }
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
