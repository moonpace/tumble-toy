extends Node
const Rules = preload("res://rules.gd")
const Campaign = preload("res://campaign.gd")
var failures: Array[String] = []

func _ready() -> void:
	test_mechanics()
	var levels = Campaign.load_levels()
	expect(levels.size()==100,"100 stages must be baked")
	var signatures = {}
	var outlines = {}
	var all_kinds = {}
	for level in levels:
		var outline = Campaign.Layouts.silhouette(level)
		expect(not outlines.has(outline),"Repeated terrain even after rotation/reflection: %d" % int(level.id))
		outlines[outline] = true
		var signature = str([level.tiles,level.start,level.goal,level.face])
		expect(not signatures.has(signature),"Duplicate stage %d" % int(level.id))
		signatures[signature] = true
		for k in level.tiles:
			all_kinds[level.tiles[k].kind] = true
			var t = level.tiles[k]
			if t.kind in ["portal","stairs"]:
				expect(level.tiles.has(Rules.cell(t.to)),"Portal destination must exist")
		for z in range(int(level.floors)): check_topology(level,z)
		var s = Rules.initial(level)
		var wait = 0.0
		for a in level.solution:
			var before = s.duplicate(true)
			var r = Rules.step(level,s,a,true)
			expect(s==before,"Transitions must not mutate undo snapshot")
			expect(r.valid and not r.state.dead,"Invalid solution step %d" % int(level.id))
			s = r.state
			wait += s.wait
		expect(s.won,"Stage %d must clear via saved solution" % int(level.id))
		expect(level.par>=level.solution.size(),"Par must permit verified solution")
		expect((int(level.id)%10 == 0) == (level.time_limit>0),"Only chapter finals have time attack")
		if level.time_limit>0: expect(level.time_limit>=wait+3*level.solution.size(),"Time medal permits reasonable verified input cadence")
	for kind in ["fragile","portal","stairs","glue","fire","electric","ice","cracked","switch","door","rotator","arrow","toggle","bridge","star","item"]:
		expect(all_kinds.has(kind),"Campaign must use "+kind)
	if failures.is_empty(): print("PASS: 100 distinct terrain outlines (rotation/reflection invariant), all solutions, topology, time budgets and mechanics")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func expect(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func sandbox() -> Dictionary:
	var l = {"tiles":{},"start":[0,1,0],"goal":[4,2,0],"face":6,"floors":1,"width":5,"height":3}
	for y in range(3):
		for x in range(5): Campaign.put(l,x,y,0,"floor")
	return l

func test_mechanics() -> void:
	var l = sandbox()
	var s = Rules.initial(l)
	for d in range(4):
		var o = s.o.duplicate()
		for _i in range(4): o = Rules.rolled(o,d)
		expect(o==s.o,"Four rolls restore die")
	Campaign.put(l,1,1,0,"fragile",{"hp":1})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.hp["1,1,0"]==1,"Entering fragile does not destroy it")
	var snapshot = s.duplicate(true)
	s = Rules.step(l,s,"right").state
	expect(s.hp["1,1,0"]==0 and snapshot.hp["1,1,0"]==1,"Leaving destroys and snapshot restores")
	s = Rules.step(l,s,"left").state
	expect(s.dead,"Entering destroyed floor is fatal")
	l = sandbox()
	Campaign.put(l,1,1,0,"portal",{"face":4,"to":[3,1,0]})
	Campaign.put(l,3,1,0,"portal",{"face":4,"to":[1,1,0]})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.p==[3,1,0] and s.o[0]==4,"Matching portal preserves face without ping-pong")
	l.tiles["1,1,0"].face = 1
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.p==[1,1,0],"Mismatched portal stays put")
	l = sandbox()
	Campaign.put(l,1,1,0,"electric")
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.p==[4,1,0] and s.o[0]==4,"Electric preserves orientation after entry roll")
	Campaign.put(l,1,1,0,"ice")
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.p==[4,1,0] and s.o[0]==1,"Ice rolls each cell until edge")
	Campaign.put(l,3,1,0,"wall")
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.p==[2,1,0],"Ice stops before wall")
	Campaign.put(l,2,1,0,"fire")
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.dead,"Forced motion still triggers fire")
	for item in ["boots","insulator"]:
		l = sandbox()
		Campaign.put(l,1,1,0,"ice" if item=="boots" else "electric")
		s = Rules.initial(l)
		s.bag[item] = 1
		s = Rules.step(l,s,"right").state
		expect(s.p==[1,1,0] and s.bag[item]==0,"Single-use immunity "+item)
	l = sandbox()
	Campaign.put(l,1,1,0,"fire")
	s = Rules.initial(l)
	s.bag.shield = 1
	s = Rules.step(l,s,"right").state
	expect(not s.dead and s.bag.shield==0,"Shield prevents one fire entry")
	Campaign.put(l,2,1,0,"fire")
	expect(Rules.step(l,s,"right").state.dead,"Second fire kills after shield used")
	l = sandbox()
	Campaign.put(l,1,1,0,"glue")
	expect(Rules.step(l,Rules.initial(l),"right").state.wait==3,"Glue waits 3s")
	s = Rules.initial(l)
	s.bag.solvent = 1
	expect(Rules.step(l,s,"right").state.wait==0,"Solvent skips wait")
	l = sandbox()
	Campaign.put(l,1,1,0,"switch",{"face":4,"id":"a"})
	Campaign.put(l,2,1,0,"door",{"face":6,"id":"a"})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.flags.get("a",false),"Number switch opens door")
	expect(Rules.step(l,s,"right").valid,"Open door permits entry")
	s.flags.clear()
	expect(not Rules.step(l,s,"right").valid,"Closed door blocks")
	s.bag.key = 1
	s = Rules.step(l,s,"right").state
	expect(s.flags.get("a",false) and s.bag.key==0,"Matching key opens door once")
	l = sandbox()
	Campaign.put(l,1,1,0,"arrow",{"direction":3})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(not Rules.step(l,s,"up").valid and Rules.step(l,s,"right").valid,"One-way exits")
	Campaign.put(l,1,1,0,"rotator")
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(s.o==Rules.rotated(Rules.rolled([1,6,2,5,3,4],3)),"Rotator turns horizontal faces")
	l = sandbox()
	Campaign.put(l,1,1,0,"toggle",{"id":"b"})
	Campaign.put(l,2,1,0,"bridge",{"id":"b"})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(Rules.step(l,s,"right").valid,"Toggle enables bridge")
	s = Rules.step(l,s,"left").state
	s = Rules.step(l,s,"right").state
	expect(not Rules.step(l,s,"right").valid,"Toggle disables bridge")
	l = sandbox()
	Campaign.put(l,1,1,0,"item",{"item":"rotate"})
	s = Rules.step(l,Rules.initial(l),"right").state
	var original = s.o.duplicate()
	s = Rules.step(l,s,"rotate").state
	expect(s.o==Rules.rotated(original) and s.bag.rotate==0,"Rotate token consumed")
	s = Rules.step(l,s,"left").state
	s = Rules.step(l,s,"right").state
	expect(s.bag.rotate==0,"Pickup cannot be farmed")
	l = sandbox()
	Campaign.put(l,1,1,0,"fragile",{"hp":1})
	s = Rules.initial(l)
	s.bag.repair = 1
	s.bag.return = 1
	s = Rules.step(l,s,"repair").state
	expect(s.hp["1,1,0"]==2,"Repair reinforces neighbor")
	s = Rules.step(l,s,"right").state
	original = s.o.duplicate()
	s = Rules.step(l,s,"return").state
	expect(s.p==l.start and s.o==original and s.hp["1,1,0"]==1,"Return leaves and preserves die orientation")
	l = sandbox()
	l.goal = [1,1,0]
	l.face = 4
	Campaign.put(l,1,0,0,"star",{"face":1})
	s = Rules.step(l,Rules.initial(l),"right").state
	expect(not s.won,"Required star gates goal")
	s.taken["1,0,0"] = true
	Rules.check_win(l,s)
	expect(s.won,"All required stars permit correct goal")

func check_topology(l: Dictionary, z: int) -> void:
	var cells = {}
	for k in l.tiles:
		var p = Rules.point(k)
		if p[2]==z: cells[Vector2i(p[0],p[1])] = true
	var queue = [cells.keys()[0]]
	var seen = {queue[0]:true}
	var cursor = 0
	var dirs = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	while cursor<queue.size():
		var p = queue[cursor]
		cursor += 1
		for d in dirs:
			if cells.has(p+d) and not seen.has(p+d): seen[p+d]=true; queue.append(p+d)
	expect(seen.size()==cells.size(),"Floor geometry must be connected")
	queue = [Vector2i(-1,-1)]
	seen = {queue[0]:true}
	cursor = 0
	while cursor<queue.size():
		var p = queue[cursor]
		cursor += 1
		for d in dirs:
			var q = p+d
			if q.x < -1 or q.y < -1 or q.x>l.width or q.y>l.height: continue
			if not cells.has(q) and not seen.has(q): seen[q]=true; queue.append(q)
	for y in range(int(l.height)):
		for x in range(int(l.width)):
			var p = Vector2i(x,y)
			expect(cells.has(p) or seen.has(p),"No enclosed initial hole: stage %d" % int(l.id))
