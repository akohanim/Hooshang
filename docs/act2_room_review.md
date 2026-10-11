# Act 2 room review

Milestone 2 acceptance, 2026-10-08. The 39-room required route is implemented
and has a continuous input-driven solution. This review applies the Act 1
checklist to room purpose, readable geometry, recovery and presentation.
It does not substitute for the user's judgment of feel or assert that every
possible detour and camera position has been played.

## Opening and gardens

- `Act_2_Level_0`: meadow playground introduces the child, springs and water.
  Duplicate spawn removed; original art and movement retained. Continuous
  opening traversal passes. Existing ledge assistance occurs here.
- `Act_2_Level_1`: fishing and conversation provide the act's first long pause.
  Observed swim entry, scene skip and real exit pass; the water-staging fall
  is fixed. Dawn/departure survives saves, retries and returns.
- `Level_2`: dedicated carpet lesson teaches low and high steering with water
  recovery. Observed flight, both banks, both optional lemons and real garden
  exit pass without climb or land mantle.
- `Act_2_Level_3`: short rising jump/dash phrases introduce garden footing.
  Broad first landing, distinct hazard floor and visible final arch.
- `Act_2_Level_4`: spring catches develop height and steering. The corrected
  third catch has a wider margin; later descending catches vary the phrase.
- `Act_2_Level_5`: lower crumbling path and upper spring path converge at a
  rest/checkpoint terrace. Both branches bank their own lemon and use the real
  exit without deaths or assistance. Observed misses verify safe retries and
  banked-fruit persistence; the experimental cross-branch drop was unsuccessful.
- `Act_2_Level_6`: two carpet passages with a broad resting island. The last
  moving thought column leaves room to dismount; its corrected flight passes.
- `Act_2_Level_7`: spring, crumble and flight combine familiar movement, with
  an intermediate rest. Widened upper catch passes; the last landing and exit
  remain visible from the final resting island.
- `Act_2_Level_8`: relief room with a safe floor, broad landing and short flight.
  A quiet contrast before the more demanding second garden sequence.
- `Act_2_Level_9`: spring-to-dash relay; widened catches and observed apex/landing
  inspection support its larger transfers. Safe intermediate terraces divide it.
- `Act_2_Level_10`: carpet dismount, island crossing and recatch. Bright platform
  edges separate the rider's narrow passage from the hazard-lined empty-rug lane.
- `Act_2_Level_11`: direction changes and alternating height. Crumbling transfers
  are separated by supported terraces; the final arch is visible at the last rise.
- `Act_2_Level_12`: low ceilings require controlled hops. Hazard bands are drawn
  on the threatening faces; broad spring terraces separate the short-hop phrases.
- `Act_2_Level_13`: flight/transfer climax, then the castle. No premature victory
  label remains. Supported islands interrupt the long course before its final exit.

All eleven garden required routes pass connected input-driven traversal without
climb or land mantle. Rendered samples from each room were reviewed under
`output/act2_polish/final_room_review/garden_*.png`; these are contact sheets of
static game renders, not claims of observed play. Observed room 3 and 9 runs,
the orchard branches, and the full connected run are recorded separately.
Small transfer ledges omit repetitive pots; broad islands retain accents.
Checkpoint behavior remains, with no decorative checkpoint flags.

## Castle and converted school

- `Act_2_Level_14`: forgiving stair/water approach gives breathing room after
  the garden climax. The authored wall encounter establishes the prison story.
- `Act_2_Level_15`: gatehouse entrance and optional upper reward establish the
  fortified school. Sign placement, forward/return travel and retries were viewed.
- `Prison_Hub`: assembly hall introduces Jamshid's cage, four visible locks and
  selectable wings. Contact inserts collected keys; reunion opens the courtyard
  route. It provides orientation and respite between the four excursions.
- `Prison_R01`: one cafeteria patrol introduces timing from safe floor.
- `Prison_R02`: two separated patrol phases develop the same timing idea.
- `Prison_R03`: pantry descent approaches the visible red key; short return opens.
- `Prison_R04`: quiet service corridor closes the red loop without replaying it.
- `Prison_G01`: the reading room introduces a shelf ascent.
- `Prison_G02`: book stacks fold the climb left/right/up to the raised archive
  entrance. Two background bookcases strengthen the room's identity.
- `Prison_G03`: reversible descending archive route reaches the visible green key.
- `Prison_G04`: staff stairs provide a short return to the assembly hall.
- `Prison_B01`: lower landing introduces water and the first surface transition.
- `Prison_B02`: submerged obstruction develops controlled swimming.
- `Prison_B03`: pump-room bank presents the blue key above the water.
- `Prison_B04`: dry drainage passage closes the swim loop with a quiet return.
- `Prison_Y01`: training hall introduces wall-jump transfers with resting ledges.
- `Prison_Y02`: balcony changes the challenge to a 64px dash gap, level takeoff
  and landing banks, and a clearly visible retry pit.
- `Prison_Y03`: equipment-store descent leads to the gold key.
- `Prison_Y04`: the locker-lined corridor provides the short return route.

All four keys and 40 directed prison connections have focused checks. Forward
library, basement and gym loops earn their keys; reverse fixtures explicitly
grant keys only to check unlocked returns. All prison room entries are their
checkpoints, without flags. Imported scenery is non-colliding; source-sync and
castle-layer tests pass. New furnishings changed only two Decor layers.
Native route captures for all sixteen wing rooms were reviewed under
`final_room_review/prison_*.png`; the updated two furnished rooms have separate
rendered inspections under `school_furnishing/`.

## Rescue, chase and ending

- `Act_2_Level_16`: friendly rooftop pursuit releases tension after the rescue.
  Jamshid waits/hops ahead; this is not a lethal chase timer.
- `Act_2_Level_17`: alley steps vary the roof jumps. Supported takeoffs and
  actual landings pass; observed retries and the onward pond connection are recorded.
- `Act_2_Level_18`: swimming creates a change of pace. Both ponds have usable
  banks; the underwater lemon was collected, banked and retained at the real exit.
- `Act_2_Level_19`: broad painted-wall floor stops the movement sequence for
  reunion, then hands into the carpet farewell.
- `Act_2_Level_20`: waking pond changes to adult Hooshang and Rumi. Separate
  instance settings preserve the shared player controller and Act 1 behavior.
- `Act_2_Level_21`: completes the poem, coat pickup, salute and departure.
  Only this endpoint completes the act. Full 108-page finale playback, native
  captures, normal/skip/save endpoints and audio-cue dispatch checks pass.

Chase route captures show readable roof landings, safe pond banks and a quiet
wall stage. The final hand release, Jamshid farewell, morning sky, memory images,
painting, coat and adult salute have separate rendered cinematic evidence.
The source dialogue remains the user's Desktop script.

## Milestone 3 acceptance

All 35 optional rewards now have pickup/banking/actual-transition evidence in
`milestone3/collectible_coverage.json`. Final detours leave the existing room
geometry intact. The complete 39-room route, retries, keys, story endpoints and
presentation review have no known progression blockers or major defects.

The focused final regression scope and legacy Act1 fixture limitations are in
`act2_verification.md`. Native packaged-menu input remains unverified on the
locked Mac; source-engine input runs are separate evidence. Audio dispatch,
stopping and clipping pass; the user's playtest judges mix, difficulty and fun.

Milestone captures: `output/act2_polish/milestones.md`.
