import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.skedar.system-monitor"

  property bool popupOpen: false
  property int cpuUsage: 0
  property int cpuTemperature: 0
  property int memoryUsage: 0
  property real memoryUsedBytes: 0
  property real memoryTotalBytes: 0
  property int diskUsage: 0
  property real diskUsedBytes: 0
  property real diskTotalBytes: 0
  property string gpuNames: ""
  property int gpuUsage: -1
  property int gpuTemperature: 0

  readonly property bool opened: popupOpen
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
  }

  function parseInteger(value, fallback) {
    var parsed = Number(value)
    return isNaN(parsed) ? fallback : Math.round(parsed)
  }

  function parseNumber(value, fallback) {
    var parsed = Number(value)
    return isNaN(parsed) ? fallback : parsed
  }

  function formatBytes(bytes) {
    var numeric = Math.max(0, Number(bytes) || 0)
    var units = ["B", "K", "M", "G", "T", "P"]
    var index = 0
    while (numeric >= 1024 && index < units.length - 1) {
      numeric /= 1024
      index += 1
    }

    var rounded = numeric >= 100 || index === 0
      ? Math.round(numeric).toString()
      : (Math.round(numeric * 10) / 10).toFixed(1).replace(/\.0$/, "")
    return rounded.replace(".", ",") + units[index]
  }

  function refresh() {
    if (!statsProcess.running) statsProcess.running = true
  }

  function open() {
    popupOpen = true
    refresh()
  }

  function close() {
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  function launchBtop() {
    close()
    if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
  }

  function openGitHubPages() {
    close()
    if (root.bar) root.bar.run("xdg-open https://skedar.github.io/")
  }

  function parseStats(raw) {
    var lines = String(raw || "").trim().split("\n")

    for (var i = 0; i < lines.length; i += 1) {
      var fields = lines[i].split("|")
      if (fields.length < 2) continue

      if (fields[0] === "CPU" && fields.length >= 3) {
        cpuUsage = clamp(parseInteger(fields[1], 0), 0, 100)
        cpuTemperature = Math.max(parseInteger(fields[2], 0), 0)
      } else if (fields[0] === "MEM" && fields.length >= 4) {
        memoryUsage = clamp(parseInteger(fields[1], 0), 0, 100)
        memoryUsedBytes = Math.max(parseNumber(fields[2], 0), 0)
        memoryTotalBytes = Math.max(parseNumber(fields[3], 0), 0)
      } else if (fields[0] === "DISK" && fields.length >= 4) {
        diskUsage = clamp(parseInteger(fields[1], 0), 0, 100)
        diskUsedBytes = Math.max(parseNumber(fields[2], 0), 0)
        diskTotalBytes = Math.max(parseNumber(fields[3], 0), 0)
      } else if (fields[0] === "GPU" && fields.length >= 4) {
        gpuNames = fields[1].trim().replace(/,/g, "|")
        gpuUsage = clamp(parseInteger(fields[2], -1), -1, 100)
        gpuTemperature = Math.max(parseInteger(fields[3], 0), 0)
      }
    }
  }

  onPopupOpenChanged: {
    if (popupOpen) refresh()
  }

  Process {
    id: statsProcess
    command: [
      "bash",
      "-c",
      "read _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ < /proc/stat; " +
      "total1=$((u1+n1+s1+i1+iw1+irq1+sirq1+st1)); idle1=$((i1+iw1)); " +
      "sleep 0.15; " +
      "read _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ < /proc/stat; " +
      "total2=$((u2+n2+s2+i2+iw2+irq2+sirq2+st2)); idle2=$((i2+iw2)); " +
      "delta_total=$((total2-total1)); delta_idle=$((idle2-idle1)); " +
      "if [ \"$delta_total\" -gt 0 ]; then cpu=$((100*(delta_total-delta_idle)/delta_total)); else cpu=0; fi; " +
      "read memory_total memory_available <<EOF\n$(awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 } END { print total, available }' /proc/meminfo)\nEOF\n" +
      "memory_total=${memory_total:-0}; memory_available=${memory_available:-0}; memory_used=$((memory_total-memory_available)); " +
      "if [ \"$memory_total\" -gt 0 ]; then memory_percent=$((100*memory_used/memory_total)); else memory_percent=0; fi; " +
      "temperature_raw=0; " +
      "for sensor in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do " +
      "  [ -r \"$sensor\" ] || continue; value=$(cat \"$sensor\" 2>/dev/null); " +
      "  case \"$value\" in *[!0-9]*|'') continue ;; esac; " +
      "  if [ \"$value\" -gt \"$temperature_raw\" ]; then temperature_raw=$value; fi; " +
      "done; temperature=$((temperature_raw / 1000)); " +
      "gpu_names=; gpu_usage=-1; gpu_temperature=0; " +
      "for card in /sys/class/drm/card[0-9]*; do " +
      "  [ -r \"$card/device/vendor\" ] || continue; vendor=$(cat \"$card/device/vendor\" 2>/dev/null); " +
      "  case \"$vendor\" in 0x8086) gpu_vendor=intel ;; 0x1002) gpu_vendor=amd ;; 0x10de) gpu_vendor=nvidia ;; *) continue ;; esac; " +
      "  [ -n \"$gpu_names\" ] && gpu_names=\"$gpu_names,\"; gpu_names=\"$gpu_names$gpu_vendor\"; " +
      "done; " +
      "if command -v nvidia-smi >/dev/null 2>&1; then " +
      "  gpu_line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); " +
      "  if [ -n \"$gpu_line\" ]; then " +
      "    IFS=, read -r nvidia_usage nvidia_temperature <<EOF\n$gpu_line\nEOF\n" +
      "    gpu_usage=$(printf '%s' \"$nvidia_usage\" | tr -cd '0-9'); gpu_temperature=$(printf '%s' \"$nvidia_temperature\" | tr -cd '0-9'); " +
      "    [ -n \"$gpu_usage\" ] || gpu_usage=0; [ -n \"$gpu_temperature\" ] || gpu_temperature=0; " +
      "  fi; " +
      "fi; " +
      "printf 'CPU|%s|%s\\n' \"$cpu\" \"$temperature\"; " +
      "printf 'MEM|%s|%s|%s\\n' \"$memory_percent\" \"$((memory_used * 1024))\" \"$((memory_total * 1024))\"; " +
      "df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, \"\", $5); print \"DISK|\" $5 \"|\" $3 \"|\" $2 }'; " +
      "printf 'GPU|%s|%s|%s\\n' \"$gpu_names\" \"$gpu_usage\" \"$gpu_temperature\""
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStats(text)
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.popupOpen
    onTriggered: root.refresh()
  }

  Timer {
    id: closeTimer
    interval: 250
    repeat: false
    onTriggered: {
      if (!button.tooltipHovered && !popup.containsMouse) root.close()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    tooltipText: "System Monitor"

    onTooltipHoveredChanged: {
      if (tooltipHovered) {
        closeTimer.stop()
        root.open()
      } else {
        closeTimer.restart()
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.launchBtop()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    triggerMode: "hover"
    open: root.popupOpen
    contentWidth: Style.space(300)
    contentHeight: popup.fittedContentHeight(cardContent.implicitHeight)

    onContainsMouseChanged: {
      if (containsMouse) closeTimer.stop()
      else if (!button.tooltipHovered) closeTimer.restart()
    }

    Item {
      id: cardContent
      width: parent.width
      implicitHeight: content.implicitHeight

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.close()
          else root.launchBtop()
        }
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

      Text {
        width: parent.width
        text: "SYSTEM MONITOR"
        color: root.contentForeground
        horizontalAlignment: Text.AlignHCenter
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      MetricRow {
        icon: "󰍛"
        label: "CPU:"
        primaryValue: root.cpuUsage + "% |"
        detailValue: root.cpuTemperature > 0 ? root.cpuTemperature + "°C" : "—"
        percent: root.cpuUsage
      }
      MetricRow {
        icon: "󰘚"
        label: "MEM:"
        primaryValue: root.memoryUsage + "% |"
        detailValue: root.formatBytes(root.memoryUsedBytes) + "/" + root.formatBytes(root.memoryTotalBytes)
        percent: root.memoryUsage
      }
      MetricRow {
        icon: "󰋊"
        label: "DISK:"
        primaryValue: root.diskUsage + "% |"
        detailValue: root.formatBytes(root.diskUsedBytes) + "/" + root.formatBytes(root.diskTotalBytes)
        percent: root.diskUsage
      }
      MetricRow {
        visible: root.gpuNames !== ""
        icon: "󰢮"
        label: "GPU:"
        primaryValue: (root.gpuUsage >= 0 ? root.gpuUsage + "%" : "—") + " |"
        detailValue: root.gpuTemperature > 0 ? root.gpuTemperature + "°C" : "—"
        subtitle: root.gpuNames
        percent: Math.max(root.gpuUsage, 0)
      }

      Item {
        width: parent.width
        height: credit.implicitHeight

        Text {
          id: credit
          anchors.right: parent.right
          text: "created by Skedar"
          color: root.contentForeground
          opacity: creditMouse.containsMouse ? 0.72 : 0.42
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: creditMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.close()
            else root.openGitHubPages()
          }
        }
      }
    }
    }
  }

  component MetricRow: Column {
    id: metric
    property string icon: ""
    property string label: ""
    property string primaryValue: ""
    property string detailValue: ""
    property string subtitle: ""
    property real percent: 0
    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Row {
      width: parent.width
      Text {
        width: Style.space(18)
        text: metric.icon
        color: Color.accent
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        width: Style.space(48)
        text: metric.label
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        width: Style.space(44)
        text: metric.primaryValue
        color: root.contentForeground
        horizontalAlignment: Text.AlignRight
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        width: parent.width - Style.space(110)
        text: metric.detailValue
        color: root.contentForeground
        elide: Text.ElideRight
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }
    }
    Text {
      visible: metric.subtitle !== ""
      width: parent.width
      text: metric.subtitle
      color: root.contentForeground
      opacity: 0.48
      horizontalAlignment: Text.AlignLeft
      elide: Text.ElideRight
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
    }
    Rectangle {
      width: parent.width
      height: Style.space(5)
      radius: height / 2
      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
      Rectangle {
        width: parent.width * root.clamp(metric.percent, 0, 100) / 100
        height: parent.height
        radius: parent.radius
        color: Color.accent
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
      }
    }
  }
}
