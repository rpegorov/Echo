# Changelog

Keep a Changelog format. A version's section becomes the release notes in
the Sparkle update window: `scripts/release.sh` moves it into the appcast's
`<description>`. Without a section for the version being released, the
release does not build.

## [2.2] — 2026-10-11

### Added

- Zone highlight while dragging a window: an animated frame with the zone
  name and its keyboard shortcut.
- Thirds and two-thirds of the screen, moving a window to the adjacent
  display, pressing the half hotkey again cycles the width: ½ → ⅔ → ⅓.
- Zone map in settings and zone badges in the shortcuts list.
- Zone grids: templates and custom grids in the editor (split by click,
  merge, drag borders), one grid per display.
- Grid mode: dragging a window with ⌥ held shows all grid zones; with ⌃ the
  window stretches across several zones.
- Zone hotkeys ⌃⌥1…9 and the "Next grid" command.
- Window arrangements: "Remember current", editing in the editor, applying
  from settings, the menu bar or a hotkey; applications that are not running
  are skipped.
- Auto rules: a new window of a chosen application lands in its zone by
  itself.

### Changed

- New default shortcuts: ⌃⌥⌘D/F/G/E/T (thirds and two-thirds), ⌃⌥⌘←/→
  (adjacent display), ⌃⌥1…9 (zones). Shortcuts you have already assigned do
  not change. ⌃⌥ and ⌃⌥⌘ overlap with VoiceOver commands — if you use
  VoiceOver, reassign the shortcuts in settings.
- If the system macOS tiling is enabled (including "Hold ⌥ while dragging
  windows"), settings offer to turn it off.

### Fixed

- Mouse window dragging shows the snap zone highlight again: the "the window
  is really being dragged" probe gave up after three reads taken within
  ~11 ms, while the system starts moving the window only after ~0.23 s, so
  the highlight never appeared — neither at screen edges nor in ⌥ grid
  mode.

### Data

- Grids and arrangements are stored in `~/Library/Application Support/
  rostislav.egorov.Echo/window-zones.json`. A corrupted file is set aside as
  `window-zones.corrupt-<date>.json`, and Echo starts with templates.
- Arrangements store window titles — locally, in this file only. Deleting an
  arrangement erases them; the set-aside copies keep them until removed
  manually.
- Echo versions before 2.2 do not see grids and arrangements saved in 2.2:
  after a downgrade only templates are available; the file is not modified.

## [2.1.1] — 2026-10-06

### Fixed

- The word-conversion undo hotkey (⌥⇧Space by default) works again with
  auto-correction enabled — previously a non-breaking space was inserted
  into the text instead of undoing.
- Holding the conversion hotkey no longer flips the word back and forth:
  auto-repeat of a held key is ignored, one press — one flip.
- Hotkey conversion fires instantly on key-down, without waiting for the
  keys to be released.

## [2.1] — 2026-10-02

### Added

- Clipboard history in a glass panel over the active window.

### Changed

- Metrics in the menu-bar popover are drawn as bars.
