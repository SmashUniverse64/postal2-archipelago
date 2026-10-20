///////////////////////////////////////////////////////////////////////////////
// Drink to add 5 to the piss meter (Piss Realism).
///////////////////////////////////////////////////////////////////////////////
class APWaterBottleInv extends P2PowerupInv;

#exec Texture Import File=Textures\APWaterBottle.tga Name=APWaterBottle Mips=Off ALPHA=1 DXT=5

state Activated
{
Begin:
	if (APGameInfo(Level.Game) != None
		&& APGameInfo(Level.Game).DrinkWaterBottle(P2Pawn(Owner)))
	{
		Amount = Amount - 1;
		if (Amount <= 0)
			UsedUp();
	}
	GotoState('');
}

defaultproperties
{
	PickupClass=class'Archipelago.APWaterBottlePickup'
	Icon=Texture'Archipelago.APWaterBottle'
	InventoryGroup=103
	GroupOffset=94
	PowerupName="Water Bottle"
	PowerupDesc="Chug to fill your bladder by 5."
	bCanThrow=false
	bCannotBeStolen=true
	MaxAmount=20
	Amount=0
	Hint1="Press %KEY_InventoryActivate%"
	Hint2="to drink. Fills your bladder by 5."
}
