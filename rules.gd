extends RefCounted
# Pure state transitions shared by play, solver and replay tests.
const DIRS = [Vector3i(0,-1,0), Vector3i(0,1,0), Vector3i(-1,0,0), Vector3i(1,0,0)]
const ACTIONS = ["up", "down", "left", "right", "rotate", "repair", "return"]

static func cell(p: Array) -> String:
	return "%d,%d,%d" % p

static func point(k: String) -> Array:
	var a = k.split(",")
	return [int(a[0]), int(a[1]), int(a[2])]

static func initial(level: Dictionary) -> Dictionary:
	var hp = {}
	for k in level.tiles:
		var t = level.tiles[k]
		if t.kind in ["fragile", "cracked"]: hp[k] = int(t.get("hp", 1))
	return {"p":level.start.duplicate(), "o":[1,6,2,5,3,4], "hp":hp,
		"taken":{}, "flags":{}, "bag":{}, "dead":false, "won":false, "wait":0.0}

static func rolled(o: Array, d: int) -> Array:
	match d:
		0: return [o[3],o[2],o[0],o[1],o[4],o[5]]
		1: return [o[2],o[3],o[1],o[0],o[4],o[5]]
		2: return [o[4],o[5],o[2],o[3],o[1],o[0]]
		3: return [o[5],o[4],o[2],o[3],o[0],o[1]]
	return o.duplicate()

static func rotated(o: Array) -> Array:
	return [o[0],o[1],o[5],o[4],o[2],o[3]]

static func consume(s: Dictionary, item: String) -> bool:
	if int(s.bag.get(item, 0)) <= 0: return false
	s.bag[item] -= 1
	return true

static func neighbor(p: Array, d: int) -> Array:
	return [int(p[0])+DIRS[d].x, int(p[1])+DIRS[d].y, int(p[2])]

static func tile(level: Dictionary, p: Array) -> Dictionary:
	return level.tiles.get(cell(p), {"kind":"void"})

static func blocked(level: Dictionary, s: Dictionary, p: Array, o: Array) -> bool:
	var t = tile(level,p)
	if t.kind in ["void", "wall"]: return true
	if t.kind == "door" and not s.flags.get(t.get("id","a"),false):
		return not (o[0] == int(t.get("face",1)) and int(s.bag.get("key",0)) > 0)
	if t.kind == "bridge" and not s.flags.get(t.get("id","b"),false): return true
	return false

static func leave(s: Dictionary) -> void:
	var k = cell(s.p)
	if s.hp.has(k): s.hp[k] = maxi(0, int(s.hp[k])-1)

static func check_win(level: Dictionary, s: Dictionary) -> void:
	s.won = false
	if s.dead or s.p != level.goal or s.o[0] != int(level.face): return
	for k in level.tiles:
		if level.tiles[k].kind == "star" and not s.taken.has(k): return
	s.won = true

static func enter(level: Dictionary, s: Dictionary, d: int) -> String:
	var k = cell(s.p)
	var t = tile(level,s.p)
	if s.hp.has(k) and int(s.hp[k]) == 0:
		s.dead = true
		return "stop"
	match t.kind:
		"fire":
			if not consume(s,"shield"): s.dead = true
		"item":
			if not s.taken.has(k):
				s.taken[k] = true
				s.bag[t.item] = int(s.bag.get(t.item,0))+1
		"star":
			if s.o[0] == int(t.face): s.taken[k] = true
		"switch":
			if s.o[0] == int(t.get("face",s.o[0])): s.flags[t.get("id","a")] = true
		"toggle":
			s.flags[t.get("id","b")] = not s.flags.get(t.get("id","b"),false)
		"door":
			if not s.flags.get(t.get("id","a"),false):
				consume(s,"key")
				s.flags[t.get("id","a")] = true
		"rotator": s.o = rotated(s.o)
		"portal", "stairs":
			if t.kind == "stairs" or s.o[0] == int(t.face):
				s.p = t.to.duplicate()
				if int(s.hp.get(cell(s.p),1)) == 0: s.dead = true
				return "teleport"
		"glue":
			s.wait = 0.0 if consume(s,"solvent") else 3.0
			return "stop"
		"electric":
			return "stop" if consume(s,"insulator") else "electric"
		"ice", "cracked":
			return "stop" if consume(s,"boots") else "ice"
	if s.dead: return "stop"
	return "continue"

static func step(level: Dictionary, before: Dictionary, action: String, trace_enabled := false) -> Dictionary:
	var s = before.duplicate(true)
	var trace: Array = []
	var result = {"state":s, "valid":false, "trace":trace}
	if s.dead or s.won: return result
	s.wait = 0.0 # UI enforces the real-time lock; solver waits before next input.
	var d = ACTIONS.find(action)
	if d >= 4:
		if int(s.bag.get(action,0)) <= 0: return result
		match action:
			"rotate": s.o = rotated(s.o)
			"repair":
				var candidates = [s.p]
				for i in range(4): candidates.append(neighbor(s.p,i))
				var found = false
				for p in candidates:
					var k = cell(p)
					if s.hp.has(k) and int(s.hp[k]) > 0:
						s.hp[k] += 1
						found = true
						break
				if not found: return result
			"return":
				if int(s.hp.get(cell(level.start),1)) == 0: return result
				leave(s)
				s.p = level.start.duplicate()
		consume(s,action)
		result.valid = true
		check_win(level,s)
		if trace_enabled: trace.append(s.duplicate(true))
		return result
	if d < 0: return result
	var current = tile(level,s.p)
	if current.kind == "arrow" and int(current.direction) != d: return result
	var next = neighbor(s.p,d)
	var next_o = rolled(s.o,d)
	if blocked(level,s,next,next_o): return result
	result.valid = true
	var mode = "normal"
	var seen = {}
	for _tick in range(256):
		leave(s)
		s.p = next
		s.o = next_o
		var effect = enter(level,s,d)
		check_win(level,s)
		if trace_enabled: trace.append(s.duplicate(true))
		if s.dead or s.won or effect in ["stop","teleport"]: return result
		if effect in ["electric","ice"]: mode = effect
		if mode == "normal": return result
		current = tile(level,s.p)
		if current.kind == "arrow" and int(current.direction) != d: return result
		next = neighbor(s.p,d)
		next_o = s.o.duplicate() if mode == "electric" else rolled(s.o,d)
		if blocked(level,s,next,next_o): return result
		var k = key(s)
		if seen.has(k):
			s.dead = true
			return result
		seen[k] = true
	s.dead = true
	return result

static func key(s: Dictionary) -> String:
	# Insertion order is fixed for hp; sort optional collected/flag/bag entries.
	var entries = []
	for field in ["hp","taken","flags","bag"]:
		var keys = s[field].keys()
		keys.sort()
		var values = []
		for k in keys:
			if s[field][k]: values.append([k,s[field][k]])
		entries.append(values)
	# Zero hp must remain distinct from absent/infinite floor.
	entries.append(s.hp)
	return str([s.p,s.o,entries])

static func solve(level: Dictionary, start_state := {}, limit := 60000) -> Dictionary:
	var first = initial(level) if start_state.is_empty() else start_state.duplicate(true)
	check_win(level,first)
	var queue = [first]
	var parents = [-1]
	var actions = [""]
	var seen = {key(first):true}
	var cursor = 0
	while cursor < queue.size() and cursor < limit:
		var s = queue[cursor]
		if s.won:
			var path = []
			var at = cursor
			while parents[at] >= 0:
				path.push_front(actions[at])
				at = parents[at]
			return {"found":true,"path":path,"visited":cursor+1}
		for action in ACTIONS:
			if ACTIONS.find(action) >= 4 and int(s.bag.get(action,0)) == 0: continue
			var r = step(level,s,action)
			if not r.valid or r.state.dead: continue
			var k = key(r.state)
			if seen.has(k): continue
			seen[k] = true
			queue.append(r.state)
			parents.append(cursor)
			actions.append(action)
		cursor += 1
	return {"found":false,"path":[],"visited":cursor,"limited":cursor>=limit}
