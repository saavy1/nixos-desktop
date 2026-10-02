---
name: cua-desktop
description: Drive this desktop (Hyprland, NixOS) with the cua-driver MCP tools, especially gpui apps such as tgg-editor and Zed. Use before any cua-driver click, drag, type or screenshot on this machine.
---

# Driving this desktop with cua-driver

This machine runs Hyprland without Cua's compositor plugin. The driver sees
windows and can act on them, but only through the one real pointer and
keyboard, and only in screen coordinates.

## Before acting

- Control is switched off by default. If a cua-driver tool is missing or the
  server will not start, run `cua status`. `cua on` enables it; the MCP server
  then needs a reconnect or a new session. Do not turn it on unless the user
  asked for desktop control.
- Every action moves the user's real pointer and can take keyboard focus.
  Say so before a long run, and run `cua off` when the work is finished.

## Seeing a window

1. `list_windows` gives `pid`, `window_id` and `bounds`.
2. `get_window_state(pid, window_id, include_accessibility_tree: false)`
   returns a screenshot. gpui apps expose no accessibility tree, so there are
   no element indexes to click; work from the screenshot.

## Acting on it

Window-targeted actions are refused here (`background_unavailable`,
`foreground_unavailable`). Target the desktop instead and convert each
screenshot pixel to a screen pixel:

    screen_x = window_bounds.x + shot_x / frame_scale
    screen_y = window_bounds.y + shot_y / frame_scale

`window_bounds` and `frame_scale` come from the same `get_window_state`
result; treat a missing `frame_scale` as 1.

- Click: `click(target: {kind: "desktop", display_id: "primary"}, x, y)`.
- Drag: `drag` with the same target and `from_x/from_y/to_x/to_y`.
- Type: click the field first, then `type_text` with the same target.
- Do not pass `scope`, `pid` or `window_id` together with `target`.

The first click on a window that is not focused only focuses it. Take a new
screenshot after every action and repeat the click if nothing changed. Tool
results say `effect: unverifiable`, so the screenshot is the only evidence.

## tgg-editor

From `~/dev/texturesgg`, build with `cargo build --release -p tgg-editor` and
launch with `direnv exec . ./target/release/tgg-editor`; outside the dev shell
it fails to load `libxcb`. Its window class is `gg.textures.editor`. Dragging
in the viewport orbits the model and scrolling zooms.
