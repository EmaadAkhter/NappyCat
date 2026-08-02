#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <fstream>
#include <string>

#include "flutter_window.h"
#include "utils.h"

bool g_pin_to_desktop = false;

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Desktop-widget mode: Windows offers no home-screen widget surface (the
  // Win+W board is a drawer), so --widget pins a frameless mini cat card to
  // the desktop layer instead - above the wallpaper, underneath every app.
  const bool widget_mode =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--widget") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(widget_mode ? 340 : 430, widget_mode ? 460 : 800);
  if (!window.Create(L"NappyCat", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  if (widget_mode) {
    HWND hwnd = window.GetHandle();
    // Frameless, no taskbar entry, parked top-right, and kept at the bottom
    // of the Z-order (the WM_WINDOWPOSCHANGING hook stops clicks raising it).
    ::SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE,
                       ::GetWindowLongPtr(hwnd, GWL_EXSTYLE) |
                           WS_EX_TOOLWINDOW);
    RECT work;
    ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
    int x = work.right - 340 - 24;
    int y = work.top + 24;
    // Reopen where they last parked it, unless that spot fell off-screen
    // (monitor unplugged, resolution change) - then the default corner.
    wchar_t local_app_data[MAX_PATH];
    if (::GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data,
                                  MAX_PATH) > 0) {
      std::ifstream f(std::wstring(local_app_data) + L"\\NappyCat\\widget_pos.txt");
      int sx, sy;
      if (f >> sx >> sy) {
        RECT probe = {sx, sy, sx + 340, sy + 460};
        if (::MonitorFromRect(&probe, MONITOR_DEFAULTTONULL) != nullptr) {
          x = sx;
          y = sy;
        }
      }
    }
    g_pin_to_desktop = true;
    ::SetWindowPos(hwnd, HWND_BOTTOM, x, y, 340, 460,
                   SWP_FRAMECHANGED | SWP_NOACTIVATE);
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
