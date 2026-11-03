import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// One viewer window for one Markdown file. Renders with `md2html --github`
// (md4c, already on every Omarchy install) into Qt rich text, themed from
// the current Omarchy palette. Reloads when the file or the theme changes.
FloatingWindow {
  id: win

  property string file: ""
  signal dismissed()

  readonly property string fileName: file.substring(file.lastIndexOf("/") + 1)
  readonly property string fileDir: file.substring(0, file.lastIndexOf("/") + 1)
  readonly property string home: Quickshell.env("HOME")
  property string body: ""
  property string source: ""
  property bool showSource: false
  property real zoom: 1.0
  property string status: ""

  // Palette from theme/colors.toml; fallbacks are a neutral dark theme.
  property var c: ({
    background: "#1a1b26", foreground: "#c0caf5", accent: "#7aa2f7",
    muted: "#565f89", selection: "#283457", lighter_background: "#24283b",
    dark_background: "#16161e", yellow: "#e0af68", green: "#9ece6a", red: "#f7768e"
  })

  title: fileName + " — mdview"
  implicitWidth: 960
  implicitHeight: 1080
  color: c.background
  visible: true
  onVisibleChanged: if (!visible) dismissed()

  function parseToml(t) {
    var out = Object.assign({}, win.c)
    String(t).split("\n").forEach(function(line) {
      var m = line.match(/^\s*([A-Za-z_]+)\s*=\s*"([^"]*)"/)
      if (m) out[m[1]] = m[2]
    })
    return out
  }

  function styled(html) {
    var p = win.c
    var css = `
      a { color: ${p.accent}; text-decoration: none; }
      h1, h2 { color: ${p.accent}; }
      h3, h4, h5, h6 { color: ${p.yellow}; }
      code { font-family: 'JetBrainsMono Nerd Font', monospace; color: ${p.green};
             background-color: ${p.lighter_background}; }
      pre { white-space: pre-wrap; font-family: 'JetBrainsMono Nerd Font', monospace;
            background-color: ${p.lighter_background}; margin: 8px 0; }
      blockquote { color: ${p.muted}; margin-left: 16px; }
      th { color: ${p.accent}; background-color: ${p.lighter_background}; }
      hr { color: ${p.muted}; }
    `
    // Qt draws no table grid unless asked for one.
    html = html.replace(/<table>/g,
      `<table border="1" cellspacing="0" cellpadding="6" style="border-color:${p.muted}; border-collapse: collapse;">`)
    return `<html><head><style>${css}</style></head><body>${html}</body></html>`
  }

  function render() {
    if (!win.file) return
    md.running = false
    md.running = true
  }

  FileView {
    path: win.home + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { win.c = win.parseToml(text()); win.render() }
  }

  FileView {
    id: srcFile
    path: win.file
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { win.source = text(); win.render() }
    onLoadFailed: win.status = "Cannot read " + win.file
  }

  Process {
    id: md
    command: ["md2html", "--github", win.file]
    stdout: StdioCollector {
      onStreamFinished: { win.body = win.styled(text); win.status = "" }
    }
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: !search.visible

    function scrollBy(dy) {
      var max = Math.max(0, flick.contentHeight - flick.height)
      flick.contentY = Math.max(0, Math.min(max, flick.contentY + dy))
    }
    function zoomBy(d) { win.zoom = Math.max(0.5, Math.min(3, win.zoom + d)) }

    Keys.onPressed: function(e) {
      var ctrl = e.modifiers & Qt.ControlModifier
      var shift = e.modifiers & Qt.ShiftModifier
      var page = flick.height * 0.9
      if (ctrl && e.key === Qt.Key_C) doc.copy()
      else if (ctrl && e.key === Qt.Key_F) search.open()
      else if (ctrl && (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)) zoomBy(0.1)
      else if (ctrl && e.key === Qt.Key_Minus) zoomBy(-0.1)
      else if (ctrl && e.key === Qt.Key_0) win.zoom = 1.0
      else if (ctrl && e.key === Qt.Key_D) scrollBy(page / 2)
      else if (ctrl && e.key === Qt.Key_U) scrollBy(-page / 2)
      else if (ctrl) return
      else if (e.key === Qt.Key_Q || e.key === Qt.Key_Escape) win.visible = false
      else if (e.key === Qt.Key_J || e.key === Qt.Key_Down) scrollBy(60)
      else if (e.key === Qt.Key_K || e.key === Qt.Key_Up) scrollBy(-60)
      else if (e.key === Qt.Key_Space || e.key === Qt.Key_PageDown) scrollBy(shift ? -page : page)
      else if (e.key === Qt.Key_B || e.key === Qt.Key_PageUp) scrollBy(-page)
      else if (e.key === Qt.Key_Home || (e.key === Qt.Key_G && !shift)) flick.contentY = 0
      else if (e.key === Qt.Key_End || e.key === Qt.Key_G) scrollBy(1e9)
      else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) zoomBy(0.1)
      else if (e.key === Qt.Key_Minus) zoomBy(-0.1)
      else if (e.key === Qt.Key_0) win.zoom = 1.0
      else if (e.key === Qt.Key_S) win.showSource = !win.showSource
      else if (e.key === Qt.Key_R) srcFile.reload()
      else if (e.key === Qt.Key_Slash) search.open()
      else if (e.key === Qt.Key_N) search.find(!shift)
      else if (e.key === Qt.Key_E) Quickshell.execDetached(["xdg-open", win.fileDir])
      else return
      e.accepted = true
    }

    Flickable {
      id: flick
      anchors { top: parent.top; left: parent.left; right: parent.right; bottom: bar.top }
      contentWidth: width
      contentHeight: doc.height + 64
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      TextEdit {
        id: doc
        y: 32
        width: Math.min(flick.width - 64, 860 * win.zoom)
        x: (flick.width - width) / 2
        readOnly: true
        selectByMouse: true
        activeFocusOnPress: false
        wrapMode: TextEdit.Wrap
        textFormat: win.showSource ? TextEdit.PlainText : TextEdit.RichText
        text: win.showSource ? win.source : win.body
        baseUrl: "file://" + win.fileDir
        color: win.c.foreground
        selectionColor: win.c.selection
        selectedTextColor: win.c.foreground
        font.family: win.showSource ? "JetBrainsMono Nerd Font" : "Liberation Sans"
        font.pixelSize: Math.round((win.showSource ? 14 : 17) * win.zoom)
        onLinkActivated: function(link) { Qt.openUrlExternally(link) }

        HoverHandler {
          cursorShape: doc.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
        }
      }
    }

    // Bottom bar: file path, find box, key hints.
    Rectangle {
      id: bar
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: 28
      color: win.c.dark_background

      Text {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: bar.width > 900 ? parent.width * 0.4 : parent.width - 24
        text: (win.status || win.file.replace(win.home, "~"))
              + (win.showSource ? "  [source]" : "")
              + (win.zoom !== 1.0 ? "  " + Math.round(win.zoom * 100) + "%" : "")
        color: win.status ? win.c.red : win.c.muted
        font.pixelSize: 12
        elide: Text.ElideMiddle
      }

      TextField {
        id: search
        visible: false
        anchors.centerIn: parent
        width: 260
        height: 22
        font.pixelSize: 12
        placeholderText: "find…  (Enter next, Esc close)"
        color: win.c.foreground
        background: Rectangle { color: win.c.lighter_background; radius: 3 }
        property int last: -1

        function open() { visible = true; forceActiveFocus(); selectAll() }
        function close() { visible = false; keys.forceActiveFocus() }
        function find(forward) {
          if (!search.text) return
          var hay = doc.getText(0, doc.length).toLowerCase()
          var needle = search.text.toLowerCase()
          var i = forward ? hay.indexOf(needle, last + 1) : hay.lastIndexOf(needle, Math.max(0, last - 1))
          if (i < 0) i = forward ? hay.indexOf(needle) : hay.lastIndexOf(needle)
          if (i < 0) { win.status = "Not found: " + search.text; return }
          win.status = ""
          last = i
          doc.select(i, i + needle.length)
          var r = doc.positionToRectangle(i)
          flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height,
                                                doc.y + r.y - flick.height / 3))
        }
        onTextChanged: { last = -1; find(true) }
        Keys.onReturnPressed: function(e) { find(!(e.modifiers & Qt.ShiftModifier)) }
        Keys.onEscapePressed: close()
      }

      Text {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        visible: bar.width > 900
        text: "j/k space/b g/G  / find  s source  ±0 zoom  e folder  q quit"
        color: win.c.muted
        font.pixelSize: 12
      }
    }
  }
}
