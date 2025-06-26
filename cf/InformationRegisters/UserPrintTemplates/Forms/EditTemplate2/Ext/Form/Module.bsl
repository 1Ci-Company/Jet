///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.SpreadsheetDocument <> Undefined Then
		TemplateToChange = Parameters.SpreadsheetDocument;
	EndIf;
	
	TemplateMetadataObjectName = Parameters.TemplateMetadataObjectName;
	DataSources.LoadValues(PrintManagement.TemplateDataSource(TemplateMetadataObjectName));
	NameParts = StrSplit(TemplateMetadataObjectName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	TemplateType = Parameters.TemplateType;
	TemplatePresentation = TemplatePresentation();
	TemplateFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(TemplatePresentation) + "." + Lower(TemplateType);
	
	If Parameters.OpenOnly Then
		Title = NStr("en = 'Open print form template';");
	EndIf;
	
	ClientType = ?(Common.IsWebClient(), "", "Not") + "WebClient";
	
	If Not Common.IsWebClient() And Not Common.IsMobileClient() And TemplateType = "MXL" Then
		Items.ApplyChangesLabelNotWebClient.Title = NStr(
			"en = 'Once you finish editing the template, click Apply changes';");
	EndIf;
	
	SetApplicationNameForTemplateOpening();
	
	Items.Dialog.CurrentPage = Items["DownloadToComputerPage" + ClientType];
	Items.CommandBar.CurrentPage = Items.DownloadBar;
	Items.ChangeButton.DefaultButton = True;
	
	If Common.IsMobileClient() Then 
		ClientType = "MobileClient";
	EndIf;
	WindowOptionsKey = ClientType + Upper(TemplateType);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
#If Not WebClient And Not MobileClient Then
		If Parameters.OpenOnly Then
			Cancel = True;
		EndIf;
		If Parameters.OpenOnly Or TemplateType = "MXL" Then
			OpenTemplate();
		EndIf;
#EndIf
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not IsBlankString(TempDirectoryName) Then
		BeginDeletingFiles(New NotifyDescription, TempDirectoryName);
	EndIf;
	
	If Exit Then
		Return;
	EndIf;
	
	EventName = "CancelTemplateChange";
	If TemplateImported Then
		EventName = "Write_UserPrintTemplates";
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("TemplateMetadataObjectName", TemplateMetadataObjectName);
	NotificationParameters.Insert("DataSources", DataSources.UnloadValues());
	
	Notify(EventName, NotificationParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure LinkToApplicationPageClick(Item)
	FileSystemClient.OpenURL(TemplateOpeningApplicationAddress);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Change(Command)
	OpenTemplate();
	If Parameters.OpenOnly Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure ExitAppUpdate(Command)
	
#If WebClient Or MobileClient Then
		NotifyDescription = New NotifyDescription("OnImportFile", ThisObject);
		ImportParameters = FileSystemClient.FileImportParameters();
		ImportParameters.FormIdentifier = UUID;
		FileSystemClient.ImportFile_(NotifyDescription, ImportParameters);
#Else
		If Lower(TemplateType) = "mxl" Then
			TemplateToChange.Hide();
			TemplateFileAddressInTemporaryStorage = PutToTempStorage(TemplateToChange);
			TemplateImported = True;
		Else
			File = New File(PathToTemplateFile);
			If File.Exists() Then
				BinaryData = New BinaryData(PathToTemplateFile);
				TemplateFileAddressInTemporaryStorage = PutToTempStorage(BinaryData);
				TemplateImported = True;
			EndIf;
		EndIf;
		WriteTemplateAndClose();
#EndIf
	
EndProcedure


&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetApplicationNameForTemplateOpening()
	
	ApplicationNameForTemplateOpening = "";
	
	FileType = Lower(TemplateType);
	If FileType = "mxl" Then
		ApplicationNameForTemplateOpening = NStr("en = '1C:Enterprise. File management';");
		TemplateOpeningApplicationAddress = "http://v8.1c.ru/metod/fileworkshop.htm";
	ElsIf FileType = "doc" Then
		ApplicationNameForTemplateOpening = NStr("en = 'Microsoft Word';");
		TemplateOpeningApplicationAddress = "http://office.microsoft.com/ru-ru/word";
	ElsIf FileType = "odt" Then
		ApplicationNameForTemplateOpening = NStr("en = 'OpenOffice Writer';");
		TemplateOpeningApplicationAddress = "http://www.openoffice.org/product/writer.html";
	ElsIf FileType = "docx" Then
		ApplicationNameForTemplateOpening = NStr("en = 'any editors that support Office Open XML documents';");
		TemplateOpeningApplicationAddress = "";
	EndIf;
	
	NavigateToAppPage = NStr("en = 'Open %1 installation web page';");
	NavigateToAppPage = StringFunctionsClientServer.SubstituteParametersToString(NavigateToAppPage, ApplicationNameForTemplateOpening);
	Items.LinkToApplicationPageBeforeDownloadWebClient.Title = NavigateToAppPage;
	Items.LinkToApplicationPageBeforeDownloadNotWebClient.Title = NavigateToAppPage;
	Items.LinkToApplyChangesApplicationPageWebClient.Title = NavigateToAppPage;
	Items.LinkToApplyChangesApplicationPageNotWebClient.Title = NavigateToAppPage;
	
	Items.BeforeDownloadTemplateInstructionWebClientLabel.Title = 
		NStr("en = 'Click Continue to import.';");
	Items.BeforeDownloadTemplateInstructionNotWebClientLabel.Title = 
		NStr("en = 'Click Continue to open the template in another application. Modify the template, close it, and follow further instructions.';");
	
	If Parameters.OpenOnly Then
		Items.BeforeDownloadTemplateApplicationWebClientLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Template file ""%1"" is ready to be imported and opened with an external application on your computer.
				 |
				 |If you haven''t installed the editor yet, we recommend installing %2.';"), TemplatePresentation,
				ApplicationNameForTemplateOpening);
	Else
		Items.BeforeDownloadTemplateApplicationWebClientLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Template file ""%1"" is ready to be imported and edited with an external application on your computer.
				 |
				 |If you haven''t installed the editor yet, we recommend installing %2.';"), TemplatePresentation,
				ApplicationNameForTemplateOpening);
	EndIf;
	
	Items.BeforeDownloadTemplateApplicationNotWebClientLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Template file ""%1"" is ready to be edited with an external application. If you haven''t installed the editor yet, we recommend installing %2.';"), 
		TemplatePresentation, ApplicationNameForTemplateOpening);
	
	Items.ApplyChangesLabelWebClient.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Please wait for the template file to be imported, then open and edit it.
			 |
			 |After editing, confirm the changes and close the template file. Then click ""Apply changes"" and select this file in the next dialog box.
			 |
			 |If you haven''t installed the editor yet, we recommend installing %1.';"), ApplicationNameForTemplateOpening);
	
	Items.ApplyChangesLabelNotWebClient.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Please wait for the template to be opened in the editor.
	    	 |
			 |After editing, confirm the changes and close the template. Then click ""Apply changes"".
			 |
			 |If you haven''t installed the editor yet, we recommend installing %1.';"), ApplicationNameForTemplateOpening);
		
	LinkToAplicationPageVisibility = (Common.IsWebClient() Or FileType <> "mxl") And FileType <> "docx";
	Items.LinkToApplicationPageBeforeDownloadWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplicationPageBeforeDownloadNotWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageNotWebClient.Visible = LinkToAplicationPageVisibility;
	
	Items.BeforeDownloadTemplateApplicationNotWebClientLabel.Visible = FileType <> "mxl";
	
	Items.DownloadToComputerPageWebClient.Visible = Common.IsWebClient();
	Items.UploadToInfobaseWebClientPage.Visible = Common.IsWebClient();
	Items.DownloadToComputerPageNotWebClient.Visible = Not Common.IsWebClient();
	Items.UploadToInfobaseNotWebClientPage.Visible = Not Common.IsWebClient();
	
EndProcedure

&AtServer
Function TemplatePresentation()
	
	Result = TemplateName;
	
	Owner = Common.MetadataObjectByFullName(OwnerName);
	If Owner <> Undefined Then
		Template = Owner.Templates.Find(TemplateName);
		If Template <> Undefined Then
			Result = Template.Synonym;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenTemplate()
#If WebClient Or MobileClient Then
		OpenWebClientTemplate();
#Else
		OpenThinClientTemplate();
#EndIf
EndProcedure

&AtClient
Procedure OpenThinClientTemplate()
	
	NotifyDescription = New NotifyDescription("OpenTemplateThinClientAfterCreateTempDirectory", ThisObject);
	FileSystemClient.CreateTemporaryDirectory(NotifyDescription);
	
EndProcedure

&AtClient
Procedure OpenTemplateThinClientAfterCreateTempDirectory(TempDirectoryName, AdditionalParameters) Export
	
#If Not WebClient And Not MobileClient Then
	Template = PrintFormTemplate(TemplateMetadataObjectName);
	PathToTemplateFile = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + TemplateFileName;
	
	If TemplateType = "MXL" Then
		If Parameters.OpenOnly Then
			Template.ReadOnly = True;
			Template.Show(TemplatePresentation,,True);
		Else
			Template.Write(PathToTemplateFile);
			Template.Show(TemplatePresentation, PathToTemplateFile, True);
			
			TemplateToChange = Template;
		EndIf;
	Else
		Template.Write(PathToTemplateFile);
		If Parameters.OpenOnly Then
			TemplateFile = New File(PathToTemplateFile);
			TemplateFile.SetReadOnly(True);
		EndIf;
		FileSystemClient.OpenFile(PathToTemplateFile);
	EndIf;
	
	GoToApplyChanges();
#EndIf
	
EndProcedure

&AtClient
Procedure OpenWebClientTemplate()
	FileSystemClient.SaveFile(Undefined, PutTemplateInTempStorage(), TemplateFileName);
	GoToApplyChanges();
EndProcedure

&AtServer
Function PutTemplateInTempStorage()
	
	Return PutToTempStorage(BinaryTemplateData(), UUID);
	
EndFunction

&AtServer
Function BinaryTemplateData()
	
	TemplateData1 = TemplateToChange;
	If TemplateToChange.TableHeight = 0 Then
		TemplateData1 = PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
	EndIf;
	
	If TypeOf(TemplateData1) = Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		TemplateData1.Write(TempFileName);
		TemplateData1 = New BinaryData(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Return TemplateData1;
	
EndFunction

&AtClient
Procedure GoToApplyChanges()
	Items.Dialog.CurrentPage = Items["UploadToInfobasePage" + ClientType];
	Items.CommandBar.CurrentPage = Items.ApplyChangesPanel;
	Items.ApplyChangesButton.DefaultButton = True;
EndProcedure

&AtServer
Function TemplateFromTempStorage()
	Template = GetFromTempStorage(TemplateFileAddressInTemporaryStorage); // SpreadsheetDocument, BinaryData 
	If Lower(TemplateType) = "mxl" And TypeOf(Template) <> Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		Template.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		Template = SpreadsheetDocument;
		DeleteFiles(TempFileName);
	EndIf;
	Return Template;
EndFunction

&AtServer
Procedure WriteTemplate(Template)
	Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Record.Object = OwnerName;
	Record.TemplateName = TemplateName;
	Record.Use = True;
	Record.Template = New ValueStorage(Template, New Deflation(9));
	Record.Write();
EndProcedure

&AtServerNoContext
Function PrintFormTemplate(TemplateMetadataObjectName)
	
	Template = PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
	If TypeOf(Template) = Type("SpreadsheetDocument") Or TypeOf(Template) = Type("BinaryData") Then
		Return Template;
	EndIf;
	
	Raise NStr("en = 'Cannot open this template for viewing or editing.';");
	
EndFunction

&AtClient
Procedure OnImportFile(File, AdditionalParameters) Export
	
	TemplateImported = File <> Undefined;
	If TemplateImported Then
		TemplateFileAddressInTemporaryStorage = File.Location;
		TemplateFileName = File.Name;
	EndIf;
	
	WriteTemplateAndClose();
	
EndProcedure

&AtClient
Procedure WriteTemplateAndClose()
	Template = Undefined;
	If TemplateImported Then
		Template = TemplateFromTempStorage();
		If Not ValueIsFilled(Parameters.SpreadsheetDocument) Then
			WriteTemplate(Template);
		EndIf;
	EndIf;
	
	Close(Template);
EndProcedure

#EndRegion
