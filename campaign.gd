extends RefCounted
const Rules = preload("res://rules.gd")
const Layouts = preload("res://layouts.gd")
const THEMES = [
	["장난감 방","ffd884","9edcf2","굴려서 목표 칸의 숫자를 윗면에 맞추세요."],
	["바삭 과자집","dca56d","edcfba","내구도 칸은 떠날 때 닳아요. 숫자는 남은 횟수!"],
	["우주 정거장","ada9e8","292847","P 숫자를 윗면에 맞추면 다른 층으로 이동해요."],
	["사탕 숲","e9b4ce","c4e9ce","찍찍이는 3초 대기. 시간 지우개가 있으면 즉시 해제!"],
	["꼬마 용의 화산","e9a076","704c67","불에 닿으면 실패! 방열 장비는 한 번만 보호해요."],
	["로봇 공장","aab8cf","7c9daf","전기는 숫자를 유지한 채 끝까지 밀어내요."],
	["얼음 왕국","b6e6f2","c5d8f1","얼음은 칸마다 구르며 벽까지 이동해요."],
	["시계탑","d4b574","b4b2cb","S 숫자로 문을 열고 회전판에서 옆면을 바꿔요."],
	["하늘 정원","b8d9aa","c4e4f4","층을 살펴보고 별과 귀환 경로를 계획하세요."],
	["마법사의 성","bda0e5","51486b","세 층의 장치를 연결해 마지막 목표를 완성하세요."]
]
const TITLES = ["첫걸음","옆길 탐색","순서의 비밀","작은 우회","숫자 준비","돌아오는 길","두 가지 선택","연결된 길","마지막 연습","테마 도전"]

static func load_levels() -> Array:
	if not FileAccess.file_exists("res://data/campaign.json"): return []
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	return normalize(data) if data is Array else []

static func normalize(value: Variant) -> Variant:
	# JSON numbers are floats in Godot; grid/orientation array equality is type-sensitive.
	if value is float: return int(value)
	if value is Array:
		for i in range(value.size()): value[i] = normalize(value[i])
	elif value is Dictionary:
		for k in value: value[k] = normalize(value[k])
	return value

static func put(l: Dictionary, x: int, y: int, z: int, kind: String, extra := {}) -> void:
	var t = {"kind":kind}
	t.merge(extra,true)
	l.tiles[Rules.cell([x,y,z])] = t

static func barrier(l: Dictionary, w: int, h: int, z: int, x: int, kind: String, extra := {}) -> void:
	for y in range(h): put(l,x,y,z,"wall")
	put(l,x,1,z,kind,extra)

static func draft(index: int, attempt := 0) -> Dictionary:
	var world = index/10
	var n = index%10
	var floors = 1
	if world in [2,8] or (world in [5,6,7] and n>=6): floors = 2
	if world==9: floors = 3
	var l = {"id":index+1,"world":world,"name":Layouts.NAMES[n],"hint":THEMES[world][3],
		"tiles":{},"floors":floors,"width":0,"height":0,
		"start":[],"goal":[],"face":1+n%6,"par":0,"time_limit":0,"solution":[]}
	var routes = []
	var entrances = []
	var exits = []
	for z in range(floors):
		var shape = Layouts.shape(index,z,attempt)
		var ends = Layouts.endpoints(shape,world+n+z+attempt)
		entrances.append([ends[0].x,ends[0].y,z])
		exits.append([ends[1].x,ends[1].y,z])
		routes.append(Layouts.path(shape,ends[0],ends[1]))
		for p in shape:
			put(l,p.x,p.y,z,"floor")
			l.width = maxi(l.width,p.x+1)
			l.height = maxi(l.height,p.y+1)
	l.start = entrances[0]
	l.goal = exits.back()
	for z in range(floors):
		if z<floors-1:
			put(l,exits[z][0],exits[z][1],z,"portal",{"face":1+(n+z)%6,"to":entrances[z+1]})
		if z>0:
			put(l,entrances[z][0],entrances[z][1],z,"stairs",{"to":exits[z-1]})
	match world:
		1:
			on_route(l,routes[0],0,0.5,"fragile",{"hp":1+n%2})
			if n>=5: on_route(l,routes[0],0,0.2,"item",{"item":"repair"})
			if n>=7: on_route(l,routes[0],0,0.75,"fragile",{"hp":1})
		2:
			if n>=3: on_route(l,routes[1],1,0.5,"fragile",{"hp":2})
			if n>=5: on_route(l,routes[0],0,0.3,"item",{"item":"rotate"})
		3:
			on_route(l,routes[0],0,0.5,"glue")
			if n%2: on_route(l,routes[0],0,0.2,"item",{"item":"solvent"})
			if n>=5: on_route(l,routes[0],0,0.8,"fragile",{"hp":1})
			if n>=7: on_route(l,routes[0],0,0.35,"item",{"item":"undo"})
		4:
			gate(l,routes[0],0,0.6,"fire")
			on_route(l,routes[0],0,0.2,"item",{"item":"shield"})
			if n>=5: on_route(l,routes[0],0,0.4,"glue")
		5:
			on_route(l,routes[0],0,0.35,"electric")
			if n>=3: on_route(l,routes[0],0,0.75,"electric")
			if n%2: on_route(l,routes[0],0,0.15,"item",{"item":"insulator"})
			if floors>1: on_route(l,routes[1],1,0.5,"electric")
		6:
			on_route(l,routes[0],0,0.3,"ice")
			on_route(l,routes[0],0,0.7,"ice")
			if n%2: on_route(l,routes[0],0,0.15,"item",{"item":"boots"})
			if n>=4: on_route(l,routes[0],0,0.85,"cracked",{"hp":1})
			if floors>1: on_route(l,routes[1],1,0.5,"ice")
		7:
			gate(l,routes[0],0,0.7,"door",{"id":"a","face":1+n%6})
			on_route(l,routes[0],0,0.2,"switch",{"id":"a","face":1+n%6})
			on_route(l,routes[0],0,0.4,"rotator")
			if n>=5: on_route(l,routes[0],0,0.1,"item",{"item":"key"})
			if n>=7:
				var at = clampi(int(routes[0].size()*0.5),1,routes[0].size()-2)
				var delta = routes[0][at+1]-routes[0][at]
				var direction = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].find(delta)
				on_route(l,routes[0],0,0.5,"arrow",{"direction":direction})
		8:
			on_route(l,routes[0],0,0.35,"star",{"face":4})
			on_route(l,routes[1],1,0.4,"fragile",{"hp":1})
			on_route(l,routes[1],1,0.2,"item",{"item":"return"})
			if n>=4:
				gate(l,routes[1],1,0.75,"bridge",{"id":"b"})
				on_route(l,routes[1],1,0.1,"toggle",{"id":"b"})
		9:
			on_route(l,routes[0],0,0.6,"fragile",{"hp":1})
			on_route(l,routes[0],0,0.3,"item",{"item":"rotate"})
			on_route(l,routes[1],1,0.3,"ice" if n%2 else "electric")
			on_route(l,routes[1],1,0.7,"star",{"face":4})
			gate(l,routes[2],2,0.6,"fire")
			on_route(l,routes[2],2,0.2,"item",{"item":"shield"})
			if n>=5: on_route(l,routes[2],2,0.4,"glue")
	return l

static func on_route(l: Dictionary, route: Array, z: int, fraction: float, kind: String, extra := {}) -> void:
	var target = clampi(int((route.size()-1)*fraction),1,route.size()-2)
	for offset in range(route.size()):
		for sign_dir in [1,-1]:
			var at = target+offset*sign_dir
			if at<1 or at>=route.size()-1: continue
			var p = route[at]
			if l.tiles[Rules.cell([p.x,p.y,z])].kind=="floor":
				put(l,p.x,p.y,z,kind,extra)
				return

static func gate(l: Dictionary, route: Array, z: int, fraction: float, kind: String, extra := {}) -> void:
	var at = clampi(int((route.size()-1)*fraction),1,route.size()-2)
	var p = route[at]
	var delta = p-route[at-1]
	for k in l.tiles:
		var q = Rules.point(k)
		if q[2]!=z or l.tiles[k].kind!="floor" or q==l.start or q==l.goal: continue
		if (delta.y!=0 and q[1]==p.y) or (delta.x!=0 and q[0]==p.x):
			l.tiles[k] = {"kind":"wall"}
	put(l,p.x,p.y,z,kind,extra)
