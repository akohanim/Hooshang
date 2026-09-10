# Full Act I background validation

34 authored rooms have 34 distinct native-size textures. All rooms were
captured in Godot, including the eclipse stages and the dawn cubicle.

Passed: full background coverage, original ten-room checks, single-moon
camera sweep, movement smoke, world bounds, separate screen rendering,
chase route/eclipse, physical collapse, backtracking, and thought hazards.

Every original Act1World child-node block remains unchanged, verified against
the scene captured before this pass. New window pairs are additions. Per-wall
reflectance adjustments keep the brighter source art from clipping under the
existing lights. No LDtk geometry or player code was changed by this pass.

The full unrelated test suite was not rerun; earlier outstanding results are
recorded in VALIDATION.md. Godot still reports the existing Level_25 missing
Exit warning and resource cleanup warnings. The return cubicle's existing
lighting and scene composition are retained.
