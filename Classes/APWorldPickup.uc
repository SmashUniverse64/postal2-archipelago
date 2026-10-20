///////////////////////////////////////////////////////////////////////////////
// Walk-into Archipelago world token. Converted pickups keep weapon ValidTouch
// (shelf FastTrace, melee mode, full weapon group) so the logo can be visible
// while the original cylinder is untouchable. This class skips those checks.
///////////////////////////////////////////////////////////////////////////////
class APWorldPickup extends P2PowerupPickup;

var string APUnique;
var name SourceName;

function PrepForGrabbing()
{
	bOKToGrab = true;
	GotoState('Pickup');
}

state Pickup
{
	function bool ValidTouch(actor Other)
	{
		if (Pawn(Other) == None)
			return false;
		if (!Pawn(Other).bCanPickupInventory || Pawn(Other).Health <= 0)
			return false;
		if (P2Player(Pawn(Other).Controller) == None)
			return false;
		if (Level.Game != None && Level.Game.PickupQuery(Pawn(Other), self))
		{
			TriggerEvent(Event, self, Pawn(Other));
			return true;
		}
		return false;
	}
}

defaultproperties
{
	InventoryType=class'Archipelago.APShopInv'
	PickupMessage="Archipelago check"
	DrawType=DT_None
	bHidden=false
	bUnlit=true
	bAcceptsProjectors=false
	AmbientGlow=255
	bRecordAfterPickup=false
	bAllowMovement=false
	bOKToGrab=true
	bCollideActors=true
	bCollideWorld=false
	bBlockActors=false
	bBlockPlayers=false
	bProjTarget=false
	CollisionRadius=34
	CollisionHeight=36
	Physics=PHYS_None
}
