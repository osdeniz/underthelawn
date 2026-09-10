extends TestBase
## The place a conversation happens in (G58).
##
## The claim that matters most is the one about what did NOT change: a briefing
## plays over the yard it is about (G54), so `brief_` must resolve to no
## backdrop at all, and a box asked for a picture that has not been painted yet
## must stay exactly as transparent as it was before this existed.

func run() -> void:
	suite = "ZEMIN"
	_rules()
	await _box()
	finish()


func _rules() -> void:
	# The prefix table, and the two kinds that deliberately have no picture.
	ck("brifingin zemini yok — bahce gorunur", Dialogue.backdrop("brief_ch01") == "",
		Dialogue.backdrop("brief_ch01"))
	ck("bahce sonu konusmasinin zemini yok",
		Dialogue.backdrop("debrief_ch01_full") == "",
		Dialogue.backdrop("debrief_ch01_full"))
	ck("tanimsiz konusma varsayilana duser",
		Dialogue.backdrop("boyle_bir_konusma_yok") == "", "")

	# The resolver itself, proved on rules this test installs rather than on
	# art that has not been painted: every shipped rule is empty on purpose
	# until the pictures exist (see the claim at the end of this section).
	var rules: Dictionary = Dialogue.data().get("backdrops", {})
	var keep: Dictionary = rules.duplicate()
	rules["chat_"] = "places/kare"
	rules["chat_ch14_observer"] = "places/tepe"
	rules["default"] = "places/varsayilan"
	ck("onek eslesir", Dialogue.backdrop("chat_ch12") == "places/kare",
		Dialogue.backdrop("chat_ch12"))
	ck("en uzun onek kazanir",
		Dialogue.backdrop("chat_ch14_observer") == "places/tepe",
		Dialogue.backdrop("chat_ch14_observer"))
	ck("eslesmeyen varsayilani alir",
		Dialogue.backdrop("hicbir_onek") == "places/varsayilan",
		Dialogue.backdrop("hicbir_onek"))
	# A conversation's own field beats every rule.
	var convos: Dictionary = Dialogue.data().get("conversations", {})
	var one: Dictionary = convos["chat_ch12"]
	one["backdrop"] = "places/kendi"
	ck("konusmanin kendi alani onekten guclu",
		Dialogue.backdrop("chat_ch12") == "places/kendi",
		Dialogue.backdrop("chat_ch12"))
	one.erase("backdrop")
	rules.clear()
	rules.merge(keep)
	ck("kurallar geri alindi", Dialogue.backdrop("chat_ch12") == "",
		Dialogue.backdrop("chat_ch12"))
	ck("kural tablosu var", not rules.is_empty(), str(rules.size()))
	ck("varsayilan tanimli", rules.has("default"), "")
	# Every place a rule names must be a real picture, or a conversation would
	# ask for art nobody has drawn and the box would warn on every line.
	var missing: Array[String] = []
	for key: Variant in rules:
		if str(key).begins_with("_"):
			continue
		var name := str(rules[key])
		if name != "" and TextureLibrary.find(name) == null:
			missing.append("%s -> %s" % [key, name])
	ck("kuraldaki her yerin resmi var", missing.is_empty(), ", ".join(missing))


func _box() -> void:
	var box := DialogueBox.new()
	add_child(box)
	# Asked BEFORE the tree is built: play() can run on the same frame.
	box.play([{"speaker": "marshal", "text": "DLG_BRIEF_CH01_1"}], "", "intro/pro_1")
	await frames(3)
	var back: TextureRect = box.find_child("Backdrop", true, false)
	ck("zemin dugumu var", back != null, "")
	if back == null:
		box.queue_free()
		return
	ck("zemin resmi yuklendi", back.texture == TextureLibrary.find("intro/pro_1"), "")
	ck("zemin gorunur", back.visible, "")
	ck("zemin ekrani kaplar",
		back.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "")
	ck("zemin tam kadraj",
		is_equal_approx(back.size.x, box.size.x) and is_equal_approx(back.size.y, box.size.y),
		"%.0fx%.0f / %.0fx%.0f" % [back.size.x, back.size.y, box.size.x, box.size.y])
	# Under the scrim, or the 55% black that keeps the type legible would be
	# painted over by the picture.
	var scrim_index := -1
	var back_index := -1
	for i in box.get_child_count():
		var child := box.get_child(i)
		if child == back:
			back_index = i
		elif child is ColorRect:
			scrim_index = i
	ck("zemin perdenin altinda", back_index >= 0 and scrim_index > back_index,
		"%d < %d" % [back_index, scrim_index])
	box.queue_free()
	await frames(2)

	# The important one: a place that has not been painted yet changes nothing.
	var plain := DialogueBox.new()
	add_child(plain)
	plain.play([{"speaker": "marshal", "text": "DLG_BRIEF_CH01_1"}], "",
		"places/henuz_cizilmedi")
	await frames(3)
	var empty: TextureRect = plain.find_child("Backdrop", true, false)
	ck("cizilmemis yer gizli kalir", empty != null and not empty.visible, "")
	ck("cizilmemis yer dokusuz", empty != null and empty.texture == null, "")
	plain.queue_free()
	await frames(2)

	# And no backdrop at all is the same thing, which is what every caller that
	# has not been told about places gets.
	var bare := DialogueBox.new()
	add_child(bare)
	bare.play([{"speaker": "marshal", "text": "DLG_BRIEF_CH01_1"}])
	await frames(3)
	var none: TextureRect = bare.find_child("Backdrop", true, false)
	ck("zemin istenmezse gizli", none != null and not none.visible, "")
	bare.queue_free()
	await frames(2)
