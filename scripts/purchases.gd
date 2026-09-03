extends Node
## Purchases autoload (G16.6): the one seam between the game and a store.
##
## The game is premium with a free start — the prologue and the first three
## chapters — and one purchase for the rest (GameConfig.DEMO_GATE). Locally
## there is no store, so `is_full()` reads a flag in the save and
## `unlock_full()` sets it; a store plugs in as a PROVIDER with three methods:
##
##   buy(product_id: String) -> bool     starts the purchase; true if it began
##   restore() -> bool                    asks the store for past purchases
##   owns(product_id: String) -> bool     the store's answer
##
## iOS: StoreKit 2 through a Godot iOS plugin (godot-ios-plugins/inappstore).
## Android: Play Billing through the GodotGooglePlayBilling plugin. Both report
## asynchronously; a provider calls `Purchases.grant()` when the store confirms,
## and the flag in the save is what the game reads from then on — so a store
## outage after purchase never locks a paying player out.
##
## DEV_UNLOCK_ALL and a build without DEMO_GATE both mean "everything open".

signal changed()

const PRODUCT_FULL := "com.lawnhealthai.underthelawn.full"
const SECTION := "purchases"
const KEY_FULL := "full"

var provider: Object = null


func is_full() -> bool:
	if not GameConfig.DEMO_GATE or GameConfig.DEV_UNLOCK_ALL:
		return true
	return bool(GameState.get_setting(SECTION, KEY_FULL, false))


## Whether a chapter may be started under the gate.
func chapter_allowed(variant_id: String) -> bool:
	if is_full():
		return true
	return variant_id == GameConfig.PROLOGUE_ID \
		or GameConfig.DEMO_FREE_CHAPTERS.has(variant_id)


## Begins the purchase. Without a provider this grants immediately — which is
## what a development build and every test wants, and what a shipped build
## must never do; the provider is what makes the difference, and it is checked
## for by ReleaseCheck.
func unlock_full() -> bool:
	if is_full():
		return true
	if provider != null and provider.has_method("buy"):
		return bool(provider.call("buy", PRODUCT_FULL))
	grant()
	return true


func restore() -> bool:
	if provider != null and provider.has_method("restore"):
		return bool(provider.call("restore"))
	return false


## Called by the provider when the store confirms, or locally by unlock_full.
func grant() -> void:
	GameState.set_setting(SECTION, KEY_FULL, true)
	Analytics.track("purchase_full", {"provider": provider != null})
	changed.emit()
