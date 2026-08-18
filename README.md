# System Monitor for Omarchy

A lightweight system-monitor widget for Omarchy 4 / Quattro.

Hover the bar icon for live telemetry. Click the icon or the balloon to open `btop`.

## Screenshots

Screenshots belong in [`img/`](img/) using numbered names such as `1.png`, `2.png`, and `3.png`.

<!-- Add your screenshots here after placing them in img/.

<p align="center">
  <img src="img/1.png" alt="System Monitor widget" width="420">
  <img src="img/2.png" alt="System Monitor telemetry balloon" width="420">
</p>
-->

## Install

```sh
omarchy plugin add https://github.com/Skedar/omarchy-system-monitor-plugin.git --enable
```

## Update

```sh
omarchy plugin update io.github.skedar.system-monitor
omarchy-restart-shell
```

## Remove

```sh
omarchy plugin remove io.github.skedar.system-monitor
```

## What it does

- Hover the bar icon to show the monitor balloon.
- Updates CPU, memory, root-disk (`/`), and GPU telemetry every two seconds while the balloon is visible.
- Shows CPU/GPU usage and temperature, memory usage and used/total capacity, and root-disk usage and used/total capacity.
- Detects Intel, AMD, and NVIDIA GPUs. Hybrid systems are displayed compactly, for example: `intel|nvidia`.
- Left-click the icon or balloon to open `btop` in Omarchy's floating, centered terminal window.
- Right-click anywhere in the balloon to close it immediately.
- Follows the active Omarchy theme automatically.

## Compatibility

- Omarchy 4 / Quattro.
- Linux systems with standard `/proc`, `/sys`, and `df` telemetry sources.
- NVIDIA utilization and temperature require `nvidia-smi`; the widget remains functional when it is unavailable.
- No root access, external service, or second Quickshell instance is required.

## Support

If this plugin is useful to you, support its development:

- [Buy Me a Coffee — Skedar](https://buymeacoffee.com/Skedar)
- [Skedar's GitHub Pages](https://skedar.github.io/)
