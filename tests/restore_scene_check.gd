extends TestBase
## Buying a restoration plays a celebration over the TOWN, not over black
## (G53): the diorama is parked on every page that is not the town's, so the
## scene has to wake it up — and the still that stands in for it is not a page
## and must not be faded out with them.

func run() -> void:
	suite = "ONARIM SAHNESI"
	GameState.set_setting("restore", "farm", false)
	GameState.add_scrap(9000)
	var hub := HubScreen.new()
	add_child(hub)
	# The hub is only live when the flow says it is on screen; built by hand
	# here, nobody has said so.
	hub.set_diorama_active(true)
	await frames(6)
	hub._on_tile("restore", false)
	await frames(4)
	ck("onarim sayfasi acildi", hub._restore_page != null and hub._restore_page.visible, "")
	ck("kasaba sayfasi degil, diorama parkta", not hub._page_wants_town, "")

	# The pieces the scene must not fade: the still and the gradient are not
	# pages.
	var pages: Array = hub._pages()
	var still: TextureRect = hub._diorama_still
	var project := ""
	for any: Variant in RestoreBoard.projects():
		var id := str((any as Dictionary).get("id", ""))
		if hub._diorama != null and hub._diorama.has_building(id) \
				and not RestoreBoard.is_built(id):
			project = id
			break
	ck("dioramada canlandirilacak bir proje var", project != "", project)
	if project == "":
		hub.queue_free()
		finish()
		return

	hub._on_project(project, false, null)
	await frames(3)
	# Mid-scene: the town is live, and the still is not covering it or faded.
	ck("sahne sirasinda kasaba ciziliyor", hub._page_wants_town, "")
	ck("sahne sirasinda sayfalar saydam",
		(pages[0] as Control).modulate.a < 1.0 or not (pages[0] as Control).visible,
		"%.2f" % (pages[0] as Control).modulate.a)
	if still != null and is_instance_valid(still):
		ck("kasaba karesi solduruimadi", still.modulate.a >= 0.99,
			"%.2f" % still.modulate.a)
	ck("gorunti kabi cizmeye acik",
		hub._diorama_view.render_target_update_mode != SubViewport.UPDATE_DISABLED,
		str(hub._diorama_view.render_target_update_mode))
	ck("kap kucultulmus degil", hub._diorama_frame.stretch_shrink == 1,
		str(hub._diorama_frame.stretch_shrink))

	# It ends, and the page comes back.
	hub._diorama.skip()
	await settle(2.5)
	ck("sahne bitince sayfalar geri gelir",
		(pages[0] as Control).modulate.a >= 0.99, "%.2f" % (pages[0] as Control).modulate.a)
	ck("sahne bitince diorama yine parkta", not hub._page_wants_town, "")
	ck("proje kuruldu", RestoreBoard.is_built(project), project)
	hub.queue_free()
	await frames(2)
	finish()
