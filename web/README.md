# Mobile browser build

Run `python3 tools/build_mobile_web.py` from the repository. Requires Godot 4.6.2
and its matching export templates. Override the executable with `--godot PATH`.
The result is `builds/hooshang-mobile-web.zip`, with `index.html` at its root.

On itch.io, select an HTML game, upload the ZIP and mark it as played in the
browser. Enable **Mobile friendly** and **Click to launch in fullscreen**.
Use landscape orientation. The shell fits the browser viewport and safe-area
insets without requiring the native Fullscreen API. Portrait shows a rotate
message; the game pauses on rotation or when backgrounded.

Controls:
- Left thumb: drag the movement pad to walk, climb, crouch, or swim.
- Right thumb: tap to jump; hold for a higher jump; swipe in any of eight
  directions to dash. Movement and actions work simultaneously.
- Top right: pause and lemon glow. Dialogue and menus accept taps; hold their
  skip label to skip a conversation or the opening film.

The Web preset uses the compatibility renderer and no threads, requiring no
cross-origin isolation headers. A modern WebGL 2 browser is required. First
load downloads the game assets; save persistence depends on browser storage.
Keyboard and controller support remain available, with prompts changing to
match the device. There is no ladder-top jump prompt.

Validation: `tests/mobile_input_test.tscn` covers simultaneous touches, all dash
directions, tap/hold distinction, cancellation, ladder jumping, pause and reset.
`tests/mobile_ui_test.tscn` covers menus, tutorials, dialogue, intro and results.
The exported game was exercised in Chromium and WebKit using mobile-sized touch
contexts. Physical iPhone/Android hardware and a hosted itch.io page still need
a final device check after upload.

See https://itch.io/docs/creators/html5 and
https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html.
