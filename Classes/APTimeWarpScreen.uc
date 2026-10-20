///////////////////////////////////////////////////////////////////////////////
// Day-select screen for Time Warp. 1-5 pick a day, then Home or an unlocked
// warp point. 6-9 and 0 story maps. Esc cancels (or goes back from the dest page).
///////////////////////////////////////////////////////////////////////////////
class APTimeWarpScreen extends StatsScreen;

var int MenuPage;
var int PendingDay;

function Show(String URLin)
{
	URL = "";
	MenuPage = 0;
	PendingDay = 0;
	AfterFadeInScreen = 'HoldScreen';
	bWantInputEvents = true;
	Super.Start();
}

function RenderScreen(canvas Canvas)
{
	if (!bEnableRender)
		return;
	DrawWarpBackground(Canvas);
	if (MenuPage == 1)
		RenderDestPage(Canvas);
	else
		RenderDayPage(Canvas);
}

function RenderDayPage(canvas Canvas)
{
	local APGameInfo G;
	local float sxl, sy, NearestFourByThree, OffsetX;
	local int d;
	local string Line;

	G = APGameInfo(GetGameSingle());
	if (G == None || MyFont == None)
		return;

	NearestFourByThree = GetPlayer().GetFourByThreeResolution(Canvas);
	OffsetX = (Canvas.ClipX - NearestFourByThree) / 2;
	sxl = LEFT_START_X;
	sy = START_Y;

	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"TIME WARP", 1, false, EJ_Left);
	sy += INC_Y * 1.5;

	for (d = 0; d < 5; d++)
	{
		Line = G.TimeWarpDayLine(d);
		MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
			Line, 0, false, EJ_Left);
		sy += INC_Y;
		Line = G.TimeWarpErrandLine(d);
		if (Line != "")
		{
			MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
				"    "$Line, 0, false, EJ_Left);
			sy += INC_Y;
		}
		sy += INC_Y * 0.3;
	}

	Line = G.TimeWarpPetitionLine();
	if (Line != "")
	{
		sy += INC_Y * 0.4;
		MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
			"ANY DAY", 0, false, EJ_Left);
		sy += INC_Y;
		MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
			"    "$Line, 0, false, EJ_Left);
	}

	sy += INC_Y * 0.5;
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"STORY MAPS", 0, false, EJ_Left);
	sy += INC_Y;
	for (d = 6; d <= 9; d++)
	{
		Line = G.TimeWarpStoryLine(d);
		if (Line != "")
		{
			MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
				Line, 0, false, EJ_Left);
			sy += INC_Y;
		}
	}
	Line = G.TimeWarpStoryLine(0);
	if (Line != "")
	{
		MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
			Line, 0, false, EJ_Left);
		sy += INC_Y;
	}

	sy += INC_Y * 0.4;
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"1-5 pick a day, then a warp point. 6-9 and 0 story maps. Esc cancels.", 0, false, EJ_Left);
}

function RenderDestPage(canvas Canvas)
{
	local APGameInfo G;
	local float sxl, sy, NearestFourByThree, OffsetX;
	local int Slot, n;
	local string Line, DayName;

	G = APGameInfo(GetGameSingle());
	if (G == None || MyFont == None)
		return;

	NearestFourByThree = GetPlayer().GetFourByThreeResolution(Canvas);
	OffsetX = (Canvas.ClipX - NearestFourByThree) / 2;
	sxl = LEFT_START_X;
	sy = START_Y;

	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"TIME WARP", 1, false, EJ_Left);
	sy += INC_Y * 1.5;

	DayName = "";
	if (G.Days.Length > PendingDay && G.Days[PendingDay] != None)
		DayName = G.Days[PendingDay].Description;
	if (DayName == "")
		DayName = string(PendingDay + 1);
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		DayName, 0, false, EJ_Left);
	sy += INC_Y * 1.2;

	n = G.TimeWarpDestCount(PendingDay);
	for (Slot = 1; Slot <= n; Slot++)
	{
		Line = G.TimeWarpDestLine(PendingDay, Slot);
		if (Line != "")
		{
			MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
				Line, 0, false, EJ_Left);
			sy += INC_Y;
		}
	}

	sy += INC_Y * 0.8;
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"Throw Time Warp after you pick. Pick it up when it lights.", 0, false, EJ_Left);
	sy += INC_Y;
	MyFont.DrawTextEx(Canvas, NearestFourByThree, OffsetX + (sxl * NearestFourByThree), sy * Canvas.ClipY,
		"Esc back.", 0, false, EJ_Left);
}

function DrawWarpBackground(canvas Canvas)
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

function bool KeyEvent(out EInputKey Key, out EInputAction Action, float Delta)
{
	if (Action != IST_Press)
		return false;
	if (MenuPage == 1)
	{
		if (Key == IK_Escape)
		{
			MenuPage = 0;
			return true;
		}
		if (Key == IK_1 || Key == IK_NumPad1)
			return ConfirmDest(1);
		if (Key == IK_2 || Key == IK_NumPad2)
			return ConfirmDest(2);
		if (Key == IK_3 || Key == IK_NumPad3)
			return ConfirmDest(3);
		if (Key == IK_4 || Key == IK_NumPad4)
			return ConfirmDest(4);
		if (Key == IK_5 || Key == IK_NumPad5)
			return ConfirmDest(5);
		if (Key == IK_6 || Key == IK_NumPad6)
			return ConfirmDest(6);
		if (Key == IK_7 || Key == IK_NumPad7)
			return ConfirmDest(7);
		if (Key == IK_8 || Key == IK_NumPad8)
			return ConfirmDest(8);
		if (Key == IK_9 || Key == IK_NumPad9)
			return ConfirmDest(9);
		return false;
	}
	if (Key == IK_Escape)
	{
		bPlayerWantsToEnd = true;
		return true;
	}
	if (Key == IK_1 || Key == IK_NumPad1)
		return TryWarpDay(0);
	if (Key == IK_2 || Key == IK_NumPad2)
		return TryWarpDay(1);
	if (Key == IK_3 || Key == IK_NumPad3)
		return TryWarpDay(2);
	if (Key == IK_4 || Key == IK_NumPad4)
		return TryWarpDay(3);
	if (Key == IK_5 || Key == IK_NumPad5)
		return TryWarpDay(4);
	if (Key == IK_6 || Key == IK_NumPad6)
		return TryWarpStory(6);
	if (Key == IK_7 || Key == IK_NumPad7)
		return TryWarpStory(7);
	if (Key == IK_8 || Key == IK_NumPad8)
		return TryWarpStory(8);
	if (Key == IK_9 || Key == IK_NumPad9)
		return TryWarpStory(9);
	if (Key == IK_0 || Key == IK_NumPad0)
		return TryWarpStory(0);
	return false;
}

function bool TryWarpDay(int Day)
{
	local APGameInfo G;

	G = APGameInfo(GetGameSingle());
	if (G == None)
		return true;
	if (!G.IsDayUnlocked(Day))
		return true;
	PendingDay = Day;
	MenuPage = 1;
	return true;
}

function bool ConfirmDest(int Slot)
{
	local APGameInfo G;

	G = APGameInfo(GetGameSingle());
	if (G == None)
		return true;
	if (G.QueueDayWarp(PendingDay, Slot))
		bPlayerWantsToEnd = true;
	return true;
}

function bool TryWarpStory(int Slot)
{
	local APGameInfo G;

	G = APGameInfo(GetGameSingle());
	if (G != None && G.QueueStoryWarp(Slot))
		bPlayerWantsToEnd = true;
	return true;
}

defaultproperties
{
	Message=""
	bWantInputEvents=true
}
