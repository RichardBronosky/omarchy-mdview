import QtQuick
import Quickshell

// Panel entry point for bronosky.mdview. Every summon opens one viewer window:
//   omarchy-shell shell summon bronosky.mdview '{"file":"/abs/path/README.md"}'
// When the last window closes, the plugin tells the shell it is done so the
// panel unloads and uses no memory until the next summon.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "bronosky.mdview"
  property var windows: []
  readonly property bool opened: windows.length > 0

  Component {
    id: windowComponent
    ViewerWindow {}
  }

  function open(payloadJson) {
    var file = ""
    try {
      var payload = JSON.parse(String(payloadJson || "{}"))
      if (payload && typeof payload.file === "string") file = payload.file
    } catch (e) { /* fall through to the warning below */ }

    if (!file) {
      console.warn(pluginId + ": summon payload needs {\"file\": \"/abs/path.md\"}")
      if (windows.length === 0) release()
      return
    }

    var win = windowComponent.createObject(root, { file: file })
    win.dismissed.connect(function() { forget(win) })
    windows = windows.concat([win])
  }

  // Host-initiated close (`omarchy-shell shell hide bronosky.mdview`).
  function close() {
    var all = windows
    windows = []
    all.forEach(function(w) { w.visible = false; w.destroy() })
  }

  function forget(win) {
    windows = windows.filter(function(w) { return w !== win })
    win.destroy()
    if (windows.length === 0) release()
  }

  function release() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }
}
