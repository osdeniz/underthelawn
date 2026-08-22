class_name Hud
extends Control
## HUD for sprints G1 + G2 (§16).
##
## G1: mown percentage, green capsule, mute button, LAWN COMPLETE panel.
## G2: secret counter, the discovery card that flies into the counter,
## collection slots, the "you missed something" line, screen dressing and the
## completion flash.
##
## The root ignores input; only the buttons and the completion backdrop stop
## events, so touches meant for the lawn reach the 3D scene.

signal restart_pressed()

@onready var _percent_label: Label = %PercentLabel
@onready var _secret_counter: Label = %SecretCounter
@onready var _progress: ProgressBar = %Progress
@onready var _mute_button: Button = %MuteButton
@onready var _secret_card: PanelContainer = %SecretCard
@onready var _card_title: Label = %CardTitle
@onready var _card_line: Label = %CardLine
@onready var _complete_panel: Control = %CompletePanel
@onready var _complete_stats: Label = %CompleteStats
@onready var _complete_title: Label = %Title
@onready var _collection: HBoxContainer = %Collection
@onready var _missed_label: Label = %MissedLabel
@onready var _flash: ColorRect = %Flash

var _shown_percent := 0.0
var _target_percent := 0.0
var _card_home := Vector2.ZERO
var _card_tween: Tween
var _counter_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_complete_panel.visible = false
	_secret_card.visible = false
	_missed_label.visible = false
	_flash.modulate.a = 0.0
	_mute_button.pressed.connect(_on_mute_pressed)
	(%RestartButton as Button).pressed.connect(func() -> void: restart_pressed.emit())
	_refresh_mute_label()
	set_progress(0.0)
	set_secret_count(0, GameConfig.SECRET_TOTAL)


# ---------------------------------------------------------------- progress

func set_progress(ratio: float) -> void:
	_target_percent = clampf(ratio, 0.0, 1.0) * 100.0


func _process(delta: float) -> void:
	if absf(_target_percent - _shown_percent) > 0.01:
		_shown_percent = lerpf(_shown_percent, _target_percent,
			clampf(delta * 9.0, 0.0, 1.0))
		_apply_percent()


func _apply_percent() -> void:
	_percent_label.text = "%%%d biçildi" % int(round(_shown_percent))
	_progress.value = _shown_percent


# ---------------------------------------------------------------- secrets

func set_secret_count(found: int, total: int) -> void:
	_secret_counter.text = "🔍 %d/%d" % [found, total]


## Counter pop, used when the flying card lands on it.
func bump_secret_counter() -> void:
	if _counter_tween and _counter_tween.is_valid():
		_counter_tween.kill()
	_secret_counter.pivot_offset = _secret_counter.size * 0.5
	_secret_counter.scale = Vector2(1.35, 1.35)
	_counter_tween = create_tween()
	_counter_tween.tween_property(_secret_counter, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows the discovery card, then shrinks it into the secret counter (§16).
## `on_landed` fires when it reaches the counter, so the count updates then.
func show_secret_card(emoji: String, item_name: String, line: String,
		on_landed: Callable) -> void:
	_card_title.text = "%s %s" % [emoji, item_name]
	_card_line.text = line

	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	# Remember the resting place so repeat cards start from the same spot.
	if _card_home == Vector2.ZERO:
		_card_home = _secret_card.position
	_secret_card.position = _card_home
	_secret_card.pivot_offset = _secret_card.size * 0.5
	_secret_card.scale = Vector2(0.8, 0.8)
	_secret_card.modulate.a = 0.0
	_secret_card.visible = true

	var target := _secret_counter.get_global_rect().get_center() \
		- _secret_card.size * 0.5

	_card_tween = create_tween()
	_card_tween.tween_property(_secret_card, "modulate:a", 1.0, 0.2)
	_card_tween.parallel().tween_property(_secret_card, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(GameConfig.CARD_SHOW_TIME)
	_card_tween.tween_property(_secret_card, "position", target,
		GameConfig.CARD_FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_card_tween.parallel().tween_property(_secret_card, "scale", Vector2(0.12, 0.12),
		GameConfig.CARD_FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_card_tween.parallel().tween_property(_secret_card, "modulate:a", 0.0,
		GameConfig.CARD_FLY_TIME).set_delay(GameConfig.CARD_FLY_TIME * 0.55)
	_card_tween.tween_callback(func() -> void:
		_secret_card.visible = false
		_secret_card.position = _card_home
		_secret_card.scale = Vector2.ONE
		bump_secret_counter()
		if on_landed.is_valid():
			on_landed.call())


# ---------------------------------------------------------------- completion

## `collected` holds one entry per found item: { emoji, name }.
func show_complete(cells: int, elapsed: String, collected: Array,
		total_secrets: int) -> void:
	_shown_percent = 100.0
	_apply_percent()
	_complete_stats.text = "%d hücre biçildi · süre: %s" % [cells, elapsed]

	for child in _collection.get_children():
		child.queue_free()
	for i in total_secrets:
		var slot := Label.new()
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 40)
		if i < collected.size():
			var entry: Dictionary = collected[i]
			slot.text = "%s\n%s" % [entry.get("emoji", "?"), entry.get("name", "")]
			slot.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		else:
			slot.text = "?\n—"
			slot.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
		_collection.add_child(slot)

	_missed_label.visible = collected.size() < total_secrets
	_complete_panel.visible = true

	# Spring pop on the title (§16).
	_complete_title.pivot_offset = _complete_title.size * 0.5
	_complete_title.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_complete_title, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func hide_complete() -> void:
	_complete_panel.visible = false
	_missed_label.visible = false
	_shown_percent = 0.0
	_target_percent = 0.0
	_apply_percent()


## Brief white bloom for the 100% moment.
func flash(strength := 0.5, duration := 0.9) -> void:
	_flash.modulate.a = clampf(strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- mute

func _on_mute_pressed() -> void:
	AudioDirector.toggle_mute()
	Haptics.light()
	_refresh_mute_label()


func _refresh_mute_label() -> void:
	_mute_button.text = "🔇" if AudioDirector.muted else "🔊"
