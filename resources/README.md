# resources/

Shared `.tres` data resources — content expressed as data rather than
hardcoded in scripts.

Use this for anything that repeats across levels and is really just data:
dialogue trees/conversations, level configs, musical-tile sequences. Define a
`Resource` subclass (`class_name`), then author instances as `.tres` files here.

Don't over-engineer one-off values — a couple of throwaway strings can stay as
`const`s in a script. Promote to a `.tres` when the content grows or repeats.
