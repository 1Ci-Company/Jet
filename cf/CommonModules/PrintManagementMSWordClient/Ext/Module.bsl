///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Creates a COM connection to a Word.Application COM object and creates a single document in it.
// 
//
Function InitializeMSWordPrintForm(Template) Export
	
	Handler = New Structure("Type", "DOC");
	
#If Not MobileClient Then
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Handler.Insert("COMJoin", COMObject);
	Try
		COMObject.Documents.Add();
	Except
		COMObject.Quit(0);
		COMObject = 0;
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	TemplatePagesSettings = Template; // Intended for backward compatibility (the type of the input parameter was changed).
	If TypeOf(Template) = Type("Structure") Then
		TemplatePagesSettings = Template.TemplatePagesSettings;
		// Copy styles from the template.
		Template.COMJoin.ActiveDocument.Close();
		Handler.COMJoin.ActiveDocument.CopyStylesFromTemplate(Template.FileName);
		
		Template.COMJoin.WordBasic.DisableAutoMacros(1);
		Template.COMJoin.Documents.Open(Template.FileName);
	EndIf;
	
	// Copy page settings.
	If TemplatePagesSettings <> Undefined Then
		For Each Setting In TemplatePagesSettings Do
			Try
				COMObject.ActiveDocument.PageSetup[Setting.Key] = Setting.Value;
			Except
				// Skip if the setting is not supported in this application version.
			EndTry;
		EndDo;
	EndIf;
	// Remember the document view kind.
	Handler.Insert("ViewType", COMObject.Application.ActiveWindow.View.Type);
	
#EndIf

	Return Handler;
	
EndFunction

// Creates a COM connection to a Word.Application COM object and opens
// a template in it. The template file is saved based on the binary data
// passed in the function parameters.
//
// Parameters:
//   BinaryTemplateData - BinaryData - Binary template data.
// Returns:
//   Structure - Template reference.
//
Function GetMSWordTemplate(Val BinaryTemplateData, Val TempFileName) Export
	
	Handler = New Structure("Type", "DOC");
#If Not MobileClient Then
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If WebClient Then
	FilesDetails1 = New Array;
	FilesDetails1.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(BinaryTemplateData)));
	TempDirectory = PrintManagementInternalClient.CreateTemporaryDirectory("MSWord");
	If Not GetFiles(FilesDetails1, , TempDirectory, False) Then // ACC:1348 - For backward compatibility purposes.
		Return Undefined;
	EndIf;
	TempFileName = CommonClientServer.AddLastPathSeparator(TempDirectory) + TempFileName;
#Else
	TempFileName = GetTempFileName("DOC");
	BinaryTemplateData.Write(TempFileName);
#EndIf
	
	Try
		COMObject.WordBasic.DisableAutoMacros(1);
		COMObject.Documents.Open(TempFileName);
	Except
		COMObject.Quit(0);
		COMObject = 0;
		DeleteFiles(TempFileName);
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
		Raise(NStr("en = 'Cannot open template file. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Handler.Insert("COMJoin", COMObject);
	Handler.Insert("FileName", TempFileName);
	Handler.Insert("IsTemplate", True);
	
	Handler.Insert("TemplatePagesSettings", New Map);
	
	For Each SettingName In PageParametersSettings() Do
		Try
			Handler.TemplatePagesSettings.Insert(SettingName, COMObject.ActiveDocument.PageSetup[SettingName]);
		Except
			// Skip if the setting is not supported in this application version.
		EndTry;
	EndDo;
#EndIf
	
	Return Handler;
	
EndFunction

// Closes connection to the Word.Application COM object.
// Parameters:
//   Handler - Reference to a print form or a template.
//   CloseApplication - Boolean - Flag indicating whether the application must be closed.
//
Procedure CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.COMJoin.Quit(0);
	EndIf;
	
	Handler.COMJoin = 0;
	
#If Not WebClient Then
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
#EndIf
	
EndProcedure

// Sets a visibility property for the Microsoft Word application.
// 
// Parameters:
//  Handler - Structure - Print form reference.
//
Procedure ShowMSWordDocument(Val Handler) Export
	
	COMJoin = Handler.COMJoin;
	COMJoin.Application.Selection.Collapse();
	
	// Restore the document view kind.
	If Handler.Property("ViewType") Then
		COMJoin.Application.ActiveWindow.View.Type = Handler.ViewType;
	EndIf;
	
	COMJoin.Application.Visible = True;
	COMJoin.Activate();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for getting areas from a template.

// Gets an area from a template.
//
// Parameters:
//  Handler - Template reference.
//  AreaName - Name of the template area.
//  OffsetStart    - Number - Overrides an area start boundary when the area doesn't begin right after the statement,
//                              but is separated by one or more characters.
//                              By default, 1 (a newline character is expected after the statement parenthesis of the area opening, 
//                                                         the newline character is not to be included in the area).
//                                                         
//  OffsetEnd - Number - Overrides an area start boundary when the area doesn't end right before the statement,
//                              but one or more characters before it. 
//                              By default, -1 (a newline character is expected before the statement parenthesis of the area end,
//                              the newline character is not to be included in the area).
//                                                         
//                                                         
//
Function GetMSWordTemplateArea(Val Handler,
									Val AreaName,
									Val OffsetStart = 1,
									Val OffsetEnd = -1) Export
	
	Result = New Structure("Document,Start,End");
	
	PositionStart = OffsetStart + GetAreaStartPosition(Handler.COMJoin, AreaName);
	PositionEnd1 = OffsetEnd + GetAreaEndPosition(Handler.COMJoin, AreaName);
	
	If PositionStart >= PositionEnd1 Or PositionStart < 0 Then
		Return Undefined;
	EndIf;
	
	Result.Document = Handler.COMJoin.ActiveDocument;
	Result.Start = PositionStart;
	Result.End   = PositionEnd1;
	
	Return Result;
	
EndFunction

// Gets a header area of the first template area.
// Parameters:
//   Handler - Template reference.
// Returns:
//   Header reference.
//
Function GetHeaderArea(Val Handler) Export
	
	Return New Structure("Header", Handler.COMJoin.ActiveDocument.Sections(1).Headers.Item(1));
	
EndFunction

// Gets a footer area of the first template area.
// Parameters:
//   Handler - Template reference.
// Returns:
//   Footer reference.
//
Function GetFooterArea(Handler) Export
	
	Return New Structure("Footer", Handler.COMJoin.ActiveDocument.Sections(1).Footers.Item(1));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for adding areas to the print form.

// Start: Operations with Microsoft Word document headers and footers.

// Adds a footer from a template to a print form.
// Parameters:
//   PrintForm - Structure - Print form reference.
//   HandlerArea - COMObject - Reference to a template area.
//
Procedure AddFooter(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Footer.Range.Copy();
	Footer(PrintForm).Paste();
	
EndProcedure

// Adds a header from a template to a print form.
// Parameters:
//   PrintForm - Print form reference.
//   AreaHandler - Template area reference.
//   Parameters - List of parameters to be replaced with values.
//   ObjectData - Object data for filling.
//
Procedure FillFooterParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue1 In ObjectData Do
		If TypeOf(ParameterValue1.Value) <> Type("Array") Then
			Replace(Footer(PrintForm), ParameterValue1.Key, ParameterValue1.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Footer(PrintForm)
	Return PrintForm.COMJoin.ActiveDocument.Sections(1).Footers.Item(1).Range;
EndFunction

// Adds a header from a template to a print form.
// Parameters:
//   PrintForm - Print form reference.
//   HandlerArea - Reference to an area in the template.
//   Parameters - List of parameters to be replaced with values.
//   ObjectData - Data for filling.
//
Procedure AddHeader(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Header.Range.Copy();
	Header(PrintForm).Paste();
	
EndProcedure

// Adds a header from a template to a print form.
// Parameters:
//   PrintForm - Print form reference.
//   AreaHandler - Template area reference.
//   Parameters - List of parameters to be replaced with values.
//   ObjectData - Object data for filling.
//
Procedure FillHeaderParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue1 In ObjectData Do
		If TypeOf(ParameterValue1.Value) <> Type("Array") Then
			Replace(Header(PrintForm), ParameterValue1.Key, ParameterValue1.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Header(PrintForm)
	Return PrintForm.COMJoin.ActiveDocument.Sections(1).Headers.Item(1).Range;
EndFunction

// End: Operations with Microsoft Word document headers and footers.

// Adds an area from a template to a print form, replacing
// the area parameters with the object data values.
// The procedure is used upon output of a single area.
//
// Parameters:
//   PrintForm - Print form reference.
//   HandlerArea - Reference to a template area.
//   GoToNextRow - Boolean - Flag indicating whether to insert a newline character after the area.
//
// Returns:
//   Structure:
//    * Document - COMObject
//    * Start - Number
//    * End - Number
//
Function AttachArea(Val PrintForm,
							Val HandlerArea,
							Val GoToNextRow = True,
							Val JoinTableRow = False) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	PFActiveDocument = PrintForm.COMJoin.ActiveDocument;
	DocumentEndPosition	= PFActiveDocument.Range().End;
	InsertionArea				= PFActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1);
	
	If JoinTableRow Then
		InsertionArea.PasteAppendTable();
	Else
		InsertionArea.Paste();
	EndIf;
	
	// Return boundaries of the inserted area.
	Result = New Structure("Document, Start, End",
							PFActiveDocument,
							DocumentEndPosition-1,
							PFActiveDocument.Range().End-1);
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return Result;
	
EndFunction

// Adds a list area from a template to a print form, replacing
// the area parameters with the values from the object data.
// It is applied upon list data output (bullet or numbered list).
//
// Parameters:
//   PrintFormArea - COMObject - Reference a print form area.
//   ObjectData - Structure
//
Procedure FillParameters_(Val PrintFormArea, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue1 In ObjectData Do
		If TypeOf(ParameterValue1.Value) <> Type("Array") Then
			Replace(PrintFormArea.Document.Content, ParameterValue1.Key, ParameterValue1.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Start: Operations with collections.

// Adds a list area from a template to a print form, replacing
// the area parameters with the values from the object data.
// It is applied upon list data output (bullet or numbered list).
//
// Parameters:
//   PrintForm - Structure - Print form reference.
//   HandlerArea - COMObject - Area reference.
//   Parameters - String - List of parameters to be replaced.
//   ObjectData - Array of Structure
//   GoToNextRow - Boolean - Flag indicating whether to insert a newline character after the area.
//
Procedure JoinAndFillSet(Val PrintForm,
									  Val HandlerArea,
									  Val ObjectData = Undefined,
									  Val GoToNextRow = True) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMJoin.ActiveDocument;
	
	If ObjectData <> Undefined Then
		For Each RowData In ObjectData Do
			InsertPosition = ActiveDocument.Range().End;
			InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
			InsertionArea.Paste();
			
			If TypeOf(RowData) = Type("Structure") Then
				For Each ParameterValue1 In RowData Do
					Replace(ActiveDocument.Content, ParameterValue1.Key, ParameterValue1.Value);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Adds a list area from a template to a print form, replacing
// the area parameters with the values from the object data.
// Used when outputting a table row.
//
// Parameters:
//   PrintForm - Structure - Print form reference.
//   HandlerArea - COMObject - Area reference.
//   TableName - Table name (for data access).
//   ObjectData - Structure
//   GoToNextRow - Boolean - Flag indicating whether to insert a newline character after the area.
//
Procedure JoinAndFillTableArea(Val PrintForm,
												Val HandlerArea,
												Val ObjectData = Undefined,
												Val GoToNextRow = True) Export
	
	If ObjectData = Undefined Or ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	FirstRow = True;
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMJoin.ActiveDocument;
	
	// Insert the first row (the following rows will inherit its formatting).
	// 
	InsertBreakAtNewLine(PrintForm); 
	InsertPosition = ActiveDocument.Range().End;
	InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
	InsertionArea.Paste();
	ActiveDocument.Range(InsertPosition-2, InsertPosition-2).Delete();
	
	If TypeOf(ObjectData[0]) = Type("Structure") Then
		For Each ParameterValue1 In ObjectData[0] Do
			Replace(ActiveDocument.Content, ParameterValue1.Key, ParameterValue1.Value);
		EndDo;
	EndIf;
	
	For Each TableRowData In ObjectData Do
		If FirstRow Then
			FirstRow = False;
			Continue;
		EndIf;
		
		NewInsertionPosition = ActiveDocument.Range().End;
		ActiveDocument.Range(InsertPosition-1, ActiveDocument.Range().End-1).Select();
		PrintForm.COMJoin.Selection.InsertRowsBelow();
		
		ActiveDocument.Range(NewInsertionPosition-1, ActiveDocument.Range().End-2).Select();
		PrintForm.COMJoin.Selection.Paste();
		InsertPosition = NewInsertionPosition;
		
		If TypeOf(TableRowData) = Type("Structure") Then
			For Each ParameterValue1 In TableRowData Do
				Replace(ActiveDocument.Content, ParameterValue1.Key, ParameterValue1.Value);
			EndDo;
		EndIf;
		
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// End: Operations with collections.

// Inserts a line break to the next line.
// Parameters:
//   Handler - Reference to the Microsoft Word document where the line break is to be inserted.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	ActiveDocument = Handler.COMJoin.ActiveDocument;
	DocumentEndPosition = ActiveDocument.Range().End;
	ActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1).InsertParagraphAfter();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

Function GetAreaStartPosition(Val COMJoin, Val AreaID)
	
	AreaID = "{v8 Area." + AreaID + "}";
	
	EntireDocument = COMJoin.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMJoin.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMJoin.Selection.End;
	EndIf;
	
	Return -1;
	
EndFunction

Function GetAreaEndPosition(Val COMJoin, Val AreaID)
	
	AreaID = "{/v8 Area." + AreaID + "}";
	
	EntireDocument = COMJoin.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMJoin.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMJoin.Selection.Start;
	EndIf;
	
	Return -1;

	
EndFunction

Function PageParametersSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("Orientation");
	SettingsArray.Add("TopMargin");
	SettingsArray.Add("BottomMargin");
	SettingsArray.Add("LeftMargin");
	SettingsArray.Add("RightMargin");
	SettingsArray.Add("Gutter");
	SettingsArray.Add("HeaderDistance");
	SettingsArray.Add("FooterDistance");
	SettingsArray.Add("PageWidth");
	SettingsArray.Add("PageHeight");
	SettingsArray.Add("FirstPageTray");
	SettingsArray.Add("OtherPagesTray");
	SettingsArray.Add("SectionStart");
	SettingsArray.Add("OddAndEvenPagesHeaderFooter");
	SettingsArray.Add("DifferentFirstPageHeaderFooter");
	SettingsArray.Add("VerticalAlignment");
	SettingsArray.Add("SuppressEndnotes");
	SettingsArray.Add("MirrorMargins");
	SettingsArray.Add("TwoPagesOnOne");
	SettingsArray.Add("BookFoldPrinting");
	SettingsArray.Add("BookFoldRevPrinting");
	SettingsArray.Add("BookFoldPrintingSheets");
	SettingsArray.Add("GutterPos");
	
	Return SettingsArray;
	
EndFunction

Function EventLogEvent()
	Return NStr("en = 'Print';", CommonClient.DefaultLanguageCode());
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Or MobileClient Then
	ClarificationText = NStr("en = 'Use thin client to generate this print from.';");
#Else		
	ClarificationText = NStr("en = 'To output print forms in MS Word formats, Microsoft Office must be installed.';");
#EndIf
	ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot generate print form: %1.
			|%2';"),
		ErrorProcessing.BriefErrorDescription(ErrorInfo), ClarificationText);
	Raise ExceptionText;
EndProcedure

Procedure Replace(Object, Val SearchString, Val ReplacementString)
	
	SearchString = "{v8 " + SearchString + "}";
	ReplacementString = String(ReplacementString);
	
	Object.Select();
	Selection = Object.Application.Selection;
	
	FindObject = Selection.Find;
	FindObject.ClearFormatting();
	While FindObject.Execute(SearchString) Do
		If IsBlankString(ReplacementString) Then
			Selection.Delete();
		ElsIf IsTempStorageURL(ReplacementString) Then
			Selection.Delete();
			TempDirectory = PrintManagementInternalClient.CreateTemporaryDirectory("MSWord");
#If WebClient Then
			TempFileName = TempDirectory + String(New UUID) + ".tmp";
#Else
			TempFileName = GetTempFileName("tmp");
#EndIf
			
			FilesDetails1 = New Array;
			FilesDetails1.Add(New TransferableFileDescription(TempFileName, ReplacementString));
			If GetFiles(FilesDetails1, , TempDirectory, False) Then // ACC:1348 - For backward compatibility purposes.
				Selection.Range.InlineShapes.AddPicture(TempFileName);
			Else
				Selection.TypeText("");
			EndIf;
		Else
			Selection.TypeText(ReplacementString);
		EndIf;
	EndDo;
	
	Selection.Collapse();
	
EndProcedure

#EndRegion
