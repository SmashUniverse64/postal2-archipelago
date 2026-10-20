///////////////////////////////////////////////////////////////////////////////
// HUD overlay: melee durability in the ammo number slot.
///////////////////////////////////////////////////////////////////////////////
class APHUD extends AWWrapHUD;

simulated function DrawHUD(canvas Canvas)
{
	Super.DrawHUD(Canvas);
	DrawClientGate(Canvas);
}

simulated function DrawClientGate(canvas Canvas)
{
	local APGameInfo G;
	local color Gold, White;
	local float y;

	G = APGameInfo(Level.Game);
	if (G == None || !G.IsWaitingForAPClient())
		return;
	if (MyFont == None || Canvas == None)
		return;
	Gold.R = 255;
	Gold.G = 210;
	Gold.B = 40;
	Gold.A = 255;
	White.R = 230;
	White.G = 230;
	White.B = 230;
	White.A = 255;
	y = Canvas.ClipY * 0.36;
	MyFont.DrawTextEx(Canvas, Canvas.ClipX, Canvas.ClipX * 0.5, y,
		"Welcome to Postal 2 Archipelago!", 1, false, EJ_Center, Gold);
	y = y + Canvas.ClipY * 0.045;
	MyFont.DrawTextEx(Canvas, Canvas.ClipX, Canvas.ClipX * 0.5, y,
		"Connect to your server in the Postal 2 Client", 0, false, EJ_Center, White);
	y = y + Canvas.ClipY * 0.035;
	MyFont.DrawTextEx(Canvas, Canvas.ClipX, Canvas.ClipX * 0.5, y,
		"and type in your slot name to continue.", 0, false, EJ_Center, White);
}

simulated function DrawWeapon(canvas Canvas, float Scale)
{
	local APGameInfo G;
	local P2Weapon Weap;
	local int Dur;
	local string str1;
	local Texture usetex;
	local float backgroundPosX, backgroundPosY;

	Super.DrawWeapon(Canvas, Scale);
	G = APGameInfo(Level.Game);
	if (G == None || !G.MeleeDurabilityEnabled())
		return;
	if (PawnOwner == None)
		return;
	Weap = P2Weapon(PawnOwner.Weapon);
	if (!G.IsDurabilityMelee(Weap))
		return;
	Dur = G.GetMeleeDur(Weap);
	str1 = string(Dur);
	if (Dur <= 0)
		Canvas.DrawColor = RedColor;
	else
		Canvas.DrawColor = DefaultIconColor;
	usetex = Texture(SectionBackground[HUD_AMMO]);
	if (usetex != None)
	{
		backgroundPosX = (IconPos[WeapIndex].X * Canvas.ClipX) - (Scale * (usetex.USize / 2));
		backgroundPosY = ((IconPos[WeapIndex].Y + HUD_N_BG_OFFSET_Y) * CanvasHeight) - (Scale * (usetex.VSize / 2));
		MyFont.DrawTextEx(Canvas, CanvasWidth,
			(backgroundPosX) + (usetex.USize * Scale / HUD_N_NUM_ALIGN_X),
			(backgroundPosY) + (usetex.VSize * Scale / 1.5) + HUD_NUMBERS_OFFSET_Y,
			str1, 2, , EJ_Right);
	}
	else
		MyFont.DrawTextEx(Canvas, CanvasWidth,
			UltraWideOffsetX + (IconPos[WeapIndex].X + HUD_NUMBERS_OFFSET_X) * CanvasWidth,
			(IconPos[WeapIndex].Y + HUD_NUMBERS_OFFSET_Y) * CanvasHeight,
			str1, 2, , EJ_Right);
}
