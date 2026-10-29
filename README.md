# MoveAnything! for Azeroth Survivors

MoveAnything! is an addon for Azeroth Survivors. It moves, scales and hides the frames of the interface: the player and target frames, the main bar, the spell buttons, the minimap, the buffs, the tooltip and more. You can also move any frame of another addon.

This addon is based on MoveAnything! by Skrag and Jason for World of Warcraft 1.12. It is rebuilt for the Azeroth Survivors client.

## Install

1. Download the `MoveAnything` zip file from the Releases page.
2. Extract the zip file.
3. Put the `MoveAnything` folder in this folder: `benilla-config/AddOns/`.
4. Start the game. Make sure that the addon is on in the AddOns options.
5. Start a run. The addon loads at the start of the next run.

## Use

Type `/move` to open the window. You can also set a key for the window with `/move key`.

The window lists the frames that you can move. Each frame has 3 controls:

- Move: puts a green overlay on the frame.
- Hide: keeps the frame hidden. The game cannot show it again.
- Reset: puts the frame back where the game puts it.

A frame that you changed shows in green.

When the overlay is on a frame:

- Drag the overlay to move the frame.
- Drag a gold handle on an edge or a corner to scale the frame.
- Hold Alt while you drag a handle to change the width or the height instead.
- Push the arrow keys while the cursor is on the overlay to move the frame by 1. Hold Shift to move it by 10.
- Right-click the overlay when you are done. Escape also stops.
- Shift-right-click the overlay to hide its color, so that you can see the frame.

### Button rows

- Spell buttons: the 6 spell buttons and the racial button, in a row or a column.
- Character and talent buttons: in a row or a column.

Use the vertical entry to put the buttons in a column. Reset puts the buttons back on the main bar.

### Move a frame that is not in the list

- Push Pick Frame. Move the cursor on the frame. Left-click to move it. The mouse wheel picks the frame under it. Right-click or Escape stops.
- Or type `/move FrameName`. Frame names are case-sensitive. The bottom of the window shows the name of the frame under the cursor.

The frame then shows in the list under "Your frames".

## Layouts

"Layout for" at the bottom of the window sets which heroes use the layout:

- All heroes: all heroes and classes use one layout.
- This class: all the heroes of this class use one layout.
- This hero: only this hero uses the layout. A hero is its name and its class, so the same name in another class has its own layout.

A new class or hero layout starts as a copy of the layout in use.

## Commands

| Command | Result |
| --- | --- |
| `/move` | Opens or closes the window. |
| `/move FrameName` | Moves the frame with that name. |
| `/move pick` | Picks a frame on the screen. |
| `/move hide FrameName` | Hides or shows the frame with that name. |
| `/move done` | Stops moving all frames. |
| `/move key <key>` | Sets a key that opens or closes the window. Example: `/move key F7`. |
| `/move key none` | Removes the key. |
| `/move lang fr` | Changes the addon language immediately. |
| `/move lang auto` | Follows the game's detected language. |
| `/move help` | Shows the commands. |
| `/unmove FrameName` | Puts the frame back where the game puts it. |
| `/movelist` | Shows the saved layouts. |
| `/movecopy Name` | Copies a saved layout into the layout in use. |
| `/movedelete Name` | Deletes a saved layout. |

The command `/moveanything` does the same thing as `/move`.

## Languages

The addon includes English, Polish, Czech, German, Brazilian Portuguese, Spanish,
French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and
Korean. Its own fonts support the supplied Latin, Cyrillic and CJK interface text.

Click the language button in `/move` to cycle through the choices. The change
applies immediately, including labels already on screen. The selection is saved.
For a direct choice, use `/move lang` followed by one of:

`auto`, `en`, `pl`, `cs`, `de`, `pt`, `es`, `fr`, `ro`, `tr`, `ru`, `uk`, `zh`, `ja`, `ko`.

Automatic mode compares the game's native spell/class names, then falls back to
`GetLocale`. This handles clients reporting `enUS` while the game text is translated.
If detection is ambiguous, select the language yourself. Native game text, frame
names and saved profile identifiers are not renamed by the addon.

## Change your own words

`Custom.lua` still overrides the built-in translations. To customize one message,
copy its English key from `Strings.lua` and add the line inside the braces in
`Custom.lua`, for example `["Reset All"] = "Reset everything",`. Save it as UTF-8
and restart the game. Other messages keep the selected built-in language.

Follow these rules:

- Do not change the words on the left side. The addon uses them to find the line.
- Keep the codes `%s`, `%d` and `%.2f` in the same order. They show names and numbers. Invalid overrides fall back to the selected built-in translation.
- Keep the quotation marks at the start and the end of the words. To write a quotation mark in the words, write `\"`.
- Do not translate the commands, such as `/move` and `/unmove`, in the words. The commands stay the same in all languages.
- The names of the frames (such as `PlayerFrame`) and the names of the layouts (`Default`, `Class:`, `Hero:`) are not translated.
- A new version can add lines or change the English words on the left side. A line in `Custom.lua` can then stop working. Compare your lines with `Strings.lua` after you update.
- When you update the addon, keep your `Custom.lua` file.

To improve a built-in translation, edit `locales/<language>.json` and regenerate
the Lua. The [contributor guide](docs/CONTRIBUTING.md) explains each step, including
testing, fonts and the code's frame/hook safeguards. Native-speaker review is welcome.

## Saved data

The addon keeps its layouts in this file: `benilla-config/saved/MoveAnything.lua`. Push Reset All two times to put all the frames of the layout in use back where the game puts them.

Root surfaces such as `UIParent` and `WorldFrame`, and the addon's own settings
and picker, are protected from movement/hiding. Native game HUD screens remain
show/hide only. Avoid letting two addons control the same moved frame.

## Development checks

From the repository root, run `lua tests/run.lua` with Lua 5.0.3,
`python tools/build_locales.py --check`, and `python tools/check_assets.py`
(the last check requires `fonttools`). These are simulated behavior and asset
checks; the contributor guide includes the remaining manual checks in the game.

`python tools/package.py` produces an installable `dist/MoveAnything.zip`.
See the [proposed changelog](docs/CHANGELOG.md) for this contribution's scope.
