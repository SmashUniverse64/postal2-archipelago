///////////////////////////////////////////////////////////////////////////////
// Pickup spawned when the player buys the AP slot from a vending machine.
///////////////////////////////////////////////////////////////////////////////
class APShopPickup extends P2PowerupPickup;

defaultproperties
{
	InventoryType=class'Archipelago.APShopInv'
	PickupMessage="Archipelago check"
	DrawType=DT_Sprite
	Texture=Texture'Archipelago.APLogo'
	Style=STY_Masked
	bUnlit=true
	bAcceptsProjectors=false
	AmbientGlow=255
	DrawScale=0.20
	bRecordAfterPickup=false
	CollisionRadius=20
	CollisionHeight=12
}
