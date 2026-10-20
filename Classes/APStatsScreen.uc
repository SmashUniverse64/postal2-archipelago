///////////////////////////////////////////////////////////////////////////////
// Stats Clipboard page for the Archipelago mutator.
///////////////////////////////////////////////////////////////////////////////
class APStatsScreen extends StatsScreen;

function Show(String URLin)
{
	URL = URLin;
	gamest = GetGameSingle().TheGameState;
	AfterFadeInScreen = 'HoldScreen';
	Super.Start();
}

function RenderScreen(canvas Canvas)
{
	local APGameInfo G;
	local float sxl, sxr, sy, NearestFourByThree, OffsetX;

	if (!bEnableRender)
		return;

	DrawBackground(Canvas);

	G = APGameInfo(GetGameSingle());
	if (G == None || MyFont == None)
		return;

	NearestFourByThree = GetPlayer().GetFourByThreeResolution(Canvas);
	OffsetX = (Canvas.ClipX - NearestFourByThree) / 2;
	sxl = LEFT_START_X;
	sxr = RIGHT_START_X;
	sy = START_Y;

	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Slot", G.ClipboardTitle());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Link", G.ClipboardConnection());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Today", G.ClipboardDay());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Today's list", G.ClipboardErrandsLeft());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Any day", G.ClipboardPetition());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Week", G.ClipboardWeek());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "In logic", G.ClipboardTracker());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Days open", G.ClipboardDaysOpen());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Hunt today", G.ClipboardHuntMaps());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Tokens here", G.ClipboardMapPickupsLeft());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Machines", G.ClipboardMapMachines());
	DrawKV(Canvas, NearestFourByThree, OffsetX, sxl, sxr, sy, "Weapons", G.ClipboardWeapons());

	sy += INC_Y;
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"Time Warp from inventory to change days. Later days can add more tokens.", 0, false, EJ_Left);
}

function DrawBackground(canvas Canvas)
{
	local float NearestFourByThree, OffsetX;

	if (BackgroundTex == None)
		return;
	if (bStretch)
	{
		Canvas.Style = 1;
		Canvas.SetDrawColor(255, 255, 255);
		Canvas.SetPos(0, 0);
		Canvas.DrawTile(BackgroundTex, Canvas.SizeX, Canvas.SizeY, 0, 0, BackgroundTex.USize, BackgroundTex.VSize);
	}
	else
	{
		NearestFourByThree = FOUR_BY_THREE_ASPECT_RATIO * (Canvas.SizeY * 1);
		OffsetX = (Canvas.ClipX - NearestFourByThree) / 2;
		Canvas.Style = 1;
		Canvas.SetDrawColor(255, 255, 255);
		Canvas.SetPos(OffsetX, 0);
		Canvas.DrawTile(BackgroundTex, NearestFourByThree, Canvas.SizeY, 0, 0, BackgroundTex.USize, BackgroundTex.VSize);
	}
}

function DrawRow(canvas Canvas, float Width, float OffsetX, float sxl, float sxr, float sy, string LeftText, string RightText)
{
	if (LeftText != "")
		MyFont.DrawTextEx(Canvas, Width, OffsetX + (sxl * Width), sy * Canvas.ClipY, LeftText, 0, false, EJ_Left);
	if (RightText != "")
		MyFont.DrawTextEx(Canvas, Width, OffsetX + (sxr * Width), sy * Canvas.ClipY, RightText, 0, false, EJ_Left);
}

function DrawKV(canvas Canvas, float Width, float OffsetX, float sxl, float sxr, out float sy, string LeftText, string RightText)
{
	local string Rest, Line;

	if (RightText == "")
		return;
	Rest = RightText;
	Line = ClipChop(Rest, 28);
	DrawRow(Canvas, Width, OffsetX, sxl, sxr, sy, LeftText, Line);
	sy += INC_Y;
	while (Rest != "")
	{
		Line = ClipChop(Rest, 28);
		DrawRow(Canvas, Width, OffsetX, sxl, sxr, sy, "", Line);
		sy += INC_Y;
	}
}

function string ClipChop(out string S, int MaxLen)
{
	local int i, Cut;
	local string Piece;

	if (S == "")
		return "";
	if (Len(S) <= MaxLen)
	{
		Piece = S;
		S = "";
		return Piece;
	}
	Cut = MaxLen;
	i = MaxLen;
	while (i > 8)
	{
		if (Mid(S, i, 1) == " " || Mid(S, i, 1) == ",")
		{
			if (Mid(S, i, 1) == ",")
				Cut = i + 1;
			else
				Cut = i;
			break;
		}
		i--;
	}
	Piece = Left(S, Cut);
	S = Mid(S, Cut);
	while (Left(S, 1) == " ")
		S = Mid(S, 1);
	return Piece;
}

defaultproperties
{
	Song="map_muzak.ogg"
	BackgroundName="P2Misc_full.InkyBlackness"
	TileName="nathans.Inventory.blackbox64"
}
