///////////////////////////////////////////////////////////////////////////////
// Inventory powerup that marks every AP token on the map with a sky flare.
///////////////////////////////////////////////////////////////////////////////
class APHintFlareInv extends P2PowerupInv;

#exec Texture Import File=Textures\APHintFlare.tga Name=APHintFlare Mips=Off ALPHA=1 DXT=5
#exec AUDIO IMPORT FILE="Sounds\flare_detonator_launch.wav" NAME=FlareDetonatorLaunch

state Activated
{
Begin:
	if (APGameInfo(Level.Game) != None
		&& APGameInfo(Level.Game).FireHintFlares(P2Pawn(Owner)))
	{
		Amount = Amount - 1;
		if (Amount <= 0)
			UsedUp();
	}
	GotoState('');
}

defaultproperties
{
	PickupClass=class'Archipelago.APHintFlarePickup'
	Icon=Texture'Archipelago.APHintFlare'
	InventoryGroup=103
	GroupOffset=96
	PowerupName="Hint Flare"
	PowerupDesc="Fires a harmless flare rocket straight up from every AP token on this map."
	bCanThrow=false
	bCannotBeStolen=true
	MaxAmount=20
	Amount=0
	Hint1="Press %KEY_InventoryActivate%"
	Hint2="to mark every AP token on this map."
}
