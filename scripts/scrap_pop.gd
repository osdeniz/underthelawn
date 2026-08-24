class_name ScrapPop
extends Node3D
## The bolt that jumps out of the grass when a cut cell held scrap (G9).
##
## A tiny billboard, not a mesh: it exists for a third of a second and reads at
## gameplay distance purely as a flash of metal, so geometry would be waste.

const RISE_TIME := 0.34


static func spawn(parent: Node3D, at: Vector3) -> void:
	var pop := ScrapPop.new()
	pop.name = "ScrapPop"
	parent.add_child(pop)
	pop.position = Vector3(at.x, 0.1, at.z)
	pop._play()


func _play() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.44, 0.44)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Banknote green; reads as money at a glance even without art.
	mat.albedo_color = Color(0.55, 0.85, 0.55)
	mat.albedo_texture = TextureLibrary.find("scrap_bolt")
	if mat.albedo_texture == null:
		# No art: a bright metallic dot still reads as a pickup.
		TextureLibrary.warn_missing("scrap_bolt", "para ikonu = yesil nokta")
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var tw := create_tween()
	tw.tween_property(self, "position:y", 0.1 + GameConfig.SCRAP_RISE,
		RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", TAU, RISE_TIME)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, RISE_TIME) \
		.set_delay(RISE_TIME * 0.55)
	tw.tween_callback(queue_free)
