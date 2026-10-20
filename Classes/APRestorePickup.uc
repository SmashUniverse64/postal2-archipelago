///////////////////////////////////////////////////////////////////////////////
// Leftover brewery restore token. Escape through the brewery load zone
// resyncs AP items now; any leftover pickup is stripped on map load.
///////////////////////////////////////////////////////////////////////////////
class APRestorePickup extends P2PowerupPickup;

defaultproperties
{
	InventoryType=class'Archipelago.APShopInv'
	PickupMessage="Archipelago loadout restored."
	DrawType=DT_Sprite
	Texture=Texture'Archipelago.APLogo'
	Style=STY_Masked
	bUnlit=true
	bAcceptsProjectors=false
	AmbientGlow=255
	DrawScale=0.20
	bRecordAfterPickup=false
	CollisionRadius=24
	CollisionHeight=16
}
