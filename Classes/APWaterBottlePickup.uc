///////////////////////////////////////////////////////////////////////////////
// Vending pickup for a Water Bottle. HUD uses the imported bottle icon.
///////////////////////////////////////////////////////////////////////////////
class APWaterBottlePickup extends P2PowerupPickup;

defaultproperties
{
	InventoryType=class'Archipelago.APWaterBottleInv'
	PickupMessage="You got a bottle of water."
	DrawType=DT_StaticMesh
	StaticMesh=StaticMesh'xPatchMesh.Pickup.CrackColaCan'
	DrawScale=0.55
	AmbientGlow=80
	bRecordAfterPickup=false
	bAllowMovement=true
	CollisionRadius=12
	CollisionHeight=16
	MaxDesireability=0.3
}
