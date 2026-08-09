## Player currency wallet.
##
## A small `Node3D` that tracks a currency balance. Attach it to the player (or
## anywhere) — it self-registers in the "wallet" group so `currency_deposit`
## areas can find it. Feed it with `add_currency()` when loot is picked up and
## let deposit areas drain it via `spend_currency()`.
extends Node3D

## Current balance. Games can set a starting amount from the inspector.
@export var currency := 0

## Emitted whenever the balance changes.
signal currency_changed(amount: int)

func _ready():
	add_to_group("wallet")

## Credits `amount` to the wallet and emits `currency_changed`.
func add_currency(amount: int):
	if amount <= 0:
		return
	currency += amount
	currency_changed.emit(currency)

## Removes up to `amount` from the wallet. Returns how much was actually spent
## (never more than the balance, never negative).
func spend_currency(amount: int) -> int:
	var spent := clampi(amount, 0, currency)
	if spent <= 0:
		return 0
	currency -= spent
	currency_changed.emit(currency)
	return spent
