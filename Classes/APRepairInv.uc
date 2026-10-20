///////////////////////////////////////////////////////////////////////////////
// Inventory powerup that restores melee durability to 100.
///////////////////////////////////////////////////////////////////////////////
class APRepairInv extends P2PowerupInv;

#exec Texture Import File=Textures\APRepair.tga Name=APRepair Mips=Off ALPHA=1 DXT=5

state Activated
{
Begin:
	if (APGameInfo(Level.Game) != None
		&& APGameInfo(Level.Game).UseRepairKit(P2Pawn(Owner)))
	{
		Amount = Amount - 1;
		if (Amount <= 0)
			UsedUp();
	}
	GotoState('');
}

defaultproperties
{
	PickupClass=class'Archipelago.APRepairPickup'
	Icon=Texture'Archipelago.APRepair'
	InventoryGroup=103
	GroupOffset=95
	PowerupName="Weapon Repair Kit"
	PowerupDesc="Restores the melee weapon you're holding to full durability."
	bCanThrow=false
	bCannotBeStolen=true
	MaxAmount=20
	Amount=0
	Hint1="Press %KEY_InventoryActivate%"
	Hint2="to repair your equipped melee weapon."
}
