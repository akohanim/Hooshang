# Act 2 creative direction review — October 21, 2026

Reviewed all 39 rooms on the native 320×180 game surface and played every authored
dialogue chapter through its director. The seven playback cases cover 201 pages,
with exact text/order comparisons against the author resource and physical
support checks during grounded dialogue. Swimming and the carpet hold are
intentional airborne compositions.

## Repairs and presentation changes

- **Missing floors:** rooms 16–19 and 21 had completely empty solid terrain.
  Restored 1,667 cells from their last authored footprints (`1bc1d735`), using
  the current grass brush. Current entities, hazards, water, gardens, prison,
  room identities and other layers are preserved. The LDtk schema and that
  preservation contract pass. Reimported with the editor closed normally.
- **Prison death loops:** destination selection checked the older semantic
  hazards but missed both painted thought layers. Three doorway arrivals could
  immediately kill the player and save a lethal retry point. The search now
  rejects painted hazards across the full player body in the destination room.
- **Rescue staging:** the conversation waits for the player to approach on the
  cell floor. His approach plays a run pose. Jamshid stops at x132 on supported
  ground, replacing x90 over the open doorway well. Completion, skip and save
  restoration use the same supported waiting point. Navigation labels and the
  quest HUD clear during the conversation and return afterward.
- **Fourth key:** restored the author's missing “I'm coming, cousin.” on safe
  ground, once per save, with normal scene skipping.
- **Pond:** the bank exit plays its water-exit clip; the floating EXIT sign
  clears during the encounter and returns when gameplay resumes.
- **Carpet farewell:** Jamshid walks onto the carpet and turns back to Hooshang.
  When the dream drains away, Hooshang's visual double and portrait become adult
  before the hand release. The new hold/release/fall poses derive from the
  approved adult art and have their own editable Aseprite source.
- **Waking bank:** portrait sides follow the actual actors, including the switch
  from underwater to the bank. Authored adult and Rumi expressions now change
  with the scene. Added interruptible silence for grief, the shadow, the look
  across the pond, and the moment alone after Rumi leaves. His first open smile
  remains late in the conversation. The adult's wall-jump settings now return
  with the rest of his movement profile.
- **Final wall:** the expression moves from reflection toward warmth as he reads
  the completed verse and comes home. Painting, coat pickup, salutes and the
  results-to-Act-3 handoff retain their tested endpoints.
- **Rooftops/alley:** orphan window stamps are hidden while their facade layer
  is empty. Their editable source remains available for future wall painting.

The meadow, carpet lesson, eleven gardens, school arrest, gatehouse, all four
prison wings, friendly chase, memories and final painting were visually inspected.
The existing warm landscape palette, child proportions, silhouettes, art sources
and author dialogue were retained.

## Verification

- Seven complete dialogue cases: **201 pages, zero staging/text failures**.
- All **40 directed prison doorways**: arrival, idle and deliberate
  death/respawn pass, with zero unplanned deaths.
- Connected final trials 16–19: real input traversal, **zero deaths**.
- Finale: full playback and seven skip variants pass; dry-bank checkpoint,
  save/reload, results screen and continuation into Act 3 pass.
- Rescue: normal, early/late skip, death and reload pass.
- Pond staging/physical keyboard skip, smoke, movement isolation, child animation,
  dialogue landing/idle, rendering surfaces, and import isolation pass.
- The 50-check inherited batch has **43 passing latest results**. Seven remain:
  `intro_test`, `slide_test`, `chimney_test`, `ledge_mantle_test`,
  `childhood_tempo_test`, plus timeouts in `death_test` and
  `jump_tutorial_test` (the latter has a `Key` type-name conflict).

The legacy garden connected-input driver fails its timed cloud recipe in room 3.
The older prison navigator cannot plan the current hub route. These results do
not establish that those routes are impossible; they limit continuous traversal
coverage. The historical source validator also compares current hub thresholds
against an older layout and fails; current schema/preservation checks and all
40 actual portal crossings pass. A fresh uninterrupted 39-room movement run
and a perceptual audio-mix review remain unverified. Accelerated scene playback
and staged debug entries were used for this presentation review.

## Evidence and rerunning

Evidence root: `output/act2_direction_review/`. `verification.json` summarizes
current checks; `source_preservation.json` identifies the only five changed LDtk
layers; `regressions/latest_results.json` links the latest broad-suite outcomes.
The `final/` folder holds native and full-UI captures and scene manifests.

Run `tests/act2_direction_test.tscn` headless with
`-- --mode=pond|wall|keys|rescue|banter|reunion|ending` (one value per run).
Run `tests/act2_direction_preview.tscn` graphically with the same mode to capture
playback, or `-- --mode=rooms` for the 39-room visual sweep. These fixtures disable
save writes. The staged entries serve visual QA; the connected finale test
supplies separate input-only traversal evidence.

The terrain repair script is a one-time recovery recipe and deliberately refuses
to replace nonempty terrain. Hand edits belong in LDtk. Export saved adult
farewell edits with `python3 tools/export_child_farewell.py --adult`.
