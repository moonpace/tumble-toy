extends SceneTree
const Campaign = preload("res://campaign.gd")
const Rules = preload("res://rules.gd")

func _initialize() -> void:
	var levels = []
	var silhouettes = {}
	for index in range(100):
		var level = {}
		var answer = {"found":false,"visited":0}
		for attempt in range(36):
			level = Campaign.draft(index,attempt)
			var outline = Campaign.Layouts.silhouette(level)
			if silhouettes.has(outline): continue
			answer = Rules.solve(level)
			if answer.found:
				silhouettes[outline] = true
				break
		if not answer.found:
			push_error("Unsolvable or search budget exceeded: %d (%d)" % [index+1,answer.visited])
			quit(1)
			return
		level.solution = answer.path
		level.par = answer.path.size()
		var state = Rules.initial(level)
		var waits = 0.0
		for action in answer.path:
			state = Rules.step(level,state,action).state
			waits += state.wait
		if not state.won:
			push_error("Replay failed: %d" % (index+1))
			quit(1)
			return
		if index%10 == 9: level.time_limit = ceil(level.par*3.0 + waits + 20.0)
		levels.append(level)
		print("VERIFIED %03d: %d inputs, %d states" % [index+1,level.par,answer.visited])
	DirAccess.make_dir_recursive_absolute("res://data")
	var file = FileAccess.open("res://data/campaign.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(levels,"\t"))
	print("100 verified stages baked to data/campaign.json")
	quit()
