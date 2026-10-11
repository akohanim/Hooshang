# Prison precision revision

Final verification and build: `prison_precision_verification.md`. The dated
implementation notes below retain the development history; later evidence
supersedes provisional timings and pending checks.

This revision responds to the user's assessment that the completed challenge
build is still too simple. The previous passing routes are a baseline, not
acceptance evidence for this revision. Celeste remains data-only research.

## Audit before rebuilding

Source snapshot and 8,650-file hash inventory: `output/prison_precision/baseline/`.
The machine-readable room inventory records current geometry and mechanism
counts. The existing rendered recipes reveal where commitment is missing:

- Library G01/G02/G03: 44/65/61 one-way cells, no temporary supports. Nodes
  require visiting locations but permit long rests between individual actions.
  G03's driver explicitly rests after crossings. More nodes would add errands,
  not sustained precision.
- Cafeteria R01: no platform sequence; a nine-second lever passage teaches
  activation but largely tests travel. R02 has a 12-second timer and permanent
  intermediate supports. R03 contains the prison's only crumbling shelf (40px
  wide), then banks a midpoint before a largely independent patrol dash.
- Basement B01/B02: permanent valves and sheltered swim routes teach the rules
  clearly, but do not develop a constrained timing sequence. B03's two seals
  can be separated by unlimited time on stable platforms. Swimming must remain
  central rather than becoming a short preface to an ordinary land gauntlet.
- Gym Y01: useful wall-jump introduction, eight-second grace. Y02 has two gaps
  and a permanent middle bank within 8.5 seconds. Y03 splits its wall-jump and
  reverse dash into separately banked phrases; the old measured upper crossing
  is 2.53s against 6s, ascent 4.17s against 7s. Merely shortening those timers
  would increase urgency without adding the missing sequence depth.
- Hub and R04/G04/B04/Y04 are intentional breathing/return rooms. Preserve their
  short routes and safe orientation role; do not turn every room into a gauntlet.

The Celeste binary analysis provides useful structural references: `10-z` pairs
16px temporary supports with moving hazards; `11-x` separates outbound control
access from the return passage; `08-d` requires high/low direction reversals.
These are measured arrangements with inferred routes, not executed Celeste
solutions. See `celeste_ch3_challenge_analysis.md`.

## Acceptance standard

A developed encounter must contain four to seven consequential movement actions
before a genuine safe rest: takeoff choice, controlled landing, reversal,
wall-jump, directional dash or timed passage. A switch press and extra walking
do not inflate the count. Capstones may contain two such sequences separated
by a banked checkpoint-like milestone; never bank after every single jump.

Use the child profile as authoritative: current run cap67.5px/s, jump impulse
144.375px/s, momentum and countersteering, existing dash/swim behavior. Shared
adult reach comments are not sufficient design measurements. Do not modify
physics. Start with 24px temporary landings; use 16px only after measured margin
and failure recovery are demonstrated. Nine-pixel body clearance must be tested,
not inferred from the visible boots.

Measure contact-to-relaunch times and the actual available landing interval,
not just total room travel time. Calibrate global timers from repeated successful
inputs plus deliberate early/late failures. Tentative dimensions and timings
below are hypotheses until rendered routes establish them.

## Milestone 1: cafeteria, commitment through temporary support

R01 introduces one collapsing landing between permanent launch/recovery ground:
observe warning → jump onto it → relaunch to permanent footing. Teach its timing
without a simultaneous patrol. Keep the lever's cause/effect local and visible.

R02 develops a descending then rising three-landing route: launch → temporary
landing → reverse or adjust launch → second temporary landing → directional dash
through the passage → permanent seal bank. Preview the whole sequence from safe
footing. No indefinite middle rest. A lower recovery route returns to the lever;
it must not give access to the seal from below. Avoid a single dash bypassing
all temporary landings. Timer expiry must not trap the actor behind a shutter.

R03 combines a rising zigzag with a wall-jump reversal and a final dash landing.
Candidate first phrase: jump-through launch ledge → first temporary landing →
higher temporary landing → wall-jump away from the partition → controlled upper
landing → dash through its opening → permanent bank. The second phrase combines
an already-taught collapse with a moving-hazard window and the key approach.
Retain the midpoint bank, dual key requirement and return route. Test whether
up-diagonal dash or entrance elevation bypasses the intended commitment; alter
partition geometry only where a bypass removes the sequence's substance.

Do not increase switch density. Existing levers restore spent supports, including
when their gate is already completed. Death/room re-entry resets temporary
footing, retains banked seals and keys, and clears incomplete timers.

## Milestone 2: distinct remaining wings

- G01 teaches a controlled landing/reversal on temporary support while retaining
  simple contact seals. G02 develops an elevated outbound chain and low return
  pocket. G03 combines high/low reversals, temporary supports and a patrol crossing.
  The sequence, rather than a larger seal count, supplies the difficulty.
- B01 retains safe swim introduction. B02 develops a readable moving-hazard
  channel with sheltered observation pockets. B02 supplies the water exit onto temporary footing. B03 develops a precise
  submerged passage with an observed patrol window and a reversed return
  sequence, then a brief dry recovery jump. No underwater dash. A timer may span one committed phrase, never
  blind exploration of the whole flooded room. Avoid drowning/air mechanics.
- Y01 retains wall-jump instruction with a constrained but fair landing. Y02
  replaces the generous permanent middle rest with taught temporary footing.
  Y03 combines plate departure, successive wall-jumps, braking on a temporary
  landing and a directional dash through a visible hazard window. Bank meaningful
  phrases, not individual actions. Reverse travel must remain possible after
  supports collapse, through a restorable or permanently opened return route.

Before authoring each developed encounter, record exact intended actions,
observation location, support widths, collapse deadlines, global timer margin,
failure path and likely bypasses in the authored-room section below.

## Presentation and validation

Keep thin wooden one-way ledges distinct from solid scaffolding. Collapsing shelves must use the existing three-frame beveled crumble stones,
never scaffolding;
retain restrained jitter and a spent outline. No circuit wires, large timer
banners, new dense labels or extra switches. Readability is checked at320×180.

Acceptance requires earned forward/reverse key loops, early/late failures,
missed landings, actual collapses and resets, safe respawns, save/load and final
rescue. Use rendered input runs for routes, explicitly staged fixtures for
isolated states, and native inspection for presentation. A successful scripted
solution is necessary but does not establish enjoyable human difficulty.

## Authored-room results

The representative wing rebuild is underway. R01 has a successful introductory
route; the developed encounters have not yet met the higher standard. The
previous build remains available separately.

### R01 authoring plan (before build)

Keep the room's external apertures and existing lever/relay gate. Replace the
small floor notch with a 104px gap, x136–240, retaining the room's outer floor.
Place one solid collapsing shelf, 24px wide with its top at y144, centered x192.
The right bank at y160 is the observation/launch area; the left bank at y160 is
the permanent recovery landing. Sequence: activate lever → jump left and brake
onto the shelf → relaunch with left dash toward the bank → reach the relay.
The shelf uses the existing 0.6s contact deadline. Keep the nine-second global
lever timer for the lesson until measured. Remove the introductory patrol so
collapse behavior is the only new timing demand. Floor spikes at the bottom of
the pit provide a quick entrance retry. A single bank-to-bank dash bypass must
be tested against the actual child; geometry alone is not proof it fails.


R01 initial measured route: zero deaths, shelf contact to relaunch0.133s against
0.6s collapse. Actual onward exit to R02 succeeded. Remaining acceptance work:
late launch, missed landing, single-dash bypass, reverse crossing and room
re-entry. This two-action lesson is not counted as a developed four-to-seven
action challenge.

### R02 authoring plan (before build)

Replace the permanent center counter with four solid 24px collapsing shelves:
centers/top edges (216,144), (176,120), (216,88), (168,64). Keep the right
entrance/start bank and left exit bank. Intended movement actions: enter the low
shutter and jump to shelf1 → jump/dash left to shelf2 → reverse right upward to
shelf3 → reverse left upward to shelf4 → flat left dash through the high shutter
and settle on the permanent seal platform at x56–112,y88. No intermediate safe
rest; each shelf keeps the taught0.6s deadline. Retain the current12s global
window provisionally, then measure its margin.

Move the shared high shutter to x120–128,y48–112 and the partition around it;
move the seal to (64,80). The lower exit stays bank-only. Remove the former
middle-return lever and both patrols: the five-action collapse chain develops
commitment; R03 will combine it with hazard timing. The remaining far return
lever sits on the final safe bank and restores all shelves. Pit floor spikes
return failures to the nearby room checkpoint. The completed state remains
permanent; opening the exit must not require repeating the chain.

Bypass probes must try jumping/dashing directly past one shelf, climbing along
partition faces by wall jumps and crossing from the entrance at high elevation.
Skipping one support through a demanding four-action alternative is acceptable;
a single dash or floor walk removing the chain is not. All timings and reverse
crossings remain unproven until actual input runs.

R02 first measured sequence succeeds with all four central shelf contacts and
no deaths/climb/mantle; contact-to-relaunch intervals are0.1s of0.6s. The final
seal was reached within6.65s including approach and capture overhead. Tighten
the global timer from12s to8.5s, retaining about1.85s margin on that demonstrated
recipe. The intended five movement actions remain the primary demand; the
shorter overall timer prevents a long delay before committing.

A two-shelf shortcut probe reaches shelf2 but fails when attempting to skip
straight to shelf4; its failure does not prove every alternate route impossible.
Deliberately waiting on shelf2 causes one actual death, safe entrance respawn,
cleared incomplete timer and restoration of every temporary shelf. Remaining:
reverse loop, deadline variations, additional bypasses and full-wing integration.


R02 return validation: widened the upper shutter to y40–112 after an actual
return jump hit its partition. Flat dash near the jump apex reaches shelf4;
a following jump reaches shelf3, then dropping along the right wall reaches
the low entrance. Earned R02 → R03 → R02 → R01 → hub input run passes with zero
deaths and no climb/mantle. Return contacts are0.133s and0.1s before departure.
Additional timing/landing tolerance probes remain necessary.

User art correction supersedes the first prototype: all collapsing supports
use the project's existing beveled crumble stones and warning frames. Solid
steel scaffolding never collapses; thin wooden ledges remain one-way. LDtk
icons and Godot rendering now agree on this distinction.

### R03 precision plan, before authoring

First phrase: launch from the left bank onto24px crumble stones at center/top
(56,136), (104,112), (64,88), (112,64), reversing direction twice; dash through
the high first shutter onto a permanent midpoint at x160–216,top96. Five
movement actions before rest. Start lever remains on the floor; remove the old
permanent left staircase, retaining only the upper portal landing. The top
portal remains reachable from the upper crumble stone for retreat. First
provisional timer9s, calibrated only after input measurement.

Second phrase: from the midpoint, jump to24px crumble stones (232,72),
(280,48), (232,32), then drop below the partition lip and dash right through
the patrol window onto the far seal ledge at top112. This combines rising
reversals with a deliberate lower crossing; ceiling clearance and hazard phase
must be measured. Observe the patrol from the permanent midpoint before starting
the second provisional8s window. Retain both banked seals, the key alcove,
original key and R04 shortcut. Existing return levers reset the appropriate
stones. Pit hazards give quick entrance retries; completed seals survive.

Bypass checks: top entrance after activation, skipping the first low stone,
direct midpoint-to-far-seal dash, and jumping over the second partition. A
trivial direct second crossing is a design failure even if the intended route
works. These layouts remain provisional until rendered input runs, recovery,
retreat and timing margins are checked.


R03 authored revisions after rendered movement:
- First safe midpoint lowered to top120, with the first seal at168112 and
  lever at200112. This puts the upper seal beyond a direct jump from the bank.
  Its first phrase measures5.58s with a9s window; all four24px stones receive
  central contacts and early0.1s departures.
- Second shutter opening raised to y16–64 after the original y40–64 gap
  physically prevented reaching the intended48px-high stone. The upper seal
  now sits above the final stone at23224, so dropping from the far intermediate
  stone does not bypass the reversal. No extra mechanism was added.
- Far wooden landing ends atx296, leaving the original right-side drop into
  the key alcove. Extending it to the wall had sealed this route; fixed after
  actual movement exposed it.
- Successful input run lands on all seven stones, banks both seals, collects
  Red and uses R04 to return to the hub without death or climb/mantle. Delayed
  departure from the first stone of phrase2 produces a clean death/reset and
  preserves phrase1. Direct bank-to-upper-seal jump/dash fails.
- Current phrase2 timer8s remains provisional. Slower-departure measurements,
  hazard phases, additional bypasses and retreat are outstanding. The initial
  lever-side jump hits the low stone's underside; the verified recipe uses
  the visible left bank as a run-up, starting aroundx28. Review that launch
  during the usability pass rather than requiring an undocumented technique.

R03 timing samples: quick route first seal5.58s, second seal2.30s; holding on
every stone for18 frames gives6.40s and2.88s. Both complete Red→R04→hub without
death. Contacts in the slower sample are0.30–0.317s against0.6s collapse, so
success does not depend on the first few landing frames. Global windows remain
9s/8s pending patrol-phase and connected-route calibration; collapse deadlines
currently provide the primary pressure.


R03 return revision: the second seal also opens a lower grate in the partition,
x264–272,y64–112. This is a bank-only linked shutter, with no extra activation
control. It prevents the earned return route requiring the near64px ascent
through the patrol. From the key-side step, observe the patrol, jump to the
far ledge, walk left through the open grate to itsx244 edge, jump to the safe
midpoint, restore the first stones and traverse104112 →6488 →11264 before
jumping to the upper portal landing. Full earned forward-plus-reverse cafeteria
run passes with zero deaths and no mantle/climb. Geometry and controller state
are both required: an isolated R03 debug start cannot prove return through
R02's still-unearned exit seal.


## Accepted user addition: two ordered musical key gates

Exactly two prison puzzles now use the existing musical tiles: G03's archive
key gate (Green) and Y03's gym key roof (Gold). Each has five physical16px pads
on the8px placement grid, numbered1–5 with the established pitch/color art.
The order must be played; merely touching all five out of order does not work.
Wrong/repeated notes reset only that unfinished melody, with the first note
able to begin a fresh attempt. Completed gate progress survives death and save;
uncompleted progress resets on death/room exit. No glow ability is granted.
Act1's note manager remains isolated from these prison pads.

These are additions to the active precision objective, not a replacement for
four-to-seven action sequences. Integrate required ordered contacts into the
library's high/low return route and the gym's wall-jump/reversal route; do not
put five pads side by side or add a separate switch for each. Keep the readable
numbered tile art, a small instruction and local note feedback. Refine their
provisional authored positions during those wings' movement passes.


## Partial entrance ledge rule

At each dry upward room connection, the upper room now has a16px thin wooden
one-way ledge positioned16px above the seam. It covers only the left two cells
of the40px entrance; the other24px remain open for descending without a
special drop-through input. Keep that body-clear gap through future room edits.
The nine locations are recorded in `entrance_ledges/placements.json`. Continuous
underwater connections retain water instead of introducing an artificial dry
landing. Validate actual upward transition/landing and side-step descent, not
just a graph edge or open boundary cells.

### G03 revised music capstone plan, before build

The prototype's second-note approach can hit note4 overhead out of order.
Replace its criss-cross permanent shelves with a clear low-ceiling music run.
Five existing solid musical pads are inset into a ceiling at centers
(56,72),(112,72),(168,72),(224,72),(280,72). They are struck from below; the
ceiling prevents standing on their tops and bypassing the movement sequence.
A safe first bank is top104; three24px crumble stones sit below notes2–4 at
top104; the final note has a permanent thin one-way bank at top104. Intended
sequence: jump-strike1 then dash right onto stone2 → jump-strike2/dash to3 →
jump-strike3/dash to4 → jump-strike4/dash to the final bank → strike5 to open
the key roof. The first bank provides a visible practice hit without a crumble
deadline. Existing0.6s stone deadlines provide pressure; no global timer or
additional switch. Geometry and contact timings must be measured.

Keep the horizontal entry accessible along the left side. Preserve the bottom
vertical portal, its partial entrance ledge, and the key/shortcut. Reset the
three ordinary crumble stones on death/room re-entry through existing world
behavior. Wrong notes reset melody progress; dropping to the lower recovery
floor permits returning to the first bank. Avoid an unrecoverable spent-stone
state: retry controls/reset behavior need actual verification before acceptance.

### G03 ceiling melody: implemented and measured

The planned ceiling sequence is now authored. First bank and all note landings
are at top104, ceiling notes at y72; three24px crumble stones are centred at
x112/168/224. Note1 starts on a permanent bank, note5 ends on a thin wooden lip.
A48×8 musical roof at(288,132) opens access to Green at(288,154). The right
edge allows a normal downward step, and a small return step exits the key
alcove toward the original lower portal and its partial catch ledge.

Actions: observe from the first bank, jump-strike1, flatten the dash beneath
note2, land/strike2 and dash3, land/strike3 and dash4, land/strike4 and dash5,
strike5 then drop into the key alcove. No global timer: each existing crumble
stone gives0.6s from contact. Scripted normal takeoff ages are about0.183s;
adding a0.3s dwell still passes, with actual takeoffs at0.383–0.433s. Dash timing
is later than takeoff and can legitimately outlast the stone.

A missed temporary landing drops toward a visible spike bed. One deliberate
late collapse was followed by a complete successful retry, proving death
restores an earned route rather than only resetting displayed state. The
connected forward loop succeeds from the hub. Reverse traversal, wrong-note
recovery, bypass probes and G01/G02 escalation remain outstanding; this is
not yet the whole-wing quality signoff.

### G01 reading-room introduction: plan before authoring

Preserve the two contact seals and existing gate; make the route between them
teach the commitment needed in the archive. A permanent first bank at top136
holds seal1 (104,128). Two24px existing crumble stones at(160,116) and(208,92)
lead to a permanent bank at top64 holding seal2 (248,56). The upper catch/exit
ledge remains at top24. Sequence: observe on bank1 → jump/dash onto stone1 →
relaunch up-right to stone2 → jump/dash to bank2 → jump through the exit lip.
The stones retain the existing0.6s collapse warning. The first bank and bank2
are safe observation/breathing points. The lower pit gives a quick room-entry
retry; the lower partial ledge and its descent gap stay exactly intact.
Measure both stone contacts, delayed departures, and reverse traversal before
calling this room finished. Probe a direct bank-to-bank dash and wall routes;
keep legitimate alternate movement without allowing a walk around the lesson.

G01 authoring/initial evidence: both stones and both seals are reachable with
jump/diagonal-dash inputs; a0.3s dwell on each stone passes (0.6s collapse).
The child jumps about32px in the exit test, so the40px rise to the upper lip
uses a straight upward dash. Diagonal steering can carry him outside the
40px aperture. Reverse inspection exposed a narrow bank below the lip; the
bank now extends fromx232 to312 (formerly288), giving a clear landing after
stepping off the lip. Its left edge and both challenge landings are unchanged.
The room's hazard pit, lower partial entrance ledge and side gap remain intact.

### G02 stacks sequence: plan before authoring

Replace the old high-left/high-right/low-pocket errands with one developed
out-and-back flight. Keep the existing completed-circuit save identity and exit.
A safe launch bank at top144 holds the first seal at(104,136). Four24px crumble
stones have top centres(160,128), (216,128), (264,96), (216,64). The final seal
rests on a permanent bankx144–184, top40. Sequence: flat crossing onto1 →
flat crossing onto2 → rise right onto3 → reverse up-left onto4 → rise left to
the seal bank. A final jump/dash reaches the permanent exit bankx264–312,top64.

A short overhead hazard strip prevents going straight from stone2 to stone4;
a second underside strip above the bottom entrance prevents jumping directly
from that entrance onto stone3. Both must read clearly and leave a safe lower
approach. Retain the partial entrance catch ledge and24px side gap. Remove the
third low contact node: it adds an errand, not movement depth. The existing
three-node puzzle becomes two endpoints connected by a continuous challenge.

The stones use their existing0.6s warnings. Bottom ground permits retreat to
G01; a missed crossing must have a fair recovery or rapid reset without leaving
spent stones as a softlock. Measure normal/delayed routes, bypass attempts,
failure/retry and return from the exit bank. This is provisional geometry until
actual input routes confirm it.

G02 implemented refinements: the launch bank is now top152, with a small
approach step at top168. A spiked masonry beam spansx128–232 (solidy144–160,
spikesy136); floor184 leaves24px beneath it for a ground-level return passage.
The spike strip continues tox280 above the lower entrance. This separates
safe approach/retreat from the challenge rather than permitting a jump directly
onto the middle stones from the floor. The original partial catch ledge at
x232–248,y176 and descent gapx248–272 are unchanged.

The first landing uses an upward diagonal dash. The second crossing uses a
short jump under the upper hazard; step toward the right edge before rising to
the third stone, then reverse up-left to the fourth and final seal bank. The
exit bank was extended16px left tox248 after the original post-seal jump missed
its edge. The bank may provide an alternate rest after the outer turn; it does
not unlock the exit or remove the final-seal requirement.

Measured scripted routes pass at0.1s and0.3s dwell on every0.6s crumble stone.
Waiting for the first stone to collapse gives one real death, restores all four
stones and the checkpoint, then a complete retry reaches G03. Full connected
forward/reverse validation remains separate from these standalone results.

G02 connected signoff for this pass: the complete earned library forward/key/
shortcut/reverse loop returns to the hub with zero deaths and no climb/mantle.
The reverse route uses the upper stone, final-seal bank, safe left descent, then
the24px lower passage and partial entrance ledge. Normal and0.3s-dwell routes
pass, as do aimed landing offsets of−3px and+3px on all four stones. An upward
jump/dash under the beam is blocked without reaching any stone or opening the
gate. These establish playable routes and some margin, not exhaustive bypass
coverage or human difficulty approval.

### B01 flooded introduction: plan before authoring

Keep the permanent submerged seal, sluice, dry room-entry checkpoint and both
room connections. Replace the single diving baffle with a roofed swim passage:
hanging bafflesx112–128 and208–224 end aty144; a floor baffle x160–176 rises
toy128. Water spansx56–272 fromy96, with a roof overx80–280 aty88. The24px
left mouth stays open for diving in and swimming/jumping back out. The roof
prevents traversing on the surface and dropping directly onto the final seal.

The seal moves to(248,160). Intended inputs: dive before the first barrier,
swim right beneath it, rise in the middle shaft, cross above the floor baffle,
dive before the last barrier, reach the seal, then turn back a short distance
to the existing exit sluice. Upper passage32px, lower passage40px, turning
shafts32px between baffles. This is a safe teaching room with no added hazard
or timer; later rooms combine this steering pattern with commitment. Verify
both directions, water exit without bank mantle, checkpoint/death recovery,
and absence of an above-water bypass before treating it as finished.

B01 measured outcome: the alternating swim passage and reverse route succeed
with real child inputs and both mantle assists disabled. Surface recovery uses
the open left mouth and normal jump kick. Underwater respawn input preserves
the earned sluice, restores dry footing, and a second complete attempt passes.
The full basement key/shortcut/reverse loop also passes; its B02/B03 portions
remain the earlier baseline, not completion evidence for their deeper redesign.
Next development should combine this steering with a moving-hazard window and
an air-pocket landing sequence, keeping the permanent dry valve milestone and
short return route. Final positions/timing require a separate authored plan.

### B02 air-pocket commitment: plan before authoring

Retain the swim approach, permanent dry-valve milestone, exit sluice and room
apertures. Replace the pocket's fixed floor with two existing crumble stones:
first centre(120,140), top136; second centre(88,116), top112. The dry valve
moves to(88,104). Raise the pocket roof to y80–88, leave airx80–136,y88–144,
and restore water beneath the stones. Sequence: dive below the entrance baffle,
rise in its left shaft, leave water onto the first stone, jump/dash up-left to
the second, operate the dry valve, then drop back to the lower swim exit.

These prison-only swim stones reuse the original0.6s art/physics but reset
when the player returns to water and their solid box is clear of the player.
This makes a failed air jump immediately retryable, without a reset switch,
forced death or changes to shared player/crumble behavior. They must not reset
while the player is airborne between the two landings. Validate this condition
and collision clearance explicitly. A moving-hazard timing window is planned
for the swim approach after the landing sequence is measured.

B02 swim-window refinement: one vertical patrol is centred at(144,112), amplitude8,
speed0.3 (approximately10.47s per cycle). Observe from(184,160), pass beneath the
entrance baffle, brake the ascent near(144,140), then turn left into the air
pocket. A deeper initial20px sweep killed during normal buoyant overshoot and
was rejected. The higher short sweep leaves readable clearance for the turn.
The left recovery water under the stones is outside its horizontal kill band.

Actual movement revealed that EXIT_WATER plays an uninterruptible0.5s landing
animation even with bank mantle disabled. The prison-only swim-stone subclass
therefore pauses its existing0.6s countdown while that animation owns a rider
on its skin. Shared player and crumble scripts are unchanged. Tests wait for
controls to return before measuring dwell, and check that animation time does
not consume the movement window. This is a local prop rule, not a new ability.

The first earned collapse/retry with the patrol succeeds without death; checks
also observe a real collapse, prevent collision restoration around the swimmer,
and require both stones to stay spent during the dry airborne sequence. Full
connected and wider timing-margin checks remain separate gates.

B02 timing-margin evidence: the route also passes with a0.5s later departure
from the observed patrol phase and0.3s dwell after controls return on each
stone (measured countdown ages0.317s/0.300s). The wet-retry run observes actual
collapse, checks the restored collision is clear of the swimmer, then earns
the valve and completes the room without death. The seven relevant regressions
pass after the local countdown-pause fix. Patrol draw order was raised above
water tiles after native inspection showed its outline being tinted away;
artwork, collision size and movement remain unchanged by this readability fix.

B02 connected validation now passes the earned full basement loop and its
complete reverse route with zero deaths/climb/mantle. Blue and all four
basement circuits survive the return. This proves current connectivity and
local movement sequences, not the unfinished B03/gym difficulty standard.

### B03 submerged commitment: first capstone revision

Before replacing the upper approach, strengthen the existing deep-seal route
while retaining the permanent dry-valve milestone. Inside the sealed reservoir,
a hanging8px baffle atx128–136 ends aty144; an8px floor baffle atx88–96 rises
toy144. The seal moves to(72,128). Enter below the hanging baffle, hold depth
in the32px turning shaft, rise during a visible patrol window, then turn left
above the floor baffle. Reverse the sequence on return. A single patrol at
(112,128), amplitude12/speed0.35, supplies commitment while the observation
points remain outside its kill band. No underwater dash or climb is involved.

Preserve the current upper seal/key/shortcut for this first pass. Its deeper
replacement remains required; a passing new swim route does not sign off the
whole B03 capstone. Test both directions with the actual swim acceleration,
keep original sluice/exit geometry, and retain the dry-valve save state.


### B03 pacing decision after the first rendered route

The upper dry seal remains a short recovery jump/dash after the submerged
commitment, rather than another copy of the library's crumble ladder. B03's
main sequence is: operate the dry valve; descend through its sluice; swim
under the hanging baffle; hold depth below the patrol; rise on its high pass;
turn left above the floor baffle to the seal; reverse the timed turn; descend
under the hanging baffle and return to the dry bank. Then reach the high seal,
collect Blue and use the upper shortcut. The hanging and floor baffles prevent
a straight swim to the deep seal. The reservoir roof blocks a dry top entry.

The actual input route completed this sequence and the Blue shortcut without
death or climb/mantle. A separate real respawn input at the deep seal returned
to dry footing, retained the opened valve, cleared the partial two-seal puzzle,
and then completed the route with exactly one expected death. The staged pump
regression now finds the deep seal from its imported entity position; its
hazard placement is outside the new baffle. It verifies physical gate blocking,
hazard death, high-first order, partial resets and permanent completed access.

B03 uses one clearly outlined patrol and two masonry baffles, with no extra
switches or connecting lines. Native renders in
`output/prison_precision/basement_capstone/` show the deep turn and key route.
The composed Hub/B01/B02/B03/Blue/B04/Hub route and full reverse pass with zero
deaths and no forbidden movement. A30-frame (0.5s) later patrol departure also
passes. A90-frame (1.5s) late departure produces a real patrol death during the
left turn. These are measured sample offsets, not a claim that the entire interval
between them is safe. Six relevant regressions pass (smoke, pond, water_tile,
pump_retry, prison_circuit_save and world_bounds). The late-death continuation
passes with exactly one death: dry respawn, retained valve and completed retry
through Blue and the shortcut. These remain scripted routes, not a human
assessment of difficulty or feel.

### Y02 balcony commitment: plan before authoring

Preserve the plate,8.5s release grace, two vertical shutters, far seal and
bottom partial entrance ledge. Replace the broad middle bank with two24px
existing crumble stones: centre184/top152 and centre232/top128. Start bank
ends112; far bank starts280 at160. Intended actions: charge plate; run to108;
jump/dash to184146; brake and immediately jump/up-dash to232122; low hop/flat
dash through the second shutter to296154; touch the seal. The temporary
supports, changing elevation and low roof distinguish this from a single long
jump. No scaffold becomes a crumble tile.

Remove the obsolete middle-bank lever rather than leaving a floating control.
The far return lever restores linked stones; room entry/death also restores
them. Missing the first two landings reaches a visible hazard bed. The preserved
bottom entrance catch at232–248 has its24px descent gap; if caught there, the
player must still be able to jump back to the route. Completion banks both
shutters and the Y03 passage. Reverse travel must be measured after real forward
completion, not assumed from forward reach. Probe direct start-to-far-bank and
floor routes for bypasses. Keep8.5s until measured child traversal establishes
its margin; do not tune physics to make the geometry work.


### Y02 measured route and return

Forward sequence passes with0.1s and0.3s dwells on the existing0.6s crumble
stones. From the launch point to confirmed far seal takes3.23s /3.82s,
respectively. Release grace is now6.5s; the slower route had2.63s remaining on
the last sampled unsolved frame before the seal banked. The obsolete middle
lever is gone. The initial plate remains a safe observation point.

The return entrance catch is at244170. Jump from it to the far bank296154,
then up-diagonal dash to232122, low hop/flat dash to184146, and up-diagonal
return to104154. Trying to jump directly from the catch to the underside of
its overhanging solid crumble stone failed; the far-bank route succeeds.
Neither direction needs climbing/mantle. The ordinary launch bank is now
solid masonry, eliminating an unnecessary one-way strip only8px above solid
flooring. The actual entrance catch remains thin wood with its side gap.

An intentional first-stone overstay produces one real hazard death, dry plate
respawn and restored stones; the same run then completes both directions. A
single jump/dash attempt to skip the first stone fails, then the retry completes
normally. This is one bypass probe, not proof against every alternate route.
Seven regressions pass for the authored two-stone geometry; final launch-bank
forward/reverse and collapse retry also pass. Smoke/world_bounds pass after that
edit. The retry test's shutter probe touched both ledge and gate atx252; it now
probes the clear side gap atx260 and passes (`gate_probe_check/`). No player or shared crumble physics edits.

Evidence: `output/prison_precision/gym_balcony/`. The old balcony scene delegates
to the new input driver. The full gym driver now composes this balcony route,
but its complete key loop awaits the Y03 musical capstone revision; no full-gym
success is claimed yet.

### Y03 musical capstone: upper reversal plan before authoring

Preserve the five notes, key, two banked timed phrases, lower wall-jump faces,
midpoint and room entrances. Audit: notes currently sit among overlapping broad
one-way shelves; the upper return can be broken into generous rests. Replace
upper shelves with two24px CrumblingShelf stones linked to gym_reverse:
centre248/top56 and centre152/top56. Keep the top entrance landing at232–272,
but add an8px hanging beam at224–232,y8–48, so that entrance shelf cannot provide
a walk-off shortcut straight to note4.

Intended route: strike note1 (128136) from below; perform the opposed wall-jump
ascent; land note2 (24080); touch/bank the midpoint and charge the second plate
(256116); jump onto note3 (296104); jump/up-dash to the first stone24850; step
left off it and fall below the beam, then dash up-left to note4 (20056); cross
the second stone15250; land note5 (10448), bank the upper seal and enter Gold's
opened alcove. The new upper phrase starts at the visible midpoint plate;
initial grace8s, to be measured. Existing return levers reset its stones.

Safe observation: permanent midpoint before commitment. Failure: fall to the
lower route or use room retry; deaths restore stones and clear partial music,
while banked timer milestones persist. No extra switches/lines. Probe the
entrance-bank shortcut, direct note3→note4 transfer and repeat-note recovery.
Retreat, the Gold shortcut and reverse ascent back to Y02 require actual input
validation. This is an authoring plan, not a claim the current room passes.

### Y03 implemented route, entry and recovery

Final adjustments from rendered tests:
- Note2 moved to26488. Its old24080 position caught the falling player from the
  first upper stone and incorrectly repeated an earlier note. The midpoint
  head-strike is now clear of that fall. Walk to280114 before jumping to note3
  so its approach does not strike note2 again.
- Upper seal moved to8856, return lever to7256, on a permanent64–96 bank at64.
  Their former overlap with note5 made completion depend on a narrow contact.
- Removed the full-width160–184 one-way at120 from the opposed-wall shaft.
  The real top entrance must descend that shaft to reach the first note. Its
  former ledge blocked descent beneath the closed upper-gate column. The open
  shaft also makes the capstone ascent consecutive wall jumps, while Y01 keeps
  the introductory resting ledge.
- Removed the upper patrol; the ordered movement, collapsing supports, beam
  and timer already supply commitment without another overlapping visual cue.

Real entrance route: from Y02's top connection, drop to the far return lever
at280114; operate it; cross the midpoint and top of the right wall; drop through
176154 and walk under the left stem to the starting plate. Once the first
phrase is banked, its gate stays open through retries. Room-entry checkpoint
behavior is unchanged, with no added flag or checkpoint entity.

Musical route: head-strike1; consecutive wall-jump ascent; bank midpoint;
head-strike2; charge second plate; step right and jump onto3; jump/dash to the
first stone; let it collapse while steering left; once below the beam, dash
up-left onto4; cross the second stone and land5; drop onto the clear upper seal;
enter Gold's opened alcove and take Y04 to Hub. Upper phrase reaches note5 in
5.35s with0.1s dwells,6.13s with0.3s dwells. The slower route has1.875s left on
the last actual timer tick before banking the upper seal (8s grace).

Default fall threshold66 and an earlier58 both succeed. A late74 transfer
misses note4 and falls to lower safe geometry. In the full connected test, an
actual retry input then causes exactly one death, restores the real top-entry
checkpoint and both stones, preserves banked ascent, and completes all five
notes, Gold, shortcut and full reverse through Y03/Y02/Y01 to Hub. A separate
wrong-note run repeats note2, verifies that the partial melody clears, walks
back through the shaft and completes the puzzle with zero deaths. These are
sampled input recipes, not an exhaustive timing interval or human difficulty
judgment.

Reverse: return from Y04, ascend the open opposed-wall shaft, use note3 and the
first restored stone, then jump/up-dash through the top entrance to Y02. The
up-dash can trigger the room transition before landing; the route waits for
that handoff rather than treating it as a missed platform. Continue through the
verified Y02 reverse sequence and Y01 to Hub.

Evidence: `output/prison_precision/gym_music/` (`full_late.json`,
`wrong_note.json`, `beam_58.json`, `hold_18.json`, native phase captures).
Six regressions pass in `checks/`; smoke/world_bounds/gym_capstone_retry pass
again after opening the shaft in `final_checks/`. Both imported musical gates
pass real staged contacts (`music_import.log`). Y01's actual held-plate,
expiry/retry, wall-jump and reverse route also passes; retain this short lesson
as breathing room before the two developed gym challenges. Direct-skip probes
and the combined four-wing mission remain in the final verification pass.


## Final integration evidence

The direct note3→4 jump/dash probe cannot reach the upper target: it falls to
the lower shelf without death, leaves the melody unsolved, and does not collect
Gold. This is one attempted bypass, not proof that every alternate route is
impossible. Both earned prison orders complete with a real disk save/load
after two keys, zero deaths, all locks and reunion. The complete39-room Act2
route also reaches the ending with zero deaths and sixteen banked lemons.

All nine dry vertical entrance seams use16px wooden catch ledges and24px open
side gaps. Final staged tests jump up onto each ledge, step into the open half,
release horizontal input and descend naturally, without death. Holding right
continuously can overshoot the hole in G01/G02; that failed test is retained.
The return does not require a drop-through button or falling through a solid
scaffold. The flooded seam retains swimming.

The final build comes from a clean import of the same runtime, art and LDtk
source. Editor save produced zero semantic changes. See the verification report
for regression coverage, captures, package instructions and limitations.
