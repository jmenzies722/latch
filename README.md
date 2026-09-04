# Latch

Latch is a menu-bar app for macOS that organizes the windows already on your screens.

Press `⌃⌥Space`. You get a live map of each display. Gold dashed lines are the desk shape Latch would use. Press Return and those windows slide into place.

It does not launch apps. It does not tile every new window. Rectangle snaps the frontmost window; Latch moves the whole desk.

No account, no network, no telemetry.

## Install

macOS 14+, Apple Silicon, Xcode Command Line Tools, and a code-signing identity.

```bash
git clone https://github.com/jmenzies722/latch.git
cd latch
make install
```

That builds Latch, signs it, copies it to `~/Applications`, and opens it. There is no Dock icon — look in the menu bar.

The maps work immediately. Moving windows needs **Accessibility**. Allow it the first time you apply a layout. Latch never records the screen.

If Settings says Latch is allowed but windows do not move, the grant is stuck on an old signature:

```bash
make unlock
```

Or pass your own identity: `make install SIGN_ID="Apple Development: you@example.com (TEAMID)"`  
Find it with `security find-identity -v -p codesigning`.

## What it does

Each display is a card: the windows that are on it, a recommended shape drawn in gold, and a button.

| Shape | When it picks this | What happens |
| --- | --- | --- |
| Coding | Editor + browser + terminal | Editor ~2/3; browser and terminal stacked in the rest |
| Research | Browser + editor | Browser large, editor beside it |
| Focus | A pile of windows | Frontmost window fills the screen; other apps hide |
| Split | Two windows | Halves |
| Maximize | One window | Full visible frame |

Hover C / R / F to preview a different shape. Drag a tile (after Accessibility) to move the real window. The HUD stays open after a latch so you can watch the map catch up. Esc dismisses it.

**Editor:** Cursor, VS Code, Xcode, Zed, Sublime, JetBrains. **Browser:** Safari, Chrome, Arc, Firefox, Brave, Edge. **Terminal:** Terminal, iTerm, Ghostty, Warp, Alacritty, kitty. Missing roles leave a slot empty. Extra windows of the same role stay put.

## Keys

| Key | Action |
| --- | --- |
| `⌃⌥Space` | Show the HUD |
| `↩` | Apply the recommended shape on the display under the pointer |
| `C` `R` `F` | Coding / Research / Focus |
| `←` `→` `M` | Left half / right half / maximize |
| `1` `2` `3` | Restore a saved desk |
| `⇧1` `⇧2` `⇧3` | Save this desk |
| `Z` | Undo the last layout |
| Esc | Dismiss |

Double-click a map to latch that display. Shortcuts are remappable in Settings.

## Privacy

No analytics, no crash reporter, no account, no network. Saved desks live at `~/Library/Application Support/Latch/`.

## Tests

```bash
make test
```

Geometry, roles, recommendations, and motion math. No Accessibility required.

## Not this

Not a tiling window manager. Not drag-to-edge snap. Not an app launcher. Not an LLM. Not Windows or Linux.

## Limits

- Accessibility is required to move windows. Rebuilds must stay signed or the grant dies (`make unlock`).
- Apple Silicon, macOS 14+.
- No notarized release — first launch on another Mac may need right-click → Open.
- Saved desks do not open apps. Missing windows are skipped.
- Fine next to Rectangle or Magnet; Latch does not steal edge-drag.

## License

[MIT](LICENSE)
