///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var TextTemplates;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DefineBehaviorInMobileClient();
	
	IsCustomSettings = Parameters.Property("Settings", Settings);
	If Not IsCustomSettings Then 
		Items.FormOK.Title = NStr("en = 'Save';");
	EndIf;
	Items.FormCancel.Visible = Not IsCustomSettings;
	Items.FormCustomizeStandardSettings.Visible = IsCustomSettings;
	
	CustomizeStandardSettingsServer();
	
	CurrentUser = Users.CurrentUser();
	
	PageSample = 1;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	TextTemplates = New Structure;
	
	TextTemplates.Insert("Date" , "[&Date]");
	TextTemplates.Insert("Time" , "[&Time]");
	TextTemplates.Insert("PageNumber" , "[&PageNumber]");
	TextTemplates.Insert("PagesTotal" , "[&PagesTotal]");
	TextTemplates.Insert("User" , "[&User]");
	TextTemplates.Insert("ReportTitle", "[&ReportTitle]");
	
	UpdatePreview();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TextOnChange(Item)
	UpdatePreview();
EndProcedure

&AtClient
Procedure StartHeaderFromPageOnChange(Item)
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure StartFooterFromPageOnChange(Item)
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure PageSampleOnChange(Item)
	
	UpdatePreview();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure InsertTemplate(Command)
	
	If TypeOf(CurrentItem) = Type("FormField")
		And CurrentItem.Type = FormFieldType.InputField
		And StrFind(CurrentItem.Name, "Text") > 0 Then
		InsertText(CurrentItem, TextTemplates[Command.Name]);	
		
		UpdatePreview();
	EndIf;
			
EndProcedure

&AtClient
Procedure CustomizeHeaderFont(Command)
	
	FontChooseDialog = New FontChooseDialog;
#If Not WebClient Then
	FontChooseDialog.Font = FontHeader;
#EndIf
	
	NotifyDescription = New NotifyDescription("HeaderFontSettingCompletion", ThisObject);
	
	FontChooseDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure CustomizeFooterFont(Command)
	
	FontChooseDialog = New FontChooseDialog;
#If Not WebClient Then
	FontChooseDialog.Font = FontFooter;
#EndIf
	
	NotifyDescription = New NotifyDescription("FooterFontSettingCompletion", ThisObject);
	
	FontChooseDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure HeaderVerticalAlignTop(Command)
	
	VerticalAlignTop = VerticalAlign.Top;
	Items.HeaderVerticalAlignTop.Check  = True;
	Items.HeaderVerticalAlignCenter.Check = False;
	Items.HeaderVerticalAlignBottom.Check   = False;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure HeaderVerticalAlignCenter(Command)
	
	VerticalAlignTop = VerticalAlign.Center;
	Items.HeaderVerticalAlignTop.Check  = False;
	Items.HeaderVerticalAlignCenter.Check = True;
	Items.HeaderVerticalAlignBottom.Check   = False;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure HeaderVerticalAlignBottom(Command)
	
	VerticalAlignTop = VerticalAlign.Bottom;
	Items.HeaderVerticalAlignTop.Check  = False;
	Items.HeaderVerticalAlignCenter.Check = False;
	Items.HeaderVerticalAlignBottom.Check   = True;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure FooterVerticalAlignTop(Command)
	
	VerticalAlignBottom = VerticalAlign.Top;
	Items.FooterVerticalAlignTop.Check  = True;
	Items.FooterVerticalAlignCenter.Check = False;
	Items.FooterVerticalAlignBottom.Check   = False;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure FooterVerticalAlignCenter(Command)
	
	VerticalAlignBottom = VerticalAlign.Center;
	Items.FooterVerticalAlignTop.Check  = False;
	Items.FooterVerticalAlignCenter.Check = True;
	Items.FooterVerticalAlignBottom.Check   = False;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure FooterVerticalAlignBottom(Command)
	
	VerticalAlignBottom = VerticalAlign.Bottom;
	Items.FooterVerticalAlignTop.Check  = False;
	Items.FooterVerticalAlignCenter.Check = False;
	Items.FooterVerticalAlignBottom.Check   = True;
	
	UpdatePreview();
	
EndProcedure

&AtClient
Procedure OK(Command)
	UpdateSettings2();
	Close(?(Not SettingsStatus.Standard1 And Not SettingsStatus.Empty1, Settings, Undefined));
EndProcedure

&AtClient
Procedure CustomizeStandardSettings(Command)
	
	Settings = Undefined;
	CustomizeStandardSettingsServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DefineBehaviorInMobileClient()
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then 
		Return;
	EndIf;
	
	Items.HeaderTextGroup.Group = ChildFormItemsGroup.HorizontalIfPossible;
	Items.FooterTextGroup.Group = ChildFormItemsGroup.HorizontalIfPossible;
	
	Items.TopLeftText.InputHint = NStr("en = 'Top left';");
	Items.TopMiddleText.InputHint = NStr("en = 'Top center';");
	Items.TopRightText.InputHint = NStr("en = 'Top right';");
	
	Items.BottomLeftText.InputHint = NStr("en = 'Bottom left';");
	Items.BottomCenterText.InputHint = NStr("en = 'Bottom center';");
	Items.BottomRightText.InputHint = NStr("en = 'Bottom right';");
	
	Items.TopLeftText.Height = 1;
	Items.TopMiddleText.Height = 1;
	Items.TopRightText.Height = 1;
	
	Items.BottomLeftText.Height = 1;
	Items.BottomCenterText.Height = 1;
	Items.BottomRightText.Height = 1;
EndProcedure

&AtClientAtServerNoContext
Function HeaderAndFooterRowHeight()
	Return 10;
EndFunction

&AtClient
Procedure InsertText(Var_CurrentItem, Text)
	ThisObject[Var_CurrentItem.Name] = ThisObject[Var_CurrentItem.Name] + Text;
EndProcedure

&AtServer
Procedure UpdateSettings2()
	Header = New Structure();
	Header.Insert("LeftText", TopLeftText);
	Header.Insert("CenterText", TopMiddleText);
	Header.Insert("RightText", TopRightText);
	Header.Insert("Font", FontHeader);
	Header.Insert("VerticalAlign", VerticalAlignTop);
	Header.Insert("HomePage", HeaderStartPage);
	
	Footer = New Structure();
	Footer.Insert("LeftText", BottomLeftText);
	Footer.Insert("CenterText", BottomCenterText);
	Footer.Insert("RightText", BottomRightText);
	Footer.Insert("Font", FontFooter);
	Footer.Insert("VerticalAlign", VerticalAlignBottom);
	Footer.Insert("HomePage", FooterStartPage);
	
	Settings = New Structure("Header, Footer", Header, Footer);
	SettingsStatus = HeaderFooterManagement.HeadersAndFootersSettingsStatus(Settings);
	
	If Not IsCustomSettings Then 
		HeaderFooterManagement.SaveHeadersAndFootersSettings(Settings);
	EndIf;
EndProcedure

// Sets the last saved common settings.
//
&AtServer
Procedure CustomizeStandardSettingsServer()
	If Settings = Undefined Then 
		Settings = HeaderFooterManagement.HeaderOrFooterSettings();
	EndIf;
	
	HeaderStartPage = Settings.Header.HomePage;
	TopLeftText = Settings.Header.LeftText;
	TopMiddleText = Settings.Header.CenterText;
	TopRightText = Settings.Header.RightText;
	FontHeader = Settings.Header.Font;
	VerticalAlignTop = Settings.Header.VerticalAlign;
	
	FooterStartPage = Settings.Footer.HomePage;
	BottomLeftText = Settings.Footer.LeftText;
	BottomCenterText = Settings.Footer.CenterText;
	BottomRightText = Settings.Footer.RightText;
	FontFooter = Settings.Footer.Font;
	VerticalAlignBottom = Settings.Footer.VerticalAlign;
	
	Items.HeaderVerticalAlignTop.Check = 
		VerticalAlignTop = VerticalAlign.Top;
	Items.HeaderVerticalAlignCenter.Check = 
		VerticalAlignTop = VerticalAlign.Center;
	Items.HeaderVerticalAlignBottom.Check = 
		VerticalAlignTop = VerticalAlign.Bottom;
		
	Items.FooterVerticalAlignTop.Check = 
		VerticalAlignBottom = VerticalAlign.Top;
	Items.FooterVerticalAlignCenter.Check = 
		VerticalAlignBottom = VerticalAlign.Center;
	Items.FooterVerticalAlignBottom.Check = 
		VerticalAlignBottom = VerticalAlign.Bottom;
	
	PreparePreview();
EndProcedure

&AtServer
Procedure PreparePreview()
	Pattern.Area(1, 1).RowHeight  = 5;
	Pattern.Area(1, 1).ColumnWidth = 1;
	
	StyleItems = Metadata.StyleItems;
	SampleColor = StyleItems.HeadersAndFootersSettingsPreviewColor.Value;
	SampleFont = StyleItems.HeaderOrFooterSettingsPreviewFont.Value;
	
	Pattern.Area(2, 2, 4, 4).BorderColor = SampleColor;
	Pattern.Area(2, 2, 4, 4).TextPlacement = SpreadsheetDocumentTextPlacementType.Block;
	
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	Pattern.Area(2, 2).Outline(Line, Line,, Line);
	Pattern.Area(2, 3).Outline(, Line,, Line);
	Pattern.Area(2, 4).Outline(, Line, Line, Line);
	
	Pattern.Area(4, 2).Outline(Line, Line,, Line);
	Pattern.Area(4, 3).Outline(, Line, , Line);
	Pattern.Area(4, 4).Outline(, Line, Line, Line);
	
	Pattern.Area(2, 2).HorizontalAlign = HorizontalAlign.Left;
	Pattern.Area(2, 3).HorizontalAlign = HorizontalAlign.Center;
	Pattern.Area(2, 4).HorizontalAlign = HorizontalAlign.Right;
	
	Pattern.Area(4, 2).HorizontalAlign = HorizontalAlign.Left;
	Pattern.Area(4, 3).HorizontalAlign = HorizontalAlign.Center;
	Pattern.Area(4, 4).HorizontalAlign = HorizontalAlign.Right;
	
	Pattern.Area(2, 2).ColumnWidth = 40;
	Pattern.Area(2, 3).ColumnWidth = 40;
	Pattern.Area(2, 4).ColumnWidth = 40;
	
	Pattern.Area(3, 2).Text      = Chars.LF + NStr("en = 'Report preview';") + Chars.LF + " ";
	Pattern.Area(3, 2).Font      = SampleFont;
	Pattern.Area(3, 2).TextColor = SampleColor;
	
	Pattern.Area(3, 2).HorizontalAlign = HorizontalAlign.Center;
	
	Pattern.Area(3, 2, 3, 4).Merge();
	Pattern.Area(3, 2, 3, 4).Outline(Line, Line, Line, Line);
EndProcedure

&AtClient
Procedure UpdatePreview()
	Pattern.Area(2, 2, 2, 4).Font = FontHeader;
	Pattern.Area(4, 2, 4, 4).Font = FontFooter;
	
	Pattern.Area(2, 2, 2, 4).VerticalAlign = VerticalAlignTop;
	Pattern.Area(4, 2, 4, 4).VerticalAlign = VerticalAlignBottom;
	
	RowsAboveCount = Max(
		2,
		RowsCountInText(TopLeftText),
		RowsCountInText(TopMiddleText),
		RowsCountInText(TopRightText));
		
	RowsBelowCount = Max(
		2,
		RowsCountInText(BottomLeftText),
		RowsCountInText(BottomCenterText),
		RowsCountInText(BottomRightText));
		
	Pattern.Area(2, 2).RowHeight = RowsAboveCount * HeaderAndFooterRowHeight();
	Pattern.Area(4, 2).RowHeight = RowsBelowCount * HeaderAndFooterRowHeight();
		
	Pattern.Area(2, 2).Text = FillTemplate(TopLeftText, HeaderStartPage);
	Pattern.Area(2, 3).Text = FillTemplate(TopMiddleText, HeaderStartPage);
	Pattern.Area(2, 4).Text = FillTemplate(TopRightText, HeaderStartPage);
	
	Pattern.Area(4, 2).Text = FillTemplate(BottomLeftText, FooterStartPage);
	Pattern.Area(4, 3).Text = FillTemplate(BottomCenterText, FooterStartPage);
	Pattern.Area(4, 4).Text = FillTemplate(BottomRightText, FooterStartPage);
EndProcedure

&AtClient
Function RowsCountInText(Text)
	Return StrSplit(Text, Chars.LF).Count();
EndFunction

&AtClient
Function FillTemplate(Template, HomePage)
	If HomePage > PageSample Then
		Result = "";
	Else
		DateToday = CommonClient.SessionDate();
		Result = StrReplace(Template   , "[&Time]"         , Format(DateToday, "DLF=T"));
		Result = StrReplace(Result, "[&Date]"          , Format(DateToday, "DLF=D"));
		Result = StrReplace(Result, "[&ReportTitle]", NStr("en = 'Standard report';"));
		Result = StrReplace(Result, "[&User]"  , String(CurrentUser));
		Result = StrReplace(Result, "[&PageNumber]" , PageSample);
		Result = StrReplace(Result, "[&PagesTotal]"  , "9");
	EndIf;

	Return Result;
EndFunction

&AtClient
Procedure HeaderFontSettingCompletion (SelectedFont, Var_Parameters) Export
	If SelectedFont = Undefined Then
		Return;
	EndIf;
	
	FontHeader = SelectedFont;
	UpdatePreview();
EndProcedure

&AtClient
Procedure FooterFontSettingCompletion (SelectedFont, Var_Parameters) Export
	If SelectedFont = Undefined Then
		Return;
	EndIf;
	
	FontFooter = SelectedFont;
	UpdatePreview();
EndProcedure

#EndRegion