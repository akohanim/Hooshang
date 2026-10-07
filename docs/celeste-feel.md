# Movement presentation, terrain variation and platform grace

Implemented October 4, 2026. These changes use Hooshang's own artwork. Celeste's
published controller selects airborne animation from actual vertical motion;
its creator also describes briefly retaining lift momentum after a stop:

- https://github.com/NoelFB/Celeste/blob/master/Source/Player/Player.cs
- https://www.maddymakesgames.com/articles/celeste_and_forgiveness/index.html

## Animation

The adult Aseprite importer builds five extra clips from existing approved poses:
`takeoff`, `rise`, `apex`, `land`, and `recover`. The existing `fall` animation
remains the descent clip. Source tags and pixels are unchanged. Rebuild with
`python3 tools/import_hooshang_aseprite.py --use-export`, or omit that flag after
editing the source Aseprite file.

Player's Animation Timing exports control 60 ms takeoff, a 25 px/s apex band,
55 ms landing compression and 65 ms standing recovery. Landing poses require
at least 60 px/s downward impact. Input is never locked: running, jumping,
and dashing interrupt recovery. The existing impact squash/dust still operates.
Wall jumps retain their dedicated kick. Airborne poses follow vertical speed,
so an upward dash ending in the FALL movement state still displays ascent.
Libraries without the extra clips (including young Hooshang) retain their
existing jump/fall art and impact squash.

## Terrain

`tools/gen_terrain_variants.py` produces three subtly weathered alternatives
for legacy brick and concrete. `gen_bricks_8px.py` rebuilds them automatically.
Only interior face pixels change; alpha, mortar, tile borders and contact lips
remain identical. Newer brick/stone already have topology-specific variants;
scaffolding keeps its connected-rail system and moss keeps its clustered rules.

`terrain_variation.gd` selects a repeatable variant from room, layer and cell
coordinates. Half the selections retain the original texture. Copied atlas
sources preserve TileData, including collision, alternatives and custom data.
Shared imported resources are not mutated. Marked variant sources make repeated
application and packing/reloading idempotent.

The level import hook applies it to Collisions layers on future LDtk imports;
LdtkWorld applies it at boot for existing imported rooms. LDtk source files and
painted tile IDs are unchanged. The LDtk editor shows the original art; Godot
shows the stable variants. Regenerate the variant PNGs after changing base art.

## Platform momentum

ConveyorBelt and MagicCarpet export `momentum_grace_time`, default 0.1 seconds.
`platform_momentum.gd` remembers each rider's last nonzero horizontal surface
speed. Stopping preserves that sample briefly. Leaving into the air consumes it
once; departure onto solid floor, dash, death, frozen input staging and leaving
the sensor discard it. Respawn immunity prevents stale sensor membership from
handing out a launch. Zero grace disables storage but preserves live transfer.

Carpets sample actual displacement, so a carpet blocked by geometry cannot
perpetually transfer its configured speed. Horizontal-only inheritance remains
the existing design contract. Conveyor launch multipliers and boost decay are
unchanged. Ordinary jump/run/dash tuning is unchanged.

## Checks

- `celeste_feel_test`: real input and collision exercise all seven animation
  phases, interruptible recovery, recent/expired stopped-belt and stopped-carpet
  launches, dash isolation and respawn reset.
- `terrain_variation_test`: multiple variants with one topology, equal collision,
  unchanged panels/scaffolding, shared-resource isolation, repeated application
  and packed-scene reload.
- Existing smoke, conveyor, carpet, child animation, scaffolding, room bounds,
  backtracking, dash-input and hatch/cutscene regressions cover integration.

Geometry/conveyor tests now remove Act1Beats before entering the world so the
opening cutscene cannot freeze their input probes. The conveyor test waits for
its pending death callback before starting its next measurement, and uses
respawn for its airborne placement rather than simulating a departure by teleport.
