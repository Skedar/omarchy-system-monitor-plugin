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
  property int memoryUsage: 0
  property int diskUsage: 0
  property int temperature: 0
  property string gpuName: "Unavailable"
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
    if (root.bar) root.bar.run("hyprctl dispatch exec '[float; center] foot -e btop'")
  }

  function openGitHubPages() {
    close()
    if (root.bar) root.bar.run("xdg-open https://skedar.github.io/")
  }

  function parseStats(raw) {
    var fields = String(raw || "").trim().split("|")
    if (fields.length !== 7) return

    cpuUsage = clamp(parseInteger(fields[0], 0), 0, 100)
    memoryUsage = clamp(parseInteger(fields[1], 0), 0, 100)
    diskUsage = clamp(parseInteger(fields[2], 0), 0, 100)
    temperature = Math.max(parseInteger(fields[3], 0), 0)
    gpuName = fields[4].trim() || "Unavailable"
    gpuUsage = clamp(parseInteger(fields[5], -1), -1, 100)
    gpuTemperature = Math.max(parseInteger(fields[6], 0), 0)
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
      "memory=$(awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 } END { if (total > 0) printf \"%d\", 100*(total-available)/total; else print 0 }' /proc/meminfo); " +
      "disk=$(df -P / 2>/dev/null | awk 'NR==2 { print int($5) }'); [ -n \"$disk\" ] || disk=0; " +
      "temperature_raw=0; " +
      "for sensor in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do " +
      "  [ -r \"$sensor\" ] || continue; value=$(cat \"$sensor\" 2>/dev/null); " +
      "  case \"$value\" in *[!0-9]*|'') continue ;; esac; " +
      "  if [ \"$value\" -gt \"$temperature_raw\" ]; then temperature_raw=$value; fi; " +
      "done; temperature=$((temperature_raw / 1000)); " +
      "gpu_name=Unavailable; gpu_usage=-1; gpu_temperature=0; " +
      "if command -v nvidia-smi >/dev/null 2>&1; then " +
      "  gpu_line=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); " +
      "  if [ -n \"$gpu_line\" ]; then " +
      "    IFS=, read -r nvidia_name nvidia_usage nvidia_temperature <<EOF\n$gpu_line\nEOF\n" +
      "    gpu_name=$(printf '%s' \"$nvidia_name\" | tr -d '|'); " +
      "    gpu_usage=$(printf '%s' \"$nvidia_usage\" | tr -cd '0-9'); gpu_temperature=$(printf '%s' \"$nvidia_temperature\" | tr -cd '0-9'); " +
      "    [ -n \"$gpu_usage\" ] || gpu_usage=0; [ -n \"$gpu_temperature\" ] || gpu_temperature=0; " +
      "  fi; " +
      "fi; " +
      "if [ \"$gpu_name\" = Unavailable ]; then " +
      "  for card in /sys/class/drm/card[0-9]*; do " +
      "    [ -r \"$card/device/vendor\" ] || continue; vendor=$(cat \"$card/device/vendor\" 2>/dev/null); " +
      "    case \"$vendor\" in 0x8086) gpu_name=Intel ;; 0x1002) gpu_name=AMD ;; 0x10de) gpu_name=NVIDIA ;; *) continue ;; esac; break; " +
      "  done; " +
      "fi; " +
      "printf '%s|%s|%s|%s|%s|%s|%s\\n' \"$cpu\" \"$memory\" \"$disk\" \"$temperature\" \"$gpu_name\" \"$gpu_usage\" \"$gpu_temperature\""
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.launchBtop()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

      Row {
        spacing: Style.space(8)
        Text {
          text: "󰍛"
          color: Color.accent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.heading
        }
        Text {
          text: "SYSTEM MONITOR"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }

      MetricRow { label: "CPU"; value: root.cpuUsage + "%"; percent: root.cpuUsage }
      MetricRow { label: "MEM"; value: root.memoryUsage + "%"; percent: root.memoryUsage }
      MetricRow { label: "DISK"; value: root.diskUsage + "%"; percent: root.diskUsage }
      MetricRow {
        visible: root.temperature > 0
        label: "TEMP"
        value: root.temperature + "°C"
        percent: root.temperature
      }

      Column {
        width: parent.width
        visible: root.gpuName !== "Unavailable"
        spacing: Style.space(4)
        Row {
          width: parent.width
          Text {
            width: Style.space(54)
            text: "GPU"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Text {
            width: parent.width - Style.space(54)
            text: root.gpuName + (root.gpuTemperature > 0 ? " · " + root.gpuTemperature + "°C" : "")
            color: root.gpuUsage > 0 ? Color.accent : root.contentForeground
            elide: Text.ElideRight
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }
        }
        Rectangle {
          visible: root.gpuUsage >= 0
          width: parent.width
          height: Style.space(5)
          radius: height / 2
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
          Rectangle {
            width: parent.width * root.gpuUsage / 100
            height: parent.height
            radius: parent.radius
            color: Color.accent
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          }
        }
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
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openGitHubPages()
        }
      }
    }
    }
  }

  component MetricRow: Column {
    id: metric
    property string label: ""
    property string value: ""
    property real percent: 0
    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Row {
      width: parent.width
      Text {
        width: Style.space(54)
        text: metric.label
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        text: metric.value
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }
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
