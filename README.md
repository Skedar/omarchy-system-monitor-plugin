# System Monitor for Omarchy Quattro

A native Quickshell bar widget for Omarchy Quattro. Hover its bar icon to inspect CPU, memory, mounted storage, and GPU status; left-click the icon to open `btop`.

## Features

- Uses Quattro's native `bar-widget`, `BarIconButton`, and hover-mode `PopupCard` components.
- Opens a hover balloon and polls only while that balloon is displayed, at a two-second interval.
- Left-clicking the icon or anywhere in the hover balloon opens `btop` through Omarchy's native launcher. It assigns the `org.omarchy.btop` app ID, which Quattro's built-in window rules float and center.
- The discreet `created by Skedar` footer opens https://skedar.github.io/.
- Keeps the theme-provided foreground and accent colors live; no fixed palette is embedded.
- Aligns the percentage-and-separator field across CPU, memory, disk, and GPU while keeping each detail field left-aligned.
- Presents the root filesystem (`/`) as `DISK`, and directs users to `btop` for broader storage inspection.
- Lists detected hybrid GPU vendors discreetly below the GPU meter, for example `intel|nvidia`.
- Right-clicking anywhere in the balloon closes it immediately.
- Requires no root privilege, service, install hook, or network connection.
- Reads standard Linux `/proc`, `/sys`, and `df` data for CPU, memory, mounted storage, and thermal telemetry.
- Detects Intel, AMD, and NVIDIA DRM vendors without assuming a fixed GPU index.
- Uses `nvidia-smi` only when available to expose NVIDIA utilization and temperature.
- Degrades to an explicit unavailable state when a sensor or optional GPU tool is absent.

## Install

```sh
omarchy plugin add https://github.com/Skedar/omarchy-system-monitor-plugin.git --enable
```

The widget defaults to the right bar section. Move it with Omarchy's bar controls if desired.

## Develop and validate

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.skedar.system-monitor"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml"
```

After saving source files, Omarchy reloads user plugins automatically. If discovery is needed explicitly:

```sh
omarchy-shell shell rescanPlugins
```

## Remove

```sh
omarchy plugin remove io.github.skedar.system-monitor
```

## Compatibility and limits

This plugin targets Omarchy 4 / Quattro. It deliberately does not launch a second Quickshell process.

GPU telemetry is best-effort. Intel and AMD cards can be identified through DRM metadata, but utilization is shown only where a supported provider exposes it. NVIDIA utilization and temperature require a working `nvidia-smi`; this covers hybrid Intel/NVIDIA systems such as a ThinkPad T480 without requiring NVIDIA to be active.

## License

License selection is pending before public marketplace submission.
