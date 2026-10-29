# Maintaining the translations and frame fixes

This guide is for a contributor who has not worked on a WoW addon before.
Players only need the `MoveAnything` folder. Python, a compiler and the original
fonts are development tools; they are not needed to run the addon.

## What loads when the game starts

`MoveAnything.toc` is the loading list. The game reads its Lua files in order.
`Strings.lua` contains English, `Locales.lua` contains the other languages and
native language probes, and `Custom.lua` contains the player's overrides.
`Core.lua` defines shared helpers. `Locale.lua` selects the language and manages
addon-owned fonts. The remaining files build the frame catalog, movement logic,
profiles, picker and settings window.

Saved data is available by `ADDON_LOADED`. The initial language can be detected
while Lua loads, but `Main.lua` selects it again after reading saved settings.
This second pass updates text created before the saved language was available.

## Change one translation

1. Open the corresponding file under `locales/`, for example `fr.json`.
2. Change the text **on the right**. Keep the English key on the left unchanged.
3. Keep format tokens such as `%s`, `%d` and `%.2f` unchanged and in the same order.
   They are filled in by the game. A literal percent sign is written as `%%`.
4. Keep commands, frame names and profile identifiers unchanged. They are used
   by the code and can be typed by the player.
5. Save as UTF-8, then run:

   ```sh
   python tools/build_locales.py
   python tools/build_locales.py --check
   ```

Commit both the JSON change and regenerated Lua. The game cannot read the JSON;
it uses the generated Lua included in the addon folder. Do not edit `Locales.lua`
by hand: regenerating it would overwrite the edit.

English is one of the 14 complete catalogs. To add an English UI message, add
its key/value to `locales/en.json`, then add that key to the other 13 files. The
generator deliberately fails on missing keys, extra keys or changed placeholders.
Translations have technical coverage checks; native-speaker wording review is
still welcome, particularly for longer instructions and game terminology.

## Automatic language detection

Some AZS clients report `enUS` from `GetLocale` even when their game text is in
another language. A private, hidden tooltip reads three native spell names.
The localized class name resolves overlaps, including English/Turkish spell
names. `GetLocale` is the fallback when those observations do not identify a
language. A player can always choose a language explicitly.

`locales/probes.json` contains only these class/spell names, observed from the
installed client used for development. It contains no executable game code.
If the game changes those names, update the probe values and regenerate Lua.
Automatic mode checks the language once at startup; an explicit selection
stays selected. Class and hero profile **keys** are not translated or renamed.

## Fonts and clipping

The bundled `MoveAnythingSans` fonts are renamed Noto derivatives. The Latin font
covers the Latin and Cyrillic UI languages. Separate Chinese, Japanese and Korean
subsets cover the supplied UI text. Copyright and license records are retained;
the two SIL Open Font License files are included under `MoveAnything/media/`.

Only this addon's labels, controls, edit box, overlays, picker and private help
tooltip are restyled. The global game font objects and shared `GameTooltip` are
not changed. Arbitrary player names and arbitrary text in a player's `Custom.lua`
are outside the static catalog's glyph-coverage guarantee.

After changing translations, check glyph coverage and button widths:

```sh
python -m pip install fonttools==4.67.0
python tools/check_assets.py
```

If a translation adds a glyph not in a bundled CJK subset, rebuild the fonts.
Download these four original files into one local folder:

- [NotoSans-Regular.ttf](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf)
- [NotoSansCJKsc-Regular.otf](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf)
- [NotoSansCJKjp-Regular.otf](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf)
- [NotoSansCJKkr-Regular.otf](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/Korean/NotoSansCJKkr-Regular.otf)

Keep those filenames. Then run:

```sh
python tools/build_fonts.py --font-dir /path/to/original-fonts
python tools/check_assets.py
```

The script reads local files and makes no network requests. Do not commit the
full original fonts; commit the four resulting derivatives and their licenses.

## Why the frame guards exist

The picker already avoided the root UI surfaces. Named commands and saved
profiles previously had another route to them. Hiding `UIParent` hides virtually
the entire interface. `A.IsProtected` now checks both names and object identity,
so assigning `SomeAlias = UIParent` cannot bypass the guard.

The command, picker, custom-frame resolver, saved-layout application and public
movement/hiding paths use the same check. Internal options/picker/help frames
are protected too. The addon's intentional tooltip/button-row stand-ins remain
editable. Ordinary addon frames and the existing popup entry remain supported.

## Why releaseable method wrappers exist

Moving a frame temporarily blocks its native positioning methods. Another addon
may wrap one of those methods afterward. Reset must not overwrite that newer hook.
It must also stop blocking calls from the newer hook to its captured predecessor.

`Layout.lua` therefore keeps a small record for each owned wrapper: its previous
method, wrapper identity and active flag. On release:

1. Mark the wrapper inactive, making captured references forward normally.
2. Restore the previous method only if the frame still points at our wrapper.
3. Leave a newer wrapper in place.

The same pattern is used for visibility. Requests to show/hide a hidden frame
are remembered, then respected when hiding is disabled. This does not guarantee
compatibility with every addon; two addons can still intentionally fight over
the same frame. It prevents a specific lost-hook and permanently-blocked-chain bug.

## Run the regression tests

Use Lua **5.0.3**, the legacy language target, from the repository root:

```sh
lua tests/run.lua
python tools/build_locales.py --check
python tools/check_assets.py
```

On Windows, the interpreter may be named `lua50.exe`. The tests load the actual
TOC-listed addon files into a small FrameXML mock. They cover root guards, aliases,
saved-profile bypasses, all six geometry methods, visibility intent and later
hooks, two-anchor dimensions, inherited scale, shared/class/hero layouts, deferred
frames, both spell-button orientations, cold saved-variable startup, every language,
automatic probes, user overrides, placeholders, tooltip
font isolation and the settings window's bounds on a smaller screen.

The mock simulates enough of the old UI API to test behavior. It does **not**
reproduce the whole AZS renderer, text shaping or real mouse/keyboard routing.
A passing test is not a completed in-game visual test.

## Manual check before releasing

1. Keep a backup of `benilla-config/saved/MoveAnything.lua` and `Custom.lua`.
2. Enable only one addon responsible for the same moved frames, then start a run.
3. Open `/move`; cycle languages and try `/move lang fr`, `/move lang zh`,
   `/move lang ja`, `/move lang ko`, and `/move lang auto`.
4. Check labels, tooltips, row alignment and button text. Try a smaller window.
5. Move and scale the player/minimap, try both button-row orientations, and reset.
6. Hide/show a naturally conditional frame, then confirm it follows native visibility.
7. Switch shared/class/hero layouts, leave the run and test another class/hero.
8. Restart normally and confirm the saved language and layouts return.
9. Try `/move hide UIParent` and `/move WorldFrame`; both must refuse the change.

Native Rust HUD screens remain show/hide only, through the existing game API.

## Make an installable ZIP

```sh
python tools/package.py
```

This creates `dist/MoveAnything.zip`, with `MoveAnything/MoveAnything.toc` directly
under its top-level folder. Development files and original font inputs are not
packaged. CI runs the checks and uploads this ZIP as a test artifact; it does not
publish a release or install anything on a player's computer.
