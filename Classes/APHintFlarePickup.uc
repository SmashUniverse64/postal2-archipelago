///////////////////////////////////////////////////////////////////////////////
// World pickup for the Hint Flare. Uses the rocket launcher projectile mesh.
///////////////////////////////////////////////////////////////////////////////
class APHintFlarePickup extends P2PowerupPickup;

defaultproperties
{
	InventoryType=class'Archipelago.APHintFlareInv'
	PickupMessage="You got a Hint Flare."
	DrawType=DT_StaticMesh
	StaticMesh=StaticMesh'stuff.stuff1.launcherrocket'
	DrawScale=0.45
	AmbientGlow=80
	bRecordAfterPickup=false
	bAllowMovement=true
	CollisionRadius=18
	CollisionHeight=22
	MaxDesireability=0.4
}
