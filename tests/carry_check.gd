extends TestBase
## G68: the haul on the driver's back stops at the nape.
##
## The old stack was pinned at local y 0.62 — above the head, since the
## character's origin is its torso pivot and the top of the head is about 0.79 —
## and grew fourteen 0.075 slabs from there, so a full load stood a metre clear
## of the person carrying it. The claims below are about HEIGHT: they are the
## only kind that can catch this coming back, because nothing else about a
## stack that is too tall is wrong.

func run() -> void:
	suite = "SIRT YUKU"
	min_checks = 11

	# The budget itself, before anything is carried: the pile's ceiling is the
	# shoulder, and the bundle count is derived from it rather than chosen.
	var nape := GameConfig.CHAR_SHOULDER.y
	var room := GameConfig.carry_stack_height()
	ck("tavan ense hizasi",
		is_equal_approx(room, nape - GameConfig.CARRY_BACK_OFFSET.y),
		"%.3f" % room)
	# Pinned on the BACK: below the shoulder, above the hip. The first attempt
	# put the base at the waist (0.02) and the render showed a satchel hanging
	# off the hip rather than a load carried on the back, so the window has a
	# floor as well as a ceiling.
	ck("yuk sirta tutturulmus, omuza ve kalcaya degil",
		GameConfig.CARRY_BACK_OFFSET.y <= nape * 0.4
			and GameConfig.CARRY_BACK_OFFSET.y >= nape * 0.15,
		"%.3f / ense %.3f" % [GameConfig.CARRY_BACK_OFFSET.y, nape])
	ck("yuk govdenin arkasinda",
		GameConfig.CARRY_BACK_OFFSET.z > GameConfig.CHAR_TORSO_SIZE.z * 0.5,
		"%.3f / %.3f" % [GameConfig.CARRY_BACK_OFFSET.z, GameConfig.CHAR_TORSO_SIZE.z])
	ck("deste omuzdan dar",
		GameConfig.CARRY_SLAB_SIZE.x < GameConfig.CHAR_TORSO_SIZE.x,
		"%.3f / %.3f" % [GameConfig.CARRY_SLAB_SIZE.x, GameConfig.CHAR_TORSO_SIZE.x])

	var most := GameConfig.carry_slab_max()
	ck("deste sayisi butceden cikiyor", most >= 6 and most <= 12, str(most))

	# Now fill it past the cap and measure what is actually in the world.
	var stack := CarryStack.new()
	add_child(stack)
	for _i in 40:
		stack.add_salvage()
	await frames(2)
	var bundles: Array = stack.get("_bills")
	ck("tavana gelince buyumeyi kesiyor", bundles.size() == most,
		"%d / %d" % [bundles.size(), most])
	var top := 0.0
	for any: Variant in bundles:
		var node := any as Node3D
		top = maxf(top, node.position.y)
	ck("desteler tavanin altinda kaliyor", top <= room - GameConfig.CARRY_EVIDENCE_ROOM,
		"%.3f / %.3f" % [top, room - GameConfig.CARRY_EVIDENCE_ROOM])

	# The crown is inside the ceiling too — this is the half that a cap on the
	# bundles alone does not buy, and the old code put every find one storey
	# higher than the last.
	for id in ["radio", "ribbon", "boot"]:
		stack.add_evidence(id)
	await frames(2)
	var items: Array = stack.get("_items")
	var crown := 0.0
	for any: Variant in items:
		crown = maxf(crown, (any as Node3D).position.y)
	ck("tac da ensenin altinda", crown <= room, "%.3f / %.3f" % [crown, room])
	ck("bulgular yan yana, ust uste degil",
		items.size() == 3 and not is_equal_approx(
			(items[0] as Node3D).position.x, (items[1] as Node3D).position.x))
	# The MESH's reach, not the node's position: a boot placed inside the
	# shoulder line still hangs out past it, and a claim on the position alone
	# would have called that a pass (it did, once).
	var widest := 0.0
	for any: Variant in items:
		var item := any as Node3D
		for m: Variant in item.find_children("*", "MeshInstance3D", true, false):
			var mesh := m as MeshInstance3D
			var box := mesh.get_aabb()
			var at := stack.global_transform.affine_inverse() * mesh.global_transform
			for c in 8:
				widest = maxf(widest, absf((at * box.get_endpoint(c)).x))
	print("[olcum] tacin en uc noktasi %.3f | omuz %.3f" % [widest, GameConfig.CHAR_SHOULDER.x])
	ck("tac omuz cizgisini asmiyor", widest <= GameConfig.CHAR_SHOULDER.x,
		"%.3f / %.3f" % [widest, GameConfig.CHAR_SHOULDER.x])
	ck("yuk sirta yatik durur", stack.rotation.x < 0.0, "%.3f" % stack.rotation.x)
	stack.queue_free()
	await frames(2)
