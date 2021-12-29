{ (C) 2012 Wesley Steiner }

{$MODE FPC}

unit winbjktbl;

interface

uses
	windows,
	owindows,
	casino;

const
	BET_CIRCLE_RADIUS=55;
	SUCKER_SEAT=4; { pos at the table for the human player }
	TIMERID2=102;

type
	PHangingNote=^OHangingNote;
	OHangingNote=object(OWindow)
		TheText:array[0..79] of Char;
		procedure Create(parent:PWindow;const text:PChar;x,y,w,h:integer);
		procedure Show; virtual;
		procedure Hide; virtual;
		procedure Paint(PaintDC:hDC; var PaintInfo:TPaintStruct); virtual;
	end;

var
	CtrPt:array[1..BJ_MAXSEATS] of TPoint; { center of the player's bet circle }

implementation 

uses
	strings,
	std,
	gdiex,
	windowsx;

procedure OHangingNote.Create(parent:PWindow;const text:PChar;x,y,w,h:integer);
begin
	StrCopy(TheText, text);
	inherited Create('',WS_CHILD,x,y,w,h,parent^.Handle,0,hInstance,LPVOID(0));
end;

procedure OHangingNote.Paint(PaintDC:hDC; var PaintInfo:TPaintStruct);
var
	aBrush, OldBrush:HBRUSH;
	DC:HDC;
	rc:TRect;
	OldFont, Font:HFONT;
	aFont:TLogFont;
begin
	aBrush:=CreateSolidBrush(RGB(255, 255, 127));
	OldBrush:=SelectObject(PaintDC, aBrush);
	GetClientRect(rc);
	{RoundRect(PaintDC, rc.left, rc.top, rc.right, rc.bottom, RectHt(rc) div 2, RectHt(rc) div 2);}
	Rectangle(PaintDC, rc.left, rc.top, rc.right, rc.bottom);
	SelectObject(PaintDC, OldBrush);
	DeleteObject(aBrush);
	with aFont do begin
		lfHeight:= ClientHeight * 5 div 6;
		lfWidth:=0;
		lfEscapement:=0;
		lfOrientation:=0;
		lfWeight:= FW_NORMAL;
		lfItalic:=0;
		lfUnderline:=0;
		lfStrikeout:=0;
		lfCharset:=ANSI_CHARSET;
		lfOutPrecision:=OUT_STROKE_PRECIS;
		lfClipPrecision:=0;
		lfQuality:=ANTIALIASED_QUALITY;
		lfPitchAndFamily:= VARIABLE_PITCH or FF_SWISS;
		strcopy(lfFaceName,'Arial');
	end;
	SetBkMode(PaintInfo.hdc,TRANSPARENT);
	SetTextColor(PaintInfo.hdc, DarkBlue);
	SetTextAlign(PaintInfo.hdc, TA_CENTER or TA_TOP);
	Font:=CreateFontIndirect(aFont);
	OldFont:=SelectObject(PaintDC, Font);
	TextOut(PaintDC,ClientWidth div 2, Center(DevFontHt(PaintDC), 0, ClientHeight), TheText, StrLen(Thetext));
	SelectObject(PaintDC, OldFont);
	DeleteObject(Font);
end;

procedure OHangingNote.Show;
begin
	if (not IsWindowVisible(handle)) then begin
		inherited ShowWindow(SW_SHOWNORMAL);
		UpdateWindow;
	end;
end;

procedure OHangingNote.Hide;
begin
	if IsWindowVisible(handle) then begin
		inherited ShowWindow(SW_HIDE);
		windows.UpdateWindow(GetParent); { repaint underneath it }
	end;
end;

end.
