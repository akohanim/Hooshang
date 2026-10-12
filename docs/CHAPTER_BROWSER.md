# Chapter browser

The title screen's Explore Chapters opens all three Acts without a save prerequisite.
Every playable LDtk room is available. Selecting a room starts an unbound replay;
Continue, Load Game and New Game retain their save-slot behavior and overwrite guard.
Act I uses the existing finished-run setup; the other Acts reset session counters
and quest state and provide dash. Quest items remain available to collect in replay.

The menu remains on the UI render surface. Chapter art comes from existing project
assets. Room miniatures use source geometry, with blue water, red hazards, mint
starts/checkpoints and gold goals. These are maps, not gameplay screenshots.

Controls: up/down or stick to browse, confirm to play, left/right to switch Acts
within the room browser, Escape/B to return, mouse hover/click/wheel, touch tap/swipe.
Each Act remembers its selected room for the current menu session.

After changing LDtk geometry, run `python3 tools/build_menu_catalog.py` to refresh
`resources/menu/rooms.json`. The catalog is intentionally lightweight: opening the
menu does not instantiate all game worlds. `chapter_browser_test` compares its room
coverage against the actual imported worlds. Its `-- --capture` option captures UI.
`chapter_replay_test` enters a room in each Act and checks dash and an unbound save.

Act 2 layer ordering is now explicit in both definitions and every room instance:
foreground, entities, hazards/water/terrain, scenery, backgrounds. All entity and
tile data is preserved. LDtk was reopened to verify Entities appears as F2, above
CastleBackground and Background. The existing runtime background visibility policy
is unchanged.
