extends RefCounted
## All score tuning lives here. Par times are seconds; whole seconds under par
## score points. Acts 2/3 use provisional ten-minute pars until tuned.
const ACTS := {
	"res://ldtk/Act1World.tscn": {"title": "WORK", "par": 600.0},
	"res://ldtk/Act2World.tscn": {"title": "IRAN", "par": 600.0},
	"res://ldtk/Act3World.tscn": {"title": "OCEAN", "par": 600.0},
}
const TIME_PER_SECOND := 10
const LEMON := 1000
const ALL_LEMONS := 5000
const DEATH := -25
const DEATHLESS := 1000

static func calculate(stats: Dictionary) -> Dictionary:
	var act: Dictionary = ACTS.get(stats.get("world", ""), {"title": "ACT", "par": 600.0})
	var time := int(floor(maxf(0.0, float(act.par) - float(stats.seconds)))) * TIME_PER_SECOND
	var lemons := int(stats.lemons) * LEMON
	var deaths := int(stats.deaths) * DEATH
	# An empty act has no collection challenge and awards no completion bonus.
	var all_lemons := ALL_LEMONS if int(stats.available) > 0 and int(stats.lemons) == int(stats.available) else 0
	var deathless := DEATHLESS if int(stats.deaths) == 0 else 0
	var final := maxi(0, time + lemons + deaths + all_lemons + deathless)
	return {"title": act.title, "time": time, "lemons": lemons, "deaths": deaths,
		"all_lemons": all_lemons, "deathless": deathless, "final": final}
