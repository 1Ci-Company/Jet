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
	
	ArchiveExtension = ".zip";
	FileNameWithoutExtension = "ReportOptions";
	
	FillInTheDescriptionOfTheReportOptions();
	ReadUserSettings();
	
	SetConditionalAppearance(); 
	
	If ReportsOptionsDetails.Count() = 0 Then
		Items.Save.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Handler = New NotifyDescription("AfterFileSystemExtensionInstallation", ThisObject);
	FileSystemClient.AttachFileOperationsExtension(Handler, SuggestionText());
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FileNameOnChange(Item)
	
	If Not ValueIsFilled(FileName) Then 
		Return;
	EndIf;
	
	CheckTheFileName();
	CheckTheFolderName();
	
EndProcedure

&AtClient
Procedure CheckTheFileName()
	
	If ReportsOptionsDetails.Count() > 1 Then 
		Return;
	EndIf;
	
	FileNameDetails = StrSplit(FileName, GetPathSeparator());
	
	ShortFileName = FileNameDetails[FileNameDetails.UBound()];
	
	If Lower(ShortFileName) = ArchiveExtension Then 
		
		ShortFileName = FileNameWithoutExtension + ArchiveExtension;
		FileNameDetails[FileNameDetails.UBound()] = ShortFileName;
		FileName = StrConcat(FileNameDetails, GetPathSeparator());
		
	ElsIf Not StrEndsWith(Lower(ShortFileName), ArchiveExtension) Then 
		
		ShortFileName = FileNameWithoutExtension + ArchiveExtension;
		FileNameDetails.Add(ShortFileName);
		FileName = StrConcat(FileNameDetails, GetPathSeparator());
		
	Else
		
		FileNameWithoutExtension = StrReplace(ShortFileName, ArchiveExtension, "");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckTheFolderName()
	
	If StrEndsWith(Lower(FileName), ArchiveExtension) Then 
		
		FileNameDetails = StrSplit(FileName, GetPathSeparator());
		FileNameDetails.Delete(FileNameDetails.UBound());
		
		PathToDirectory = StrConcat(FileNameDetails, GetPathSeparator());
		
	Else
		PathToDirectory = FileName;
	EndIf;
	
	FileNameAfterDirectoryChoice(PathToDirectory, Undefined);
	
EndProcedure

&AtClient
Procedure FileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectDirectory();
	
EndProcedure

&AtClient
Procedure DirectoryNameOnChange(Item)
	
	DirectoryName = CommonClientServer.AddLastPathSeparator(DirectoryName);
	SetFileNames();
	
EndProcedure

&AtClient
Procedure DirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectDirectory();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersUserSettings

&AtClient
Procedure UserSettingsOnChange(Item)
	
	If ReportsOptionsDetails.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentUserSettings = PersonalSettings.FindByValue(
		ReportsOptionsDetails[0].UserSettingsKey);
	
	If CurrentUserSettings <> Undefined Then 
		CurrentUserSettings.Check = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReportsOptionsDetails

&AtClient
Procedure ReportsOptionsDetailsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ReportsOptionsDetailsAfterDeleteRow(Item)
	
	SetFileNames();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command) 
	
	If ReportsOptionsDetails.Count() = 0 Then
		Return;
	EndIf;
	
	PackageReportOptionsSettings();
	
	If Not ValueIsFilled(FileName) Then 
		SetFileNames();
	EndIf;
	
	Handler = New NotifyDescription("CompressReportOptionSettingsCompletion", ThisObject);
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.SuggestionText = SuggestionText();
	SavingParameters.Dialog.Filter = NStr("en = 'Archive (*.zip)|*.zip';");
	SavingParameters.Dialog.Title = NStr("en = 'Select file';");
	SavingParameters.Dialog.FullFileName = FileName;
	
	For Each ReportOptionDetails In ReportsOptionsDetails Do 
		
		FileSystemClient.SaveFile(
			Handler, ReportOptionDetails.ArchiveStorageAddress, ReportOptionDetails.FileName, SavingParameters);
		
	EndDo;
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserSettingsValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PersonalSettings.Presentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "[IsCurrentSettings]";
	
	FontImportantLabel = Metadata.StyleItems.ImportantLabelFont;
	Item.Appearance.SetParameterValue("Font", FontImportantLabel.Value);     
	If ReportsOptionsDetails.Count() > 0 Then
		Item.Appearance.SetParameterValue("Text", ReportsOptionsDetails[0].UserSettingsPresentation);
	EndIf;
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserSettingsCheckBox.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PersonalSettings.Presentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "[IsCurrentSettings]";
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtServer
Procedure FillInTheDescriptionOfTheReportOptions()
	
	If Parameters.SelectedReportsOptions <> Undefined Then 
		
		DataOfReportVariants = Common.ObjectsAttributesValues(
			Parameters.SelectedReportsOptions, "Report, VariantKey, Presentation, Settings, ReportType");
		
		TheSubsystemAdditionalReportsAndProcessingExists = Common.SubsystemExists(
			"StandardSubsystems.AdditionalReportsAndDataProcessors");
		
		ModuleAdditionalReportsAndDataProcessors = Undefined;
		
		If TheSubsystemAdditionalReportsAndProcessingExists Then 
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		EndIf;
		
		For Each DataOfTheReportVariant In DataOfReportVariants Do 
			
			FillReportOptionDetails(
				DataOfTheReportVariant.Key,
				DataOfTheReportVariant.Value,
				TheSubsystemAdditionalReportsAndProcessingExists,
				ModuleAdditionalReportsAndDataProcessors);
			
		EndDo;
		
	Else
		
		ReportOptionDetails = ReportsOptionsDetails.Add();
		FillPropertyValues(ReportOptionDetails, Parameters);
		
	EndIf;
	
	If ReportsOptionsDetails.Count() > 1 Then
		
		Items.SaveOptions.CurrentPage = Items.MultipleReportsOptions;
		Title = NStr("en = 'Save report options to file';");
		
	ElsIf ReportsOptionsDetails.Count() = 1 Then
		
		Items.SaveOptions.CurrentPage = Items.OneReportOption;
		Title = NStr("en = 'Save report option to file';");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillReportOptionDetails(ReportVariant, DataOfTheReportVariant,
	TheSubsystemAdditionalReportsAndProcessingExists, ModuleAdditionalReportsAndDataProcessors)
	
	If DataOfTheReportVariant.ReportType = Enums.ReportsTypes.Additional
		And Not TheSubsystemAdditionalReportsAndProcessingExists Then 
		
		Return;
	EndIf;
	
	ReportOptionDetails = ReportsOptionsDetails.Add();
	ReportOptionDetails.Ref = ReportVariant;
	
	If DataOfTheReportVariant.ReportType = Enums.ReportsTypes.Additional Then 

		ReportOptionDetails.ReportName = StringFunctionsClientServer.SubstituteParametersToString(
			"ExternalReport.%1", Common.ObjectAttributeValue(DataOfTheReportVariant.Report, "ObjectName"));
	Else
		MetadataOfReport = Common.MetadataObjectByID(DataOfTheReportVariant.Report);
		ReportOptionDetails.ReportName = MetadataOfReport.FullName();
	EndIf;
	
	ReportOptionDetails.VariantKey = DataOfTheReportVariant.VariantKey;
	ReportOptionDetails.VariantPresentation = DataOfTheReportVariant.Presentation;
	
	ObjectKey = ReportOptionDetails.ReportName
		+ "/" + ReportOptionDetails.VariantKey
		+ "/" + "CurrentUserSettingsKey";
	
	Filter = New Structure("ObjectKey, User", ObjectKey, UserName());
	Selection = SystemSettingsStorage.Select(Filter);
	
	If Selection.Next() Then 
		ReportOptionDetails.UserSettingsKey = Selection.Settings;
	EndIf;
	
	ReportOptionDetails.Settings = DataOfTheReportVariant.Settings.Get();
	
	If ReportOptionDetails.Settings <> Undefined Then 
		Return;
	EndIf;
	
	If DataOfTheReportVariant.ReportType = Enums.ReportsTypes.Additional Then 
		Report = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(DataOfTheReportVariant.Report);
	Else
		Report = ReportsServer.ReportObject(ReportOptionDetails.ReportName);
	EndIf;
	
	If Report.DataCompositionSchema = Undefined Then 
		ReportsOptionsDetails.Delete(ReportOptionDetails);
		Common.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Report option ""%1"" cannot be saved.';"), DataOfTheReportVariant.Presentation));
		Return;
	EndIf;
	
	ReportOptionDetails.Settings =
		Report.DataCompositionSchema.SettingVariants[ReportOptionDetails.VariantKey].Settings;
	
EndProcedure

&AtServer
Procedure ReadUserSettings()
	
	If ReportsOptionsDetails.Count() <> 1 Then 
		Return;
	EndIf;
	
	ReportOptionDetails = ReportsOptionsDetails[0];
	
	ObjectKey = ReportOptionDetails.ReportName + "/" + ReportOptionDetails.VariantKey;
	Filter = New Structure("ObjectKey, User", ObjectKey, UserName());
	
	Selection = ReportsUserSettingsStorage.Select(Filter);
	While Selection.Next() Do 
		
		PersonalSettings.Add(Selection.SettingsKey, Selection.Presentation);
		FillPropertyValues(UserSettingsStorage.Add(), Selection);
		
	EndDo;
	
	CurrentUserSettings = PersonalSettings.FindByValue(ReportOptionDetails.UserSettingsKey);
	If CurrentUserSettings = Undefined Then 
		Items.CommandBarPersonalSettings.Visible = False;
		Items.PersonalSettings.ReadOnly = True;
		Items.PersonalSettings.Enabled = False;
		PersonalSettings.Add("", NStr("en = 'The report has no personal settings.';"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(ReportOptionDetails.UserSettingsPresentation) Then 
		ReportOptionDetails.UserSettingsPresentation = CurrentUserSettings.Presentation;
	EndIf;
	
	CurrentUserSettings.Check = True;
	CurrentUserSettings.Presentation = CurrentUserSettings.Presentation + " [IsCurrentSettings]";
	
	IndexOf = PersonalSettings.IndexOf(CurrentUserSettings);
	If IndexOf > 0 Then 
		PersonalSettings.Move(CurrentUserSettings, -IndexOf);
	EndIf;
	
EndProcedure

&AtClient
Procedure FileNameAfterDirectoryChoice(PathToDirectory, AdditionalParameters) Export 
	
	If ValueIsFilled(PathToDirectory) Then 
		
		DirectoryName = CommonClientServer.AddLastPathSeparator(PathToDirectory);
		SetFileNames();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure PackageReportOptionsSettings()
	
	For Each ReportOptionDetails In ReportsOptionsDetails Do 
		CompressReportOptionSettings(ReportOptionDetails);
	EndDo;
	
EndProcedure

&AtServer
Procedure CompressReportOptionSettings(ReportOptionDetails)
	
	TempDirectoryName = FileSystem.CreateTemporaryDirectory();
	If Not ValueIsFilled(TempDirectoryName) Then 
		Return;
	EndIf;
	
	TempDirectoryName = CommonClientServer.AddLastPathSeparator(TempDirectoryName);
	ArchiveFileName = GetTempFileName("zip");
	
	Archive = New ZipFileWriter(ArchiveFileName);
	
	AddSettingsToArchive(Archive, ReportOptionDetails.Settings, TempDirectoryName, "Settings");
	AddSettingsDetailsToArchive(Archive, TempDirectoryName, ReportOptionDetails);
	
	Counter = 0;
	Search = New Structure("SettingsKey");
	
	For Each ListItem In PersonalSettings Do 
		
		If Not ListItem.Check Then 
			Continue;
		EndIf;
		
		Counter = Counter + 1;
		Search.SettingsKey = ListItem.Value;
		
		FoundSettings = UserSettingsStorage.FindRows(Search);
		AddSettingsToArchive(Archive, FoundSettings[0].Settings, TempDirectoryName, "UserSettings", Counter);
		
	EndDo;
	
	Archive.Write();
	
	BinaryData = New BinaryData(ArchiveFileName);
	ReportOptionDetails.ArchiveStorageAddress = PutToTempStorage(BinaryData, New UUID);
	
	FileSystem.DeleteTemporaryDirectory(TempDirectoryName);
	FileSystem.DeleteTempFile(ArchiveFileName);
	
EndProcedure

&AtClient
Procedure CompressReportOptionSettingsCompletion(Files, AdditionalParameters) Export 
	
	If TypeOf(Files) <> Type("Array")
		Or Files.Count() = 0 Then 
		
		Return;
	EndIf;
	
	If ReportsOptionsDetails.Count() = 1 Then 
		Explanation = FileName;
	Else
		Explanation = DirectoryName;
	EndIf;
	
	ShowUserNotification(NStr("en = 'Report option saved to file';"),, Explanation);
	
EndProcedure

&AtServer
Procedure AddSettingsToArchive(Archive, Settings, TempDirectoryName, SettingsType1, Suffix = Undefined)
	
	SettingsFileName = TempDirectoryName + SettingsType1 + ?(Suffix = Undefined, "", Suffix) + ".xml";
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(SettingsFileName);
	
	XDTOSerializer.WriteXML(XMLWriter, Settings, XMLTypeAssignment.Explicit);
	
	XMLWriter.Close();
	
	Archive.Add(SettingsFileName);
	
EndProcedure

// Adds an XML file of details of report option settings to a ZIP archive with the following specification:
//  <SettingsDescription ReportName="Отчет.Файлы">
//  	<Settings Key="50a4127a-7646-49b3-9d09-51681e6e16b9" Presentation="Версии файлов"/>
//  	<UserSettings Key="a61e745b-ac46-46d3-92a6-5bba4969b7d2" Presentation="Files > 100 KB" isCurrent="true"/>
//  	<UserSettings Key="6895ac09-f02d-4b17-82b6-79dd76c7b2a3" Presentation="Files > 10 MB" isCurrent="false"/>
//  </SettingsDescription>
//
// Parameters:
//  Archive - ZipFileWriter - Archive to add report option settings and details to.
//  TempDirectoryName - String - Name of the temporary directory containing XML files of report option settings and details.
//
&AtServer
Procedure AddSettingsDetailsToArchive(Archive, TempDirectoryName, ReportOptionDetails)
	
	SettingsDetailsFileName = TempDirectoryName + "SettingsDescription.xml";
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(SettingsDetailsFileName);
	
	XMLWriter.WriteStartElement("SettingsDescription");
	
		XMLWriter.WriteAttribute("ReportName", ReportOptionDetails.ReportName);
	
		XMLWriter.WriteStartElement("Settings");
		
			XMLWriter.WriteAttribute("Key", ReportOptionDetails.VariantKey);
			XMLWriter.WriteAttribute("Presentation", ReportOptionDetails.VariantPresentation);
		
		XMLWriter.WriteEndElement(); // <Settings>
	
		For Each ListItem In PersonalSettings Do 
			
			If Not ListItem.Check Then 
				Continue;
			EndIf;
			
			SettingPresentation = TrimAll(StrReplace(ListItem.Presentation, "[IsCurrentSettings]", ""));   
			If ReportsOptionsDetails.Count() > 0 Then
				IsCurrentSettings = SettingPresentation = ReportsOptionsDetails[0].UserSettingsPresentation;
			EndIf;
			
			XMLWriter.WriteStartElement("UserSettings");
			
			XMLWriter.WriteAttribute("Key", ListItem.Value);
			XMLWriter.WriteAttribute("Presentation", SettingPresentation);
			XMLWriter.WriteAttribute("isCurrent", XMLString(IsCurrentSettings));
			
			XMLWriter.WriteEndElement(); // <UserSettings>
			
		EndDo;
	
	XMLWriter.WriteEndElement(); // <SettingsDescription>
	XMLWriter.Close();
	
	Archive.Add(SettingsDetailsFileName);
	
EndProcedure

&AtClient
Procedure SelectDirectory()
	
	FileSystemClient.SelectDirectory(New NotifyDescription("FileNameAfterDirectoryChoice", ThisObject));
	
EndProcedure

&AtClient
Procedure AfterFileSystemExtensionInstallation(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached = True Then 
		
		Handler = New NotifyDescription("AfterGetDocumentsDir", ThisObject);
		BeginGettingDocumentsDir(Handler);
		
	ElsIf Not ValueIsFilled(FileName) Then 
		
		SetFileNames();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGetDocumentsDir(DocumentsDirName, AdditionalParameters) Export 
	
	If Not ValueIsFilled(DocumentsDirName) Then 
		Return;
	EndIf;
	
	If ReportsOptionsDetails.Count() > 1 Then 
		
		DirectoryName = CommonClientServer.AddLastPathSeparator(
			StringFunctionsClientServer.SubstituteParametersToString("%1ReportsOptions", DocumentsDirName));
	Else 
		DirectoryName = DocumentsDirName;
	EndIf;
	
	SetFileNames();
	
EndProcedure

&AtClient
Procedure SetFileNames()
	
	NumberOfReportOptions = ReportsOptionsDetails.Count();
	
	If NumberOfReportOptions = 0 Then 
		Return;
	EndIf;
	
	For NumberOfTheReportVariant = 1 To NumberOfReportOptions Do 
		
		ReportOptionDetails = ReportsOptionsDetails[NumberOfTheReportVariant - 1];
		ReportOptionDetails.FileName = DirectoryName
			+ FileNameWithoutExtension
			+ ?(ReportsOptionsDetails.Count() = 1, "", NumberOfTheReportVariant)
			+ ArchiveExtension;
		
		ReportOptionDetails.ShortFileName = StrReplace(ReportOptionDetails.FileName, DirectoryName, "");
		
	EndDo;
	
	If NumberOfReportOptions > 0 Then
		FileName = ReportsOptionsDetails[0].FileName;
	EndIf;
	
EndProcedure

&AtClient
Function SuggestionText()
	
	Return NStr("en = 'It is recommended that you install 1C:Enterprise Extension before you save the report option to a file.';");
	
EndFunction

#EndRegion