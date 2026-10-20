///////////////////////////////////////////////////////////////////////////////
// World pickup for the Weapon Repair Kit. Uses the napalm-area toolbox mesh.
///////////////////////////////////////////////////////////////////////////////
class APRepairPickup extends P2PowerupPickup;

defaultproperties
{
	InventoryType=class'Archipelago.APRepairInv'
	PickupMessage="You got a Weapon Repair Kit."
	DrawType=DT_StaticMesh
	StaticMesh=StaticMesh'Zo_Meshes.zo_toolchest'
	DrawScale=0.35
	AmbientGlow=80
	bRecordAfterPickup=false
	bAllowMovement=true
	CollisionRadius=22
	CollisionHeight=14
	MaxDesireability=0.5
}
