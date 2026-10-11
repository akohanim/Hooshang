# Act 2 candidate playtest

> The later castle-prison challenge revision is documented in
> [prison_challenge_verification.md](prison_challenge_verification.md).
> Results below describe the earlier Act2 polish baseline unless noted.


Candidate build: `builds/act2_playtest/Hooshang-Act2-Playtest.zip`.
Unzip and open `Hooshang.app`. From **DEBUG PICKER**, choose
**Act2 Room 1 — Act_2_Level_0**. This starts at the meadow and does not write
to the existing save slots. The ordinary NEW GAME button still starts Act 1.

Use the existing movement controls; hold **X** to skip a whole dialogue scene.
At the cage, approach it to insert collected keys. Use **Up** at the courtyard
door after the reunion to follow Jamshid. Each prison room is its checkpoint.

The current continuous input run completes all 39 rooms through the final poem:
zero deaths, four keys, four opened locks and sixteen banked lemons. It includes
the revised library and gym. The alley input sequence now approaches supported
takeoffs and checks actual landings. Separate observed sessions cover missed
jumps, respawns, return routes and the chase pond's underwater reward.
These checks establish solutions and retry behavior, not human enjoyment.

The macOS app's title screen and the exported Act 2 resource pack were rendered
successfully. Interactive packaged-menu navigation remains unverified because
CUA could capture the window but keyboard attempts did not move selection and
clicks returned `noWindowsAvailable`. Act 2 saves now show their own subtitle and readable school-room names.
Act 1 title and numbering behavior remain unchanged.

The candidate also reduces repeated garden decoration, clears room titles from
platforms and removes the premature garden completion banner. Both orchard
reward branches pass continuous entrance-to-exit checks.

The candidate now includes the progressive final painting, half-salute and
visible coat pickup/carry, and Jamshid’s carpet farewell salute against the
pale morning sky. The full 108-page preview and normal/skip/save checks pass.

All three milestones are ready for your playtest. All 35 lemons have verified
pickup, banking and retention across room transitions, using separate detours
in addition to the main run. Your supplied Desktop script governs the dialogue.

See `act2_verification.md` for exact evidence and limits, `act2_room_review.md`
for room purposes, and `output/act2_polish/milestones.md` for captures. The final
native UI retry reports a locked Mac; packaged menu navigation and perceptual
sound-mix review remain unverified. Your playtest is the judgment of feel and fun.
