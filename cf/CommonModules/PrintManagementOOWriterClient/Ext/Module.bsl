///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

////////////////////////////////////////////////////////////////////////////////
// Print using OpenDocument Text (ODT) templates on the client side. Intended for backward compatibility.
//
// The details of the reference to a print form and template.
// Structure with the following fields:
// ServiceManager - An  Open Office service manager.
// Desktop - Open Office app (the UNO service).
// Document - A document (print form).
// Type - The print form type ("ODT").
//
////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Print form initialization: create a COM object and set properties.
// 
//
Function InitializeOOWriterPrintForm(Val Template = Undefined) Export
	
	Handler = New Structure("ServiceManager,Desktop,Document,Type");
	
#If Not MobileClient Then
	
	ObjectName = "com.sun.star.ServiceManager";
	Try
		ServiceManager = New COMObject(ObjectName);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when connecting to service ""%1"".';", CommonClient.DefaultLanguageCode()), ObjectName)
			+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorText, , True);
			
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	ObjectName = "com.sun.star.frame.Desktop";
	Try
		Desktop = ServiceManager.CreateInstance(ObjectName);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when starting service ""%1"".';", CommonClient.DefaultLanguageCode()), ObjectName)
			+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorText,,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Parameters = GetComSafeArray();
	
#If Not WebClient Then
	Parameters.SetValue(0, PropertyValue1(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.LoadComponentFromURL("private:factory/swriter", "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	If Template <> Undefined Then
		TemplateStyleName = Template.Document.CurrentController.getViewCursor().PageStyleName;
		TemplateStyle = Template.Document.StyleFamilies.getByName("PageStyles").getByName(TemplateStyleName);
			
		StyleName = Document.CurrentController.getViewCursor().PageStyleName;
		Style = Document.StyleFamilies.getByName("PageStyles").getByName(StyleName);
		
		Style.TopMargin = TemplateStyle.TopMargin;
		Style.LeftMargin = TemplateStyle.LeftMargin;
		Style.RightMargin = TemplateStyle.RightMargin;
		Style.BottomMargin = TemplateStyle.BottomMargin;
	EndIf;
	
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	
#EndIf

	Return Handler;
	
EndFunction

// Returns a structure with a print form template.
//
// Parameters:
//   BinaryTemplateData1 - BinaryData - Binary template data.
// Returns:
//   Structure - Template reference.
//
Function GetOOWriterTemplate(Val BinaryTemplateData1, TempFileName) Export
	
	Handler = New Structure("ServiceManager,Desktop,Document,FileName");
	
#If Not MobileClient Then
	
	ObjectName = "com.sun.star.ServiceManager";
	Try
		ServiceManager = New COMObject(ObjectName);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when connecting to service ""%1"".';", CommonClient.DefaultLanguageCode()), ObjectName)
			+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorText, , True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	ObjectName = "com.sun.star.frame.Desktop";
	Try
		Desktop = ServiceManager.CreateInstance(ObjectName);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when starting service ""%1"".';", CommonClient.DefaultLanguageCode()), ObjectName)
			+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			ErrorText,,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If WebClient Then
	FilesDetails1 = New Array;
	FilesDetails1.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(BinaryTemplateData1)));
	TempDirectory = PrintManagementInternalClient.CreateTemporaryDirectory("OOWriter");
	If Not GetFiles(FilesDetails1, , TempDirectory, False) Then // ACC:1348 - For backward compatibility purposes.
		Return Undefined;
	EndIf;
	TempFileName = CommonClientServer.AddLastPathSeparator(TempDirectory) + TempFileName;
#Else
	TempFileName = GetTempFileName("ODT");
	BinaryTemplateData1.Write(TempFileName);
#EndIf
	
	DocumentParameters = GetComSafeArray();
#If Not WebClient Then
	DocumentParameters.SetValue(0, PropertyValue1(ServiceManager, "Hidden", True));
#EndIf
	
	// Opening parameters: Disable macros.
	RunMode = PropertyValue1(ServiceManager,
		"MacroExecutionMode",
		0); // const short NEVER_EXECUTE = 0
	DocumentParameters.SetValue(0, RunMode);
	
	Document = Desktop.LoadComponentFromURL("file:///" + StrReplace(TempFileName, "\", "/"), "_blank", 0, DocumentParameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	Handler.FileName = TempFileName;
	
#EndIf

	Return Handler;
	
EndFunction

// Closes a print form template and deletes references to the COM object.
//
Procedure CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.Document.Close(0);
	EndIf;
	
	Handler.Document = Undefined;
	Handler.Desktop = Undefined;
	Handler.ServiceManager = Undefined;
	
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	
	Handler = Undefined;
	
EndProcedure

// Sets a visibility property for OpenOffice Writer.
// 
// Parameters:
//  Handler - Structure - Print form reference.
//
Procedure ShowOOWriterDocument(Val Handler) Export
	
	ContainerWindow = Handler.Document.getCurrentController().getFrame().getContainerWindow();
	ContainerWindow.setVisible(True);
	ContainerWindow.setFocus();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Template management.

// Gets a template area.
// Parameters:
//   Handler - Template reference.
//   AreaName - Area name.
//   OffsetStart - Offset from the area start. The default offset:
//					1 - The area is taken without a newline character, after the area's opening statement parenthesis.
//					OffsetEnd - Offset from the area end. The default offset:
//   11 - Area is taken without a newline character, before the area's closing statement parenthesis.
//					
//					
//
Function GetTemplateArea(Val Handler, Val AreaName) Export
	
	Result = New Structure("Document,Start,End");
	
	Result.Start = GetAreaStartPosition(Handler.Document, AreaName);
	Result.End   = GetAreaEndPosition(Handler.Document, AreaName);
	Result.Document = Handler.Document;
	
	Return Result;
	
EndFunction

// Gets a header area.
//
Function GetHeaderArea(Val TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

// Gets a footer area.
//
Function GetFooterArea(TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Print form operations

// Inserts a line break to the next row.
// Parameters:
//   Handler - Reference to the Microsoft Word document where the line break is to be inserted.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	
	oText = Handler.Document.getText();
	oCursor = oText.createTextCursor();
	oCursor.gotoEnd(False);
	oText.insertControlCharacter(oCursor, 0, False);
	
EndProcedure

// Adds a header to a print form.
//
Procedure AddHeader(Val PrintForm,
									Val Area) Export
	
	TemplateoTxtCrsr = SetMainCursorToHeader(Area);
	While TemplateoTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorToHeader(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds a footer to a print form.
//
Procedure AddFooter(Val PrintForm,
									Val Area) Export
	
	TemplateoTxtCrsr = SetMainCursorToFooter(Area);
	While TemplateoTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorToFooter(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds an area from a template to a print form, replacing
// the area parameters with the object data values.
// The procedure is used upon output of a single area.
//
// Parameters:
//   PrintForm - Print form reference.
//   HandlerArea - Area reference.
//   GoToNextRow - Boolean - Flag indicating whether to insert a newline character after the area.
//
Procedure AttachArea(Val HandlerPrintForm,
							Val HandlerArea,
							Val GoToNextRow = True,
							Val JoinTableRow = False) Export
	
	TemplateoTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	TemplateoTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If Not JoinTableRow Then
		TemplateoTxtCrsr.goRight(1, False);
	EndIf;
	
	TemplateoTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
	If JoinTableRow Then
		DeleteRow(HandlerPrintForm);
	EndIf;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Populates parameters in a print form's table.
//
Procedure FillParameters_(PrintForm, Data) Export
	
	For Each KeyValue In Data Do
		If TypeOf(KeyValue) <> Type("Array") Then
			ReplacementString = KeyValue.Value;
			If IsTempStorageURL(ReplacementString) Then
#If WebClient Then
				TempFileName = PrintManagementInternalClient.CreateTemporaryDirectory("OOWriter")
				  + String(New UUID) + ".tmp";
#Else
				TempFileName = GetTempFileName("tmp");
#EndIf
				BinaryData = GetFromTempStorage(ReplacementString); // BinaryData - 
				BinaryData.Write(TempFileName);
				
				TextGraphicObject = PrintForm.Document.createInstance("com.sun.star.text.TextGraphicObject");
				FileURL = FileNameInURL(TempFileName);
				TextGraphicObject.GraphicURL = FileURL;
				
				Document = PrintForm.Document;
				SearchDescriptor = Document.CreateSearchDescriptor();
				SearchDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				SearchDescriptor.SearchCaseSensitive = False;
				SearchDescriptor.SearchWords = False;
				Found = Document.FindFirst(SearchDescriptor);
				While Found <> Undefined Do
					Found.GetText().InsertTextContent(Found.getText(), TextGraphicObject, True);
					Found = Document.FindNext(Found.End, SearchDescriptor);
				EndDo;
			Else
				PFoDoc = PrintForm.Document;
				PFReplaceDescriptor = PFoDoc.createReplaceDescriptor();
				PFReplaceDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				PFReplaceDescriptor.ReplaceString = String(KeyValue.Value);
				PFoDoc.replaceAll(PFReplaceDescriptor);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Adds a collection area to a print form.
//
Procedure JoinAndFillCollection(Val HandlerPrintForm,
										  Val HandlerArea,
										  Val Data,
										  Val IsTableRow = False,
										  Val GoToNextRow = True) Export
	
	TemplateoTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	TemplateoTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If Not IsTableRow Then
		TemplateoTxtCrsr.goRight(1, False);
	EndIf;
	TemplateoTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	
	For Each RowWithData In Data Do
		HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
		If IsTableRow Then
			DeleteRow(HandlerPrintForm);
		EndIf;
		FillParameters_(HandlerPrintForm, RowWithData);
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Moves the pointer to the end of DocumentRef.
//
Procedure SetMainCursorToDocumentBody(Val DocumentRef) Export
	
	oDoc = DocumentRef.Document;
	oViewCursor = oDoc.getCurrentController().getViewCursor();
	oTextCursor = oDoc.Text.createTextCursor();
	oViewCursor.gotoRange(oTextCursor, False);
	oViewCursor.gotoEnd(False);
	
EndProcedure

// Moves the pointer to the header.
//
Function SetMainCursorToHeader(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.HeaderIsOn = True;
	HeaderTextCursor = oPStyle.getPropertyValue("HeaderText").createTextCursor();
	xCursor.gotoRange(HeaderTextCursor, False);
	Return xCursor;
	
EndFunction

// Moves the pointer to the footer.
//
Function SetMainCursorToFooter(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.FooterIsOn = True;
	FooterTextCursor = oPStyle.getPropertyValue("FooterText").createTextCursor();
	xCursor.gotoRange(FooterTextCursor, False);
	Return xCursor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

// Gets a structure used to set UNO object parameters.
// 
//
Function PropertyValue1(Val ServiceManager, Val Property, Val Value)
	
	PropertyValue = ServiceManager.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
	PropertyValue.Name = Property;
	PropertyValue.Value = Value;
	
	Return PropertyValue;
	
EndFunction

Function GetAreaStartPosition(Val xDocument, Val AreaName)
	
	SearchText = "{v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = SearchText;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'Cannot find where template begins:';") + " " + AreaName;	
	EndIf;
	Return xFound.End;
	
EndFunction

Function GetAreaEndPosition(Val xDocument, Val AreaName)
	
	SearchText = "{/v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = SearchText;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'Cannot find where template ends:';") + " " + AreaName;	
	EndIf;
	Return xFound.Start;
	
EndFunction

Procedure DeleteRow(HandlerPrintForm)
	
	oFrame = HandlerPrintForm.Document.getCurrentController().Frame;
	
	dispatcher = HandlerPrintForm.ServiceManager.CreateInstance ("com.sun.star.frame.DispatchHelper");
	
	oViewCursor = HandlerPrintForm.Document.getCurrentController().getViewCursor();
	
	dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	EndDo;
	
	dispatcher.executeDispatch(oFrame, ".uno:Delete", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoDown", "", 0, GetComSafeArray());
	EndDo;
	
EndProcedure

Function GetComSafeArray()
	
#If WebClient Then
	scr = New COMObject("MSScriptControl.ScriptControl");
	scr.language = "javascript";
	scr.eval("Array=new Array()");
	Return scr.eval("Array");
#ElsIf Not MobileClient Then
	Return New COMSafeArray("VT_DISPATCH", 1);
#EndIf
	Return Undefined;
	
EndFunction

Function EventLogEvent()
	Return NStr("en = 'Print';");
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Or MobileClient Then
	ClarificationText = NStr("en = 'Use thin client to generate this print from.';");
#Else
	ClarificationText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
		"en = 'To output print forms in %1 format, %2 must be installed.';"),
		"OpenOffice.org Writer", "OpenOffice.org");
#EndIf
	ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot generate print form: %1.
			|%2';"),
		ErrorProcessing.BriefErrorDescription(ErrorInfo), ClarificationText);
	Raise ExceptionText;
EndProcedure

Function FileNameInURL(Val FileName)
	FileName = StrReplace(FileName, " ", "%20");
	FileName = StrReplace(FileName, "\", "/"); 
	Return "file:/" + "/localhost/" + FileName; 
EndFunction

#EndRegion