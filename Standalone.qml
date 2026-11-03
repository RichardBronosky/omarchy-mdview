import QtQuick
import Quickshell

// Fallback used by bin/mdview when the plugin is not enabled in omarchy-shell:
//   MDVIEW_FILE=/abs/path.md qs -p Standalone.qml
ShellRoot {
  ViewerWindow {
    file: Quickshell.env("MDVIEW_FILE") || ""
    onDismissed: Qt.quit()
  }
}
