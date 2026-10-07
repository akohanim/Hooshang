# Mobile browser build

Run `python3 tools/build_mobile_web.py` from the repository. Requires Godot 4.6.2
and its matching export templates. Override the executable with `--godot PATH`.
The result is `builds/hooshang-web-upload.zip`, with `index.html` at its root.

On itch.io, select an HTML game, upload the ZIP and mark it as played in the
browser. Enable **Mobile friendly** and **Click to launch in fullscreen**.
Use landscape orientation. The shell fits the browser viewport and safe-area
insets without requiring the native Fullscreen API. Portrait shows a rotate
message; the game pauses on rotation or when backgrounded.

The top-left screen button requests native fullscreen directly from a tap when
supported. Web starts windowed; the desktop application's fullscreen setting is
unchanged. On iPhone without native fullscreen, the button reads **Install to
play fullscreen** and presents a Home Screen setup flow:

1. From the embed, choose **Open install page** (the actual game, not the itch listing).
2. In Safari choose **Share → Add to Home Screen**.
3. Keep **Open as Web App** enabled if offered, then tap **Add**.
4. Launch **Hooshang** from the Home Screen and rotate to landscape.

The archive includes a relative-scope manifest and Apple's standalone metadata.
Home Screen mode removes Safari's tabs and address bar; a regular Safari tab
cannot be forced into that mode by JavaScript. Installation remains a manual
Safari action. The redundant install button is hidden after a standalone launch.
Internet is still required (no offline cache). Home Screen storage can be
separate from Safari's save storage. If itch assigns a new game asset URL after
an upload, re-add the updated build to the Home Screen.

The shell follows `visualViewport` changes so browser bars do not obscure the
canvas when playing in a normal tab. The loader displays downloaded MB and
percentage, distinguishing download time from engine startup.

Apple documentation:
https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html

Browser regression checks: `NODE_PATH=/path/to/node_modules node
tests/web_fullscreen_test.cjs` with Playwright Chromium and WebKit installed.

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
It also sends the device-0 mouse motion observed before browser touch drags:
`InputDevice` must preserve an active thumb and ignore trailing compatibility
mouse events for 500 ms. Checking only `DEVICE_ID_EMULATION` loses both joystick
and swipe ownership in the Web export. Actual keyboard/controller events still
switch devices immediately; a real mouse resumes after the touch grace period.
`tests/mobile_ui_test.tscn` covers menus, tutorials, dialogue, intro and results.
The exported game was exercised in Chromium and WebKit using mobile-sized touch
contexts. Physical iPhone/Android hardware and a hosted itch.io page still need
a final device check after upload.

See https://itch.io/docs/creators/html5 and
https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html.

## Shell organization

- `mobile_shell.html`: semantic markup and Godot export substitutions.
- `game_shell.css`: layout, safe areas, loading and install screens.
- `game_shell.js`: viewport sizing, fullscreen/install behavior and engine startup.
- `manifest.webmanifest`: Home Screen app identity and launch scope.

The build helper explicitly copies all three sidecar files beside `index.html`.
Use the helper, not a bare Godot export, when preparing the upload ZIP.

## iPhone Home Screen touch test

The same upload ZIP includes an opt-in diagnostic room, accessible only by
adding `?touch_test=1` to the exported game URL. Normal gameplay has no test
button. The diagnostic URL starts a separate practice room with dash unlocked,
a flat floor and a ladder; it unbinds saves before spawning the player.

From that test page, use Safari Share → Add to Home Screen. Its separate
`touch-test.webmanifest` launches `index.html?touch_test=1`, so the icon returns
to the test room instead of silently losing the diagnostic query. The title is
**Touch Test**. If testing an iframe, use the existing install button to open
the test page in its own tab first; the query is preserved.

The overlay shows HOME SCREEN vs SAFARI / BROWSER and the UTC export build ID.
It compares raw canvas events with Godot events, finger ownership, movement
vector, actual player velocity/state and reset reasons. Walk/climb/jump/dash
checks are based on the real player. **Copy report** copies recent input and
engine snapshots; a selectable text field is the fallback if clipboard access
is unavailable. Reports stay local and contain no saves, passwords or URL query
parameters. **Exit test** returns to the normal game menu.

After replacing the itch.io upload, install the test from the newly uploaded
page. An existing Home Screen icon can point to an older itch.io asset folder;
reloading that old URL does not establish that it loaded the new upload.

`tests/web_touch_test.cjs` drives the exported room in Chromium and WebKit,
checks actual player movement and the manifest launch URL, and reads the same
report available on the phone. Serve `builds/mobile-web` with an HTTP server,
then run with Playwright on `NODE_PATH`; `HOOSHANG_TEST_URL` defaults to
`http://127.0.0.1:8765/`. `CHROME_PATH` can select a local Chrome executable.
These checks simulate standalone mode; they do not replace a physical iPhone.

### Touch movement ownership

The drawn pad has a fixed centre: pressing an arrow immediately produces a
movement vector. A press elsewhere in the lower-left movement region starts a
floating pad at that point. Both use the same drag/release ownership and the
same player physics as keyboard/gamepad input.

Browser touch identifiers are opaque signed 32-bit values. TouchControls maps
all 32 bits into a nonnegative Godot 64-bit integer before storing ownership,
so valid negative IDs (including -1) cannot collide with its unowned sentinel.
Regression tests include signed boundary IDs and pressing arrows without a drag.
