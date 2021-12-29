{ (C) 1998 Wesley Steiner }

{$MODE FPC}

program QuickBlackjack;

{$ifdef DEBUG}
{!define AUTOPLAY}
{!define TEST_HOUSE_LIMIT}
{!$define TEST_SPLITBJ}
{!define TEST_BOTHBJ}
{!define TEST_HOUSEBJ}
{!define TEST_HUMANBJ}
{!$define TEST_SPLIT}
{!define TEST_SPLITSPLIT}
{!define TEST_SPLITDD}
{!define TEST_DD}
{!define TEST_DDSOFT}
{!define TEST_INSURANCE_WIN}
{!define TEST_INSURANCE_LOSE}
{$endif}

{$ifdef TEST_INSURANCE_WIN}
{$define TEST_HOUSEBJ}
{$endif}

{$ifdef TEST_SPLITDD}
{$!define TEST_SPLIT}
{$endif}

{$ifdef TEST_SPLITSPLIT}
{$!define TEST_SPLIT}
{$endif}

{$ifdef TEST_BOTHBJ}
{$!define TEST_HOUSEBJ}
{$!define TEST_HUMANBJ}
{$endif}

uses
	punit,
	strings,
	windows,
	mmsystem,
	std,
	xy,
	cards,
	oapp,
	owindows,
	odlg,
	screen,
	sdkex,
	gdiex,
	cardFactory,
	quick,
	winqcktbl, {$ifdef TEST} winqcktbl_tests, {$endif}
	stdwin,
	casino,
	winTabletopChips,
	casview,
	toolbars,
	winCardFactory,
	windowsx,
	quickWin,
	winbjktbl;

{$R menus.res}
{$R dialogs.res}
{$R main.res}

type
	OInformationPanel=object(Owindow)
		constructor Init;
		procedure Create(parent:PWindow;title:PChar;x,y,w,h:integer);
		procedure redraw; virtual;
		procedure refresh; virtual;
		procedure Show; virtual;
		procedure Hide; virtual;
		function IsVisible:boolean;
		procedure SetMenuItem(a_hmenu:HMENU; a_cmd:integer); { associates this panel with an existing menu command to show and hide it }
	private
		menu:HMENU;
		menucmd:integer;
	end;

	PCheatSheet=^OCheatSheet;
	OCheatSheet=object(OInformationPanel)
		_clroff, _clron, _clralt:TColorRef; { off, on, alt colors }
		flash_column, flash_row:integer; { 1..n, 1..n current grid to flash on }
		constructor Init;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual;
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function OnMsg(aMsg:UINT; wParam:WPARAM; lParam:LPARAM):LONG; virtual;
		procedure Create(parent:PWindow; aTitle:PChar; nRows:integer);
		procedure Paint(PaintDC:hDC; var PaintInfo:TPaintStruct); virtual;
		procedure StartFlashing(nrow:integer);
		procedure StartFlash;
		procedure StopFlashing;
		procedure OnTimer(wParam:WORD);
	private
		rc:TRect;
		TimerID:word;
		rcGrid:TRect; { rectangle that contains the grid for this table }
		NumRows:integer;
		OrgColor:TColorRef;
		procedure ColorGrid(DC:HDC; row, col:integer);
	end;

	PHardDrawCard=^OHardDrawCard;
	OHardDrawCard=object(OCheatSheet)
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

	PSoftDrawCard=^OSoftDrawCard;
	OSoftDrawCard=object(OCheatSheet)
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

	PHardDoubleDownCard=^OHardDoubleDownCard;
	OHardDoubleDownCard=object(OCheatSheet)
		constructor Init;
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

	PSoftDoubleDownCard=^OSoftDoubleDownCard;
	OSoftDoubleDownCard=object(OCheatSheet)
		constructor Init;
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

	PSoftDoubleDownMultiDeckCard=^OSoftDoubleDownMultiDeckCard;
	OSoftDoubleDownMultiDeckCard=object(OCheatSheet)
		constructor Init;
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

	PSplitCard=^OSplitCard;
	OSplitCard=object(OCheatSheet)
		constructor Init;
		procedure Create(parent:PWindow);
		function GetGridState(nrow:integer; ncol:integer):integer; virtual;
		function GetRowText(nrow:integer; abuf:PChar):PChar; virtual;
		function GetFlashRow(aHand:PBJPlayerHand):integer; virtual; { return row # for hand of this value }
	end;

(*	PIEOddsPanel=^TIEOddsPanel;
	TIEOddsPanel=object(InformationPanel)
		constructor Init(parent:PWindow);
		{procedure WMEraseBkgnd; virtual wm_First+wm_EraseBkgnd;}
		procedure Paint(PaintDC:hDC; var PaintInfo:TPaintStruct); virtual;
	end;
*)
(*	PIECountPanel=^TIECountPanel;
	TIECountPanel=object(InformationPanel)
		constructor Init(parent:PWindow);
		{procedure WMEraseBkgnd; virtual wm_First+wm_EraseBkgnd;}
		procedure Paint(PaintDC:hDC; var PaintInfo:TPaintStruct); virtual;
	end;
*)

	OWagerProp=object(OChipstackProp)
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
	end;
	PWagerProp=^OWagerProp;

	OSplitProp=object(OWagerProp)
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
	end;
	PSplitProp=^OSplitProp;

	OPlayerBetManager=object
		constructor Init(first_bet,split_bet:PWagerProp);
		destructor Done; virtual;
		function DollarValue:real;
	private
		first_wager,split_wager:PWagerProp;
		is_split:boolean;
	end;

	PSeatedPlayer=^OSeatedPlayer;

	InsuranceBetPropP=^InsuranceBetProp;
	InsuranceBetProp=object(OChipstackProp)
		constructor Init(aSeat:PSeatedPlayer);
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
	private
		_owner:^OSeatedPlayer;
	end;

	OPlayerChipsProp=object(OChipbundleProp)
		AmountBorrowed:real;
		constructor Init;
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
		procedure Borrow(const aAmount:real);
		procedure OnStackClicked(aChipType:TypeOfChip); virtual;
		procedure TransferToPile(target:OChipstackProp_ptr;amount:real);
		procedure TransferChipsToPile(target:OChipstackProp_ptr;aChipType:TypeOfChip;n:integer);
	end;

	PHandPropBase=^OHandPropBase;
	
	OHandNote=object(OHangingNote)
		constructor Construct(aHand:PHandPropBase);
		procedure Create(parent:PWindow);
	private
		my_hand:PHandPropBase;
	end;

	OHandPropBase=object(OCardpileProp)
		value_wart:OHangingNote;
		myHand:PBlackJackHand;
		constructor Init(aPile:PBlackJackHand);
		function IsPair:boolean;
		function IsBJ:boolean;
		function IsBust:boolean;
		function IsHardHand:boolean;
		function Value:word;
		procedure DisplayResult(const aMsg:PChar);
		procedure Hit; virtual;
		procedure OnTopcardFlipped; virtual;
		procedure ShowValue;
	private
		my_note_bar:OHandNote;
	end;

	PDealerHandProp=^ODealerHandProp;
	ODealerHandProp=object(OHandPropBase)
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
		function AddFacedown:boolean; virtual;
		function GetCardX(ith:integer):integer; virtual;
		function GetCardY(ith:integer):integer; virtual;
		procedure Hit; virtual;
	end;

	PPlayerHandProp=^OPlayerHandProp;
	OPlayerHandProp=object(OHandPropBase)
		chips:OChipstackProp_ptr;
		constructor Init(aPos:integer; aPile:PBlackJackHand; aBet:OChipstackProp_ptr);
		destructor Done; virtual;
		function Action:TAction;
		function AddFacedown:boolean; virtual;
		function AllowSplitting:boolean;
		function CanDoubleDown:boolean;
		function GetCardX(ith:integer):integer; virtual;
		function GetCardY(ith:integer):integer; virtual;
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
		function SeatNum:integer;
		procedure BJ;
		procedure Busted;
		procedure Hit; virtual;
		procedure Tally; { tally up this hand against the house hand }
	private
		_ipos:integer;
	end;

	PDealerShoeProp=^ODealerShoeProp;
	ODealerShoeProp=object(OCardpileProp)
		function GetCardX(ith:integer):integer; virtual;
		function GetCardY(ith:integer):integer; virtual;
		function GetAnchorPoint(table_width,table_height:word):xypair; virtual;
		procedure DealTo(TargetPile:OCardpileProp_ptr); virtual;
	end;

	OSeatedPlayer=object
		SeatNum:integer;
		constructor Init(const aPos:integer);
		destructor Done; virtual;
		procedure ReDraw(DC:HDC);
		function CheckChips(aAmount:real):integer;
		procedure TakeInsurance;
		function IsInsured:boolean;
		procedure WinInsuranceBet; { pay off the insurance bet to the player }
		procedure LoseInsuranceBet; { player loses the insurance bet }
		procedure Cleanup; virtual;
	private
		insurance_wager:InsuranceBetPropP;
	end;

	PMainView=^OMainView;
	OMainView=object(OTabletop)
		Seat:array[1..BJ_MAXSEATS] of PSeatedPlayer;
		player_chips:OPlayerChipsProp;
		PlrHand:array[1..BJ_MAXSEATS] of PPlayerHandProp;
		SplHand:array[1..BJ_MAXSEATS] of PPlayerHandProp;
		destructor Done; virtual;
		function Create(frame:HWND;w,h:number):HWND; virtual;
		function DealerUpCard:TCard;
		function HandsRemaining:word; { # of hands remaing at the table after each person has played }
		function IsSeated(pn:integer):boolean;
		function OnDoubleTapped(x,y:integer):boolean; virtual;
		function OnSize(resizeType:uint; new_width,new_height:integer):LONG; virtual;
		function PlayerBet(pn:integer; n:real):boolean;
		procedure AddHumanPlayer(aSeatNum:integer; aPlayer:PBlackJackPlayer);
		procedure AssignDealer;
		procedure Cleanup; virtual;
		procedure CleanupPlayer(pn:integer);
		procedure ChangeNumDecks(n:word);
		procedure Deal;
		procedure DoubleDown(pn:integer);
		procedure Initialize;
		procedure Shuffle;
		procedure Stand(pn:integer);
		{procedure Evaluate(pn:integer);}
		{procedure DisplayResult(const aMsg:PChar);}
		procedure RenderTabletopSurface(aDC:HDC; a_adjustX, a_adjustY:integer); virtual;
		procedure Split(pn:integer);
	private
		shoe:PDealerShoeProp;
		wagers:array[1..BJ_MAXSEATS] of OPlayerBetManager;
		dealer_hand:PDealerHandProp;
		bj_table:PBlackJackTable; { access this via "the_bj_table" global }
		function WagerPromptText:pchar;
		procedure DoHit;
		procedure PostManualWager;
		procedure PreManualWager;
	end;

const
	fastdisplaymode:boolean=FALSE;

var
	the_active_hand:PPlayerHandProp;
	the_bj_table:PBlackJackTable;
	the_hard_draw_card:PHardDrawCard;
	the_soft_draw_card:PSoftDrawCard;
	the_hard_dbldown_card:PHardDoubleDownCard;
	the_soft_dbldown_card:PSoftDoubleDownCard;
	the_soft_dbldown_multi_deck_card:PSoftDoubleDownMultiDeckCard;
	the_split_card:PSplitCard;
	TheBJView:PMainView;
	the_min_bet_button:PBarButton;
	the_x2_bet_button:PBarButton;
	the_x3_bet_button:PBarButton;
	the_x4_bet_button:PBarButton;
	the_max_bet_button:PBarButton;
	the_active_card:PCheatSheet;
	the_ok_button:PBarButton;
	the_cancel_button:PBarButton;

const
	CM_DEAL				= CM_NEXT+0;
	CM_HIT				= 302;
	CM_STAND			= 303;
	CM_MODE				= CM_NEXT+7; { Game Mode }
	CM_BETMIN			= 311; { Play|Minimum Bet }
	CM_BET2TP			= 312;
	CM_BET3TP			= 313;
	CM_BET4TP			= 314;
	CM_BETMAX			= 319; { Play|Maximum Bet }
	CM_DBLDOWN				= 320;
	CM_SPLIT				= 321;
	CM_PLACEBET=CM_NEXT+110;
	CM_RULES=CM_NEXT+120;
	CM_VIEWDRAW			= CM_NEXT+130;
	CM_VIEWDD			= CM_NEXT+140;
	CM_VIEWSPLIT		= CM_NEXT+150;
	CM_CANCELBET 			= CM_NEXT+160;
	CM_CARDCOUNT		= CM_NEXT+170;
	CM_FASTDISPLAY		= CM_NEXT+210;

	WM_DEAL		 		= wm_User+0; { deal a new hand }
	WM_PLAY		 		= wm_User+1; { play the hand }
	WM_HIT		 		= wm_User+2; { hit/draw for a player }
	WM_STAND		 		= wm_User+3; { player stands }
	WM_HPLAY		 		= wm_User+4; { house plays out it's hand }
	WM_HHIT		 		= wm_User+5; { house hit }
	WM_BET		 		= wm_User+6; { place your bets }
	WM_BETMIN	 		= wm_User+7; { place your minimum bet }
	WM_BETMAX	 		= wm_User+8; { place your maximum bet }
	WM_DBLDOWN	 			= wm_User+9; { double down }
	WM_SPLIT	 			= wm_User+10; { split }
	WM_PLACEBET=wm_User+11;
	WM_BET2TP	 		= wm_User+13;
	WM_BET3TP	 		= wm_User+14;
	WM_BET4TP	 		= wm_User+15;
	WM_TALLY		 		= wm_User+16; { tally up all the players hands }
	WM_CONTINUE	 		= WM_USER+17;
	WM_BETRCM	 		= wm_User+18;
	WM_DOLLARS	 		= wm_User+21;
	WM_CANCELBET=wm_User+22;

type
	FrameWindowP=^FrameWindow;
	FrameWindow=object(quickWin.FrameWindow)
		procedure CMDEAL;
		procedure CMHIT;
		procedure CMSTAND;
		procedure WMBET(wParam:WORD);
		procedure WMDEAL;
		procedure WMPLAY(wParam:WORD);
		procedure OnHit;
		procedure OnDoubleDown;
		procedure OnSplit;
		procedure OnPlaceBet;
		procedure OnCancelBet;
		procedure WMSTAND;
		procedure WMHPLAY;
		procedure WM_HHIT_PROC;
		procedure OnContinue;
		procedure WMBETMIN;
		procedure WMBETMAX;
		procedure WMBET2TP;
		procedure WMBET3TP;
		procedure WMBET4TP;
		procedure WMBETRCM;
		procedure WMTALLY(wParam:WORD);
		procedure OnStart;
		procedure OnTimer(wParam:WORD);
		procedure WMDOLLARS;
		function OnCmd(aCmdId:UINT):LONG; virtual;
		function OnMsg(aMsg:UINT;wParam:WPARAM;lParam:LPARAM):LONG; virtual;
	end;

	PMainFrame=^OMainFrame;
	OMainFrame=object(quickWin.Frame)
		constructor Init(pwo:ApplicationP);
		destructor Done; virtual;
		function CanClose:boolean; virtual;
		procedure BeforeHumanBets;
		procedure AfterHumanBets;
		procedure BeforeHumanPlays;
		procedure AfterHumanPlays;
		procedure EndHumanPlay;
		procedure CloseAllTables;
	end;
	
	OMainApp=object(quickWin.Application)
		constructor Init;
		destructor Done; virtual;
		function DonatePageUrl:pchar; virtual;
		function HomePageUrl:pchar; virtual;
		function WriteINI(aFileName:PChar):boolean; virtual;
		procedure InitMainWindow; virtual;
		procedure OnNew; virtual;
	private
		function Window:PMainFrame;
	end;

//const
//	ViewOdds:boolean=False; { user wants to view the odds table }
//	ViewSim:boolean=False; { user is viewing the simulation }

var
	the_main_app:OMainApp;
	hwChipWaggle:THandle;
	hwChipClank:array[1..4] of THandle;

function GetScreenWd:integer;
begin
	GetScreenWd:=Screen.Properties.Width;
end;

function GetScreenHt:integer;
begin
	GetScreenHt:=Screen.Properties.Height;
end;

function TheMainFrame:PMainFrame;
begin
	TheMainFrame:=PMainFrame(the_main_app.Frame);
end;

function DotColor:TColorRef;
begin
	DotColor:= RGB_WHITE;
end;

function PotValue:real;
begin
	with TheBJView^ do PotValue:=wagers[SUCKER_SEAT].DollarValue;
end;

function GridSize:integer;
{ size, in pixels,  of each square in the table grids }
begin
	GridSize:= SysFontHt-1; { pixels }
end;

function OMainView.Create(frame:HWND;w,h:number):HWND;
var
	i:integer;
	Args:array[0..0] of word;
	rname:array[0..30] of Char;
begin
	Create:=inherited Create(frame,w,h);
	TheBJView:=@Self;
	shoe:=nil;
	dealer_hand:=nil;
	for i:=1 to 4 do begin
		Args[0]:=i;
		rname:='Chip_Clank_'+NumberToString(Args[0]);
		hwChipClank[i]:=FindResource(hInstance,rName,'WAVE');
		hwChipClank[i]:=LoadResource(hInstance,hwChipClank[i]);
	end;
end;

procedure OMainView.Initialize;
var
	i:integer;
begin
	bj_table:=New(PBlackJackTable, Init(BJ_MAXSEATS, @self));
	the_bj_table:=bj_table;
	with bj_table^ do begin
		for i:= 1 to BJ_MAXSEATS do begin
			Seat[i]:= nil;
			PlrHand[i]:= nil;
			SplHand[i]:= nil;
		End;
	end;
end;

destructor OMainView.Done;
var
	i:integer;
begin
	{ Save the current game. }
(*		the_main_app.save_data_int('Player', 'Purse',
		Trunc(player_chips.TheBundle^.DollarValue));
	the_main_app.save_data_int('Player', 'Change',
		Trunc(Frac(player_chips.TheBundle^.DollarValue)*100.0));
	the_main_app.save_data_int('Player', 'Loaned',
		Trunc(player_chips.AmountBorrowed));
*)
	hotList.delete(@player_chips);
	player_chips.Done;
	for i:= 1 to BJ_MAXSEATS do begin
		wagers[i].Done;
		if (PlrHand[i] <> nil) then begin
			hotList.delete(plrHand[i]);
			Dispose(PlrHand[i], Done);
		end;
		if (SplHand[i] <> nil) then begin
			hotList.delete(SplHand[i]);
			Dispose(SplHand[i], Done);
		end;
		if (Seat[i] <> nil) then Dispose(Seat[i], Done);
	end;
	if (dealer_hand <> nil) then begin
		{hotList.delete(dealer_hand);} {? 981107 causes a runtime error 213 }
		Dispose(dealer_hand, Destruct);
	end;
	if (shoe <> nil) then begin
		hotList.delete(shoe);
		Dispose(shoe, Destruct);
	end;
	Dispose(bj_table, Done);
end;

procedure OMainView.AssignDealer;
begin
	bj_table^.AssignDealer(nil{New(PBlackJackDealer)});
	shoe:=New(PDealerShoeProp, Construct(52*10));
	shoe^.ThePile:=bj_table^.Deck; // this is a hack to keep the TDealerShoeProp in synch with the TCasinoDeck !!!
	shoe^.ThePile^.Shuffle;
	AddProp(shoe);
	dealer_hand:=New(PDealerHandProp,Init(bj_table^.HouseHand));
	AddProp(dealer_hand);
end;

var
	HouseYPos:integer;

function ODealerHandProp.GetAnchorPoint(table_width,table_height:word):xypair;
begin
	GetAnchorPoint:=MakeXYPair(Center(CurrentWidth*2, 0, table_width-1), HouseYPos);
end;

const
	DELTA_ANGLE=0.3;
	START_ANGLE=PI+DELTA_ANGLE;
	END_ANGLE=2.0*PI-DELTA_ANGLE;
	BoxAngle=(END_ANGLE-START_ANGLE)/(BJ_MAXSEATS*2-1); { radians spanned by a bet box }

{ radius of the arc, in pixels, from the center point to the inside edge of the insurance bar }
function Radius:real;
begin
	Radius:=Max(XWND(TheBJView^.Handle).ClientWidth, XWND(TheBJView^.Handle).ClientHeight)/1.8;
end;

function GetRadialCenterX(table_width:integer):integer;
begin
	GetRadialCenterX:=(table_width div 2);
end;

function GetRadialCenterY(table_height:integer):integer;
begin
	GetRadialCenterY:=(table_height div 2)-Round(Radius);
end;

function InsBarWd:real;
{ width, in pixels, of the insurance bar }
begin
	InsBarWd:= Radius/7.0;
end;

function OPlayerHandProp.GetAnchorPoint(table_width,table_height:word):xypair;
var
	a:real;
	function AdjustXFor(ith:integer):integer;
	{ hands on the end of the circle are placed farther out }
	begin
		AdjustXFor:= -(ith-(BJ_MAXSEATS div 2+1))*Round(Radius/20);
	end;
	function AdjustYFor(ith:integer):integer;
	{ hands on the end of the circle are placed higher up on the table }
	begin
		AdjustYFor:= abs(ith-(BJ_MAXSEATS div 2+1))*Round(Radius/14);
	end;
begin
	a:=END_ANGLE-((BoxAngle*2)*(_ipos-1)+BoxAngle/2);
	GetAnchorPoint:=MakeXYPair(
		GetRadialCenterX(table_width)+Round(cos(a)*Radius)-(CurrentWidth div 2)+AdjustXFor(_ipos),
		GetRadialCenterY(table_height)-Round(sin(a)*Radius)-(CurrentHeight)-AdjustYFor(_ipos));
end;

// distance from insurance bar to bet circles
function Box_Space:real;
begin
	Box_Space:=Radius/3.0;
end;

function OMainView.OnSize(resizeType:uint; new_width,new_height:integer):LONG;
var
	i:integer;
	a:real;
begin //writeln('OMainView.OnSize(resizeType:uint,',new_width,',',new_height,')');
	if (resizeType=SIZE_MINIMIZED) or ((new_width=0) or (new_height=0)) then begin
		OnSize:= 1;
		Exit;
	end;
	a:=END_ANGLE-BoxAngle/2;
	for i:=1 to BJ_MAXSEATS do begin
		CtrPt[i].X:=GetRadialCenterX(new_width)+Round(cos(a)*(Radius+BOX_SPACE));
		CtrPt[i].Y:=GetRadialCenterY(new_height)-Round(sin(a)*(Radius+BOX_SPACE));
		a:= a-BoxAngle*2;
	end;
	OnSize:=inherited OnSize(resizeType,new_width,new_height);
	with bj_table^ do for i:= 1 to BJ_MAXSEATS do begin
		if (Player[i]<>nil) then begin
			PlrHand[i]^.value_wart.Hide;
			PlrHand[i]^.Hide;
			if (SplHand[i]<>nil) then PlrHand[i]^.SetPosition(PlrHand[i]^.Anchor.X-CurrentWidth,PlrHand[i]^.Anchor.Y);
			PlrHand[i]^.Show;
		end;
		if (SplHand[i]<>nil) then begin
			SplHand[i]^.value_wart.Hide;
			SplHand[i]^.Hide;
			SplHand[i]^.SetPosition(PlrHand[i]^.Anchor.X+CurrentWidth*2,PlrHand[i]^.Anchor.Y);
			SplHand[i]^.Show;
		end;
		if ((the_active_hand<>NIL) and (the_active_hand^.Size>0)) then the_active_hand^.ShowValue;
	end;
end;

function ODealerHandProp.GetCardX(ith:integer):integer;
begin
	GetCardX:= (ith-1)*OptXSpace
end;

function ODealerHandProp.GetCardY(ith:integer):integer;
begin
	GetCardY:= 0;
end;

function ODealerHandProp.AddFacedown:boolean;
begin
	AddFacedown:= IsEmpty;
end;

function OPlayerHandProp.AddFacedown:boolean;
begin
	AddFacedown:= FALSE;
end;

procedure OMainView.RenderTabletopSurface(aDC:HDC; a_adjustX, a_adjustY:integer);
var
	i:integer;
	ThePen, OldPen:HPEN;
	ptl1, ptl2, ptr1, ptr2:TPoint;
	a, da:real;
	aClientRect:TRect;
	r:real;
	OldBrush:HBRUSH;

	function RadialCenterX:integer;
	begin
		RadialCenterX:=GetRadialCenterX(XWND(self.Handle).ClientWidth);
	end;

	function RadialCenterY:integer;
	begin
		RadialCenterY:=GetRadialCenterY(XWND(self.Handle).ClientHeight);
	end;

	procedure ArcText(DC:HDC; FontHt:integer; IfItalic:integer; aColor:TColorRef; aString:PChar; aRadius:real);
	var
		a, b:real;
		i:integer;
		OldFont, Font:HFONT;
		aFont:TLogFont;
	begin
		with aFont do begin
			lfHeight:= FontHt;
			lfWidth:=0;
			lfEscapement:=0;
			lfOrientation:=0;
			lfWeight:=FW_BOLD;
			lfItalic:=IfItalic;
			lfUnderline:=0;
			lfStrikeout:=0;
			lfCharset:=ANSI_CHARSET;
			lfOutPrecision:=OUT_STROKE_PRECIS;
			lfClipPrecision:=0;
			//lfQuality:=5{CLEARTYPE_QUALITY}; 
			lfQuality:=ANTIALIASED_QUALITY;
			lfPitchAndFamily:=VARIABLE_PITCH or FF_ROMAN;
			strcopy(lfFaceName, 'New Times Roman');
		end;
		SetBkMode(DC, TRANSPARENT);
		SetTextColor(DC, aColor);
		SetTextAlign(DC, TA_CENTER+TA_BASELINE);
		b:=0.7*FontHt/aRadius;
		a:=START_ANGLE+(END_ANGLE-START_ANGLE-(b*strlen(aString)))/2+b/2;
		for i:= 1 to strlen(aString) do begin
			aFont.lfEscapement:=-Round(2700.0-RadToDeg(a)*10.0);
			Font:=CreateFontIndirect(aFont);
			OldFont:=SelectObject(DC, Font);
			TextOut(DC,
				a_adjustX+RadialCenterX+Round(cos(a)*aRadius){-(LOWORD(GetTextExtent(DC, @aString[i], 1)) div 2)},
				a_adjustY+RadialCenterY-Round(sin(a)*aRadius){-(HIWORD(GetTextExtent(DC, @aString[i], 1)) div 2)},
				@aString[i-1],1);
			a:=a+b;
			SelectObject(DC,OldFont);
			DeleteObject(Font);
		end;
	end;

begin //writeln('OMainView.RenderTabletopSurface(aDC,', a_adjustX, ',', a_adjustY, ')');
	inherited RenderTabletopSurface(aDC, a_adjustX, a_adjustY);
	GetClientRect(aClientRect);
	HouseYPos:= aClientRect.bottom div 20; { need this value later on }
	ThePen:= CreatePen(PS_SOLID, Min(aClientRect.right, aClientRect.bottom) div 100, RGB(195, 195, 195));
	OldPen:= SelectObject(aDC, ThePen);
	ptl2.X:= a_adjustX+RadialCenterX+Round(cos(START_ANGLE)*Radius);
	ptl2.Y:= a_adjustY+RadialCenterY-Round(sin(START_ANGLE)*Radius);
	ptr2.X:= a_adjustX+RadialCenterX+Round(cos(END_ANGLE)*Radius);
	ptr2.Y:= a_adjustY+RadialCenterY-Round(sin(END_ANGLE)*Radius);

	// the insurance bar arc
	Arc(aDC,
		a_adjustX+RadialCenterX-Round(Radius), a_adjustY+RadialCenterY-Round(Radius),
		a_adjustX+RadialCenterX+Round(Radius), a_adjustY+RadialCenterY+Round(Radius),
		ptl2.X, ptl2.Y, ptr2.X, ptr2.Y);
	r:= Radius+InsBarWd;
	ptl1.X:= a_adjustX+RadialCenterX+Round(cos(START_ANGLE)*r);
	ptl1.Y:= a_adjustY+RadialCenterY-Round(sin(START_ANGLE)*r);
	ptr1.X:= a_adjustX+RadialCenterX+Round(cos(END_ANGLE)*r);
	ptr1.Y:= a_adjustY+RadialCenterY-Round(sin(END_ANGLE)*r);
	Arc(aDC,
		a_adjustX+RadialCenterX-Round(r), a_adjustY+RadialCenterY-Round(r),
		a_adjustX+RadialCenterX+Round(r), a_adjustY+RadialCenterY+Round(r),
		ptl1.X, ptl1.Y, ptr1.X, ptr1.Y);
	MoveToEx(aDC, ptl1.X, ptl1.Y,LPPOINT(0)); LineTo(aDC, ptl2.X, ptl2.Y);
	MoveToEx(aDC, ptr1.X, ptr1.Y,LPPOINT(0)); LineTo(aDC, ptr2.X, ptr2.Y);

	// the bet circles
	OldBrush:= SelectObject(aDC, GetStockObject(NULL_BRUSH));
	a:= END_ANGLE-BoxAngle/2;
	for i:= 1 to BJ_MAXSEATS do begin
		CtrPt[i].X:= RadialCenterX+Round(cos(a)*(Radius+BOX_SPACE));
		CtrPt[i].Y:= RadialCenterY-Round(sin(a)*(Radius+BOX_SPACE));
		Ellipse(aDC,
			a_adjustX+CtrPt[i].X-BET_CIRCLE_RADIUS, a_adjustY+CtrPt[i].Y-BET_CIRCLE_RADIUS,
			a_adjustX+CtrPt[i].X+BET_CIRCLE_RADIUS, a_adjustY+CtrPt[i].Y+BET_CIRCLE_RADIUS);
		a:= a-BoxAngle*2;
	end;
	SelectObject(aDC, OldBrush);

	SelectObject(aDC, OldPen);
	DeleteObject(ThePen);

	{ the text }
	if (not fastdisplaymode) then begin
		ArcText(aDC, Round(Radius/11), 0, RGB_WHITE, 'BLACKJACK PAYS 3 TO 2', Radius-Radius/6);
		ArcText(aDC, Round(Radius/15), 1, Red, 'Dealer must draw to 16 and stand on 17', Radius-Radius/16);
		ArcText(aDC, Round(Radius/9), 0, Yellow, 'INSURANCE PAYS 2 TO 1', Radius+3*InsBarWd/4);
	end;
end;

function MidSeat:integer;
begin
	MidSeat:= (BJ_MAXSEATS div 2+1);
end;

function CARDXSPACE:integer;
begin
	CardXSpace:= OptXSpace+1;
end;

function OPlayerHandProp.GetCardX(ith:integer):integer;
begin
	if (_ipos < MidSeat) then
		GetCardX:= (ith-1) *-CARDXSPACE
	else
		GetCardX:= (ith-1)*CARDXSPACE;
end;

function OPlayerHandProp.GetCardY(ith:integer):integer;
begin
	GetCardY:= (ith-1)*-5;
end;

function ODealerShoeProp.GetCardX(ith:integer):integer;
begin
	GetCardX:=-3*((ith-1) div (52 div 4));
end;

function ODealerShoeProp.GetCardY(ith:integer):integer;
begin
	GetCardY:=0;
end;

function ODealerShoeProp.GetAnchorPoint(table_width,table_height:word):xypair;
begin
	GetAnchorPoint:=MakeXYPair(Round(0.75*table_width), table_height div 20);
end;

procedure OHandPropBase.Hit;
begin
	TheBJView^.shoe^.DealTo(@self);
	ShowValue;
end;

procedure OHandPropBase.ShowValue;
var
	ss:array[0..10] of Char;
	aSpanRect:TRect;
begin
	with self.value_wart do begin
		if IsWindowVisible(Handle) then Hide;
		GetSpanRect(aSpanRect);
		MoveWindow(Handle,aSpanRect.right-9,aSpanRect.top-Height+9,Width,Height,FALSE);
		itoz(Value,ss);
		StrCopy(TheText,ss);
		Show;
	end;
end;

procedure OPlayerHandProp.Hit;
begin
	inherited Hit;
	FlipTopcard;
end;

procedure ODealerHandProp.Hit;
begin
	inherited Hit;
	FlipTopcard;
end;

function OMainView.PlayerBet(pn:integer; n:real):boolean;
{ execute a bet of "n" dollars }
begin
	if (pn=SUCKER_SEAT) then case Seat[pn]^.CheckChips(n) of
		1:begin
			player_chips.TransferToPile(wagers[pn].first_wager,n);
			ChipClankSound;
			PlayerBet:=True;
		end;
		-1:begin
			PostMessage(WM_COMMAND,CM_FILENEW,0);
			PlayerBet:=False;
		end;
		0:
			PlayerBet:=False;
	end;
end;

procedure OMainView.Deal;
var
	i, pn:integer;
begin
	bj_table^.PreDeal;
//	PlrHand[SUCKER_SEAT]^.SetPosition(MakeXYPair(Width, Height)); { move it back to its default position }
	for i:= 1 to 2 do begin
		shoe^.DealTo(PlrHand[SUCKER_SEAT]);
		PlrHand[SUCKER_SEAT]^.FlipTopcard;
		shoe^.DealTo(dealer_hand);
		if i=2 then dealer_hand^.FlipTopcard;
	end;

	{$ifdef TEST_HOUSEBJ}
	dealer_hand^.Discard;
	dealer_hand^.AddCard(MakeCard(TJACK, TSPADES));
	dealer_hand^.AddCard(MakeCard(TACE, THEARTS));
	dealer_hand^.Refresh;
	dealer_hand^.FlipTopcard;
	{$endif}

	{$ifdef TEST_INSURANCE_LOSE}
	dealer_hand^.Discard;
	dealer_hand^.AddCard(MakeCard(TNine, TSPADES));
	dealer_hand^.AddCard(MakeCard(TACE, THEARTS));
	dealer_hand^.Refresh;
	dealer_hand^.FlipTopcard;
	{$endif}

	{$ifdef TEST_HUMANBJ}
	with PlrHand[SUCKER_SEAT]^ do begin
		Discard;
		AddCard(MakeCard(TJACK, TSPADES));
		AddCard(MakeCard(TACE, THEARTS));
		Refresh;
	end;
	{$endif}

	{$ifdef TEST_DD}
	with PlrHand[SUCKER_SEAT]^ do begin
		Discard;
		AddCard(MakeCard(PFIVE, TSPADES));
		AddCard(MakeCard(PSIX, THEARTS));
		Refresh;
	end;
	{$endif}

	{$ifdef TEST_DDSOFT}
	with PlrHand[SUCKER_SEAT]^ do begin
		Discard;
		AddCard(MakeCard(TACE, TSPADES));
		AddCard(MakeCard(PSIX, THEARTS));
		Refresh;
	end;
	{$endif}

	{$ifdef TEST_SPLIT}
	with PlrHand[SUCKER_SEAT]^ do begin
		Discard;
		AddCard(MakeCard(TSix, TSPADES) or FACEUP_BIT);
		AddCard(MakeCard(TSix, THEARTS) or FACEUP_BIT);
		{AddCard(MakeCard(ACE, SPADES));
		AddCard(MakeCard(ACE, HEARTS));}
		Refresh;
	end;
	{$endif}

	PlrHand[SUCKER_SEAT]^.ShowValue;
	bj_table^.PostDeal;
end;

procedure OMainView.Stand(pn:integer);
begin
	bj_table^.Player[pn]^.Hand^.Stand;
end;

procedure OHardDrawCard.Create(parent:PWindow);
var
	buf:array[0..99] of Char;
begin
	LoadString(hInstance, IDS_DRAW_TABLE_HARD, buf, 100);
	inherited Create(parent, buf, 4);
end;

function OCheatSheet.GetGridState(nrow:integer; ncol:integer):integer;
begin
	GetGridState:= 0;
end;

function OCheatSheet.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	GetFlashRow:= 1;
end;

function OCheatSheet.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	StrCopy(aBuf, '');
	GetRowText:= aBuf;
end;

function OHardDrawCard.GetGridState(nrow:integer; ncol:integer):integer;
begin
	case nrow of
		1:GetGridState:= (BJTblDrawHard[20, nCol+1]);
		2:GetGridState:= (BJTblDrawHard[16, nCol+1]);
		3:GetGridState:= (BJTblDrawHard[12, nCol+1]);
		4:GetGridState:= (BJTblDrawHard[11, nCol+1]);
	end;
end;

function OHardDrawCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	case aHand^.Value of
		4..11:GetFlashRow:= 4;
		12:GetFlashRow:= 3;
		13..16:GetFlashRow:= 2;
		17..21:GetFlashRow:= 1;
	end;
end;

function OSoftDrawCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	case aHand^.Value of
		13..17:GetFlashRow:= 3;
		18:GetFlashRow:= 2;
		19..21:GetFlashRow:= 1;
	end;
end;

function OSoftDoubleDownCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	case aHand^.Value of
		20:GetFlashRow:= 1;
		19:GetFlashRow:= 2;
		18:GetFlashRow:= 3;
		17:GetFlashRow:= 4;
		13..16:GetFlashRow:= 5;
	end;
end;

function OSoftDoubleDownMultiDeckCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	case aHand^.Value of
		19..20:GetFlashRow:= 1;
		17..18:GetFlashRow:= 2;
		15..16:GetFlashRow:= 3;
		13..14:GetFlashRow:= 4;
	end;
end;

function OHardDoubleDownCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	GetFlashRow:= 5-integer(aHand^.Value)+8;
end;

function OHardDoubleDownCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	case nrow of
		1:StrCopy(abuf, '12');
		2:StrCopy(abuf, '11');
		3:StrCopy(abuf, '10');
		4:StrCopy(abuf, '9');
		5:StrCopy(abuf, '8');
	end;
	GetRowText:= aBuf;
end;

function OSoftDoubleDownCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	case nrow of
		1:StrCopy(abuf, '20');
		2:StrCopy(abuf, '19');
		3:StrCopy(abuf, '18');
		4:StrCopy(abuf, '17');
		5:StrCopy(abuf, '13-16');
	end;
	GetRowText:= aBuf;
end;

function OSoftDoubleDownMultiDeckCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	case nrow of
		1:StrCopy(abuf, '19-20');
		2:StrCopy(abuf, '17-18');
		3:StrCopy(abuf, '15-16');
		4:StrCopy(abuf, '13-14');
	end;
	GetRowText:= aBuf;
end;

function OHardDrawCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	case nrow of
		1:StrCopy(abuf, '17-21');
		2:StrCopy(abuf, '13-16');
		3:StrCopy(abuf, '12');
		4:StrCopy(abuf, '4-11');
	end;
	GetRowText:= aBuf;
end;

function OSoftDrawCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
begin
	case nrow of
		1:StrCopy(abuf, '19-21');
		2:StrCopy(abuf, '18');
		3:StrCopy(abuf, '13-17');
	end;
	GetRowText:= aBuf;
end;

(*
constructor TIEOddsPanel.Init(parent:PWindow);

	begin
		Inherited Init(parent, 'Odds Dealer Holds...',
			GetScreenWd div 25, GetScreenHt div 10,
			(1+4+5+1)*GridSize, GridSize*8);
	end;

procedure TIEOddsPanel.Paint(PaintDC:hDC; var PaintInfo:TPaintStruct);

	var
		buf:array[0..255] of Char;
		OldPen, BluePen:HPEN;
		rc, rcGrid:TRect; { top & left edge of the table }
		OldFont, TheFont:HFONT;
		i, j:integer;
		OldBrush, DoItBrush, DontBrush:HBRUSH;
		pcnt:real;

	begin
		{ the grid }

		rcGrid.top:= GridSize;
		rcGrid.bottom:= rcGrid.top+GridSize*6;
		rcGrid.left:= GridSize*5;
		rcGrid.right:= rcGrid.left+5*GridSize;

		OldBrush:= SelectObject(PaintDC, GetStockObject(LTGRAY_BRUSH));
		Rectangle(PaintDC, rcGrid.left, rcGrid.top, rcGrid.right, rcGrid.bottom);
		SelectObject(PaintDC, OldBrush);

		SetBkMode(PaintDC, TRANSPARENT);

		TheFont:= CreateFont(
			(GridSize-1), 0,
			0,
			0,
			FW_NORMAL,
			0, 0, 0,
			ANSI_CHARSET,
			OUT_DEFAULT_PRECIS,
			CLIP_DEFAULT_PRECIS,
			PROOF_QUALITY,
			VARIABLE_PITCH or FF_SWISS,
			'Arial'
			);
		OldFont:= SelectObject(PaintDC, TheFont);
		DoItBrush:= CreateSolidBrush(Red);
		for i:= 21 downto 16 do begin
			SetTextAlign(PaintDC, TA_CENTER or TA_TOP);
			SetTextColor(PaintDC, Blue);
			if i=16 then begin
				pcnt:= 0.0;
				for j:= i downto 4 do pcnt:= pcnt+the_bj_table^.OddsDealerHolds(j)*100.0;
				StrCopy(buf, '...16');
			end
			else begin
				pcnt:= TheBJView^.bj_table^.OddsDealerHolds(i)*100.0;
				I2S(i,buf);
			end;
			TextOut(PaintDC, GridSize+GridSize div 2, GridSize*(21-i+1)+2, buf, strlen(buf));
			SetBkMode(PaintDC, OPAQUE);

			if
				(TheBJView^.dealer_hand^.Size= 2)
				and
				(TheBJView^.dealer_hand^.IsFacedown(1))
				and
				(pcnt > 0.0)
			then begin
				j:= Round(pcnt);
				I2S(j,buf);
				SetTextColor(PaintDC, Red);
				SetTextAlign(PaintDC, TA_RIGHT or TA_TOP);
				TextOut(PaintDC, rcGrid.left-2, GridSize*(21-i+1)+2, buf, strlen(buf));
				rc.left:= rcGrid.left+1;
				rc.top:= rcGrid.top+GridSize*(21-i)+2;
				rc.right:= rc.left+Round(pcnt)*(GridSize*5-2) div 100;
				rc.bottom:= rc.top+GridSize-4;
				OldBrush:= SelectObject(PaintDC, DoitBrush);
				FillRect(PaintDC, rc, DoItBrush);
				SelectObject(PaintDC, OldBrush);
			end;
		end;
		DeleteObject(DoItBrush);
		SelectObject(PaintDC, OldFont);
		DeleteObject(TheFont);
	end;
*)

procedure OCheatSheet.StartFlash;
var
	DC:HDC;
begin
	DC:=GetDC(Handle);
	OrgColor:=GetPixel(DC, rcGrid.left+1, rcGrid.top+1);
	ReleaseDC(Handle, DC);
	BringWindowTotop(Handle);
	TimerID:=SetTimer(Handle, 1, 500, nil);
end;

procedure OCheatSheet.StartFlashing(nrow:integer);
begin //writeln('OCheatSheet.StartFlashing(nrow:integer)');
	flash_column:=SoftPipVal(CardPip(the_bj_table^.HouseHand^.Gettop))-1;
	flash_row:=nrow;
	StartFlash;
end;

procedure OCheatSheet.StopFlashing;
var
	DC:HDC;
begin
	KillTimer(Handle, TimerID);
	DC:= GetDC(Handle);
	ColorGrid(DC, flash_row, flash_column);
	ReleaseDC(Handle, DC);
end;

procedure OCheatSheet.Paint(PaintDC:hDC; var PaintInfo:TPaintStruct);
var
	buf:array[0..255] of Char;
	OldPen, BluePen:HPEN;
	OldFont, TheFont:HFONT;
	i, j:integer;
	row:integer;
begin
	{ the grid }
	Rectangle(PaintDC, rcGrid.left, rcGrid.top, rcGrid.right, rcGrid.bottom);

	for i:= 1 to 9 do begin
		MoveToEx(PaintDC, rcGrid.left+i*GridSize, rcGrid.top,NIL);
		LineTo(PaintDC, rcGrid.left+i*GridSize, rcGrid.bottom);
	end;

	for i:= 1 to NumRows do begin
		MoveToEx(PaintDC, rcGrid.left, rcGrid.top+i*GridSize,NIL);
		LineTo(PaintDC, rcGrid.right, rcGrid.top+i*GridSize);
	end;

	SetBkMode(PaintDC, TRANSPARENT);

	TheFont:=CreateFont(
		(GridSize), 0,
		0,
		0,
		FW_BOLD,
		0, 0, 0,
		ANSI_CHARSET,
		OUT_STROKE_PRECIS, //OUT_DEFAULT_PRECIS,
		CLIP_DEFAULT_PRECIS,
		//5{CLEARTYPE_QUALITY}, 
		ANTIALIASED_QUALITY, 
		//PROOF_QUALITY,
		VARIABLE_PITCH or FF_SWISS,
		'Arial'
		);
	OldFont:= SelectObject(PaintDC, TheFont);

	SetTextAlign(PaintDC, TA_CENTER or TA_TOP);
	{OldPen:= SelectObject(PaintDC, BluePen);}
	SetTextColor(PaintDC, RGB_BLACK);

	StrCopy(buf, 'Your');
	TextOut(PaintDC, rcGrid.left div 2+4, GridSize*0, buf, strlen(buf));
	StrCopy(buf, 'Hand');
	TextOut(PaintDC, rcGrid.left div 2+4, GridSize*1, buf, strlen(buf));

	for row:= 1 to NumRows do begin
		GetRowText(row, buf);
		TextOut(PaintDC, rcGrid.left div 2+4, GridSize*(row+1), buf, strlen(buf));
	end;

	StrCopy(buf, 'Dealer''s Up Card');
	TextOut(PaintDC, rcGrid.left+GetRectWd(rcGrid) div 2, rcGrid.top-GridSize*2, buf, strlen(buf));

	for i:= 2 to 11 do begin
		if i=11 then
			StrCopy(buf, 'A')
		else
			I2S(i,buf);
		TextOut(PaintDC,
			rcGrid.left+(i-2)*GridSize+GridSize div 2,
			rcGrid.top-GridSize*1, buf, strlen(buf));
	end;
	{SelectObject(PaintDC, OldPen);}

	SelectObject(PaintDC, OldFont);
	DeleteObject(TheFont);

	{ color the squares }

	for i:= 0 to NumRows-1 do for j:= 0 to 9 do begin
		ColorGrid(PaintDC, i+1, j+1);
	end;
end;

procedure OCheatSheet.ColorGrid(DC:HDC; row, col:integer);
var
	aBrush:HBRUSH;
begin
	rc.left:= rcGrid.left+(GridSize*(col-1))+1;
	rc.top:= rcGrid.top+(GridSize*(row-1))+1;
	rc.right:= rc.left+GridSize-1;
	rc.bottom:= rc.top+GridSize-1;

	case GetGridState(row, col) of
		0:aBrush:= CreateSolidBrush(_ClrOff);
		1:aBrush:= CreateSolidBrush(_ClrOn);
		else
			aBrush:= CreateSolidBrush(_clralt)
	end;
	FillRect(DC, rc, aBrush);
	DeleteObject(aBrush);
end;

procedure OCheatSheet.OnTimer(wParam:WORD);
var
	DC:HDC;
	aBrush, SpotBrush:HBRUSH;
begin
	rc.left:= rcGrid.left+(GridSize*(flash_column-1))+1;
	rc.top:= rcGrid.top+(GridSize*(flash_row-1))+1;
	rc.right:= rc.left+GridSize-1;
	rc.bottom:= rc.top+GridSize-1;
	DC:= GetDC(Handle);
	if GetPixel(DC, rc.left+GetRectWd(rc) div 2, rc.top+GetRectHt(rc) div 2) <> DotColor then begin
		InflateRect(rc, -2, -2);
		SpotBrush:= CreateSolidBrush(DotColor);
		aBrush:= SelectObject(DC, SpotBrush);
		Ellipse(DC, rc.left, rc. top, rc.right, rc.bottom);
		SelectObject(DC, aBrush);
		DeleteObject(SpotBrush);
	end
	else
		ColorGrid(DC, flash_row, flash_column);
	ReleaseDC(Handle, DC);
end;

const
	ShowCount:integer=0; { how many of the panels are displayed }

constructor OCheatSheet.Init;
begin
	inherited Init;
	_clroff:= Red;
	_clron:= Green;
	_clralt:= Blue;
end;

procedure OCheatSheet.Create(parent:PWindow; aTitle:PChar; nRows:integer);
begin
	inherited Create(parent, aTitle,
		{ x } GetScreenWd div 40+ShowCount*GridSize div 4,
		{ y } GetScreenHt div 12+ShowCount*GridSize*2,
		{ w } (3+10+1)*GridSize,
		{ h } (2+NRows+1)*GridSize);
	NumRows:= nRows;
	rcGrid.top:= GridSize*2;
	rcGrid.bottom:= rcGrid.top+GridSize*NumRows+1;
	rcGrid.left:= GridSize*3;
	rcGrid.right:= rcGrid.left+10*GridSize+1;
	Inc(ShowCount);
end;

constructor OPlayerBetManager.Init(first_bet,split_bet:PWagerProp);
begin
	first_wager:=first_bet;
	split_wager:=split_bet;
	is_split:=FALSE;
end;

destructor OPlayerBetManager.Done;
begin
	Dispose(split_wager,Destruct);
	Dispose(first_wager,Destruct);
end;

function OMainView.IsSeated(pn:integer):boolean;
begin
	IsSeated:=(bj_table^.Player[pn] <> nil);
end;

function OPlayerBetManager.DollarValue:real;
begin
	DollarValue:= first_wager^.Value+split_wager^.Value;
end;

function OPlayerChipsProp.GetAnchorPoint(table_width,table_height:word):xypair;
begin //writeln('OPlayerChipsProp.GetAnchorPoint(',table_width,',',table_height,')');
	GetAnchorPoint:=MakeXYPair((table_width div 2)-Width, table_height-12);
end;

function OMainView.HandsRemaining:word;
begin
	HandsRemaining:=bj_table^.HandsRemaining;
end;

procedure OMainView.CleanupPlayer(pn:integer);
begin
	with wagers[pn] do begin
		with first_wager^ do if (DollarValue > 0.0) then begin
			TransferTo(@player_chips);
			ChipClankSound;
		end;
		with split_wager^ do if (DollarValue > 0.0) then begin
			TransferTo(@player_chips);
			ChipClankSound;
		end;
		is_split:=FALSE;
		PHotspot(first_wager)^.SnapTo(first_wager^.GetAnchorPoint(Width, Height));
	end;
	if (PlrHand[pn]<>nil) then begin
		PlrHand[pn]^.value_wart.Hide;
		PlrHand[pn]^.my_note_bar.Hide;
		PlrHand[pn]^.Discard;
		PlrHand[pn]^.SnapTo(PlrHand[pn]^.GetAnchorPoint(Width, Height));
	end;
	if (SplHand[pn]<>nil) then begin
		SplHand[pn]^.value_wart.Hide;
		SplHand[pn]^.my_note_bar.Hide;
		SplHand[pn]^.Discard;
		hotList.Delete(SplHand[pn]);
		Dispose(SplHand[pn], Done);
		SplHand[pn]:=nil;
	end;
end;

procedure OMainView.DoubleDown(pn:integer);
begin
	if Seat[pn]^.CheckChips(wagers[pn].first_wager^.Value)=1 then begin
		if the_active_hand=SplHand[pn] 
			then player_chips.TransferToPile(wagers[pn].split_wager, wagers[SUCKER_SEAT].first_wager^.Value)
			else player_chips.TransferToPile(wagers[pn].first_wager, wagers[SUCKER_SEAT].first_wager^.Value);
		shoe^.DealTo(the_active_hand);
		the_active_hand^.FlipTopcard;
		PlrHand[SUCKER_SEAT]^.ShowValue;
	end;
end;

function OPlayerHandProp.CanDoubleDown:boolean;
begin
	CanDoubleDown:= PBJPlayerHand(myHand)^.CanDoubleDown;
end;

(*
constructor TIECountPanel.Init(parent:PWindow);

	var
		buf:array[0..99] of Char;

	begin
		LoadString(hInstance, IDS_COUNT_PANEL, buf, 100);
		Inherited Init(parent, buf,
			{ x } GetScreenWd-GetScreenWd div 3,
			{ y } GetScreenHt div 2,
			{ w } GridSize*15,
			{ h } GridSize*8);
	end;
*)

function OHandPropBase.IsBust:boolean;
begin
	IsBust:= myHand^.Busted;
end;

procedure OMainView.Split(pn:integer);
begin
	if (the_active_card <> nil) then the_active_card^.StopFlashing;
	PlrHand[pn]^.value_wart.Hide;
	with wagers[pn] do begin
		is_split:=TRUE;
		PHotspot(first_wager)^.SnapTo(first_wager^.GetAnchorPoint(Width, Height));
		player_chips.TransferToPile(split_wager, first_wager^.Value);
	end;
	PlrHand[pn]^.Hide;
	PlrHand[pn]^.SetPosition(PlrHand[pn]^.Anchor.X-CurrentWidth,PlrHand[pn]^.Anchor.Y);
	PlrHand[pn]^.Show;

	SplHand[pn]:=New(PPlayerHandProp, Init(pn,bj_table^.Player[pn]^.SplitHand,wagers[pn].split_wager));
	AddProp(SplHand[pn],MakeXYPair(SplHand[pn]^.anchor.x,SplHand[pn]^.anchor.y));
	SplHand[pn]^.SetPosition(PlrHand[pn]^.Anchor.X+CurrentWidth*2,PlrHand[pn]^.Anchor.Y);
	PlrHand[pn]^.Dealto(SplHand[pn]);
	PBJPlayerHand(PlrHand[pn]^.myHand)^.AllowSplitting:= False;
	PBJPlayerHand(SplHand[pn]^.myHand)^.AllowSplitting:= False;
	shoe^.DealTo(SplHand[pn]);
	SplHand[pn]^.FlipTopcard;
	shoe^.DealTo(PlrHand[pn]);
	PlrHand[pn]^.FlipTopcard;

	{$ifdef TEST_SPLITSPLIT}

	with PlrHand[pn]^ do begin
		Discardtop;
		AddCard(MakeCard(KING, Spades));
	end;
	with SplHand[pn]^ do begin
		Discardtop;
		AddCard(MakeCard(KING, Spades));
	end;
	{$endif}

	{$ifdef TEST_SPLITDD}
	with PlrHand[pn]^ do begin
		Discardtop;
		AddCard(MakeCard(PFour, Spades));
	end;
	with SplHand[pn]^ do begin
		Discardtop;
		AddCard(MakeCard(PFour, Spades));
	end;
	{$endif}
end;

function OPlayerHandProp.Action:TAction;
begin
	Action:= PBJPlayerHand(myHand)^.Action;
end;

function OHandPropBase.IsPair:boolean;
begin
	IsPair:= myHand^.IsPair;
end;

function OHandPropBase.IsBJ:boolean;
begin
	IsBJ:= myHand^.IsBJ;
end;

function OHandPropBase.IsHardHand:boolean;
begin
	IsHardHand:= myHand^.IsHardHand;
end;

procedure OHandPropBase.DisplayResult(const aMsg:PChar);
var
	w, h:integer;
	pt:TPoint;
	buf:array[0..80] of Char;
	SpanRect:TRect;
begin
	w:=myTabletop^.ClientWidth div 9;
	h:=myTabletop^.ClientHeight div 24;
	GetSpanRect(SpanRect);
	pt.X:= Center(w, SpanRect.left, SpanRect.right);
	pt.Y:= Center(h, SpanRect.top, SpanRect.bottom);
	StrCopy(buf, amsg);
	MoveWindow(my_note_bar.Handle,pt.x,pt.y,w,h,FALSE);
	StrCopy(my_note_bar.TheText,amsg);
	my_note_bar.Show;
end;

constructor OHandNote.Construct(aHand:PHandPropBase);
begin
	inherited Construct; 
	my_hand:=aHand;
end;

procedure OHandNote.Create(parent:PWindow);
begin
	inherited Create(parent,'',0,0,0,0);
end;

constructor OHandPropBase.Init(aPile:PBlackJackHand);
begin
	inherited Construct(52);
	ThePile:=aPile;
	myHand:=aPile;
	value_wart.Construct;
	value_wart.Create(TheBJView, '', 0, 0, 31, 26);
	my_note_bar.Construct(@Self);
	my_note_bar.Create(TheBJView);
end;

function OHandPropBase.Value:word;
begin
	Value:= myHand^.Value;
end;

procedure OPlayerHandProp.BJ;
begin
	chips^.PayBJ;
	DisplayResult('Blackjack');
	PBJPlayerHand(myHand)^.PostWinBJ;
end;

procedure OPlayerHandProp.Busted;
begin
	chips^.Discard;
	DisplayResult('Bust');
end;

function OMainView.DealerUpCard:TCard;
begin
	DealerUpCard:= dealer_hand^.myHand^.Gettop;
end;

function DealerHasNatural:boolean;
begin
	DealerHasNatural:= TheBJView^.dealer_hand^.IsBJ;
end;

procedure OPlayerHandProp.Tally;
{ tally up this hand against the house hand }
var
	i:integer;
begin
	i:=PMainView(MyTabletop)^.bj_table^.EvaluateHand(myHand);
	case i of
		-1:begin
			{with TheBJView^ do with Seat[SeatNum]^ do if (DealerHasNatural and IsInsured) then WinInsuranceBet;}
			chips^.Discard;
			DisplayResult('Lose');
			{with TheBJView^.dealer_hand^ do if (not IsBJ) then DisplayResult('');}
			PBJPlayerHand(myHand)^.PostLose;
		end;
		0:begin
			DisplayResult('Push');
			PBJPlayerHand(myHand)^.PostPush;
		end;
		1,2:begin
			with PBJPlayerHand(myHand)^ do if IsSplitHand or ((not IsSplitHand) and (i=1)) then begin
				chips^.MatchIt;
				DisplayResult('Win');
				PBJPlayerHand(myHand)^.PostWin;
			end
			else begin
				chips^.PayBJ;
				PBJPlayerHand(myHand)^.PostWinBJ;
			end;
		end;
	end;
end;

constructor OSeatedPlayer.Init(const aPos:integer);
{ "aPos" is the seat # (1..n) at the table }
begin
	SeatNum:=aPos;
	insurance_wager:=New(InsuranceBetPropP, Init(@Self));
end;

destructor OSeatedPlayer.Done;
begin
	Dispose(insurance_wager, Destruct);
end;

procedure OSeatedPlayer.ReDraw(DC:HDC);
begin
	with insurance_wager^ do ReDraw(DC, Anchor.X, Anchor.Y);
end;

function SpokeAngle(aPos:integer):real;
{ return the angle in radians of the 'spoke' for pos "apos" }
begin
	SpokeAngle:= END_ANGLE-((BoxAngle*2)*(aPos-1)+BoxAngle/2);
end;

function InsuranceBetProp.GetAnchorPoint(table_width,table_height:word):xypair;
var
	a:real;
	SpanRect:TRect;
begin
	GetSpanRect(SpanRect);
	a:=SpokeAngle(_owner^.SeatNum);
	GetAnchorPoint:=MakeXYPair(
		GetRadialCenterX(table_width)+Round(cos(a)*(Radius+InsBarWd))-(GetRectWd(SpanRect) div 2),
		GetRadialCenterY(table_height)-Round(sin(a)*(Radius+InsBarWd))+ChipHeight*2);
end;

constructor InsuranceBetProp.Init(aSeat:PSeatedPlayer);
begin
	inherited Init(New(PPileOfChips, Init(10)));
	_owner:= aSeat;
end;

procedure OSeatedPlayer.TakeInsurance;
begin //writeln('OSeatedPlayer.TakeInsurance');
	TheBJView^.player_chips.TransferToPile(insurance_wager,TheBJView^.wagers[SeatNum].first_wager^.Value/2);
	ChipClankSound;
	insurance_wager^.Show;
end;

function OSeatedPlayer.IsInsured:boolean;
begin
	IsInsured:= (insurance_wager^.Value > 0);
end;

procedure OSeatedPlayer.WinInsuranceBet;
begin //writeln('OSeatedPlayer.WinInsuranceBet');
	insurance_wager^.Double;
	insurance_wager^.TransferTo(@TheBJView^.player_chips);
	ChipClankSound;
end;

procedure OSeatedPlayer.LoseInsuranceBet;
begin //writeln('OSeatedPlayer.LoseInsuranceBet');
	insurance_wager^.Discard;
end;

function OPlayerHandProp.SeatNum:integer;
begin
	SeatNum:= _ipos;
end;

(*
procedure TIECountPanel.Paint(PaintDC:hDC; var PaintInfo:TPaintStruct);

	var
		x, y:integer;
		buf:array[0..99] of Char;
		cbuf:array[0..99] of Char;
		OldFont, TheFont:HFONT;
		OldmBM, mBM:HBITMAP;
		mDC:HDC;
		rcMem:TRect;
		rcChart:TRect;
		OldPen:HPEN;
		OldBrush, aBrush:HBRUSH;

	procedure Bar(val:integer; AtY:integer;
		Wd:integer; { full width of the bar represents this many "val"s }
		RG:boolean);

		begin
			if (val > 0) then
				StrCopy(buf, '+')
			else
				StrCopy(buf, '');
			StrCat(buf, itoz(val, cbuf));
			x:= rcChart.left+(GetRectWd(rcChart) div 2);
			if (val < 0) then begin
				SetTextAlign(mDC, TA_LEFT or TA_TOP);
				x:= x+3;
			end
			else begin
				SetTextAlign(mDC, TA_RIGHT or TA_TOP);
				x:= x-3;
			end;
			TextOut(mDC, x, AtY, buf, strlen(buf));
			if (val <> 0) then begin
				x:= rcChart.left+(GetRectWd(rcChart) div 2);
				if (RG) then begin
					if (val < 0) then
						aBrush:= CreateSolidBrush(Red)
					else
						aBrush:= CreateSolidBrush(Green);
				end
				else
					aBrush:= CreateSolidBrush(Yellow);
				OldPen:= SelectObject(mDC, GetStockObject(BLACK_PEN));
				OldBrush:= SelectObject(mDC, aBrush);
				Rectangle(mDC,
					x+QInteger(val < 0, 1, 0), AtY+1,
					x+val*(GetRectWd(rcChart) div 2-1) div wd, AtY+DevFontHt(mDC)-1);
				SelectObject(mDC, OldBrush);
				DeleteObject(aBrush);
				SelectObject(mDC, OldPen);
			end;
		end;

	begin
		SetRect(rcMem, 0, 0, ClientWidth-GridSize*2, ClientHeight-GridSize*2);
		SetRect(rcChart, GetRectWd(rcMem) div 2, 0, rcMem.right, rcMem.bottom);
		mBM:= CreateCompatibleBitmap(PaintDC, GetRectWd(rcMem), GetRectHt(rcMem));

		mDC:= CreateCompatibleDC(PaintDC);
		OldmBM:= SelectObject(mDC, mBM);

		FillRect(mDC, rcMem, GetStockObject(WHITE_BRUSH));

		OldPen:= SelectObject(mDC, GetStockObject(BLACK_PEN));
		OldBrush:= SelectObject(mDC, GetStockObject(LTGRAY_BRUSH));
		Rectangle(mDC, rcChart.left, rcChart.top, rcChart.right, rcChart.bottom);
		MoveTo(mDC, rcChart.left+GetRectWd(rcChart) div 2, rcChart.top);
		LineTo(mDC, rcChart.left+GetRectWd(rcChart) div 2, rcChart.bottom);
		MoveTo(mDC, rcChart.left, rcChart.top+GetRectHt(rcChart) div 2);
		LineTo(mDC, rcChart.right, rcChart.top+GetRectHt(rcChart) div 2);
		SelectObject(mDC, OldBrush);
		SelectObject(mDC, OldPen);

		TheFont:= CreateFont(
			(GridSize-2), 0,
			0,
			0,
			FW_NORMAL,
			0, 0, 0,
			ANSI_CHARSET,
			OUT_DEFAULT_PRECIS,
			CLIP_DEFAULT_PRECIS,
			PROOF_QUALITY,
			VARIABLE_PITCH or FF_SWISS,
			'Arial'
			);
		OldFont:= SelectObject(mDC, TheFont);

		SetBkMode(mDC, TRANSPARENT);
		SetTextColor(mDC, Blue);

		x:= rcChart.left-3;
		y:= Center(DevFontHt(mDC), 0, GridSize-1);
		SetTextAlign(mDC, TA_RIGHT or TA_TOP);
		StrCopy(buf, '+1 [2,3,4,5,6]:');
		TextOut(mDC, x, y, buf, strlen(buf));
		Inc(y, GridSize);
		StrCopy(buf, '0 [7,8,9]:');
		TextOut(mDC, x, y, buf, strlen(buf));
		Inc(y, GridSize);
		StrCopy(buf, '-1 [10,J,Q,K,A]:');
		TextOut(mDC, x, y, buf, strlen(buf));
		Inc(y, GridSize);
		StrCopy(buf, 'Card Count:');
		TextOut(mDC, x, y, buf, strlen(buf));
		{TextOut(mDC, x-1, y, buf, strlen(buf));}

		Inc(y, GridSize);
		if (the_bj_table^.NumDecks=1) then
			StrCopy(buf, '1/4 Decks left:')
		else
			StrCopy(buf, 'Decks left:');
		TextOut(mDC, x, y, buf, strlen(buf));

		Inc(y, GridSize);
		StrCopy(buf, 'True Count:');
		TextOut(mDC, x, y, buf, strlen(buf));
		{TextOut(mDC, x-1, y, buf, strlen(buf));}

		Bar(
			the_bj_table^.LowCardsSeen,
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*0,
			13*5*the_bj_table^.NumDecks,
			True);
		Bar(
			the_bj_table^.EvenCardsSeen,
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*1,
			3*13*the_bj_table^.NumDecks,
			True);
		Bar(
			-the_bj_table^.HighCardsSeen,
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*2,
			13*5*the_bj_table^.NumDecks,
			True);
		{ the Count } Bar(
			the_bj_table^.GetCardCount,
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*3,
			8*the_bj_table^.NumDecks,
			True);
		{ # of decks or (1/4 decks) remaining } Bar(
			QInteger((the_bj_table^.NumDecks=1), the_bj_table^.QuarterDecksRem, the_bj_table^.NumDecksRem),
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*4,
			the_bj_table^.NumDecks*QInteger((the_bj_table^.NumDecks=1), 4, 1)+1,
			False);
		{ the true Count } Bar(
			the_bj_table^.GetTrueCount,
			Center(DevFontHt(mDC), 0, GridSize-1)+GridSize*5,
			32*the_bj_table^.NumDecks,
			True);

		SelectObject(mDC, OldFont);
		DeleteObject(TheFont);

		SelectObject(mDC, OldmBM);
		DeleteDC(mDC);

		PutBitmap(PaintDC, mBM, GridSize, GridSize, SRCCOPY);

		DeleteObject(mBM);
	end;
*)

procedure ODealerShoeProp.DealTo(TargetPile:OCardpileProp_ptr);
begin
	with PHandPropBase(TargetPile)^.value_wart do if IsWindowVisible(Handle) then Hide;
	if (PMainView(MyTabletop)^.bj_table^.TimeToShuffle) then TheBJView^.Shuffle;
	inherited DealTo(TargetPile);
end;

procedure OSoftDrawCard.Create(parent:PWindow);
var
	buf:array[0..99] of Char;
begin
	LoadString(hInstance, IDS_DRAW_TABLE_Soft, buf, 100);
	inherited Create(parent, buf, 3);
end;

constructor OHardDoubleDownCard.Init;
begin
	inherited Init;
	_clroff:= RGB_LIGHT_GRAY;
	_clron:= Yellow;
	_clralt:= DarkYellow;
end;

procedure OHardDoubleDownCard.Create(parent:PWindow);
var
	buf:array[0..99] of Char;
begin
	LoadString(hInstance, IDS_DD_TABLE_Hard, buf, 100);
	inherited Create(parent, buf, 5);
end;

constructor OSoftDoubleDownCard.Init;
begin
	inherited Init;
	_clroff:= RGB_LIGHT_GRAY;
	_clron:= Yellow;
	_clralt:= DarkYellow;
end;

procedure OSoftDoubleDownCard.Create(parent:PWindow);
var
	buf:array[0..99] of Char;
begin
	LoadString(hInstance, IDS_DD_TABLE_Soft, buf, 100);
	inherited Create(parent, buf, 5);
end;

constructor OSoftDoubleDownMultiDeckCard.Init;
begin
	inherited Init;
	_clroff:= RGB_LIGHT_GRAY;
	_clron:= Yellow;
	_clralt:= DarkYellow;
end;

procedure OSoftDoubleDownMultiDeckCard.Create(parent:PWindow);
var
	buf:array[0..99] of Char;
begin
	LoadString(hInstance, IDS_DD_TBL_Soft_Mult, buf, 100);
	inherited Create(parent, buf, 4);
end;

function OSoftDrawCard.GetGridState(nrow:integer; ncol:integer):integer;
{ return the state of the Hit/Draw strategy table grid at (nrow, ncol). }
begin
	case nrow of
		1:GetGridState:= (BJTblDrawSoft[20, nCol+1]);
		2:GetGridState:= (BJTblDrawSoft[18, nCol+1]);
		3:GetGridState:= (BJTblDrawSoft[17, nCol+1]);
	end;
end;

function OHardDoubleDownCard.GetGridState(nrow:integer; ncol:integer):integer;
begin
	GetGridState:= (BJTblDDHard[12-nrow+1, nCol+1]);
end;

function OSoftDoubleDownCard.GetGridState(nrow:integer; ncol:integer):integer;
begin
	GetGridState:= (BJTblDDSoft[20-nrow+1, nCol+1]);
end;

function OSoftDoubleDownMultiDeckCard.GetGridState(nrow:integer; ncol:integer):integer;
begin
	case nrow of
		1:GetGridState:= (BJTblDDSoftMult[20, nCol+1]);
		2:GetGridState:= (BJTblDDSoftMult[18, nCol+1]);
		3:GetGridState:= (BJTblDDSoftMult[16, nCol+1]);
		4:GetGridState:= (BJTblDDSoftMult[14, nCol+1]);
	end;
end;

procedure OMainView.ChangeNumDecks(n:word);
begin
	shoe^.Hide;
	bj_table^.SetNumPacks(n);
	shoe^.Show;
	Shuffle;
end;

constructor OSplitCard.Init;

begin
	Inherited Init;
	_clroff:=RGB_LIGHT_GRAY;
	_clron:=Cyan;
	_clralt:=DarkCyan;
end;

procedure OSplitCard.Create(parent:PWindow);

var
	buf:array[0..99] of Char;

begin
	LoadString(hInstance, ids_split_table, buf, 100);
	inherited Create(parent, buf, 10);
end;

function OSplitCard.GetGridState(nrow:integer; ncol:integer):integer;

	begin
		GetGridState:= (BJTblSplit[12-nrow, nCol+1]);
	end;

function OSplitCard.GetRowText(nrow:integer; aBuf:PChar):PChar;
var
	arg:array[1..2] of word;
begin
	case nrow of
		1:StrCopy(abuf, 'A,A');
		2:StrCopy(abuf, '10,10');
		else begin
			abuf[0]:=Char(Ord('9')-nrow+3);
			abuf[1]:=',';
			abuf[2]:=Char(Ord('9')-nrow+3);
			abuf[3]:=Char(0);
		end;
	end;
	GetRowText:= aBuf;
end;

function OSplitCard.GetFlashRow(aHand:PBJPlayerHand):integer;
begin
	if (aHand^.Value=12) and (CardPip(the_active_hand^.Get(1))=TACE) then
		GetFlashRow:= 1
	else
		GetFlashRow:= 12-(integer(aHand^.Value) div 2);
end;

procedure OMainView.Shuffle;
var
	hw:THandle;
	hwp:Pointer;
begin //writeln('OMainView.Shuffle');
	shoe^.Hide;
	bj_table^.CollectDiscards;
	bj_table^.SetNumPacks(DEFAULT_NUMPACKS);
	bj_table^.ShuffleDeck;
	hw:= FindResource(hInstance, 'DECK_SHUFFLE', 'WAVE');
	hw:= LoadResource(hInstance, hw);
	hwp:= LockResource(hw);
	if x_SoundStatus then begin
		SndPlaySound(hwp, Snd_NoDefault or SND_SYNC or SND_MEMORY);
		SndPlaySound(hwp, Snd_NoDefault or SND_SYNC or SND_MEMORY);
		SndPlaySound(hwp, Snd_NoDefault or SND_SYNC or SND_MEMORY);
	end;
	FreeResource(hw);
	shoe^.Show;

	{$ifdef TEST_SPLITBJ}
	with theDeck^.thePile^ do begin
		ref(size-0)^:= MakeCard(TJACK, TSPADES);
		ref(size-1)^:= MakeCard(TNINE, TDIAMONDS);
		ref(size-2)^:= MakeCard(TKING, TDIAMONDS);
		ref(size-3)^:= MakeCard(TSEVEN, TCLUBS);
		ref(size-4)^:= MakeCard(TTHREE, TDIAMONDS);
		ref(size-5)^:= MakeCard(TACE, THEARTS);
	end;
	{$endif}
end;

procedure OMainView.AddHumanPlayer(aSeatNum:integer; aPlayer:PBlackJackPlayer);
begin //writeln('OMainView.AddHumanPlayer(',aSeatNum,',aPlayer)');
	with bj_table^ do begin
		AddHumanPlayer(aSeatNum,aPlayer);
		player_chips.Init;
		player_chips.Hide; // hack
		AddProp(@player_chips);
		wagers[aSeatNum].Init(New(PWagerProp, Init(Player[aSeatNum]^.Hand^.TheBet)), New(PSplitProp, Init(Player[aSeatNum]^.SplitHand^.TheBet)));
		AddProp(wagers[aSeatNum].first_wager);
		AddProp(wagers[aSeatNum].split_wager);
		PlrHand[aSeatNum]:=New(PPlayerHandProp,Init(aSeatNum, Player[aSeatNum]^.Hand, wagers[aSeatNum].first_wager));
		AddProp(plrHand[aSeatNum]);
		self.Seat[aSeatNum]:=New(PSeatedPlayer, Init(aSeatNum));
		AddProp(self.Seat[aSeatNum]^.insurance_wager);
		player_chips.Show; // hack
	end;
end;

procedure OMainView.Cleanup;
begin
	Seat[SUCKER_SEAT]^.Cleanup;
end;

procedure OSeatedPlayer.Cleanup;
begin
	with TheBJView^ do CleanupPlayer(SeatNum);
end;

procedure OPlayerChipsProp.Borrow(const aAmount:real);
begin
	AmountBorrowed:= AmountBorrowed+aAmount;
	SetAmount(TheBundle^.DollarValue+aAmount);
end;

constructor OPlayerChipsProp.Init;
begin
	inherited Init(New(PBundleOfChips, Init(DefaultPurse)));
	AmountBorrowed:= 0.0;
end;

function OSeatedPlayer.CheckChips(aAmount:real):integer;
begin
	if (TheBJView^.player_chips.TheBundle^.DollarValue >= aAmount) then
		CheckChips:= 1
	else case MessageBox(TheBJView^.Handle,
		'Would you like to borrow from the house?', 'You can''t afford that!',
		MB_YESNO or MB_ICONEXCLAMATION) of
		IDYES:begin
			with TheBJView^.player_chips do while (TheBundle^.DollarValue < aAmount) do Borrow(ChipDollarValue(High(TypeOfChip)));
			ChipClankSound;
			CheckChips:= 1;
		end;
		IDNO:
			CheckChips:= 0;
	end;
end;

function OPlayerHandProp.AllowSplitting:boolean;
begin
	AllowSplitting:=PBJPlayerHand(myHand)^.AllowSplitting;
end;

procedure OPlayerChipsProp.OnStackClicked(aChipType:TypeOfChip);
begin //writeln('OPlayerChipsProp.OnStackClicked(aChipType:TypeOfChip)');
	with TheBJView^ do begin
		if ((PotValue+ChipDollarValue(aChipType)) > PMainView(MyTabletop)^.bj_table^.MaxBet) then
			MessageBox(TheBJView^.Handle, 'That would exceed the table limit.', 'Sorry!', MB_OK or MB_ICONINFORMATION)
		else begin
			TransferChipsToPile(wagers[SUCKER_SEAT].first_wager,aChipType,1);
			ChipClankSound;
			the_min_bet_button^.Disable;
			the_x2_bet_button^.Disable;
			the_x3_bet_button^.Disable;
			the_x4_bet_button^.Disable;
			the_max_bet_button^.Disable;
			the_ok_button^.Enabled(PotValue >= PMainView(MyTabletop)^.bj_table^.MinBet);
			the_cancel_button^.Enable;
		end;
	end;
end;

function NumPlayers:integer;
begin
	NumPlayers:= the_bj_table^.NumPlayers;
end;

function OMainApp.Window:PMainFrame;
begin
	Window:=PMainFrame(MainWindow);
end;

procedure OMainApp.InitMainWindow;
begin
	MainWindow:=New(PMainFrame,Init(@self));
	MainWindow^.MyFrameWindow:=New(FrameWindowP,Construct);
	MainWindow^.Create;
	Frame^.SetTabletopWindow(PTabletop(New(PMainView,Construct(RGB(0,127,0),
		LoadBitmapFromFile(PChar(GetStringData(KEY_TABLETOP,KEY_TABLETOP_IMAGEPATH,''))),
		GetBooleanData(KEY_TABLETOP,KEY_TABLETOP_USEIMAGE,FALSE)))));
end;

var
	the_hit_button:PBarButton;
	the_stand_button:PBarButton;
	the_dbldown_button:PBarButton;
	the_split_button:PBarButton;

constructor OMainFrame.Init(pwo:ApplicationP);
const
	START_MAXIMIZED=TRUE;
var
	buf:array[0..255] of char;
begin //writeln('OMainFrame.Init(pwo:ApplicationP)');
	inherited Init(@the_main_app,START_MAXIMIZED);
	the_hard_draw_card:=New(PHardDrawCard,Init);
	the_soft_draw_card:=New(PSoftDrawCard,Init);
	the_hard_dbldown_card:=New(PHardDoubleDownCard,Init);
	the_soft_dbldown_card:=New(PSoftDoubleDownCard,Init);
	the_soft_dbldown_multi_deck_card:=New(PSoftDoubleDownMultiDeckCard,Init);
	the_split_card:=New(PSplitCard,Init);
(*		CountPanel:= New(PIECountPanel, Init(@Self));*)
//		OddsPanel:= New(PIEOddsPanel, Init(@Self));
	the_min_bet_button:=New(PBarButton,Construct(CM_BETMIN));
	the_x2_bet_button:=New(PBarButton,Construct(CM_BET2TP));
	the_x3_bet_button:=New(PBarButton,Construct(CM_BET3TP));
	the_x4_bet_button:=New(PBarButton,Construct(CM_BET4TP));
	the_max_bet_button:=New(PBarButton,Construct(CM_BETMAX));
	the_ok_button:=New(PBarButton,Init(CM_PLACEBET));
	the_cancel_button:=New(PBarButton,Init(CM_CANCELBET));
	the_hit_button:=New(PBarButton,Init(CM_HIT));
	the_stand_button:=New(PBarButton, Construct(CM_STAND));
	the_dbldown_button:=New(PBarButton, Construct(CM_DBLDOWN));
	the_split_button:=New(PBarButton, Construct(CM_SPLIT));
end;

destructor OMainFrame.Done;
begin
	inherited Done;
end;

procedure FrameWindow.CMDEAL;
begin
	PostMessage(WM_CONTINUE, 0, 0);
end;

procedure FrameWindow.CMHIT;
begin
	PostMessage(WM_HIT,SUCKER_SEAT,0);
end;

procedure FrameWindow.CMSTAND;
begin
	PostMessage(WM_STAND,SUCKER_SEAT,0);
end;

(*
procedure FrameWindow.CMODH;
	begin
		ViewOdds:= not ViewOdds;
		if ViewOdds then
			OddsPanel^.Show
		else
			OddsPanel^.Hide;
		SetMenuBoolean(hmView, CM_ODH, ViewOdds);
	end;
*)

var
	RecommendedAction:integer;

procedure FrameWindow.WMDEAL;
var
	pn:integer;
	dlg:ODialog;
begin
	TheBJView^.Deal;
	the_active_hand:= TheBJView^.PlrHand[SUCKER_SEAT];
	if (CardPip(TheBJView^.DealerUpCard)=TACE) then begin
		dlg.Construct(Handle,IDD_INSURANCE);
		if (dlg.Modal=IDOK) then TheBJView^.Seat[SUCKER_SEAT]^.TakeInsurance;
	end;
	if (DealerHasNatural) then begin
		TheBJView^.dealer_hand^.thePile^.FlipAllFaceup;
		TheBJView^.dealer_hand^.Refresh;
		with TheBJView^.Seat[SUCKER_SEAT]^ do if IsInsured then WinInsuranceBet;
		PostMessage(WM_HPLAY, 0, 0);
	end
	else begin
		with TheBJView^.Seat[SUCKER_SEAT]^ do if IsInsured then LoseInsuranceBet;
		PostMessage(WM_PLAY, 1, 0);
	end;
end;

const
	InTrainingMode:boolean=True;

procedure RecommendPlay;
{ Display the recommended play to the user. }
begin
	the_active_card:= nil;
	case the_active_hand^.Action of
		ACTION_HIT:begin
			RecommendedAction:= wm_Hit;
			if the_active_hand^.IsHardHand 
				then the_active_card:= the_hard_draw_card
				else the_active_card:= the_soft_draw_card;
		end;
		ACTION_STAND:begin
			RecommendedAction:= wm_Stand;
			if the_active_hand^.IsHardHand 
				then the_active_card:= the_hard_draw_card
				else the_active_card:= the_soft_draw_card;
		end;
		ACTION_DBLDOWN:begin
			RecommendedAction:= WM_DBLDOWN;
			if the_active_hand^.IsHardHand 
				then the_active_card:=the_hard_dbldown_card
				else if the_bj_table^.SingleDeck 
					then the_active_card:=the_soft_dbldown_card
					else the_active_card:=the_soft_dbldown_multi_deck_card;
		end;
		ACTION_SPLIT:begin
			RecommendedAction:= wm_Split;
			the_active_card:=the_split_card;
		end;
	end;
	if InTrainingMode then begin
		if (the_active_card <> nil) and (not TheBJView^.PlrHand[SUCKER_SEAT]^.IsBJ) then with the_active_card^ do begin
			if (not IsVisible) then Show;
			StartFlashing(GetFlashRow(PBJPlayerHand(the_active_hand^.myHand)));
		end;
	end
end;

procedure OMainFrame.BeforeHumanPlays;
begin
	the_hit_button^.Enabled(not the_active_hand^.IsBust);
	the_stand_button^.Enabled(TRUE);
	the_dbldown_button^.Enabled(the_active_hand^.CanDoubleDown);
	the_split_button^.Enabled((TheBJView^.SplHand[SUCKER_SEAT]=NIL) and (the_active_hand^.AllowSplitting) and the_active_hand^.IsPair);
	the_active_hand^.ShowValue;
	RecommendPlay;
end;

procedure OMainFrame.AfterHumanPlays;
begin
	the_hit_button^.Disable;
	the_stand_button^.Disable;
	the_dbldown_button^.Disable;
	the_split_button^.Disable;
	MyFrameWindow^.PostMessage(WM_PLAY, SUCKER_SEAT+1, 0);
end;

var
	RecommendedBet:real; { the currently recommend bet, valid during the betting phase }

procedure FrameWindow.WMBET(wParam:WORD);
begin
	if (wParam > the_bj_table^.NumSeats) then begin
		PostMessage(WM_PLAY, 1, 0);
		Exit;
	end;
	if (wParam=SUCKER_SEAT) then begin
		if (TheBJView^.player_chips.TheBundle^.DollarValue >= BJ_HouseCeiling) then begin
			MessageBox(AppWnd,
				'You have beat the house limit of $20,000 in winnings. The management of this Casino requests that you leave the premises immediately and never return!',
				'Congratulations!', MB_ICONEXCLAMATION or MB_OK);
			the_main_app.OnNew;
			Exit;
		end
		else begin
			TheMainFrame^.BeforeHumanBets;
			{$ifdef AUTOPLAY}
			PostMessage(WM_BETMIN, SUCKER_SEAT, 0);
			{$endif}
			Exit;
		end;
	end;
	if (the_bj_table^.Player[wParam] <> nil) then
		SendMessage(WM_BETMIN, wParam, 1)
	else
		PostMessage(WM_BET, wParam+1, 0);
end;

procedure FrameWindow.WMHPLAY;
{ play out the house hand }
begin
	TheBJView^.dealer_hand^.ShowValue;
	with the_bj_table^.HouseHand^ do while (Value < 17) do SendMessage(WM_HHIT, 0, 0);
	if (the_bj_table^.HouseHand^.Busted) then TheBJView^.dealer_hand^.DisplayResult('Bust');
	PostMessage(WM_TALLY,1,0);
end;

procedure OMainFrame.EndHumanPlay;
{ do this after the human has played out a hand }
begin
	if (the_active_card <> nil) then the_active_card^.StopFlashing;
	if (
		(TheBJView^.SplHand[SUCKER_SEAT] <> nil)
		and
		(the_active_hand <> TheBJView^.PlrHand[SUCKER_SEAT])
		)
	then begin
		the_active_hand:=TheBJView^.PlrHand[SUCKER_SEAT];
		the_active_hand^.ShowValue;
		MyFrameWindow^.PostMessage(WM_PLAY,SUCKER_SEAT,0);
	end
	else begin
		AfterHumanPlays;
	end;
end;

procedure PlayRaspberry;
begin
	if x_SoundStatus then
		{SndPlaySound(hwpRaspberry, Snd_NoDefault or Snd_Memory);}
		SndPlaySound('Ding', 0);
end;

function CheckRecommendation(const aSelection:integer):boolean;
{ return true if "aSelection" is the same as the current recommended action }
begin
	CheckRecommendation:= True
end;

procedure FrameWindow.OnHit;
begin //writeln('OMainFrame.OnHit');
	TheBJView^.DoHit;
end;

procedure FrameWindow.WM_HHIT_PROC;
{ wParam=player number 1..n }
begin
	TheBJView^.dealer_hand^.Hit;
	with the_bj_table^.HouseHand^ do if (Value > 16) or Busted then Exit;
end;

procedure FrameWindow.WMSTAND;
{ wParam=player number 1..n }
begin
	if (not CheckRecommendation(WM_STAND)) then exit;
	TheBJView^.Stand(SUCKER_SEAT);
	TheMainFrame^.EndHumanPlay;
end;

procedure OMainView.PreManualWager;
begin
	player_chips.Enable;
	player_prompt.SetText('Place your Bets (minimum 5)');
	player_prompt.Show;
end;

procedure OMainView.PostManualWager;
begin
	player_prompt.Hide;
	player_chips.Disable;
end;

procedure OMainFrame.BeforeHumanBets;
begin
	the_min_bet_button^.Enable;
	the_x2_bet_button^.Enable;
	the_x3_bet_button^.Enable;
	the_x4_bet_button^.Enable;
	the_max_bet_button^.Enable;
	the_ok_button^.Disable;
	the_cancel_button^.Disable;
	the_hit_button^.Disable;
	the_stand_button^.Disable;
	the_dbldown_button^.Disable;
	the_split_button^.Disable;
	RecommendedBet:= the_bj_table^.Player[SUCKER_SEAT]^.BetAction;
	TheBJView^.PreManualWager;
end;

procedure OMainFrame.AfterHumanBets;
begin
	TheBJView^.PostManualWager;
	the_min_bet_button^.Disable;
	the_x2_bet_button^.Disable;
	the_x3_bet_button^.Disable;
	the_x4_bet_button^.Disable;
	the_max_bet_button^.Disable;
	the_ok_button^.Disable;
	the_cancel_button^.Disable;
end;

procedure FrameWindow.WMBETMIN;
begin
	{if (not CheckRecommendation(WM_BETMIN)) then exit;}
	if TheBJView^.PlayerBet(SUCKER_SEAT, the_bj_table^.MinBet) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end
end;

procedure FrameWindow.WMBETMAX;
begin
	{if (not CheckRecommendation(WM_BETMAX)) then exit;}
	if TheBJView^.PlayerBet(SUCKER_SEAT, the_bj_table^.MaxBet) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end;
end;

procedure FrameWindow.WMBET2TP;
{ wParam=player number 1..n }
begin
	{if (not CheckRecommendation(WM_BET2TP)) then exit;}
	if TheBJView^.PlayerBet(SUCKER_SEAT, the_bj_table^.MinBet*2) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end;
end;

procedure FrameWindow.WMBET3TP;
begin
	{if (not CheckRecommendation(WM_BET3TP)) then exit;}
	if TheBJView^.PlayerBet(SUCKER_SEAT, the_bj_table^.MinBet*3) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end;
end;

procedure FrameWindow.WMBET4TP;
begin
	{if (not CheckRecommendation(WM_BET4TP)) then exit;}
	if TheBJView^.PlayerBet(SUCKER_SEAT, the_bj_table^.MinBet*4) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end;
end;

procedure FrameWindow.WMBETRCM;
begin
	if TheBJView^.PlayerBet(SUCKER_SEAT, RecommendedBet) then begin
		TheMainframe^.AfterHumanBets;
		PostMessage(WM_DEAL, SUCKER_SEAT, 0);
	end;
end;

const
	DelayContinue=2250; { millisec to wait before continuing with the next hand }

var
	idt_Continue:word;

procedure FrameWindow.WMTALLY(wParam:WORD);
{ tally up the player's hands against the dealer }
begin
	if (wParam > the_bj_table^.NumSeats) then begin
		{TheConButton^.Enable;}
		idt_Continue:= SetTimer(Handle, TimerID2, DelayContinue, nil);
		Exit;
	end;
	with TheBJView^ do begin
		if IsSeated(wParam) then begin
			with PlrHand[wParam]^ do if (Size > 0) and (not IsBust) then Tally;
			if (SplHand[wParam] <> nil) then with SplHand[wParam]^ do if (Size > 0) and (not IsBust) then Tally;
		end;
	end;
	PostMessage(WM_TALLY, wParam+1, 0);
end;

procedure FrameWindow.OnDoubleDown;
begin
	if (not CheckRecommendation(WM_DBLDOWN)) then exit;
	if (TheBJView^.IsSeated(SUCKER_SEAT)) then begin
		TheBJView^.DoubleDown(SUCKER_SEAT);
		if the_active_hand^.IsBust then begin
			the_active_hand^.Busted;
			{SendMessage(AppWnd, WM_BUST, SUCKER_SEAT, 0);}
		end;
		TheMainFrame^.EndHumanPlay;
	end;
end;

procedure FrameWindow.OnSplit;
begin
	if (not CheckRecommendation(WM_SPLIT)) then exit;
	with TheBJView^ do case Seat[SUCKER_SEAT]^.CheckChips(PlrHand[SUCKER_SEAT]^.chips^.Value) of
		1:begin
			Split(SUCKER_SEAT);
			the_active_hand:= TheBJView^.SplHand[SUCKER_SEAT];
			SplHand[SUCKER_SEAT]^.ShowValue;
			TheMainFrame^.BeforeHumanPlays;
			PostMessage(WM_PLAY, SUCKER_SEAT, 0);
		end;
		-1:begin
			PostMessage(WM_COMMAND, CM_FILENEW, 0);
		end;
	end;
end;

procedure FrameWindow.WMPLAY(wParam:WORD);
{ wParam is the player # (1..n) }
	function AllBJ:boolean;
	{ all player hands at the table are BJ }
	var
		i:integer;
	begin
		AllBJ:= True;
		with the_bj_table^ do for i:= 1 to NumPlayers do if
			(TheBJView^.IsSeated(i))
			and
			(not (Player[i]^.Hand^.IsBJ or Player[i]^.SplitHand^.IsBJ))
		then begin
			AllBJ:=False;
			Exit;
		end;
	end;
begin
	if (wParam > the_bj_table^.NumSeats) then begin
		TheBJView^.dealer_hand^.thePile^.FlipAllFaceup;
		TheBJView^.dealer_hand^.Refresh;
		if (TheBJView^.HandsRemaining=0) or AllBJ then
			PostMessage(WM_TALLY, 1, 0)
		else
			PostMessage(WM_HPLAY, 0, 0);
		Exit;
	end;

	if (wParam=SUCKER_SEAT) then begin
		if
			(TheBJView^.PlrHand[SUCKER_SEAT]^.IsBJ)
		then begin
			TheBJView^.PlrHand[SUCKER_SEAT]^.DisplayResult('Blackjack');
			PostMessage(WM_PLAY, SUCKER_SEAT+1, 0);
		end
		else begin
			TheMainFrame^.BeforeHumanPlays;
			{$ifdef AUTOPLAY}
			PostMessage(WM_STAND, SUCKER_SEAT, 0);
			{$endif}
		end;
		Exit;
	end;

	with the_bj_table^ do begin
		if (Player[wParam] <> nil) then with Player[wParam]^ do begin
			while not Hand^.IsDone do case Hand^.Action of
				ACTION_HIT:
					SendMessage(WM_HIT, wParam, 0);
				ACTION_STAND:
					SendMessage(WM_STAND, wParam, 0);
				ACTION_DBLDOWN:
					Hand^.DDHit;
			end { case }
		end
		else
			PostMessage(WM_PLAY, wParam+1, 0);
	end;
end;

procedure FrameWindow.OnTimer(wParam:WORD);
begin
	if (wParam=idt_Continue) then begin
		KillTimer(Handle, idt_Continue);
		PostMessage(WM_CONTINUE,0,0);
	end
end;

procedure FrameWindow.OnContinue;
begin
	TheMainFrame^.CloseAllTables;
	TheBJView^.CleanupPlayer(SUCKER_SEAT);
	TheBJView^.dealer_hand^.value_wart.Hide;
	TheBJView^.dealer_hand^.my_note_bar.Hide;
	TheBJView^.dealer_hand^.Discard;
	PostMessage(WM_BET,1,0);
end;

procedure OMainFrame.CloseAllTables;
begin
	the_hard_draw_card^.Hide;
	the_soft_draw_card^.Hide;
	the_hard_dbldown_card^.Hide;
	the_soft_dbldown_card^.Hide;
	the_soft_dbldown_multi_deck_card^.Hide;
	the_split_card^.Hide;
end;

procedure OMainApp.OnNew;
begin
	with TheBJView^ do begin
		Window^.CloseAllTables;
		Cleanup;
		player_chips.SetAmount(DefaultPurse);
		player_chips.AmountBorrowed:= 0;
		TheBJView^.Shuffle;
	end;
	inherited OnNew;
	PostMessage(MainWindow^.MyFrameWindow^.Handle, WM_BET, 1, 0);
end;

constructor OMainApp.init;
begin
	inherited Construct('Blackjack');
	splash;
end;

destructor OMainApp.Done;
begin
	inherited Destruct;
end;

procedure FrameWindow.OnStart;
var
	w:word;
	money:real;
begin //writeln('FrameWindow.OnStart');
	the_hard_draw_card^.Create(@self);
	the_soft_draw_card^.Create(@self);
	the_hard_dbldown_card^.Create(@self);
	the_soft_dbldown_card^.Create(@self);
	the_soft_dbldown_multi_deck_card^.Create(@self);
	the_split_card^.Create(@self);
	with the_main_app do begin
		InsertMenu(Window^.GameMenu, 2, MF_BYPOSITION or MF_SEPARATOR, 0, nil);
		InsertMenu(Window^.GameMenu, 2, MF_BYPOSITION or MF_STRING, CM_VIEWSPLIT, 'Show Spli&t Tables');
		InsertMenu(Window^.GameMenu, 2, MF_BYPOSITION or MF_STRING, CM_VIEWDD, 'Show &Double Down Tables');
		InsertMenu(Window^.GameMenu, 2, MF_BYPOSITION or MF_STRING, CM_VIEWDRAW, 'Show Draw and &Stand Tables');
(*			CountPanel^.SetMenuItem(Window^.hmView, CM_CARDCOUNT);*)
		the_hard_draw_card^.SetMenuItem(Window^.GameMenu, CM_VIEWDRAW);
		the_soft_draw_card^.SetMenuItem(Window^.GameMenu, CM_VIEWDRAW);
		the_hard_dbldown_card^.SetMenuItem(Window^.GameMenu, CM_VIEWDD);
		the_soft_dbldown_card^.SetMenuItem(Window^.GameMenu, CM_VIEWDD);
		the_soft_dbldown_multi_deck_card^.SetMenuItem(Window^.GameMenu, CM_VIEWDD);
		the_split_card^.SetMenuItem(Window^.GameMenu, CM_VIEWSPLIT);
	end;

	with TheMainFrame^ do begin
		the_min_bet_button^.Create(myToolbar,'Min',BB_SHIFT);
		the_x2_bet_button^.Create(myToolbar,'x2',0);
		the_x3_bet_button^.Create(myToolbar,'x3',0);
		the_x4_bet_button^.Create(myToolbar,'x4',0);
		the_max_bet_button^.Create(myToolbar,'Max',0);
		the_ok_button^.Create(myToolbar,'OK', BB_SHIFT);
		the_cancel_button^.Create(myToolbar,'X',0);
		the_hit_button^.Create(myToolbar,'Hit',0);
		the_stand_button^.Create(myToolbar,'Stand', 0);
		the_dbldown_button^.Create(myToolbar,'Dbl-Down', 0);
		the_split_button^.Create(myToolbar,'Split', 0);
	end;

	TheBJView^.Initialize;
	TheBJView^.AssignDealer;
	TheBJView^.Shuffle;
	TheBJView^.AddHumanPlayer(SUCKER_SEAT, New(PBlackJackPlayer, Init(the_bj_table)));
	money:= the_main_app.GetIntegerData('Player', 'Purse', 500);
	money:= money+the_main_app.GetIntegerData('Player', 'Change', 0)/100.0;
	TheBJView^.player_chips.SetAmount(money);
	{$ifdef TEST_HOUSE_LIMIT}
	TheBJView^.player_chips.SetAmount(BJ_HouseCeiling+5);
	{$endif}
	PostMessage(WM_BET, 1, 0);
end;


function OMainApp.WriteINI(aFileName:PChar):boolean;
{ write all keywords applicable to this application }
begin
	WriteINI:= True;
end;

procedure FrameWindow.WMDOLLARS;
begin
//		the_main_app.ExecDialog(New(p_Info_Dialog, Init(the_main_app.MainWindow, MakeIntResource(IDD_INFO))));
//		Msg.Result:= 0;
end;

procedure FrameWindow.OnPlaceBet;
begin
	TheMainFrame^.AfterHumanBets;
	PostMessage(WM_DEAL,SUCKER_SEAT,0);
end;

procedure FrameWindow.OnCancelBet;
begin
	with TheBJView^ do wagers[SUCKER_SEAT].first_wager^.TransferTo(@player_chips);
	ChipClankSound;
	the_min_bet_button^.Enable;
	the_x2_bet_button^.Enable;
	the_x3_bet_button^.Enable;
	the_x4_bet_button^.Enable;
	the_max_bet_button^.Enable;
	the_ok_button^.Disable;
	the_cancel_button^.Disable;
end;

function OMainFrame.CanClose:boolean;
begin
	{if (TheBJView^.player_chips <> nil) then
		with TheBJView^.player_chips do saveDollars(theBundle^.DollarValue-AmountBorrowed);}
	canClose:= inherited CanClose;
end;

constructor OPlayerHandProp.Init(aPos:integer; aPile:PBlackJackHand; aBet:OChipstackProp_ptr);
begin
	inherited Init(aPile);
	_ipos:= aPos;
	chips:= aBet;
end;

destructor OPlayerHandProp.Done;
begin
	inherited Destruct;
end;

procedure OHandPropBase.OnTopcardFlipped;
begin
	if (not IsFacedown(Size)) then begin
		PMainView(MyTabletop)^.bj_table^.CardCounting(Get(Size));
	end;
end;

procedure OPlayerChipsProp.TransferToPile(target:OChipstackProp_ptr;amount:real);
begin
	SetAmount(Value-amount);
	target^.AddAmount(amount);
end;

procedure OPlayerChipsProp.TransferChipsToPile(target:OChipstackProp_ptr;aChipType:TypeOfChip;n:integer);
begin
	PopUnits(ChipUnitValue(aChipType)*n);
	target^.PushChips(aChipType,n);
end;

function FrameWindow.OnCmd(aCmdId:UINT):LONG;
var
	NewDecks:word;
	Span:TRect;
begin
	OnCmd:=1;
	case aCmdId of
		CM_DEAL:begin CMDEAL; OnCmd:=1; end;
		CM_HIT:begin CmHit; OnCmd:=1; end;
		CM_STAND:begin CMSTAND; OnCmd:=1; end;
		CM_BETMIN:PostMessage(WM_BETMIN, SUCKER_SEAT, 0);
		CM_BET2TP:PostMessage(WM_BET2TP, SUCKER_SEAT, 0);
		CM_BET3TP:PostMessage(WM_BET3TP, SUCKER_SEAT, 0);
		CM_BET4TP:PostMessage(WM_BET4TP, SUCKER_SEAT, 0);
		CM_BETMAX:PostMessage(WM_BETMAX, SUCKER_SEAT, 0);
		CM_SPLIT:PostMessage(WM_SPLIT, SUCKER_SEAT, 0);
		CM_DBLDOWN:PostMessage(WM_DBLDOWN, SUCKER_SEAT, 0);
		CM_PLACEBET:PostMessage(WM_PLACEBET,SUCKER_SEAT,0);
		CM_CANCELBET:PostMessage(WM_CANCELBET,SUCKER_SEAT,0);
		CM_VIEWDRAW:begin
			if GetCheckedMenuItem(TheMainFrame^.GameMenu,CM_VIEWDRAW) then begin
				SetMenuBoolean(TheMainFrame^.GameMenu,CM_VIEWDRAW,False);
				the_hard_draw_card^.Hide;
				the_soft_draw_card^.Hide;
			end
			else begin
				SetMenuBoolean(TheMainFrame^.GameMenu,CM_VIEWDRAW,True);
				the_hard_draw_card^.Show;
				the_soft_draw_card^.Show;
			end;
		end;
		CM_VIEWDD:begin
			if GetCheckedMenuItem(TheMainFrame^.GameMenu,CM_VIEWDD) then begin
				SetMenuBoolean(TheMainFrame^.GameMenu,CM_VIEWDD, False);
				the_hard_dbldown_card^.Hide;
				the_soft_dbldown_card^.Hide;
				the_soft_dbldown_multi_deck_card^.Hide;
			end
			else begin
				SetMenuBoolean(TheMainFrame^.GameMenu, CM_VIEWDD, True);
				the_hard_dbldown_card^.Show;
				if the_bj_table^.SingleDeck then
					the_soft_dbldown_card^.Show
				else
					the_soft_dbldown_multi_deck_card^.Show;
			end;
		end;

		CM_VIEWSPLIT:begin
			if GetCheckedMenuItem(TheMainFrame^.GameMenu,CM_VIEWSPLIT) then begin
				SetMenuBoolean(TheMainFrame^.GameMenu,CM_VIEWSPLIT, False);
				the_split_card^.Hide;
			end
			else begin
				SetMenuBoolean(TheMainFrame^.GameMenu,CM_VIEWSPLIT,TRUE);
				the_split_card^.Show;
			end;
		end
		else OnCmd:=inherited OnCmd(aCmdId);
	end;
end;

function OCheatSheet.OnMsg(aMsg:UINT; wParam:WPARAM; lParam:LPARAM):LONG;
begin
	OnMsg:=0;
	case aMsg of
		WM_TIMER:OnTimer(wParam);
		else OnMsg:=inherited OnMsg(aMsg, wParam, lParam);
	end;
end;

function FrameWindow.OnMsg(aMsg:UINT;wParam:WPARAM;lParam:LPARAM):LONG;
begin
	OnMsg:=0;
	case aMsg of
		WM_BET:WMBET(wParam);
		WM_DEAL:WMDEAL;
		WM_PLAY:WMPLAY(wParam);
		WM_HIT:OnHit;
		WM_DBLDOWN:OnDoubleDown;
		WM_SPLIT:OnSplit;
		WM_PLACEBET:OnPlaceBet;
		WM_CANCELBET:OnCancelBet;
		WM_STAND:WMSTAND;
		WM_HPLAY:WMHPLAY;
		WM_HHIT:WM_HHIT_PROC;
		WM_CONTINUE:OnContinue;
		WM_BETMIN:WMBETMIN;
		WM_BETMAX:WMBETMAX;
		WM_BET2TP:WMBET2TP;
		WM_BET3TP:WMBET3TP;
		WM_BET4TP:WMBET4TP;
		WM_BETRCM:WMBETRCM;
		WM_TALLY:WMTALLY(wParam);
		WM_START:OnStart;
		WM_TIMER:OnTimer(wParam);
		WM_DOLLARS:WMDOLLARS;
		else OnMsg:=inherited OnMsg(aMsg,wParam,lParam);
	end;
end;

constructor OInformationPanel.Init;
begin
	inherited Construct;
	menucmd:=0;
end;

procedure OInformationPanel.Create(parent:PWindow;title:PChar;x,y,w,h:integer);

var
	rc:TRect;
	style:DWORD;

begin
	style:=DWORD(WS_POPUP) or DWORD(WS_BORDER);
	if (title<>nil) then Style:=(Style or WS_CAPTION);
	style:=(Style and (not WS_VISIBLE));
	SetRect(rc,0,0,w,h);
	AdjustWindowRect(rc, Style, FALSE);
	inherited Create(title,style,x,y,rc.right-rc.left,rc.bottom-rc.top,parent^.Handle,0,hInstance,LPVOID(0));
end;

procedure OInformationPanel.Show;

begin
	if (not IsVisible) then begin
		inherited ShowWindow(SW_SHOW);
		InvalidateRect(handle, nil, FALSE);
		UpdateWindow;
		ValidateRect(GetParent, nil);
		if (menucmd <> 0) then SetMenuBoolean(menu, menucmd, True);
	end;
end;

procedure OInformationPanel.Hide;

begin
	if (IsVisible) then begin
		inherited ShowWindow(SW_HIDE);
		windows.UpdateWindow(windows.GetParent(handle));
		if (menucmd <> 0) then SetMenuBoolean(menu, menucmd, False);
	end;
end;

procedure OInformationPanel.redraw;
	begin
		if IsVisible then begin
			InvalidateRect(handle, nil, true);
			UpdateWindow;
		end;
	end;

procedure OInformationPanel.Refresh;
{ repaint the contents of the client area }
begin
	if IsVisible then begin
		InvalidateRect(handle, nil, false);
		UpdateWindow;
	end;
end;

function OInformationPanel.IsVisible:boolean;
begin
	IsVisible:= IsWindowVisible(handle);
end;

procedure OInformationPanel.SetMenuItem(a_hmenu:HMENU; a_cmd:integer);
{ associates this panel with an existing menu command to show and hide it }
begin
	menu:= a_hmenu;
	menucmd:= a_cmd;
end;

function OMainApp.HomePageUrl:pchar;
begin
	HomePageUrl:='http://www.wesleysteiner.com/quickgames/blackjack.html';
end;

function OMainApp.DonatePageUrl:pchar;
begin
	DonatePageUrl:=HOMEPAGE_DIR+'blackjack/donate.html';
end;

procedure OMainView.DoHit;
begin
	if (not CheckRecommendation(WM_HIT)) then exit;
	if (the_active_card <> nil) then the_active_card^.StopFlashing;
	the_dbldown_button^.Disable;
	the_split_button^.Disable;
	the_active_hand^.Hit;
	if the_active_hand^.IsBust then begin
		the_active_hand^.Busted;
		TheMainFrame^.EndHumanPlay;
	end
	else
		RecommendPlay;
end;

function OMainView.OnDoubleTapped(x,y:integer):boolean;
begin //writeln('OMainView.OnDoubleTapped(x,y:integer)');
	OnDoubleTapped:=FALSE;
	if (the_hit_button^.IsEnabled) then begin
		DoHit;
		OnDoubleTapped:=TRUE;
	end;
end;

function OMainView.WagerPromptText:pchar;
begin
	WagerPromptText:=PChar(AnsiString('Place your Bets (minimum '+NumberToString(Integer(DEFAULTMINBET))+')'));
end;

{$ifdef TEST}

// these tests belong in winbjktbl when possible to do so

type
	testable_OMainView=object(OMainView)
		constructor Construct;
	end;

constructor testable_OMainView.Construct;
begin
	inherited Construct(RGB(0,0,0), 0, FALSE);
end;

// can we unit test the tabletop view?
procedure OMainViewTest;
var
	host:OWindow;
	view:OMainView;
begin
	host.Construct;
	host.Create('host window', WS_OVERLAPPEDWINDOW or WS_VISIBLE, 10, 20, 800, 600, 0, 0, hInstance, NIL);
	view.Construct(RGB(0,127,0), 0, FALSE);
	view.Create(host.Handle, host.ClientWidth, host.ClientHeight);
	host.ShowWindow(SW_SHOWNORMAL);
	host.UpdateWindow;
	view.Initialize;
end;

procedure WagerPromptText;
var
	view:testable_OMainView;
begin
	view.Construct;
	AssertAreEqual('Place your Bets (minimum 5)', view.WagerPromptText);
end;
{$endif}

function OWagerProp.GetAnchorPoint(table_width,table_height:word):xypair;
begin
	with TheBJView^.wagers[SUCKER_SEAT] do if is_split
		then GetAnchorPoint:=MakeXYPair(CtrPt[SUCKER_SEAT].X-BET_CIRCLE_RADIUS-(ChipWidth div 2), CtrPt[SUCKER_SEAT].Y+(ChipHeight div 2))
		else GetAnchorPoint:=MakeXYPair(CtrPt[SUCKER_SEAT].X-(ChipWidth div 2), CtrPt[SUCKER_SEAT].Y+BET_CIRCLE_RADIUS-ChipHeight-(ChipHeight div 2));
end;

function OSplitProp.GetAnchorPoint(table_width,table_height:word):xypair;
begin
	GetAnchorPoint:=MakeXYPair(CtrPt[SUCKER_SEAT].X+BET_CIRCLE_RADIUS-(ChipWidth div 2), CtrPt[SUCKER_SEAT].Y+(ChipHeight div 2));
end;

begin
	{$ifdef TEST}
//	Suite.Add(@OMainViewTest);
	Suite.Add(@WagerPromptText);
	Suite.Run('main');
	{$else}
	the_main_app.Init;
	the_main_app.Run;
	the_main_app.Done;
	{$endif}
end.
