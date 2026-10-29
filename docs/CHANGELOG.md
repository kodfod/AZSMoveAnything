# Proposed contribution

## Added

- 112 UI messages in each of the 14 AZS languages: English, Polish, Czech,
  German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian,
  Ukrainian, Simplified Chinese, Japanese and Korean.
- An in-window language cycle and `/move lang <code>`, applied immediately.
- Saved language preference and automatic detection through native spell/class
  names, with a locale fallback.
- Scoped Latin/Cyrillic and CJK fonts, their SIL licenses, translation/glyph/control
  width checks and a larger settings panel that scales to smaller screens.
- A native Lua 5.0.3 regression suite, CI and an installable test ZIP builder.
- A maintenance guide explaining the files, translation workflow, wrapper design,
  test limits and manual in-game checks.

## Fixed

- Root UI surfaces and their aliases can no longer be moved/hidden through named
  commands, the picker or saved-layout application.
- Resetting layout/visibility preserves a newer addon hook. Captured references
  to released blockers resume forwarding to their previous methods.
- Invalid placeholders in `Custom.lua` no longer override a valid translation.

## Compatibility

- `Custom.lua` overrides valid built-in translations. Existing English keys,
  commands, frame identifiers, saved layout IDs and authorship are retained.
- Existing button groups, profile scopes and native HUD show/hide behavior remain.
- No native Rust HUD movement is added. In-game visual validation and native-speaker
  review of translations remain part of release testing.
