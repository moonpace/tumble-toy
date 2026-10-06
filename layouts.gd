extends RefCounted
const Rules = preload("res://rules.gd")
const NAMES = ["꺾인 마당","넓은 지붕","엇갈린 방","모래시계 길","계단 산책","돌아가는 만","네 방향 광장","깃발 언덕","쌍둥이 방","빗살 골목"]

static func shape(index: int, floor_index: int, attempt: int) -> Dictionary:
	var theme = index/10
	var motif = (index%10 + floor_index*3)%10
	var w = 5 + theme%3 + attempt%2
	var h = 5 + theme/3 + (attempt/2)%2
	var neck = 2 + ((theme+attempt)/3)%2
	var tiles = {}
	for y in range(h):
		var left = 0
		var right = w-1
		match motif:
			0: right = neck-1 if y<h-2 else w-1
			1:
				if y>=2: left = (w-neck)/2; right = left+neck-1
			2:
				if y<2: right = w-3
				elif y>=h-2: left = 2
			3:
				if y>=2 and y<h-2: left = (w-neck)/2; right = left+neck-1
			4:
				left = mini(y/2,w-3)
				right = mini(left+2+(theme%2),w-1)
			5:
				if y>=2 and y<h-2: right = neck-1
			6:
				if y< h/2-1 or y>h/2: left = (w-neck)/2; right = left+neck-1
			7:
				if y>=h/2: right = neck-1
			8:
				if y<2: right = w-2
				elif y>=h-2: left = 1
				else: left = 1; right = neck
			9:
				if y%3==2: right = neck-1
		for x in range(left,right+1): tiles[Vector2i(x,y)] = true
	return tiles

static func neighbors(p: Vector2i) -> Array:
	return [p+Vector2i.UP,p+Vector2i.DOWN,p+Vector2i.LEFT,p+Vector2i.RIGHT]

static func distances(tiles: Dictionary, start: Vector2i) -> Dictionary:
	var dist = {start:0}
	var q = [start]
	var at = 0
	while at<q.size():
		var p = q[at]
		at += 1
		for n in neighbors(p):
			if tiles.has(n) and not dist.has(n):
				dist[n] = dist[p]+1
				q.append(n)
	return dist

static func endpoints(tiles: Dictionary, variant: int) -> Array:
	var keys = tiles.keys()
	var start = keys[variant%keys.size()]
	for _pass in range(2):
		var dist = distances(tiles,start)
		var far = start
		for p in dist:
			if dist[p]>dist[far]: far = p
		start = far
	var dist = distances(tiles,start)
	var ends = keys.duplicate()
	ends.sort_custom(func(a,b): return dist[a]>dist[b])
	var goal = ends[variant%mini(3,ends.size())]
	return [start,goal]

static func path(tiles: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var dist = distances(tiles,goal)
	var route = [start]
	var p = start
	while p!=goal:
		for n in neighbors(p):
			if dist.has(n) and dist[n]<dist[p]:
				p = n
				route.append(p)
				break
	return route

static func silhouette(level: Dictionary) -> String:
	# Canonicalize the first-floor outline under all eight rotations/reflections.
	# Ignore every number, endpoint, wall and special-tile kind deliberately.
	var points = []
	for k in level.tiles:
		var p = Rules.point(k)
		if p[2]==0: points.append(Vector2i(p[0],p[1]))
	var variants = []
	for mirror in [false,true]:
		for turn in range(4):
			var transformed = []
			var low = Vector2i(9999,9999)
			for p in points:
				var q = Vector2i(-p.x if mirror else p.x,p.y)
				for _i in range(turn): q = Vector2i(-q.y,q.x)
				transformed.append(q)
				low = low.min(q)
			var entries = []
			for q in transformed: entries.append("%02d,%02d" % [q.x-low.x,q.y-low.y])
			entries.sort()
			variants.append(";".join(entries))
	variants.sort()
	return variants[0]
