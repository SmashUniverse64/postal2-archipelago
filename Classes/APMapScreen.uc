///////////////////////////////////////////////////////////////////////////////
// Map screen that refreshes errand visibility (clinic, old deactivated
// paycheck/book chores) before drawing.
///////////////////////////////////////////////////////////////////////////////
class APMapScreen extends MapScreen;

#exec Texture Import File=Textures\APMapCheck.tga Name=APMapCheck Mips=Off ALPHA=1 DXT=5
#exec OBJ LOAD FILE=P2Fonts.utx

var Font MapLabelFont;
var string LabKey[32];
var string LabStr[32];
var float LabX[32];
var float LabY[32];
var float LabW[32];
var float LabH[32];
var int LabN[32];
var int LabOpen[32];
var int LabVis[32];
var int LabFixed[32];
var int LabCount;

function MapInit()
{
	local APGameInfo G;
	local P2GameInfoSingle GI;

	G = APGameInfo(GetGameSingle());
	if (G != None)
		G.RefreshMapErrands();

	GI = GetGameSingle();
	if (GI == None || GI.TheGameState == None)
	{
		Day = None;
		gs = None;
		return;
	}
	Super.MapInit();
}

function int FindUnrevealedErrand(int ErrandIndex)
{
	if (Day == None || gs == None)
		return -1;
	return Super.FindUnrevealedErrand(ErrandIndex);
}

function float PlayDudeComment(Sound DudeComment, optional float PadTime, optional float OtherDuration)
{
	if (DudeComment == None)
		return FMax(PadTime, OtherDuration);
	return Super.PlayDudeComment(DudeComment, PadTime, OtherDuration);
}

function MapStart(bool bShowTrail, optional bool bDontPauseGame_In)
{
	if (Day == None)
		return;
	Super.MapStart(bShowTrail, bDontPauseGame_In);
}

function ShowErrands(optional String SendToURL, optional bool bWantFancyFadeIn)
{
	MapInit();
	if (Day == None || FindUnrevealedErrand(-1) == -1)
	{
		if (SendToURL != "")
		{
			PostRevealSendToURL = SendToURL;
			if (Day == None)
			{
				GetGameSingle().SendPlayerEx(GetPlayer(), SendToURL);
				return;
			}
			bUnpauseAfterReaveal = bWantFancyFadeIn;
			bFadeGameInOut = false;
			FadeInGameTime = 0.0;
			FadeOutGameTime = 0.0;
			bFadeScreenInOut = false;
			FadeInScreenTime = 0.0;
			FadeOutScreenTime = 0.0;
			bFancyMapFade = true;
			AfterFadeInScreen = 'RevealSendPlayer';
			MapStart(false, true);
			return;
		}
	}
	Super.ShowErrands(SendToURL, bWantFancyFadeIn);
}

state RevealErrands
{
	function BeginState()
	{
		RevealErrand = FindUnrevealedErrand(-1);
		RevealCount = 0;
		if (RevealErrand == -1)
		{
			if (PostRevealSendToURL != "")
				GotoState('RevealSendPlayer');
			else
				GotoState('RevealErrandsFinish');
			return;
		}
		DelayedGotoState(PreferredTime(BigHoldTime), 'RevealErrands2');
	}
}

function SetupSprites()
{
	local int i;
	local APGameInfo G;
	local string U;

	Super.SetupSprites();
	if (Day == None)
		return;
	G = APGameInfo(GetGameSingle());
	for (i = 0; i < Day.NumErrands(); i++)
	{
		U = "";
		if (Day.Errands[i] != None)
			U = Day.Errands[i].UniqueName;
		if (Mode == Mode_CrossOutErrand && i == CrossOutErrand)
			continue;
		if (Day.IsErrandComplete(i) || (G != None && U != "" && G.HasRecordedCheck(U)))
		{
			if (Sprites[ErrandNameBase + i].tex != None)
				Sprites[CrossoutBase + i].status = SS_On;
			if (Sprites[ErrandLocCrossBase + i].tex != None)
				Sprites[ErrandLocCrossBase + i].status = SS_On;
		}
	}
}

function RenderScreen(canvas Canvas)
{
	Super.RenderScreen(Canvas);
	DrawAreaTokenCounts(Canvas);
}

function string AreaKeyFromTag(name Tag)
{
	local string T;

	T = Caps(string(Tag));
	if (InStr(T, "SUBURBS-1") != -1) return "SUBURBS-1";
	if (InStr(T, "SUBURBS-2") != -1) return "SUBURBS-2";
	if (InStr(T, "SUBURBS-3") != -1) return "SUBURBS-3";
	if (InStr(T, "SUBURBS-4") != -1) return "SUBURBS-4";
	if (InStr(T, "RWSBLOCK") != -1) return "RWSBLOCK";
	if (InStr(T, "WESTMALL") != -1) return "WESTMALL";
	if (InStr(T, "EASTMALL") != -1) return "EASTMALL";
	if (InStr(T, "HIGHLANDS") != -1) return "HIGHLANDS";
	if (InStr(T, "INDUSTRY2") != -1) return "INDUSTRY2";
	if (InStr(T, "INDUSTRY") != -1) return "INDUSTRY";
	if (InStr(T, "GREENBELT1") != -1) return "GREENBELT1";
	if (InStr(T, "GREENBELT2") != -1) return "GREENBELT2";
	if (InStr(T, "NAPALM") != -1) return "NAPALM";
	if (InStr(T, "COMPOUND") != -1) return "COMPOUND";
	if (InStr(T, "LIB2") != -1) return "LIBRARY2";
	if (InStr(T, "LIB1") != -1) return "LIBRARY1";
	if (InStr(T, "POST") != -1) return "PARCELCENTER";
	if (InStr(T, "POL") != -1) return "POLICE";
	if (InStr(T, "SLAUGHTER") != -1) return "SLAUGHTERHOUSE";
	if (InStr(T, "CHURCH") != -1) return "CHURCH";
	if (InStr(T, "BREWERY") != -1) return "BREWERY";
	if (InStr(T, "ESTATES") != -1) return "ESTATES";
	if (InStr(T, "JUNKYARD") != -1) return "JUNKYARD";
	if (InStr(T, "FOREST") != -1) return "FOREST";
	return "";
}

function vector AreaMapPos(string K)
{
	local int i, n;
	local vector Acc;
	local string AK;

	Acc = vect(0,0,0);
	n = 0;
	for (i = 0; i < MapPositions.Length; i++)
	{
		AK = AreaKeyFromTag(MapPositions[i].UniqueTag);
		if (AK ~= K)
		{
			Acc = Acc + MapPositions[i].Pos;
			n++;
		}
	}
	if (n <= 0)
	{
		if (K ~= "UNDERHUB" || K ~= "TORABORA")
			return AreaMapPos("SUBURBS-3");
		return vect(0,0,0);
	}
	Acc.X = Acc.X / n;
	Acc.Y = Acc.Y / n;
	return Acc;
}

function vector AreaLabelNudge(string K)
{
	if (K ~= "SUBURBS-3") return vect(36, -20, 0);
	if (K ~= "UNDERHUB") return vect(92, -36, 0);
	if (K ~= "TORABORA") return vect(92, -8, 0);
	// Main Street / Library / Burning Library: shared X, native Y stack.
	if (K ~= "SUBURBS-1") return vect(-14, 0, 0);
	if (K ~= "LIBRARY2") return vect(20, 0, 0);
	if (K ~= "LIBRARY1") return vect(-6, 0, 0);
	// Ghetto / Police Station: shared X, extra Y so the two lines do not overlap.
	if (K ~= "SUBURBS-2") return vect(6, 3, 0);
	if (K ~= "POLICE") return vect(-6, -8, 0);
	// Suburbs East / Meat World: shared X, native Y stack.
	if (K ~= "SUBURBS-4") return vect(-7, 0, 0);
	if (K ~= "SLAUGHTERHOUSE") return vect(7, 0, 0);
	if (K ~= "FOREST") return vect(8, 24, 0);
	if (K ~= "PARCELCENTER") return vect(28, -18, 0);
	if (K ~= "GREENBELT1") return vect(28, 22, 0);
	// Napalm Factory Exterior / Napalm Factory: shared X, stacked Y.
	if (K ~= "GREENBELT2") return vect(-22, -16, 0);
	if (K ~= "NAPALM") return vect(21, 12, 0);
	if (K ~= "JUNKYARD") return vect(-38, 12, 0);
	// Clinic Area / Brewery: shared X, native Y stack.
	if (K ~= "INDUSTRY") return vect(18, 0, 0);
	if (K ~= "BREWERY") return vect(-18, 0, 0);
	if (K ~= "INDUSTRY2") return vect(42, 18, 0);
	// East Mall / West Mall: shared X, native Y stack.
	if (K ~= "EASTMALL") return vect(-20, 0, 0);
	if (K ~= "WESTMALL") return vect(21, 0, 0);
	if (K ~= "HIGHLANDS") return vect(-56, -22, 0);
	if (K ~= "CHURCH") return vect(-64, -24, 0);
	if (K ~= "COMPOUND") return vect(22, -14, 0);
	if (K ~= "RWSBLOCK") return vect(-22, 18, 0);
	if (K ~= "ESTATES") return vect(28, -16, 0);
	return vect(0,0,0);
}

function DrawAreaTokenCounts(canvas Canvas)
{
	local APGameInfo G;
	local int a;
	local string Keys[26];
	local string K;
	local vector P;
	local float MapScale, MapX, MapY, NearestFourByThree, OffsetX, sx, sy, MapW, MapH;
	local color Gold;

	if (!bEnableRender || BackgroundTex == None || MyFont == None)
		return;
	G = APGameInfo(GetGameSingle());
	if (G == None)
		return;

	Keys[0] = "SUBURBS-1";
	Keys[1] = "SUBURBS-2";
	Keys[2] = "SUBURBS-3";
	Keys[3] = "SUBURBS-4";
	Keys[4] = "RWSBLOCK";
	Keys[5] = "WESTMALL";
	Keys[6] = "EASTMALL";
	Keys[7] = "HIGHLANDS";
	Keys[8] = "INDUSTRY";
	Keys[9] = "INDUSTRY2";
	Keys[10] = "GREENBELT1";
	Keys[11] = "GREENBELT2";
	Keys[12] = "NAPALM";
	Keys[13] = "COMPOUND";
	Keys[14] = "LIBRARY1";
	Keys[15] = "LIBRARY2";
	Keys[16] = "PARCELCENTER";
	Keys[17] = "POLICE";
	Keys[18] = "SLAUGHTERHOUSE";
	Keys[19] = "CHURCH";
	Keys[20] = "BREWERY";
	Keys[21] = "ESTATES";
	Keys[22] = "JUNKYARD";
	Keys[23] = "FOREST";
	Keys[24] = "UNDERHUB";
	Keys[25] = "TORABORA";

	if (!bFancyMapFade)
	{
		MapScale = 1.0;
		MapX = 0;
		MapY = 0;
	}
	else
	{
		MapScale = 0.5 + ((FadeAlpha / 255) * 0.5);
		MapX = (Canvas.SizeX - (Canvas.SizeX * MapScale)) / 2;
		MapY = (Canvas.SizeY - (Canvas.SizeY * MapScale)) / 1.5;
	}
	NearestFourByThree = FOUR_BY_THREE_ASPECT_RATIO * (Canvas.SizeY * MapScale);
	OffsetX = (Canvas.ClipX - NearestFourByThree) / 2;
	if (!bEnableWidescreenStretch && Canvas.SizeX > NearestFourByThree)
		MapX = OffsetX;
	MapH = Canvas.SizeY * MapScale;
	if (!bEnableWidescreenStretch)
		MapW = NearestFourByThree;
	else
		MapW = Canvas.SizeX * MapScale;

	Gold.R = 255;
	Gold.G = 210;
	Gold.B = 40;
	Gold.A = 255;

	BeginMapLabels(Canvas, MapScale);
	LabCount = 0;
	for (a = 0; a < 26; a++)
	{
		K = Keys[a];
		P = AreaMapPos(K);
		if (P.X == 0 && P.Y == 0)
			continue;
		P = P + AreaLabelNudge(K);
		if (!bEnableWidescreenStretch)
		{
			sx = FOUR_BY_THREE_ASPECT_RATIO * (P.X * ScaleY * MapScale) + MapX;
			sy = (P.Y * ScaleY * MapScale) + MapY;
		}
		else
		{
			sx = (P.X * ScaleX * MapScale) + MapX;
			sy = (P.Y * ScaleY * MapScale) + MapY;
		}
		AddMapLabel(Canvas, G, K, sx, sy);
	}
	LayoutMapLabels(Canvas, MapX, MapY, MapW, MapH);
	for (a = 0; a < LabCount; a++)
	{
		if (LabFixed[a] != 0)
			continue;
		DrawTokenLabel(Canvas, LabX[a], LabY[a], LabStr[a], LabN[a], Gold,
			LabVis[a] != 0, LabOpen[a] != 0, LabKey[a]);
	}
	DrawCheckLegend(Canvas);
	EndMapLabels(Canvas);
}

function AddMapLabel(canvas Canvas, APGameInfo G, string K, float sx, float sy)
{
	local string Title, Str;
	local float XL, YL, Icon, Pad, W;
	local int Icons, N;
	local bool bOpen, bVis;

	if (LabCount >= 31 || G == None)
		return;
	Title = G.AreaMapTitle(K);
	if (Title == "")
		return;
	if (!G.IsHuntUnlocked(K))
		return;
	bOpen = G.IsMapTokenOpen(K);
	bVis = G.HasVisitedArea(K);
	N = G.CountAreaTokens(K);
	if (bOpen && N > 0)
		Str = Title$": "$string(N);
	else
		Str = Title;
	Canvas.TextSize(Str, XL, YL);
	if (YL < 1)
		YL = 8;
	Icon = YL;
	Pad = FMax(2.0, YL * 0.15);
	Icons = 0;
	if (bVis)
		Icons++;
	if (N == 0)
		Icons++;
	if (G.AreaColaDone(K))
		Icons++;
	if (G.AreaATMDone(K))
		Icons++;
	if (G.AreaVendDone(K))
		Icons++;
	W = XL;
	if (Icons > 0)
		W = W + Icons * (Icon + Pad);
	LabKey[LabCount] = K;
	LabStr[LabCount] = Str;
	LabW[LabCount] = W;
	LabH[LabCount] = YL;
	LabX[LabCount] = sx - (W * 0.5);
	LabY[LabCount] = sy;
	LabN[LabCount] = N;
	LabOpen[LabCount] = 0;
	if (bOpen)
		LabOpen[LabCount] = 1;
	LabVis[LabCount] = 0;
	if (bVis)
		LabVis[LabCount] = 1;
	LabFixed[LabCount] = 0;
	LabCount++;
}

function int LabelStackId(string K)
{
	if (K ~= "SUBURBS-1" || K ~= "LIBRARY1" || K ~= "LIBRARY2")
		return 1;
	if (K ~= "SUBURBS-2" || K ~= "POLICE")
		return 2;
	if (K ~= "SUBURBS-4" || K ~= "SLAUGHTERHOUSE")
		return 3;
	if (K ~= "GREENBELT2" || K ~= "NAPALM")
		return 4;
	if (K ~= "INDUSTRY" || K ~= "INDUSTRY2" || K ~= "BREWERY")
		return 5;
	if (K ~= "RWSBLOCK" || K ~= "WESTMALL" || K ~= "EASTMALL")
		return 6;
	return 0;
}

function int LabelStackOrder(string K)
{
	if (K ~= "SUBURBS-1") return 0;
	if (K ~= "LIBRARY1") return 1;
	if (K ~= "LIBRARY2") return 2;
	if (K ~= "RWSBLOCK") return 0;
	if (K ~= "WESTMALL") return 1;
	if (K ~= "EASTMALL") return 2;
	return 10;
}

function LayoutMapLabels(canvas Canvas, float MapX, float MapY, float MapW, float MapH)
{
	local float Gap, XL, YL, Icon, Pad, Row, LegW, LegH, x0, y0, x1, y1;
	local int Sid;

	if (LabCount <= 0)
		return;
	Gap = FMax(3.0, LabH[0] * 0.22);
	PlaceHomeSideColumn(Gap);
	for (Sid = 1; Sid <= 6; Sid++)
		PackLabelStack(Sid, Gap);
	Canvas.TextSize("AP Tokens", XL, YL);
	Icon = YL;
	Pad = FMax(2.0, YL * 0.2);
	Row = YL + FMax(1.0, YL * 0.1);
	LegW = XL + Icon + Pad + 8;
	LegH = Row * 5;
	if (LabCount < 32)
	{
		LabKey[LabCount] = "_LEGEND";
		LabStr[LabCount] = "";
		LabW[LabCount] = LegW;
		LabH[LabCount] = LegH;
		LabX[LabCount] = Canvas.ClipX * 0.98 - LegW;
		LabY[LabCount] = Canvas.ClipY * 0.78;
		LabFixed[LabCount] = 1;
		LabOpen[LabCount] = 0;
		LabVis[LabCount] = 0;
		LabN[LabCount] = 0;
		LabCount++;
	}
	x0 = MapX;
	y0 = MapY;
	x1 = MapX + MapW;
	y1 = MapY + MapH;
	if (x1 <= x0 || y1 <= y0)
	{
		x0 = 0;
		y0 = 0;
		x1 = Canvas.ClipX;
		y1 = Canvas.ClipY;
	}
	SeparateMapLabels(Gap, x0, y0, x1, y1);
}

function PlaceHomeSideColumn(float Gap)
{
	local int i, iH, iS, iT;
	local float Rx;

	iH = -1;
	iS = -1;
	iT = -1;
	for (i = 0; i < LabCount; i++)
	{
		if (LabKey[i] ~= "SUBURBS-3")
			iH = i;
		else if (LabKey[i] ~= "UNDERHUB")
			iS = i;
		else if (LabKey[i] ~= "TORABORA")
			iT = i;
	}
	if (iH < 0)
		return;
	Rx = LabX[iH] + LabW[iH] + Gap;
	if (iS >= 0)
	{
		LabX[iS] = Rx;
		LabY[iS] = LabY[iH] - LabH[iS] - Gap;
	}
	if (iT >= 0)
	{
		LabX[iT] = Rx;
		LabY[iT] = LabY[iH] + LabH[iH] + Gap;
	}
}

function PackLabelStack(int Sid, float Gap)
{
	local int Idx[8], n, i, j, t;
	local float Cx, Top, Total, Mid;

	n = 0;
	Cx = 0;
	Mid = 0;
	for (i = 0; i < LabCount; i++)
	{
		if (LabFixed[i] != 0)
			continue;
		if (LabelStackId(LabKey[i]) != Sid)
			continue;
		if (n >= 8)
			break;
		Idx[n] = i;
		Cx = Cx + LabX[i] + (LabW[i] * 0.5);
		Mid = Mid + LabY[i] + (LabH[i] * 0.5);
		n++;
	}
	if (n < 2)
		return;
	for (i = 0; i < n - 1; i++)
	{
		for (j = i + 1; j < n; j++)
		{
			if (LabelStackOrder(LabKey[Idx[j]]) < LabelStackOrder(LabKey[Idx[i]])
				|| (LabelStackOrder(LabKey[Idx[j]]) == LabelStackOrder(LabKey[Idx[i]])
				&& LabY[Idx[j]] < LabY[Idx[i]]))
			{
				t = Idx[i];
				Idx[i] = Idx[j];
				Idx[j] = t;
			}
		}
	}
	Cx = Cx / n;
	Total = 0;
	for (i = 0; i < n; i++)
		Total = Total + LabH[Idx[i]];
	Total = Total + Gap * (n - 1);
	Top = (Mid / n) - (Total * 0.5);
	for (i = 0; i < n; i++)
	{
		t = Idx[i];
		LabX[t] = Cx - (LabW[t] * 0.5);
		LabY[t] = Top;
		Top = Top + LabH[t] + Gap;
	}
}

function ClampLab(int i, float x0, float y0, float x1, float y1)
{
	if (LabFixed[i] != 0)
		return;
	if (LabX[i] < x0)
		LabX[i] = x0;
	if (LabY[i] < y0)
		LabY[i] = y0;
	if (LabX[i] + LabW[i] > x1)
		LabX[i] = x1 - LabW[i];
	if (LabY[i] + LabH[i] > y1)
		LabY[i] = y1 - LabH[i];
	if (LabX[i] < x0)
		LabX[i] = x0;
	if (LabY[i] < y0)
		LabY[i] = y0;
}

function PushPairY(int Lo, int Hi, float Dist)
{
	if (LabFixed[Lo] != 0 && LabFixed[Hi] != 0)
		return;
	if (LabFixed[Lo] != 0)
		LabY[Hi] = LabY[Hi] + Dist;
	else if (LabFixed[Hi] != 0)
		LabY[Lo] = LabY[Lo] - Dist;
	else
	{
		LabY[Lo] = LabY[Lo] - Dist * 0.5;
		LabY[Hi] = LabY[Hi] + Dist * 0.5;
	}
}

function PushPairX(int Lo, int Hi, float Dist)
{
	if (LabFixed[Lo] != 0 && LabFixed[Hi] != 0)
		return;
	if (LabFixed[Lo] != 0)
		LabX[Hi] = LabX[Hi] + Dist;
	else if (LabFixed[Hi] != 0)
		LabX[Lo] = LabX[Lo] - Dist;
	else
	{
		LabX[Lo] = LabX[Lo] - Dist * 0.5;
		LabX[Hi] = LabX[Hi] + Dist * 0.5;
	}
}

function SeparateMapLabels(float Gap, float x0, float y0, float x1, float y1)
{
	local int Pass, i, j, Lo, Hi;
	local float Ox, Oy, Ax2, Ay2, Bx2, By2;
	local bool bMoved;

	for (Pass = 0; Pass < 16; Pass++)
	{
		bMoved = false;
		for (i = 0; i < LabCount; i++)
		{
			for (j = i + 1; j < LabCount; j++)
			{
				Ax2 = LabX[i] + LabW[i];
				Ay2 = LabY[i] + LabH[i];
				Bx2 = LabX[j] + LabW[j];
				By2 = LabY[j] + LabH[j];
				Ox = FMin(Ax2, Bx2) - FMax(LabX[i], LabX[j]);
				Oy = FMin(Ay2, By2) - FMax(LabY[i], LabY[j]);
				if (Ox <= -Gap || Oy <= -Gap)
					continue;
				Ox = Ox + Gap;
				Oy = Oy + Gap;
				if (Oy <= Ox)
				{
					if (LabY[i] <= LabY[j])
					{
						Lo = i;
						Hi = j;
					}
					else
					{
						Lo = j;
						Hi = i;
					}
					PushPairY(Lo, Hi, Oy);
				}
				else
				{
					if (LabX[i] <= LabX[j])
					{
						Lo = i;
						Hi = j;
					}
					else
					{
						Lo = j;
						Hi = i;
					}
					PushPairX(Lo, Hi, Ox);
				}
				bMoved = true;
			}
		}
		for (i = 0; i < LabCount; i++)
			ClampLab(i, x0, y0, x1, y1);
		if (!bMoved)
			break;
	}
}

function BeginMapLabels(canvas Canvas, float MapScale)
{
	local float S, H;

	if (MapLabelFont == None)
		MapLabelFont = Font(DynamicLoadObject("P2Fonts.Fancy48", class'Font'));
	if (MapLabelFont != None)
		Canvas.Font = MapLabelFont;
	else if (MyFont != None)
		Canvas.Font = MyFont.GetFont(0, false, Canvas.ClipX);
	H = Canvas.SizeY;
	if (H < 1)
		H = Canvas.ClipY;
	// Fancy48 scaled to match Fancy19 at 1440p, then track map height.
	S = (19.0 / 48.0) * (H / 1440.0) * MapScale;
	if (S < 0.16)
		S = 0.16;
	if (S > 0.90)
		S = 0.90;
	Canvas.FontScaleX = S;
	Canvas.FontScaleY = S;
}

function EndMapLabels(canvas Canvas)
{
	Canvas.FontScaleX = Canvas.Default.FontScaleX;
	Canvas.FontScaleY = Canvas.Default.FontScaleY;
}

function DrawMapLabelText(canvas Canvas, float x, float y, string Str, color Col)
{
	local float Ox;

	Ox = 1;
	if (Canvas.FontScaleY >= 0.35)
		Ox = 2;
	Canvas.Style = 1;
	Canvas.SetDrawColor(20, 20, 20, 220);
	Canvas.SetPos(x + Ox, y + Ox);
	Canvas.DrawText(Str, false);
	Canvas.DrawColor = Col;
	Canvas.SetPos(x, y);
	Canvas.DrawText(Str, false);
}

function DrawTokenLabel(canvas Canvas, float sx, float sy, string Str, int N, color Gold, bool bVisited, bool bOpen, string K)
{
	local float XL, YL, x0, rx, Icon, Pad;
	local color Col;
	local APGameInfo G;

	if (Str == "")
		return;
	G = APGameInfo(GetGameSingle());
	Canvas.TextSize(Str, XL, YL);
	Icon = YL;
	Pad = FMax(2.0, YL * 0.15);
	x0 = sx;
	if (bVisited)
	{
		DrawCheckAt(Canvas, x0, sy, Icon, 90, 210, 255);
		x0 = x0 + Icon + Pad;
	}
	if (bOpen)
		Col = Gold;
	else
	{
		Col.R = 110;
		Col.G = 110;
		Col.B = 125;
		Col.A = 255;
	}
	DrawMapLabelText(Canvas, x0, sy, Str, Col);
	rx = x0 + XL + Pad;
	if (N == 0)
	{
		DrawCheckAt(Canvas, rx, sy, Icon, 255, 210, 40);
		rx = rx + Icon + Pad;
	}
	if (K != "" && G != None)
	{
		if (G.AreaColaDone(K))
		{
			DrawCheckAt(Canvas, rx, sy, Icon, 40, 90, 255);
			rx = rx + Icon + Pad;
		}
		if (G.AreaATMDone(K))
		{
			DrawCheckAt(Canvas, rx, sy, Icon, 255, 70, 200);
			rx = rx + Icon + Pad;
		}
		if (G.AreaVendDone(K))
		{
			DrawCheckAt(Canvas, rx, sy, Icon, 230, 40, 40);
		}
	}
}

function DrawCheckAt(canvas Canvas, float x, float y, float Icon, byte R, byte G, byte B)
{
	Canvas.Style = 5;
	Canvas.SetDrawColor(R, G, B, 255);
	Canvas.SetPos(x, y);
	Canvas.DrawTile(Texture'Archipelago.APMapCheck', Icon, Icon, 0, 0, 32, 32);
}

function DrawLegendRow(canvas Canvas, float RightX, float sy, float Icon, float Pad, string Label, byte R, byte G, byte B)
{
	local float XL, YL, x;
	local color Col;

	Canvas.TextSize(Label, XL, YL);
	x = RightX - XL;
	DrawCheckAt(Canvas, x - Icon - Pad, sy, Icon, R, G, B);
	Col.R = 230;
	Col.G = 230;
	Col.B = 230;
	Col.A = 255;
	DrawMapLabelText(Canvas, x, sy, Label, Col);
}

function DrawCheckLegend(canvas Canvas)
{
	local float RightX, sy, Icon, Pad, XL, YL, Row;

	if (Canvas.Font == None)
		return;
	Canvas.TextSize("AP Tokens", XL, YL);
	Icon = YL;
	Pad = FMax(2.0, YL * 0.2);
	Row = YL + FMax(1.0, YL * 0.1);
	RightX = Canvas.ClipX * 0.98;
	sy = Canvas.ClipY * 0.78;
	DrawLegendRow(Canvas, RightX, sy, Icon, Pad, "Visited", 90, 210, 255);
	sy = sy + Row;
	DrawLegendRow(Canvas, RightX, sy, Icon, Pad, "AP Tokens", 255, 210, 40);
	sy = sy + Row;
	DrawLegendRow(Canvas, RightX, sy, Icon, Pad, "Crackola", 40, 90, 255);
	sy = sy + Row;
	DrawLegendRow(Canvas, RightX, sy, Icon, Pad, "ATMs", 255, 70, 200);
	sy = sy + Row;
	DrawLegendRow(Canvas, RightX, sy, Icon, Pad, "Vending", 230, 40, 40);
}
