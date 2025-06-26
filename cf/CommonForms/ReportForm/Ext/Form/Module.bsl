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
Var HandlerAfterGenerateAtClient Export;
&AtClient
Var RunMeasurements;
&AtClient
Var MeasurementID;
&AtClient
Var Directly;
&AtClient
Var GeneratingOnOpen;
&AtClient
Var IdleInterval;
&AtClient
Var SettingsResult;
&AtServer
Var DownloadParametersBeforeSetCurrentOption;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	DefineBehaviorInMobileClient();

	DetailsMode = Parameters.Details <> Undefined Or Parameters.VariantPresentation = "Details";

	OutputRight = AccessRight("Output", Metadata);

	ReportObject     = FormAttributeToValue("Report");
	ReportMetadata = ReportObject.Metadata();
	ReportFullName  = ReportMetadata.FullName();

	OptionContext = ReportOptionContext();
	SetPurposeUseKey();
	SaveFormParameters();
	
	// Define report settings.
	ReportByStringType = ReportsOptions.ReportByStringType(Parameters.Report);
	If ReportByStringType = Undefined Then
		Information      = ReportsOptions.ReportInformation(ReportFullName, True);
		Parameters.Report = Information.Report;
	EndIf;

	SetCurrentOptionKey(ReportFullName, ReportObject);
	ParametersForm.InitialOptionKey = CurrentVariantKey;

	ReportSettings = ReportSettings(ReportObject);

	UpdateInfoOnReportOption();
	ParametersForm.InitialKeyOfPredefinedOption = ReportSettings.PredefinedOptionKey;

	If Parameters.GenerateOnOpen Then
		Parameters.GenerateOnOpen = False;
		Items.GenerateImmediately.Check = True;
		ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = False;
	EndIf;

	If Common.IsWebClient() Then
		Items.Preview.Visible = False;
	EndIf;
	
	// Default parameters.
	If Not ReportSettings.OutputSelectedCellsTotal Or ReportSettings.DisableStandardContextMenu Then
		Items.IndicatorGroup.Visible = False;
		Items.IndicatorsArea.Visible = False;
		Items.MoreIndicatorsKindsCommands.Visible = False;
		Items.MoreCommandBar.HorizontalStretch = Undefined;
	EndIf;

	SetUserPermissions();
	
	// Register commands and form attributes that will not be deleted when overwriting quick settings.
	AttributesSet = GetAttributes();
	For Each Attribute In AttributesSet Do
		FullAttributeName = Attribute.Name + ?(IsBlankString(Attribute.Path), "", "." + Attribute.Path);
		ConstantAttributes.Add(FullAttributeName);
	EndDo;

	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;

	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		SetVisibilityAvailability();
	EndIf;

	CheckTheAvailabilityOfSharingOptionSettings(ReportMetadata);
	
	// Close integration with email and mailing.
	CanSendEmails = False;
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperations = Common.CommonModule("EmailOperations");
		CanSendEmails = ModuleEmailOperations.CanSendEmails();
	EndIf;

	If CanSendEmails Then
		If ReportSettings.EditOptionsAllowed And Common.SubsystemExists("StandardSubsystems.ReportMailing") 
			And ReportsOptions.ReportAttachedToStorage(FormAttributeToValue("Report").Metadata()) 
			And Not ReportSettings.HideBulkEmailCommands Then

			ModuleReportDistribution = Common.CommonModule("ReportMailing");
			ModuleReportDistribution.ReportFormAddCommands(ThisObject, Cancel, StandardProcessing);
		Else // If the submenu contains only one command, the dropdown list is not shown.
			Items.SendByEmail.Title = Items.SendGroup.Title + "...";
			Items.Move(Items.SendByEmail, Items.SendGroup.Parent, Items.SendGroup);
		EndIf;
	Else
		Items.SendGroup.Visible = False;
	EndIf;
	
	// Determine if the report contains invalid data.
	If Not Items.GenerateImmediately.Check Then
		Try
			TablesToUse = ReportsOptions.TablesToUse(ReportObject.DataCompositionSchema);
			TablesToUse.Add(ReportSettings.FullName);

			If ReportSettings.Events.OnDefineUsedTables Then
				ReportObject.OnDefineUsedTables(CurrentVariantKey, TablesToUse);
			EndIf;

			ReportsOptions.CheckUsedTables(TablesToUse);
		Except
			ErrorText = NStr("en = 'Cannot identify referenced tables:';");
			ErrorText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			ReportsOptions.WriteToLog(EventLogLevel.Error, ErrorText,
				ReportSettings.OptionRef);
		EndTry;
	EndIf;

	ReportsClientServer.DisplayReportState(
		ThisObject, NStr("en = 'To run the report, click ""Generate"".';"));

	SSLSubsystemsIntegration.OnCreateAtServerReportsOptions(ThisObject, Cancel, StandardProcessing);
	ReportsOverridable.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	If ReportSettings.Events.OnCreateAtServer Then
		ReportObject.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	EndIf;

	Items.UsersRights.Visible = Users.IsFullUser()
		And Common.SubsystemExists("StandardSubsystems.AccessManagement");

	FillPathToExternalReportFileOnClient(ReportObject);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
#If WebClient Then
	If ValueIsFilled(PathToExternalReportFileAtClient) Then
		ErrorText = NStr("en = 'For this action, start the client application';");
		Raise ErrorText;
	EndIf;
#EndIf
	RunMeasurements = False;
	
	// In the save mode, additional reports are generated directly as they cannot
	// attach themselves and use native methods in background jobs.
	Directly = ReportSettings.External Or ReportSettings.Safe;
	GeneratingOnOpen = False;
	IdleInterval = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2);

	If Items.GenerateImmediately.Check Then
		GeneratingOnOpen = True;
		AttachIdleHandler("Generate", 0.1, True);
	Else
		ResetTheCurrentArea();
	EndIf;

	CommonInternalClient.SetIndicatorsPanelVisibiility(Items, ExpandIndicatorsArea);
	CalculateIndicators(MainIndicator);

	AttachIdleHandler("DefineTheBehaviorOnTheHomePage", 0.1, True);
EndProcedure

&AtClient
Procedure ChoiceProcessing(Result, SubordinateForm)

	ResultProcessed = False;
	
	If TypeOf(SubordinateForm) = Type("ClientApplicationForm") Then

		SubordinateFormName1 = SubordinateForm.FormName;
		If SubordinateFormName1 = "SettingsStorage.ReportsVariantsStorage.Form.ReportSettings"
			Or SubordinateForm.OnCloseNotifyDescription <> Undefined Then

			ResultProcessed = True; // See ApplySettingsAndReshapeReport.

		ElsIf TypeOf(Result) = Type("Structure") Then

			FormNameParts1 = StrSplit(SubordinateFormName1, ".");
			FormSourceName = Upper(FormNameParts1[FormNameParts1.Count() - 1]);
			If StrCompare(FormSourceName, "ReportSettingsForm") = 0 
				Or StrCompare(FormSourceName, "SettingsForm") = 0
				Or StrCompare(FormSourceName, "ReportVariantForm") = 0 
				Or StrCompare(FormSourceName, "VariantForm") = 0 Then

				UpdateSettingsFormItems(Result);
				ResultProcessed = True;
			EndIf;
		EndIf;

		If ReportsOptionsInternalClient.ThisIsAContextSettingEvent(Result) 
			And Result.OwnerID = UUID Then

			ApplySettingsFromTheContextMenu(Result);
			ResultProcessed = True;
		EndIf;

	ElsIf TypeOf(SubordinateForm) = Type("DataCompositionSchemaWizard") Then

		ApplyTheSchemaFromTheConstructor(Result);
		ResultProcessed = True;

	Else 
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistributionClient = CommonClient.CommonModule("ReportMailingClient");
		ModuleReportDistributionClient.ChoiceProcessingReportForm(ThisObject, Result, SubordinateForm,
			ResultProcessed);
	EndIf;
	SSLSubsystemsIntegrationClient.OnProcessChoice(ThisObject, Result, SubordinateForm, ResultProcessed);
	ReportsClientOverridable.ChoiceProcessing(ThisObject, Result, SubordinateForm, ResultProcessed);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName = "Write_ConstantsSet" Then

		PanelOptionsCurrentOptionKey = BlankOptionKey();
		Return;

	ElsIf EventName = ReportsOptionsClient.EventNameChangingOption() Then

		ReportSettings.SchemaKey = "";

		If ValueIsFilled(Parameter.VariantKey) Then
			SetCurrentVariant(Parameter.VariantKey);
		Else
			PanelOptionsCurrentOptionKey = BlankOptionKey();
		EndIf;

		DetachIdleHandler("UpdateOptionsSelectionCommandsIdleHandler");
		AttachIdleHandler("UpdateOptionsSelectionCommandsIdleHandler", 2, True);

	ElsIf EventName = ReportsOptionsClientServer.ApplyPassedSettingsActionName() Then

		ApplyPassedSettings(Parameter);

	ElsIf ReportsOptionsInternalClient.ThisIsAContextSettingEvent(Parameter) 
		And Parameter.OwnerID = UUID Then
		
		ApplySettingsFromTheContextMenu(Parameter);
	
	ElsIf EventName = "ChangeReportOptionVisibilityInReportPanel" And Parameter = ReportSettings.FullName
		And ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey)
		And ReportSettings.OptionSelectionAllowed Then

		DetachIdleHandler("UpdateOptionsSelectionCommandsIdleHandler");
		AttachIdleHandler("UpdateOptionsSelectionCommandsIdleHandler", 2, True);
		Return;

	EndIf;

	SSLSubsystemsIntegrationClient.OnProcessNotification(ThisObject, EventName, Parameter, Source,
		True);
	ReportsClientOverridable.NotificationProcessing(ThisObject, EventName, Parameter, Source, True);
	
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(NewDCSettings)
	// If the report is not in DCS and settings are not imported, do nothing.
	If NewDCSettings = Undefined Or Not ReportsOptionsInternalClientServer.ReportOptionMode(
		CurrentVariantKey) Then

		Return;
	EndIf;

	AdditionalProperties = NewDCSettings.AdditionalProperties;

	If PanelOptionsCurrentOptionKey <> CurrentVariantKey Then
		AdditionalProperties.Delete("VariantKey");
		AdditionalProperties.Delete("PredefinedOptionKey");
		AdditionalProperties.Delete("OptionContext");
		AdditionalProperties.Delete("FormParametersSelection");
		AdditionalProperties.Delete("DescriptionOption");
	EndIf;

	If DetailsMode Then
		If TypeOf(Parameters.Details) = Type("DataCompositionDetailsProcessDescription") Then
			ReportsOptionsInternal.PrepareReportSettingsToDecipherByDetailedRecords(
				ThisObject, NewDCSettings, Parameters.Details.UsedSettings);
		EndIf;

		If ValueIsFilled(CurrentVariantKey) Then
			AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
		EndIf;
	EndIf;

	SSLSubsystemsIntegration.BeforeLoadVariantAtServer(ThisObject, NewDCSettings);
	ReportsOverridable.BeforeLoadVariantAtServer(ThisObject, NewDCSettings);
	If ReportSettings.Events.BeforeLoadVariantAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.BeforeLoadVariantAtServer(ThisObject, NewDCSettings);
	EndIf;
	
	// Prepare for calling the reinitialization event.
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewXMLSettings = Common.ValueToXMLString(NewDCSettings);
		Except
			NewXMLSettings = Undefined;
		EndTry;
		ReportSettings.NewXMLSettings = NewXMLSettings;
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadVariantAtServer(NewDCSettings)
	// If the report is not a DCS report and no settings were imported.
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) And NewDCSettings = Undefined Then
		Return;
	EndIf;
	
	// Import fixed settings for the details mode.
	If DetailsMode Then
		ReportCurrentOptionDescription = CommonClientServer.StructureProperty(
			NewDCSettings.AdditionalProperties, "DescriptionOption");

		If TypeOf(Parameters.Details) = Type("DataCompositionDetailsProcessDescription") Then
			Report.SettingsComposer.LoadFixedSettings(Parameters.Details.UsedSettings);
			Report.SettingsComposer.FixedSettings.AdditionalProperties.Insert("DetailsMode", True);
		EndIf;

		If CurrentVariantKey = Undefined Then
			CurrentVariantKey = CommonClientServer.StructureProperty(
				NewDCSettings.AdditionalProperties, "VariantKey");
		EndIf;
	EndIf;
	
	// Fixed filters are set using the composer because it has the widest range of settings.
	// "BeforeImport" might be missing the parameters whose settings were not overridden.
	If ReportsOptions.ItIsAcceptableToSetContext(ThisObject) And TypeOf(ParametersForm.Filter) = Type("Structure") Then

		ReportsServer.SetFixedFilters(ParametersForm.Filter, Report.SettingsComposer.Settings,
			ReportSettings);
	EndIf;
	
	// Update the report option reference.
	If PanelOptionsCurrentOptionKey <> CurrentVariantKey Then
		UpdateInfoOnReportOption();
	EndIf;

	If ReportSettings.Events.OnLoadVariantAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.OnLoadVariantAtServer(ThisObject, NewDCSettings);
	EndIf;

	If IsMobileClient Then
		ResourcePlacement = Report.SettingsComposer.Settings.OutputParameters.FindParameterValue(
			New DataCompositionParameter("ResourcePlacement"));
		If ResourcePlacement.Use And ResourcePlacement.Value = DataCompositionResourcesPlacement.Vertically Then
			Items.DecorationEditResourcePlacement.Title = NStr("en = 'Horizontal';");
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure BeforeLoadUserSettingsAtServer(NewDCUserSettings)
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewUserXMLSettings = Common.ValueToXMLString(NewDCUserSettings);
		Except
			NewUserXMLSettings = Undefined;
		EndTry;
		ReportSettings.NewUserXMLSettings = NewUserXMLSettings;
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(NewDCUserSettings)
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		Return;
	EndIf;

	If ReportSettings.Events.OnLoadUserSettingsAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.OnLoadUserSettingsAtServer(ThisObject, NewDCUserSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnUpdateUserSettingSetAtServer(StandardProcessing)
	SettingsKey = ReportOptionSettingsKey(ReportSettings.FullName, CurrentVariantKey);
	RestoreTheSelectedGroupingLevel(SettingsKey, SelectedGroupsLevel, DetailsMode);

	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		Return;
	EndIf;

	StandardProcessing = False;

	If Not VariantModified Then
		RestoreTheStateOfTheOutputSettingsHeadersOption(SettingsKey, OutputSettingsTitles, DetailsMode);
	EndIf;

	ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters("OnUpdateUserSettingSetAtServer");
	UpdateSettingsFormItemsAtServer(ParametersOfUpdate);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		Return;
	EndIf;

	If PathToItemsData = Undefined Then
		Return;
	EndIf;

	SettingsItems = Report.SettingsComposer.UserSettings.Items;
	For Each SettingItem In SettingsItems Do
		If TypeOf(SettingItem) <> Type("DataCompositionSettingsParameterValue") 
			Or TypeOf(SettingItem.Value) <> Type("StandardPeriod") 
			Or Not SettingItem.Use Then
			Continue;
		EndIf;

		NameTemplate = PathToItemsData.ByIndex[SettingsItems.IndexOf(SettingItem)];
		If NameTemplate = Undefined Then
			Continue;
		EndIf;

		StartDate = Items.Find(NameTemplate + "StartDate");
		EndDate = Items.Find(NameTemplate + "EndDate");
		If StartDate = Undefined Or EndDate = Undefined Then
			Continue;
		EndIf;

		Value = SettingItem.Value; // StandardPeriod
		If StartDate.AutoMarkIncomplete = True And Not ValueIsFilled(Value.StartDate)
			And Not ValueIsFilled(Value.EndDate) Then
			ErrorText = NStr("en = 'The period is not specified.';");
			DataPath = StartDate.DataPath;
		ElsIf Value.StartDate > Value.EndDate Then
			ErrorText = NStr("en = 'Period end must be later than period start.';");
			DataPath = EndDate.DataPath;
		Else
			Continue;
		EndIf;

		Common.MessageToUser(ErrorText,, DataPath,, Cancel);
	EndDo;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	Value = Settings["SettingsFormAdvancedMode"];
	If Value <> Undefined Then
		If Value = 1 And Not ReportSettings.EditStructureAllowed Then
			Return;
		EndIf;
		ReportSettings.SettingsFormAdvancedMode = Value;
	EndIf;
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)

	SaveDataInSettingsOnServer(Settings);

EndProcedure

&AtServer
Procedure OnSaveVariantAtServer(DCSettings)
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		Return;
	EndIf;

	NewDCSettings = Report.SettingsComposer.GetSettings();
	ReportsClientServer.LoadSettings(Report.SettingsComposer, NewDCSettings);
	DCSettings.AdditionalProperties.Insert("Address", PutToTempStorage(NewDCSettings));
	DCSettings = NewDCSettings;
	PanelOptionsCurrentOptionKey = BlankOptionKey();
	UpdateInfoOnReportOption();
	SetVisibilityAvailability();
	UpdateDetailsDataAdditionalProperties();

	If Common.IsWebClient() Then
		SaveDataInSettingsOnServer();
	EndIf;
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(DCUserSettings)
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		Return;
	EndIf;
	ReportsOptions.OnSaveUserSettingsAtServer(ThisObject, DCUserSettings);
	UpdateOptionsSelectionCommands();
EndProcedure

#If MobileClient Then

&AtClient
Procedure OnMainServerAvailabilityChange(StandardProcessing)

	If MainServerAvailable() = False Then
		OpenForm("InformationRegister.ReportsSnapshots.Form.ReportViewForm");
		Close();
	EndIf;

EndProcedure

#EndIf

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Attachable objects.

&AtClient
Procedure Attachable_SettingItem_OnChange(Item)
	SettingsComposer = Report.SettingsComposer;

	IndexOf = PathToItemsData.ByName[Item.Name];
	If IndexOf = Undefined Then
		IndexOf = ReportsClientServer.SettingItemIndexByPath(Item.Name);
	EndIf;

	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];

	IsFlag = StrStartsWith(Item.Name, "CheckBox") Or StrEndsWith(Item.Name, "CheckBox");
	If IsFlag Then
		SettingItem.Value = ThisObject[Item.Name];
	EndIf;

	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue")
		And ReportSettings.ImportSettingsOnChangeParameters.Find(SettingItem.Parameter) <> Undefined Then

		WasOptionModified = VariantModified;
		SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
		VariantModified = WasOptionModified;
		ParametersChanged = True;

		ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters();
		ParametersOfUpdate.DCSettingsComposer = SettingsComposer;
		ParametersOfUpdate.UserSettingsModified = True;
		UpdateSettingsFormItems(ParametersOfUpdate);

	EndIf;

	ReportsClientServer.NotifyOfSettingsChange(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_SettingItemStartChoice(Item, ChoiceData, StandardProcessing)
	ParametersChanged = True;
	ShowChoiceList(Item, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_Period_OnChange(Item)
	ParametersChanged = True;
	ReportsClient.SetPeriod(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_SelectPeriod(Command)
	ParametersChanged = True;
	ReportsClient.SelectPeriod(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_MoveThePeriodBack(Command)
	ParametersChanged = True;
	ReportsClient.ShiftThePeriod(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_MoveThePeriodForward(Command)
	ParametersChanged = True;
	ReportsClient.ShiftThePeriod(ThisObject, Command.Name);
EndProcedure

#Region EventHandlersForUniversalSearchStringElements

&AtClient
Procedure FactorExtendedTooltipURLProcessing(Item, FormattedStringURL,
	StandardProcessing)

	StandardProcessing = False;

	If Items.AllSettings.Visible Then
		GoToSettings(ReportSettings.EditOptionsAllowed);
	Else
		ShowMessageBox(, NStr("en = 'Advanced filter settings are not available';"));
	EndIf;

EndProcedure

&AtClient
Procedure FactorOnChange(Item)

	TheTransitionToTheSettingsIsCompleted();

EndProcedure

&AtClient
Procedure FactorChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If TypeOf(ValueSelected) <> Type("Array") Then
		ResetUniversalSearch();
		Return;
	EndIf;

	StandardProcessing = False;
	ApplyTheUniversalSearchValue(ValueSelected);

EndProcedure

&AtClient
Procedure FactorAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)

	If Not ValueIsFilled(Text) Then
		Return;
	EndIf;

	Query = TrimAll(Text);

	If TheTransitionToTheSettingsIsCompleted(Query) Then
		Return;
	EndIf;

	SuitableValues = SuitableUniversalSearchValues(Query);

	If SuitableValues.Count() = 0 Then
		Return;
	EndIf;

	ChoiceData = SuitableValues;
	StandardProcessing = False;

EndProcedure

#EndRegion

#Region DocumentEventHandlersReportTabularDocument

&AtClient
Procedure ReportSpreadsheetDocumentSelection(Item, Area, StandardProcessing)

	DetailProcessing = False;

	If StandardProcessing Then
		SSLSubsystemsIntegrationClient.OnProcessSpreadsheetDocumentSelection(ThisObject, Item, Area,
			StandardProcessing);
		ReportsClientOverridable.SpreadsheetDocumentSelectionHandler(ThisObject, Item, Area,
			StandardProcessing);
	EndIf;

	If Not DetailProcessing And StandardProcessing And TypeOf(Area) = Type("SpreadsheetDocumentRange") Then

		If GoToLink(Area.Text) Then
			StandardProcessing = False;
			Return;
		EndIf;

		Try
			DetailsValue = Area.Details;
		Except
			DetailsValue = Undefined;
			// Some spreadsheet area types (the property "AreaType") don't support reading drill-downs.
			// Therefore, a try–except clause is used.
		EndTry;

		If DetailsValue <> Undefined And GoToLink(DetailsValue) Then
			StandardProcessing = False;
			Return;
		EndIf;

		If GoToLink(Area.Mask) Then
			StandardProcessing = False;
			Return;
		EndIf;
	EndIf;

	If Not DetailProcessing And StandardProcessing Then
		ReportsOptionsInternalClient.ShowTheContextSettingOfTheReport(ThisObject, Item, Area,
			StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)

	SSLSubsystemsIntegrationClient.OnProcessDetails(ThisObject, Item, Details, StandardProcessing);
	ReportsClientOverridable.DetailProcessing(ThisObject, Item, Details, StandardProcessing);

	If StandardProcessing Then
		ReportsOptionsInternalClient.DetailProcessing(ThisObject, Item, Details, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentAdditionalDetailProcessing(Item, Details, StandardProcessing)

	SSLSubsystemsIntegrationClient.OnProcessAdditionalDetails(ThisObject,
		Item, Details, StandardProcessing);
	
	ReportsClientOverridable.AdditionalDetailProcessing(ThisObject,
		Item, Details, StandardProcessing);

	If StandardProcessing Then
		Data = DataOfTheDecryptionElement(Details);
		ReportsOptionsInternalClient.AdditionalDetailProcessing(ThisObject,
			Data, Item, Details, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentOnActivate(Item)

	ReportsOptionsInternalClient.WhenActivatingTheReportResult(ThisObject, Items.ReportSpreadsheetDocument);
	AttachIdleHandler("CalculateIndicatorsDynamically", 0.2, True);

EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentBeforeWrite(Item, Copy, Cancel)

	Cancel = True;
	SaveReport(Commands.Find(Items.SaveReport.CommandName));

EndProcedure

#EndRegion

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AllSettings(Command)

	GoToSettings();

EndProcedure

&AtClient
Procedure ApplySettingsAndReshapeReport(Result, ExecutionParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	CommonClientServer.SupplementStructure(Result, ReportsClientServer.ReportFormUpdateParameters(), False);

	If Result.EventName = ReportsOptionsInternalClientServer.NameEventFormSettings() 
		And Result.VariantModified Then

		ReportsOptionsInternalClient.AddSettingstoStack(
			ThisObject, Result.DCSettingsComposer.Settings, Result.EventName);
	EndIf;

	SettingsResult = Result;
	ReportCreated = Result.Regenerate;

	AttachIdleHandler("UpdateSettingsFormItemsDeferred", 0.1, True);
EndProcedure

&AtClient
Procedure DefaultSettings(Command)
	FillParameters = ReportsClientServer.ReportFormUpdateParameters(
		ReportsClientServer.NameOfTheDefaultSettingEvent());

	If VariantModified
	 Or ReportSettings.FullName = "Report.UniversalReport" Then
		FillParameters.ClearOptionSettings = True;
		FillParameters.VariantModified = False;
	EndIf;

	FillParameters.ResetCustomSettings = True;
	FillParameters.UserSettingsModified = True;

	ReportCreated = False;

	ResetTheSelectedGroupingLevel();
	ReportsOptionsInternalClient.ResetStackNotesSettings(StackSettings);
	UpdateSettingsFormItems(FillParameters);
EndProcedure

&AtClient
Procedure SaveVariant(Command)

	If Not VariantModified
	   And ReportSettings.FullName <> "Report.UniversalReport" Then
		Return;
	EndIf;

	SaveReportOption();

EndProcedure

&AtClient
Procedure SendByEmail(Command)
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	If StatePresentation.Visible = True 
		And StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance Then
		QueryText = NStr("en = 'Report not generated. Do you want to generate the report?';");
		Handler = New NotifyDescription("GenerateBeforeEmailing", ThisObject);
		ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	Else
		ShowSendByEmailDialog();
	EndIf;
EndProcedure

&AtClient
Procedure ReportComposeResult(Command)
	ClearMessages();
	Generate();
	ParametersChanged = False;
EndProcedure

&AtClient
Procedure GenerateImmediately(Command)
	GenerateImmediately = Not Items.GenerateImmediately.Check;
	Items.GenerateImmediately.Check = GenerateImmediately;

	StateBeforeChange = New Structure("Visible, AdditionalShowMode, Picture, Text");
	FillPropertyValues(StateBeforeChange, Items.ReportSpreadsheetDocument.StatePresentation);

	Report.SettingsComposer.UserSettings.AdditionalProperties.Insert("GenerateImmediately",
		GenerateImmediately);
	UserSettingsModified = True;

	FillPropertyValues(Items.ReportSpreadsheetDocument.StatePresentation, StateBeforeChange);
EndProcedure

&AtClient
Procedure OtherReports(Command)
	DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);

	VisibleOptions = New Array;
	For Each ReportVariant In AddedOptions Do
		VisibleOptions.Add(ReportVariant.Ref);
	EndDo;

	FormParameters = New Structure;
	FormParameters.Insert("OptionRef", ReportSettings.OptionRef);
	FormParameters.Insert("ReportRef", ReportSettings.ReportRef);
	FormParameters.Insert("SubsystemRef", ParametersForm.Subsystem);
	FormParameters.Insert("ReportDescription", DescriptionOfReportSettings.Description);
	FormParameters.Insert("VisibleOptions", New FixedArray(VisibleOptions));
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.OtherReportsPanel", FormParameters, ThisObject,
		True,,,, FormWindowOpeningMode.LockOwnerWindow);
		
EndProcedure

&AtClient
Procedure ChangeQuickSettingsComposition(Command)

	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("CurrentVariantKey", CurrentVariantKey);
	FormParameters.Insert("OutputSettingsTitles", OutputSettingsTitles);

	Handler = New NotifyDescription("AfterChangingTheCompositionOfTheQuickSettings", ThisObject);
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.QuickReportSettings", FormParameters,
		ThisObject, UUID,,, Handler);

EndProcedure

&AtClient
Procedure EditResourcePlacement(Command)

	ResourcePlacement = Items.DecorationEditResourcePlacement.Title;
	ParameterValue = Report.SettingsComposer.Settings.OutputParameters.FindParameterValue(
		New DataCompositionParameter("ResourcePlacement"));
	If ParameterValue <> Undefined Then
		ParameterValue.Use = True;
		ParameterValue.Value = DataCompositionResourcesPlacement[ResourcePlacement];
	EndIf;
	Items.DecorationEditResourcePlacement.Title = ?(ResourcePlacement = "Vertically", "Horizontally",
		"Vertically");

	ClearMessages();
	Generate();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of DCS modification commands.

&AtClient
Procedure ImportSchema(Command)

	NotifyDescription = New NotifyDescription("ImportSchemaAfterLocateFile", ThisObject);

	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Filter = NStr("en = 'XML files (*.xml) |*.xml';");
	ImportParameters.FormIdentifier = UUID;

	FileSystemClient.ImportFile_(NotifyDescription, ImportParameters);

EndProcedure

&AtClient
Procedure EditSchema(Command)
#If ThickClientOrdinaryApplication Or ThickClientManagedApplication Then
	DataCompositionSchema = GetFromTempStorage(ReportSettings.SchemaURL);

	If DataCompositionSchema.DefaultSettings.AdditionalProperties.Property("DataCompositionSchema") Then
		DataCompositionSchema.DefaultSettings.AdditionalProperties.DataCompositionSchema = Undefined;
	EndIf;

	Designer = New DataCompositionSchemaWizard(DataCompositionSchema);
	Designer.Edit(ThisObject);
#Else
	ShowMessageBox(, NStr("en = 'To edit composition schema, run the application in thick client mode.';"));
#EndIf
EndProcedure

&AtClient
Procedure RestoreDefaultSchema(Command)
	Report.SettingsComposer.Settings.AdditionalProperties.Clear();

	If ReportSettings.FullName = "Report.UniversalReport" Then
		DataParameters = Report.SettingsComposer.Settings.DataParameters.Items;
		ParametersNamesToClear = StrSplit("MetadataObjectType, MetadataObjectName, TableName", ", ", False);
		For Each ParameterName In ParametersNamesToClear Do
			FoundParameter = DataParameters.Find(ParameterName);
			If FoundParameter <> Undefined Then
				FoundParameter.Value = Undefined;
			EndIf;
		EndDo;
	EndIf;

	FillParameters = ReportsClientServer.ReportFormUpdateParameters();
	FillParameters.DCSettingsComposer = Report.SettingsComposer;
	FillParameters.UserSettingsModified = True;
	UpdateSettingsFormItems(FillParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of (main and user) settings exchange commands.

&AtClient
Procedure SaveReportOptionToFile(Command)
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SaveReportOptionToFile",
		ReportsOptionsInternalClient.ParametersForSavingAReportVariantToAFile(ThisObject), ThisObject);
EndProcedure

&AtClient
Procedure UpdateReportOptionFromFile(Command)

	ReportOptionProperties = ReportsOptionsClient.BaseReportOptionProperties();
	ReportOptionProperties.Ref = ReportSettings.OptionRef;
	ReportOptionProperties.ReportName = ReportSettings.FullName;
	ReportOptionProperties.VariantPresentation = CurrentVariantPresentation;
	ReportsOptionsClient.UpdateReportOptionFromFiles(ReportOptionProperties, UUID);

EndProcedure

&AtClient
Procedure ShareSettings(Command)
	SettingsDescription = New Structure;
	SettingsDescription.Insert("ReportVariant", ReportSettings.OptionRef);
	SettingsDescription.Insert("ObjectKey", ReportSettings.FullName + "/" + CurrentVariantKey);
	SettingsDescription.Insert("SettingsKey", CurrentUserSettingsKey);
	SettingsDescription.Insert("Presentation", CurrentUserSettingsPresentation);
	SettingsDescription.Insert("Settings", Report.SettingsComposer.UserSettings);
	SettingsDescription.Insert("VariantModified", VariantModified);

	ReportsOptionsClient.ShareUserSettings(SettingsDescription);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of report result save commands.

&AtClient
Procedure SaveReport(Command)

	Context = New Structure;
	Context.Insert("IndexOfReportSavingFormats", New Map);

	Dialog = New FileDialog(FileDialogMode.Save);
	Dialog.Filter = AvailableFormatsForSavingTheReport(Context.IndexOfReportSavingFormats);
	Dialog.Multiselect = False;
	Dialog.Title = NStr("en = 'Save report result';");

	Handler = New NotifyDescription("SaveReportAfterFilenameSelected", ThisObject, Context);
	FileSystemClient.ShowSelectionDialog(Handler, Dialog);

EndProcedure

&AtClient
Procedure SaveReportSnapshot(Command)

	If ReportSettings.ResultProperties.SettingsComposer = Undefined Then
		WarningText = NStr("en = 'Generate the report before saving the snapshot.';");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;

	SaveUserReportSnapshot();

EndProcedure

&AtClient
Procedure ReportsSnapshots(Command)

	OpenForm("InformationRegister.ReportsSnapshots.ListForm", New Structure("User",
		UsersClient.CurrentUser()));

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of context menu commands in the report resulting spreadsheet document.

&AtClient
Procedure GroupBySelectedField(Command)

	ReportsOptionsInternalClient.GroupBySelectedField(ThisObject, Command);

EndProcedure

&AtClient
Procedure InsertFieldLeft(Command)

	ReportsOptionsInternalClient.InsertFieldLeft(ThisObject, Command);

EndProcedure

&AtClient
Procedure InsertFieldRight(Command)

	ReportsOptionsInternalClient.InsertFieldRight(ThisObject, Command);

EndProcedure

&AtClient
Procedure InsertGroupAbove(Command)

	ReportsOptionsInternalClient.InsertGroupAbove(ThisObject, Command);

EndProcedure

&AtClient
Procedure InsertGroupBelow(Command)

	ReportsOptionsInternalClient.InsertGroupBelow(ThisObject, Command);

EndProcedure

&AtClient
Procedure MoveFieldLeft(Command)

	ReportsOptionsInternalClient.MoveFieldLeft(ThisObject, Command);

EndProcedure

&AtClient
Procedure MoveFieldRight(Command)

	ReportsOptionsInternalClient.MoveFieldRight(ThisObject, Command);

EndProcedure

&AtClient
Procedure MoveFieldUp(Command)

	ReportsOptionsInternalClient.MoveFieldUp(ThisObject, Command);

EndProcedure

&AtClient
Procedure MoveFieldDown(Command)

	ReportsOptionsInternalClient.MoveFieldDown(ThisObject, Command);

EndProcedure

&AtClient
Procedure HideField(Command)

	ReportsOptionsInternalClient.HideField(ThisObject, Command);

EndProcedure

&AtClient
Procedure RenameField(Command)

	ReportsOptionsInternalClient.RenameField(ThisObject, Command);

EndProcedure

&AtClient
Procedure DisableFilter(Command)

	ReportsOptionsInternalClient.DisableFilter(ThisObject, TitleProperties());

EndProcedure

&AtClient
Procedure FilterCommand(Command)

	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	TitleProperties = ResultProperties.Headers[NameOfTheCurrentCellArea()];
	ReportsOptionsInternalClient.ShowAdvancedFilterSetting(ThisObject, TitleProperties);

EndProcedure

&AtClient
Procedure SortAsc(Command)

	ReportsOptionsInternalClient.Sort(ThisObject, Command);

EndProcedure

&AtClient
Procedure SortDesc(Command)

	ReportsOptionsInternalClient.Sort(ThisObject, Command);

EndProcedure

&AtClient
Procedure ClearAppearance(Command)

	ReportsOptionsInternalClient.ClearAppearance(ThisObject, TitleProperties());

EndProcedure

&AtClient
Procedure FormatNegativeValues(Command)

	ReportsOptionsInternalClient.HighlightInRed(ThisObject, Command);

EndProcedure

&AtClient
Procedure FormatPositiveValues(Command)

	ReportsOptionsInternalClient.HighlightInGreen(ThisObject, Command);

EndProcedure

&AtClient
Procedure SetRowHeight(Command)

	ReportsOptionsInternalClient.SetRowHeight(ThisObject, Command);

EndProcedure

&AtClient
Procedure SetColumnWidth(Command)

	ReportsOptionsInternalClient.SetColumnWidth(ThisObject, Command);

EndProcedure

&AtClient
Procedure ApplyAppearanceMore(Command)

	ReportsOptionsInternalClient.ApplyAppearanceMore(ThisObject, Command);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of indicator calculation commands.

&AtClient
Procedure SelectIndicatorClick(Item)

	Menu = MenuOfIndicatorTypes(Items.IndicatorsKindsCommands);
	ShowChooseFromMenu(New NotifyDescription("AfterSelectingTheIndicator", ThisObject), Menu, Item);

EndProcedure

&AtClient
Procedure CalculateAmount(Command)
	CalculateIndicators(Command.Name);
EndProcedure

&AtClient
Procedure CalculateCount(Command)
	CalculateIndicators(Command.Name);
EndProcedure

&AtClient
Procedure CalculateAverage(Command)
	CalculateIndicators(Command.Name);
EndProcedure

&AtClient
Procedure CalculateMin(Command)
	CalculateIndicators(Command.Name);
EndProcedure

&AtClient
Procedure CalculateMax(Command)
	CalculateIndicators(Command.Name);
EndProcedure

&AtClient
Procedure CalculateAllIndicators(Command)
	ExpandIndicatorsArea = Not Items.CalculateAllIndicators.Check;
	CommonInternalClient.SetIndicatorsPanelVisibiility(Items, ExpandIndicatorsArea);
EndProcedure

&AtClient
Procedure CollapseIndicators(Command)
	CommonInternalClient.SetIndicatorsPanelVisibiility(Items);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable objects.

// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_Command(Command)

	Prefix_Name = ReportsClientServer.CommandNamePrefixWithReportOptionPreSave();
	If StrStartsWith(Command.Name, Prefix_Name) And IsOptionMustBeSaved() Then
		SaveAsNewOrOverwriteExistingReportOptionAndContinue(Command);
		Return;
	EndIf;

	ConstantCommand = ConstantCommands.FindByValue(Command.Name);
	If ConstantCommand <> Undefined And ValueIsFilled(ConstantCommand.Presentation) Then
		SubstringsArray = StrSplit(ConstantCommand.Presentation, ".");
		ModuleClient = CommonClient.CommonModule(SubstringsArray[0]);
		Handler = New NotifyDescription(SubstringsArray[1], ModuleClient, Command);
		ExecuteNotifyProcessing(Handler, ThisObject);
	Else
		SSLSubsystemsIntegrationClient.OnProcessCommand(ThisObject, Command, False);
		ReportsClientOverridable.HandlerCommands(ThisObject, Command, False);
	EndIf;
EndProcedure

// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_ImportReportOption(Command)
	FoundItems = AddedOptions.FindRows(New Structure("CommandName", Command.Name));
	If FoundItems.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'The report option does not exist.';"));
		Return;
	EndIf;

	FormOption = FoundItems[0];
	ReportSettings.SettingsFormAdvancedMode = 0;

	LoadVariant(FormOption.VariantKey);

	UniqueKey = ReportsClientServer.UniqueKey(ReportSettings.FullName, FormOption.VariantKey);

	If Items.GenerateImmediately.Check Then
		AttachIdleHandler("Generate", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ShowGroupsLevel(Command)

	TheLevelOfGroupingByAString = StrReplace(Command.Name, Items.ShowGroupsLevel.Name, "");

	NumberDetails = New TypeDescription("Number");
	GroupingLevel = NumberDetails.AdjustValue(TheLevelOfGroupingByAString);

	ShowTheSelectedGroupingLevel(GroupingLevel);

EndProcedure

// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_JumpBetweenSettingsChanges(Command)

	OrderPresentation = StrReplace(Command.Name, PrefixCommandNameTransitionBetweenSettingChanges(), "");
	NumberDetails = New TypeDescription("Number");
	Order = NumberDetails.AdjustValue(OrderPresentation);

	FoundRecords = StackSettings.FindRows(New Structure("Order", Order));
	CurrentStackSettings = FoundRecords[0];

	Result = ReportsOptionsInternalClient.ResultContextSettings(
		Report.SettingsComposer, CurrentStackSettings.Action, UUID);

	Result.Insert("DCSettings", CurrentStackSettings.Settings);
	Result.Delete("DCSettingsComposer");

	RefineReportAutoGenerationSign(Result);

	ReportsOptionsInternalClient.ResetStackNotesSettings(StackSettings);
	CurrentStackSettings.Check = True;


EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure DefineTheBehaviorOnTheHomePage()

	HomePageWindow = Undefined;

	ProgramWindows = GetWindows();
	
	If ProgramWindows = Undefined Then
		Return;
	EndIf;

	For Each ProgramWindow In ProgramWindows Do

		If ProgramWindow.HomePage Then

			HomePageWindow = ProgramWindow;
			Break;

		EndIf;

	EndDo;

	If HomePageWindow = Undefined Then
		Return;
	EndIf;

	ThisIsTheFormOfTheInitialPage = False;
	For Each TheFormOfTheInitialPage In HomePageWindow.Content Do
		If TheFormOfTheInitialPage.FormName = FormName And TheFormOfTheInitialPage.UniqueKey = UniqueKey Then
			ThisIsTheFormOfTheInitialPage = True;
			Break;
		EndIf;
	EndDo;

	If Not ThisIsTheFormOfTheInitialPage Then
		Return;
	EndIf;

	CommonClientServer.SetFormItemProperty(Items, "GroupSaveReportOptionSelection",
		"Visible", False);
	CommonClientServer.SetFormItemProperty(Items, "Find", "Visible", False);
	CommonClientServer.SetFormItemProperty(Items, "GroupOutput", "Visible", False);

EndProcedure

&AtClient
Procedure UpdateSettingsFormItems(ParametersOfUpdate)
	UpdateSettingsFormItemsAtServer(ParametersOfUpdate);

	If ParametersOfUpdate.Regenerate Then
		ClearMessages();
		Generate();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateSettingsFormItemsDeferred()

	UpdateSettingsFormItems(SettingsResult);

EndProcedure

#Region GenerationWithSendingByEmail

&AtClient
Procedure GenerateBeforeEmailing(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Handler = New NotifyDescription("SendByEmailAfterGenerate", ThisObject);
		ReportsClient.GenerateReport(ThisObject, Handler);
	EndIf;
EndProcedure

&AtClient
Procedure SendByEmailAfterGenerate(SpreadsheetDocumentGenerated, AdditionalParameters) Export
	If SpreadsheetDocumentGenerated Then
		ShowSendByEmailDialog();
	EndIf;
EndProcedure

#EndRegion

#Region Generation1

&AtClient
Async Procedure Generate()

	If ValueIsFilled(PathToExternalReportFileAtClient) And Not ValueIsFilled(ExternalReportBinaryDataAddress) Then
		Result = Await PutFileToServerAsync(,,, PathToExternalReportFileAtClient, UUID); // StoredFileDescription
		If TypeOf(Result) = Type("StoredFileDescription") And Not Result.PutFileCanceled Then
			ExternalReportBinaryDataAddress = Result.Address;
		EndIf;
	EndIf;

	GenerateReport();

EndProcedure

&AtClient
Procedure GenerateReport()

	StartMeasurement();
	GenerationParameters = New Structure("FormationStartTime", CurrentUniversalDateInMilliseconds());
	Result = ReportGenerationResult(GeneratingOnOpen, 
		ReportSettings.External Or ReportSettings.Safe, False);
	If Result = Undefined Then
		Return;
	EndIf;

	Context = New Structure;
	Context.Insert("Result", Result);
	Context.Insert("GenerationParameters", GenerationParameters);
	Context.Insert("WarningDisclaimerSetting", Undefined);

	If Result.Property("StorageParameterNameWarningDisclaimer") Then
		Warn = True;
		SuggestMoreDontWarn = True;

		If ValueIsFilled(Result.StorageParameterNameWarningDisclaimer) Then
			LayoutParameter = New DataCompositionParameter(Result.StorageParameterNameWarningDisclaimer);
			For Each Setting In Report.SettingsComposer.UserSettings.Items Do
				If Setting.Parameter = LayoutParameter Then
					Context.WarningDisclaimerSetting = Setting;
					Break;
				EndIf;
			EndDo;
			If Context.WarningDisclaimerSetting = Undefined Then
				SuggestMoreDontWarn = False;
			ElsIf Context.WarningDisclaimerSetting.Value = True Then
				Warn = False;
			EndIf;
		Else
			SuggestMoreDontWarn = False;
		EndIf;

		If Warn Then
			Buttons = New ValueList;
			Buttons.Add("Continue", NStr("en = 'Continue';"));
			Buttons.Add("Cancel", NStr("en = 'Cancel';"));
			QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
			QuestionParameters.DefaultButton = "Cancel";
			QuestionParameters.Title = Title;
			QuestionParameters.PromptDontAskAgain = SuggestMoreDontWarn;
			StandardSubsystemsClient.ShowQuestionToUser(
				New NotifyDescription("GenerateAfterWarning", ThisObject, Context),
				Result.WarningText, Buttons, QuestionParameters);
			Return;
		EndIf;
	EndIf;

	GenerateAfterWarning(Null, Context);

EndProcedure

&AtClient
Procedure GenerateAfterWarning(Response, Context) Export

	GenerationParameters = Context.GenerationParameters;

	If Response = Null Then
		Result = Context.Result;

	ElsIf TypeOf(Response) = Type("Structure") Then
		If Response.NeverAskAgain And Context.WarningDisclaimerSetting <> Undefined Then
			Context.WarningDisclaimerSetting.Value = True;
		EndIf;
		If Response.Value = "Continue" Then
			StartMeasurement();
			GenerationParameters.FormationStartTime = CurrentUniversalDateInMilliseconds();
			Result = ReportGenerationResult(GeneratingOnOpen, ReportSettings.External
				Or ReportSettings.Safe, True);
		Else
			Return;
		EndIf;
	Else
		Return;
	EndIf;

	If Result = Undefined Then
		Return;
	EndIf;

	GenerationParameters.Insert("ImportResult", False);
	GenerationParameters.Insert("JobID", Result.JobID);

	If Result.Status <> "Running" Then
		AfterGenerate(Result, GenerationParameters);
		Return;
	EndIf;

	GenerationParameters.ImportResult = True;

	Handler = New NotifyDescription("AfterGenerate", ThisObject, GenerationParameters);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;

	TimeConsumingOperationsClient.WaitCompletion(Result, Handler, IdleParameters);
EndProcedure

&AtClient
Procedure StartMeasurement()

	RunMeasurements = ReportSettings.RunMeasurements And ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.TimeMeasurement(
			ReportSettings.MeasurementsKey + ".Generation1", False, False);
		Comment = New Map;
		Comment.Insert("Directly", Directly);
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, Comment);
	EndIf;

EndProcedure

&AtClient
Procedure AfterGenerate(Result, GenerationParameters) Export

	If IDBackgroundJob <> GenerationParameters.JobID Or Not IsOpen() Then
		Return;
	EndIf;
	
	IDBackgroundJob = Undefined;
	
	If Result = Undefined Then

		ShowGenerationErrors(NStr("en = 'Report generation is canceled by the administrator';"));
		ShowUserNotification(NStr("en = 'Report is not generated';"),
			?(Window <> Undefined, Window.GetURL(), Undefined), Title);

	ElsIf Result.Status = "Completed2" Then

		If GenerationParameters.ImportResult Then
			ImportReportGenerationResult();
		EndIf;

		ReportSettings.ResultProperties.FormationTime = (CurrentUniversalDateInMilliseconds()
			- GenerationParameters.FormationStartTime) / 1000;
			
		ShowUserNotification(NStr("en = 'Report is generated';"),
			?(Window <> Undefined, Window.GetURL(), Undefined), Title);

	ElsIf Result.Status = "Error" Then

		ShowGenerationErrors(Result.BriefErrorDescription);
		ShowUserNotification(NStr("en = 'Report is not generated';"),
			?(Window <> Undefined, Window.GetURL(), Undefined), Title);
	EndIf;

	GeneratingOnOpen = False;

	RunMeasurements = ReportSettings.RunMeasurements And ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;

	ReportCreated = ?(Result = Undefined, False, Result.Status = "Completed2");

	SSLSubsystemsIntegrationClient.AfterGenerate(ThisObject, ReportCreated);
	ReportsClientOverridable.AfterGenerate(ThisObject, ReportCreated);

	ResetTheCurrentArea();
	ShowTheSelectedGroupingLevel();

	Handler = HandlerAfterGenerateAtClient;
	If TypeOf(Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Handler, ReportCreated);
		HandlerAfterGenerateAtClient = Undefined;
	EndIf;

EndProcedure

&AtServer
Function ReportGenerationResult(Val GeneratingOnOpen, Directly, AfterWarning)

	If ValueIsFilled(IDBackgroundJob) Then
		TimeConsumingOperations.CancelJobExecution(IDBackgroundJob);
		IDBackgroundJob = Undefined;
	EndIf;

	If Not CheckFilling() Then
		If GeneratingOnOpen Then
			ErrorText = "";
			Messages = GetUserMessages(True);
			For Each Message In Messages Do
				ErrorText = ErrorText + ?(ErrorText = "", "", ";" + Chars.LF + Chars.LF) + Message.Text;
			EndDo;
			ShowGenerationErrors(ErrorText);
		EndIf;
		Return Undefined;
	EndIf;

	If ReportSettings.Events.BeforeFormationReport And Not AfterWarning Then
		QuestionParameters = New Structure;
		QuestionParameters.Insert("WarningText", "");
		QuestionParameters.Insert("StorageParameterNameWarningDisclaimer", "");
		ReportObject = FormAttributeToValue("Report");
		ReportObject.BeforeFormationReport(ThisObject, QuestionParameters);
		If ValueIsFilled(QuestionParameters.WarningText) Then
			Return QuestionParameters;
		EndIf;
	EndIf;

	ReportName = StrSplit(ReportSettings.FullName, ".")[1];
	GenerationParameters = ReportGenerationParameters(ReportName, Directly);
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Running report: %1';"), ReportName);
	ExecutionParameters.RunNotInBackground1 = Directly;

	Result = TimeConsumingOperations.ExecuteInBackground("ReportsOptions.GenerateReportInBackground", GenerationParameters,
		ExecutionParameters);

	IDBackgroundJob = Result.JobID;
	BackgroundJobStorageAddress = Result.ResultAddress;

	If Result.Status <> "Running" Then
		ImportReportGenerationResult();
	Else
		ReportsClientServer.DisplayReportState(
			ThisObject, NStr("en = 'Generating report…';"), PictureLib.TimeConsumingOperation48);
	EndIf;
	Return Result;

EndFunction

&AtServer
Function ReportGenerationParameters(ReportName, Directly)

	AdditionalProperties = Report.SettingsComposer.UserSettings.AdditionalProperties;
	AdditionalProperties.Insert("VariantModified", VariantModified);
	AdditionalProperties.Insert("UserSettingsModified", UserSettingsModified);

	ReportGenerationParameters = ReportsOptions.ReportGenerationParameters();
	ReportGenerationParameters.RefOfReport = ReportSettings.ReportRef;
	ReportGenerationParameters.OptionRef1 = ReportSettings.OptionRef;
	ReportGenerationParameters.VariantKey = CurrentVariantKey;
	ReportGenerationParameters.SchemaKey = ReportSettings.SchemaKey;
	ReportGenerationParameters.TablesToUse = ReportSettings.TablesToUse;
	ReportGenerationParameters.ExternalReportBinaryData = ?(ValueIsFilled(ExternalReportBinaryDataAddress),
		GetFromTempStorage(ExternalReportBinaryDataAddress), Undefined);
	ReportGenerationParameters.ParametersChanged = ParametersChanged;
	ReportGenerationParameters.SchemaModified = ReportSettings.SchemaModified;
	ReportGenerationParameters.DCSettings = Report.SettingsComposer.Settings;
	ReportGenerationParameters.FixedDCSettings = Report.SettingsComposer.FixedSettings;
	ReportGenerationParameters.DCUserSettings = Report.SettingsComposer.UserSettings;
	FillPropertyValues(ReportGenerationParameters, ReportGenerationMeasurementsParameters(ReportName));

	If Directly Then
		If ReportSettings.SchemaModified Then
			ReportGenerationParameters.SchemaURL = ReportSettings.SchemaURL;
		EndIf;
		ReportGenerationParameters.Object = FormAttributeToValue("Report");
		ReportGenerationParameters.FullName = ReportSettings.FullName;
	Else
		If ReportSettings.SchemaModified Then
			ReportGenerationParameters.DCSchema = GetFromTempStorage(ReportSettings.SchemaURL);
		EndIf;
	EndIf;

	Return ReportGenerationParameters;

EndFunction

&AtServer
Function ReportGenerationMeasurementsParameters(ReportName)
	MeasurementsParameters = New Structure("KeyOperationName, KeyOperationComment");

	If Not ReportSettings.RunMeasurements Or Not ValueIsFilled(ReportSettings.MeasurementsKey) Then
		Return MeasurementsParameters;
	EndIf;

	KeyOperationComment = New Map;
	KeyOperationComment.Insert("ReportName", ReportName);
	KeyOperationComment.Insert("PredefinedOptionKey", ReportSettings.PredefinedOptionKey);
	KeyOperationComment.Insert("External", Number(ReportSettings.External));
	KeyOperationComment.Insert("Custom", Number(ReportSettings.Custom));
	KeyOperationComment.Insert("Details", Number(DetailsMode));
	KeyOperationComment.Insert("ItemModified", Number(VariantModified));

	MeasurementsParameters.KeyOperationName = ReportSettings.MeasurementsKey + ".Generation1";
	MeasurementsParameters.KeyOperationComment = KeyOperationComment;

	Return MeasurementsParameters;
EndFunction

&AtServer
Procedure ImportReportGenerationResult()
	If Not IsTempStorageURL(BackgroundJobStorageAddress) Then
		ShowGenerationErrors(NStr("en = 'Cannot generate the report.';"));
		Return;
	EndIf;

	Result = GetFromTempStorage(BackgroundJobStorageAddress);

	DeleteFromTempStorage(BackgroundJobStorageAddress);
	BackgroundJobStorageAddress = Undefined;

	If Result = Undefined Then
		ShowGenerationErrors(NStr("en = 'Cannot generate the report (empty result)';"));
		Return;
	EndIf;

	Success = CommonClientServer.StructureProperty(Result, "Success");
	If Success <> True Then
		ShowGenerationErrors(Result.ErrorText);
		Return;
	EndIf;

	DataStillUpdating = CommonClientServer.StructureProperty(Result, "DataStillUpdating", False);
	If DataStillUpdating Then
		Common.MessageToUser(ReportsOptions.DataIsBeingUpdatedMessage());
	EndIf;

	ReportsClientServer.DisplayReportState(ThisObject);

	FillPropertyValues(ReportSettings.Print, ReportSpreadsheetDocument); // Save print settings.
	ReportSpreadsheetDocument = Result.SpreadsheetDocument;
	FillPropertyValues(ReportSpreadsheetDocument, ReportSettings.Print); // Recovery.
	ReportCreated = True;

	If ValueIsFilled(ReportDetailsData) And IsTempStorageURL(ReportDetailsData) Then
		DeleteFromTempStorage(ReportDetailsData);
	EndIf;
	ReportDetailsData = PutToTempStorage(Result.Details, UUID);

	ReportsOptionsInternal.InitializeReportHeaders(ThisObject);
	InitializeTheMenuOfGroupingLevels();

	If Not Result.VariantModified And Not Result.UserSettingsModified Then
		Return;
	EndIf;

	ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters("AfterGenerate");
	CommonClientServer.SupplementStructure(ParametersOfUpdate, Result, True);
	UpdateSettingsFormItemsAtServer(ParametersOfUpdate);
EndProcedure

#EndRegion

&AtClient
Procedure ShowSendByEmailDialog()
	Attachment = New Structure;
	Attachment.Insert("AddressInTempStorage", PutToTempStorage(ReportSpreadsheetDocument,
		UUID));
	Attachment.Insert("Presentation", ReportCurrentOptionDescription);

	AttachmentsList = CommonClientServer.ValueInArray(Attachment);

	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsClient = CommonClient.CommonModule(
			"EmailOperationsClient");
		SendOptions = ModuleEmailOperationsClient.EmailSendOptions();
		SendOptions.Subject = ReportCurrentOptionDescription;
		SendOptions.Attachments = AttachmentsList;
		ModuleEmailOperationsClient.CreateNewEmailMessage(SendOptions);
	EndIf;
EndProcedure

// Parameters:
//  Item - FormField
//  StandardProcessing - Boolean
//
&AtClient
Procedure ShowChoiceList(Item, StandardProcessing)
	StandardProcessing = False;

	InformationRecords = ReportsClient.SettingItemInfo(Report.SettingsComposer, Item.Name);
	SettingsDescription = InformationRecords.LongDesc;

	UserSettings = Report.SettingsComposer.UserSettings.Items;

	ChoiceParameters = ReportsClientServer.ChoiceParameters(
		InformationRecords.Settings, UserSettings, InformationRecords.Item);

	ExtendedTypesDetails = CommonClientServer.StructureProperty(
		Report.SettingsComposer.Settings.AdditionalProperties, "ExtendedTypesDetails");

	ValueType = Undefined;
	If ExtendedTypesDetails <> Undefined Then
		ExtendedTypeDetails = ExtendedTypesDetails[InformationRecords.IndexOf];
		If ExtendedTypeDetails <> Undefined Then
			ValueType = ExtendedTypeDetails.TypesDetailsForForm;
		EndIf;
	EndIf;

	Item.AvailableTypes = ReportsClient.ValueTypeRestrictedByLinkByType(
		InformationRecords.Settings, UserSettings, InformationRecords.Item, SettingsDescription, ValueType);

	If TypeOf(InformationRecords.UserSettingItem) = Type("DataCompositionSettingsParameterValue") Then
		CurrentValue = InformationRecords.UserSettingItem.Value;
	Else
		CurrentValue = InformationRecords.UserSettingItem.RightValue;
	EndIf;

	MarkedValues = ReportsClientServer.ValuesByList(CurrentValue);
	AvailableValues = ?(SettingsDescription = Undefined, Undefined, SettingsDescription.AvailableValues);

	Condition = ReportsClientServer.SettingItemCondition(InformationRecords.UserSettingItem, SettingsDescription);
	ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
		?(SettingsDescription = Undefined, Undefined, SettingsDescription.ChoiceFoldersAndItems), Condition);

	ValuesForSelection = ValuesForSelection(Item.ChoiceList, InformationRecords.UserSettingItem, 
		Item.AvailableTypes, AvailableValues);

	RestrictSelectionBySpecifiedValues = AvailableValues <> Undefined;

	HandlerParameters = New Structure;
	HandlerParameters.Insert("UserSettingItem", InformationRecords.UserSettingItem);
	HandlerParameters.Insert("RestrictSelectionBySpecifiedValues", RestrictSelectionBySpecifiedValues);
	HandlerParameters.Insert("TagName", Item.Name);

	Handler = New NotifyDescription("CompleteChoiceFromList", ThisObject, HandlerParameters);

	If ReportsClient.ChoiceOverride(ThisObject, Handler, InformationRecords.LongDesc, Item.AvailableTypes,
		MarkedValues, ChoiceParameters) Then
		Return;
	EndIf;

	If ReportsClient.IsSelectMetadataObjects(Item.AvailableTypes, MarkedValues, Handler) Then
		Return;
	EndIf;

	OpeningParameters = New Structure;
	OpeningParameters.Insert("Marked", MarkedValues);
	OpeningParameters.Insert("TypeDescription", Item.AvailableTypes);
	OpeningParameters.Insert("ValuesForSelection", ValuesForSelection);
	OpeningParameters.Insert("ValuesForSelectionFilled", Item.ChoiceList.Count() > 0);
	OpeningParameters.Insert("RestrictSelectionBySpecifiedValues", RestrictSelectionBySpecifiedValues);
	OpeningParameters.Insert("Presentation", Item.Title);
	OpeningParameters.Insert("ChoiceParameters", New Array(ChoiceParameters));
	OpeningParameters.Insert("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	OpeningParameters.Insert("QuickChoice", ?(SettingsDescription = Undefined, False, SettingsDescription.QuickChoice));
	
	Context = New Structure;
	Context.Insert("OpeningParameters", OpeningParameters);
	Context.Insert("Handler", Handler);
	
	If RestrictSelectionBySpecifiedValues Then
		ShowChoiceListFollowUp(Undefined, Context);
	Else
		ReportsClient.StartSelectUsers(ThisObject,
			Item, Item.AvailableTypes, MarkedValues, ChoiceParameters, Handler,
			New NotifyDescription("ShowChoiceListFollowUp", ThisObject, Context));
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowChoiceListFollowUp(Result, Context) Export
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes",
		Context.OpeningParameters, ThisObject,,,, Context.Handler);
	
EndProcedure

&AtClient
Function ValuesForSelection(ChoiceList, SettingItem, AvailableTypes, AvailableValues)
	ValuesForSelection = CommonClient.CopyRecursive(ChoiceList);
	If SettingItem = Undefined Then
		Return ValuesForSelection;
	EndIf;

	ValuesForSelection.ValueType = AvailableTypes;

	FilterValue = ReportsClient.SelectionValueCache(Report.SettingsComposer, SettingItem);
	If FilterValue <> Undefined Then
		CommonClientServer.SupplementList(ValuesForSelection, FilterValue);
	EndIf;

	ReportsClient.UpdateListViews(ValuesForSelection, AvailableValues);

	Return ValuesForSelection;
EndFunction

// Parameters:
//  List - ValueList
//         - Array of CatalogRef.Users
//  ChoiceParameters - Structure:
//    * UserSettingItem - DataCompositionFilterItem
//                                       - DataCompositionSettingsParameterValue
//    * RestrictSelectionBySpecifiedValues - Boolean
//    * TagName - String
//
&AtClient
Procedure CompleteChoiceFromList(List, ChoiceParameters) Export
	If TypeOf(List) = Type("Array") Then
		SelectedValues = List;

		List = New ValueList;
		List.LoadValues(SelectedValues);
		List.FillChecks(True);
	ElsIf TypeOf(List) <> Type("ValueList") Then
		Return;
	EndIf;

	SelectedValues = New ValueList;
	For Each ListItem In List Do
		If ListItem.Check Then
			FillPropertyValues(SelectedValues.Add(), ListItem);
		EndIf;
	EndDo;

	UserSettingItem = ChoiceParameters.UserSettingItem;
	UserSettingItem.Use = True;

	If TypeOf(UserSettingItem) = Type("DataCompositionSettingsParameterValue") Then
		UserSettingItem.Value = SelectedValues;
	Else
		UserSettingItem.RightValue = SelectedValues;
	EndIf;

	If Not ChoiceParameters.RestrictSelectionBySpecifiedValues Then
		Item = Items.Find(ChoiceParameters.TagName);

		If Item <> Undefined Then
			Item.ChoiceList.Clear();

			For Each ListItem In List Do
				FillPropertyValues(Item.ChoiceList.Add(), ListItem);
			EndDo;
		EndIf;
	EndIf;

	ReportsClient.CacheFilterValue(Report.SettingsComposer, UserSettingItem, List);

	ReportsClientServer.NotifyOfSettingsChange(ThisObject);
EndProcedure

&AtClient
Function GoToLink(HyperlinkAddress)
	If IsBlankString(HyperlinkAddress) Then
		Return False;
	EndIf;
	ReferenceAddressInReg = Upper(HyperlinkAddress);
	If StrStartsWith(ReferenceAddressInReg, Upper("http://")) Or StrStartsWith(ReferenceAddressInReg, Upper("https://"))
		Or StrStartsWith(ReferenceAddressInReg, Upper("e1cib/")) Or StrStartsWith(ReferenceAddressInReg, Upper("e1c://")) Then
		FileSystemClient.OpenURL(HyperlinkAddress);
		Return True;
	EndIf;
	Return False;
EndFunction

&AtClient
Procedure ImportSchemaAfterLocateFile(SelectedFiles, AdditionalParameters) Export
	If SelectedFiles = Undefined Then
		Return;
	EndIf;

	BinaryData = GetFromTempStorage(SelectedFiles.Location);

	AdditionalProperties = Report.SettingsComposer.Settings.AdditionalProperties;
	AdditionalProperties.Clear();
	AdditionalProperties.Insert("DataCompositionSchema", BinaryData);
	AdditionalProperties.Insert("ReportInitialized", False);

	FillParameters = ReportsClientServer.ReportFormUpdateParameters();
	FillParameters.DCSettingsComposer = Report.SettingsComposer;
	FillParameters.UserSettingsModified = True;
	UpdateSettingsFormItems(FillParameters);
	
EndProcedure

&AtClient
Procedure ApplyPassedSettings(SettingsDescription)
	If VariantModified Then
		ShowMessageBox(, NStr("en = 'The report option was changed.
			|Please save the changes before applying the settings.';"));
		Return;
	EndIf;

	SetCurrentUserSettings(SettingsDescription.SettingsKey);
	CurrentUserSettingsPresentation = SettingsDescription.Presentation;

	Report.SettingsComposer.LoadUserSettings(SettingsDescription.Settings);
	Generate();
EndProcedure

#Region IndicatorsCalculation

// Parameters:
//  Parent - FormGroup
//  Menu - Undefined
//       - ValueList
// 
// Returns:
//  - Undefined
//  - ValueList
//
&AtClient
Function MenuOfIndicatorTypes(Parent, Menu = Undefined)

	If Menu = Undefined Then
		Menu = New ValueList;
	EndIf;

	MenuItems = Parent.ChildItems; // FormItems

	For Each Item In MenuItems Do

		If TypeOf(Item) <> Type("FormGroup") Then
			Menu.Add(Item.Name, Item.Title, MainIndicator = Item.Name);
		Else
			MenuOfIndicatorTypes(Item, Menu);
		EndIf;

	EndDo;

	MenuItem = Menu.FindByValue(Items.CalculateAllIndicators.Name);

	If MenuItem <> Undefined Then
		MenuItem.Check = ExpandIndicatorsArea;
	EndIf;

	Return Menu;

EndFunction

&AtClient
Procedure AfterSelectingTheIndicator(TheSelectedIndicator, AdditionalParameters) Export

	If TypeOf(TheSelectedIndicator) <> Type("ValueListItem") Then
		Return;
	EndIf;

	If TheSelectedIndicator.Value = Items.CalculateAllIndicators.Name Then

		ExpandIndicatorsArea = Not Items.CalculateAllIndicators.Check;
		CommonInternalClient.SetIndicatorsPanelVisibiility(Items, ExpandIndicatorsArea);

	Else
		CalculateIndicators(TheSelectedIndicator.Value);
	EndIf;

EndProcedure

// This procedure calculates functions for the selected cell range.
// See the ReportSpreadsheetDocumentOnActivateArea event handler.
//
&AtClient
Procedure CalculateIndicatorsDynamically()

	CalculateIndicators();

EndProcedure

&AtClient
Procedure CalculateIndicators(CurrentCommand = "")

	If Not ReportSettings.OutputSelectedCellsTotal Then

		SavedInSettingsDataModified = True;
		Return;

	EndIf;

	Factor = "";
	CommonInternalClient.CalculateIndicators(ThisObject, "ReportSpreadsheetDocument", CurrentCommand, 2);

EndProcedure

#EndRegion

#Region UniversalSearch

&AtClient
Procedure GoToSettings(ExtendedMode = Undefined)

	RunMeasurements = ReportSettings.RunMeasurements And ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.TimeMeasurement(
			ReportSettings.MeasurementsKey + ".Settings", False, False);
	EndIf;

	FormParameters = New Structure;
	CommonClientServer.SupplementStructure(FormParameters, ParametersForm, True);

	If ExtendedMode = True Then

		ReportSettings.SettingsFormAdvancedMode = 1;

		FormParameters.Insert("PageName", "FiltersPage");
		FormParameters.Insert("ResetCustomSettings", True);

	EndIf;

	FormParameters.Insert("VariantKey", String(CurrentVariantKey));
	FormParameters.Insert("Variant", Report.SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("DescriptionOption", String(ReportCurrentOptionDescription));

	Handler = New NotifyDescription("ApplySettingsAndReshapeReport", ThisObject);
	Form = OpenForm(ReportSettings.FullName + ".SettingsForm", FormParameters, ThisObject,,,, Handler);

	If RunMeasurements And Form <> Undefined Then
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;

EndProcedure

&AtClient
Function TheTransitionToTheSettingsIsCompleted(Query = Undefined)

	TheRequestIsNormalized = Upper(?(ValueIsFilled(Query), Query, Factor));
	If TheRequestIsNormalized = "DCS" Then
		ResetUniversalSearch();
		GoToSettings(ReportSettings.EditOptionsAllowed);
		Return True;
	EndIf;
	Return False;

EndFunction

&AtClient
Procedure ResetUniversalSearch()

	Factor = "";
	Items.Factor.UpdateEditText();

EndProcedure

&AtClient
Function SuitableUniversalSearchValues(Query)

	SuitableValues = New ValueList;
	MaximumNumberOfSuitableValues = 50;

	SearchParameters = UniversalSearchParameters(Query);

	If Not ValueIsFilled(SearchParameters.SearchString) Then
		Return SuitableValues;
	EndIf;

	CreateAUniversalSearchField(SearchParameters.ControlCharacters);

	SearchFieldsByType = UniversalSearchFieldsByType(
		ReportSettings.SchemaURL, Report.SettingsComposer.Settings);

	If SearchFieldsByType.Count() = 0 Then
		Return SuitableValues;
	EndIf;

	If TheUniversalSearchParametersAreApplicableToLinks(SearchParameters) Then
		FindSuitableUniversalSearchValues(SuitableValues, SearchFieldsByType, SearchParameters);
	EndIf;

	FindSuitableValuesBooleanUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters);

	FindSuitableValuesDateUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters);

	FindSuitableValuesStringUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters);

	FindSuitableValuesOfTheUniversalNumberSearch(SuitableValues, SearchFieldsByType, SearchParameters);

	If SuitableValues.Count() = 0 Then

		If StrLen(SearchParameters.SearchString) > 2 Then
			Message = NStr("en = 'No matches found';");
		Else
			Message = NStr("en = 'Continue typing…';");
		EndIf;

		FormattedMessage = New FormattedString(Message, , WebColors.MediumGray);
		SuitableValues.Add("", FormattedMessage);

	EndIf;

	If SuitableValues.Count() <= MaximumNumberOfSuitableValues Then
		Return SuitableValues;
	EndIf;

	SuitableValuesAreNormalized = New ValueList;

	For ItemNumber = 1 To MaximumNumberOfSuitableValues Do
		FillPropertyValues(SuitableValuesAreNormalized.Add(), SuitableValues[ItemNumber - 1]);
	EndDo;

	Return SuitableValuesAreNormalized;

EndFunction

&AtClient
Function UniversalSearchParameters(Query)

	SearchParameters = New Structure;
	SearchParameters.Insert("SearchString", Query);
	SearchParameters.Insert("TheSearchStringIsNormalized", Query);
	SearchParameters.Insert("SearchNumber", Undefined);
	SearchParameters.Insert("SearchDate", Date(1, 1, 1));
	SearchParameters.Insert("ControlCharacters", "");

	FirstChar = Left(Query, 1);
	TheFirstTwoCharacters = Left(Query, 2);

	If TheFirstTwoCharacters = ">=" Or TheFirstTwoCharacters = "<=" Or TheFirstTwoCharacters = "<>" Then

		SearchParameters.SearchString = Mid(Query, 3);
		SearchParameters.ControlCharacters = TheFirstTwoCharacters;

	ElsIf FirstChar = "-" Or FirstChar = ">" Or FirstChar = "<" Or FirstChar = "=" Then

		SearchParameters.SearchString = Mid(Query, 2);
		SearchParameters.ControlCharacters = FirstChar;

	EndIf;

	If CommonClientServer.IsNumber(SearchParameters.SearchString) Then

		NumberDetails = New TypeDescription("Number");
		SearchParameters.SearchNumber = NumberDetails.AdjustValue(SearchParameters.SearchString);

	EndIf;

	SearchParameters.SearchDate = CommonClientServer.StringToDate(SearchParameters.SearchString);

	SearchParameters.TheSearchStringIsNormalized = StrReplace(SearchParameters.SearchString, """", "_");

	Return SearchParameters;

EndFunction

&AtClient
Procedure CreateAUniversalSearchField(ControlCharacters)

	TheQueryBox = Items.Factor;

	If ControlCharacters = "-" Then

		TheQueryBox.TextColor = WebColors.Red;

	ElsIf Not IsBlankString(ControlCharacters) Then

		TheQueryBox.TextColor = WebColors.Green;

	Else

		TheQueryBox.TextColor = New Color;

	EndIf;

EndProcedure

&AtClient
Function TheUniversalSearchParametersAreApplicableToLinks(SearchParameters)

	InvalidControlCharacters = New Array;
	InvalidControlCharacters.Add(">");
	InvalidControlCharacters.Add(">=");
	InvalidControlCharacters.Add("<");
	InvalidControlCharacters.Add("<=");

	If InvalidControlCharacters.Find(SearchParameters.ControlCharacters) <> Undefined Then
		Return False;
	EndIf;

	Return StrLen(SearchParameters.SearchString) > 2 
		Or CommonClientServer.IsNumber(SearchParameters.SearchString);

EndFunction

&AtClient
Procedure FindSuitableValuesOfTheUniversalNumberSearch(SuitableValues, SearchFieldsByType, SearchParameters)

	If Not CommonClientServer.IsNumber(SearchParameters.SearchString) Then
		Return;
	EndIf;

	SearchFields = SearchFieldsByType[Type("Number")];

	If SearchFields = Undefined Then
		Return;
	EndIf;

	SuitableValuesForTheNumber = New ValueList;

	AvailableSearchFields = AvailableNumberSearchFields(SearchFields, SearchParameters.SearchNumber,
		SearchParameters.ControlCharacters);

	For Each FieldForSearch In AvailableSearchFields Do

		SearchProperties = UniversalSearchProperties(FieldForSearch.Key, SearchParameters.SearchNumber,
			SearchParameters.ControlCharacters);
		SearchOptions = New Array;
		SearchOptions.Add(SearchProperties);
		SuitableValuesForTheNumber.Add(SearchOptions, ViewSearchResultClient(
			FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));

	EndDo;

	SuitableValuesForTheNumber.SortByPresentation();
	CommonClientServer.SupplementList(SuitableValues, SuitableValuesForTheNumber);

EndProcedure

&AtClient
Function AvailableNumberSearchFields(SearchFields, SearchValue, ControlCharacters)

	Condition = UniversalSearchCondition(SearchValue, ControlCharacters);

	If Condition = DataCompositionComparisonType.Equal Then
		Return CommonClient.CopyRecursive(SearchFields);
	EndIf;

	AvailableSearchFields = New Map;
	ParameterAvailableFields = Report.SettingsComposer.Settings.DataParametersAvailableFields;

	For Each FieldForSearch In SearchFields Do

		If ParameterAvailableFields.FindField(FieldForSearch.Key) = Undefined Then
			AvailableSearchFields.Insert(FieldForSearch.Key, FieldForSearch.Value);
		EndIf;

	EndDo;

	Return AvailableSearchFields;

EndFunction

&AtServerNoContext
Procedure FindSuitableUniversalSearchValues(SuitableValues, SearchFieldsByType, SearchParameters)

	If Not ValueIsFilled(SearchParameters.SearchString) Then
		Return;
	EndIf;

	QueriesTexts = New Array;
	For Each Item In SearchFieldsByType Do

		If Not Common.IsReference(Item.Key) Then
			Continue;
		EndIf;

		MetadataObject = Metadata.FindByType(Item.Key);
		If Metadata.Enums.Contains(MetadataObject) Then
			For Each FieldElement In Item.Value Do
				For Each Value In MetadataObject.EnumValues Do
					If StrStartsWith(Upper(Value.Synonym), Upper(SearchParameters.SearchString)) Then
						EnumerationValue = Common.PredefinedItem(MetadataObject.FullName()
							+ "." + Value.Name);
						SearchProperties = UniversalSearchProperties(FieldElement.Key, EnumerationValue,
							SearchParameters.ControlCharacters);
						SearchOptions = New Array;
						SearchOptions.Add(SearchProperties);
						SuitableValues.Add(SearchOptions, ViewSearchResult(
							FieldElement.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));
					EndIf;
				EndDo;
			EndDo;
			Continue;
		EndIf;

		If Not AccessRight("Read", MetadataObject) Then
			Continue;
		EndIf;

		QueryText = TheTextOfTheRequestForTheSearchObject(MetadataObject, SearchParameters);
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "SELECT"); // @query-part-1, @query-part-2
		EndIf;
		QueriesTexts.Add(QueryText);

	EndDo;

	If QueriesTexts.Count() = 0 Then
		Return;
	EndIf;

	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF); // @query-part
	Query = New Query(QueryText);

	If StrFind(QueryText, "&SearchNumber") > 0 Then
		Query.SetParameter("SearchNumber", SearchParameters.SearchNumber);
	EndIf;

	If StrFind(QueryText, "&SearchDate") > 0 Then
		Query.SetParameter("SearchDate", SearchParameters.SearchDate);
	EndIf;

	Selection = Query.Execute().Select();

	IndexOfSearchOptions = New Map;
	IndexOfSearchViews = New Map;

	IndexOfAdditionalValues = New Map;
	AdditionalValues = New ValueList;

	While Selection.Next() Do

		SearchFields = SearchFieldsByType[TypeOf(Selection.Ref)];
		For Each FieldForSearch In SearchFields Do

			SearchProperties = UniversalSearchProperties(FieldForSearch.Key, Selection.Ref,
				SearchParameters.ControlCharacters);
			SearchOptions = IndexOfSearchOptions[SearchProperties.RightValue];
			If SearchOptions = Undefined Then

				SearchView = RepresentationOfTheUniversalLinkSearch(
					Selection, FieldForSearch.Value, SearchProperties.ComparisonType, SearchParameters.SearchString);

				IndexOfSearchViews.Insert(SearchProperties.RightValue, SearchView);
				SearchOptions = New Array;

			EndIf;

			SearchOptions.Add(SearchProperties);
			IndexOfSearchOptions.Insert(SearchProperties.RightValue, SearchOptions);

			If Not ValueIsFilled(Selection.FieldByCondition) 
				Or IndexOfAdditionalValues[FieldForSearch.Key] 	<> Undefined Then

				Continue;
			EndIf;

			DataPath = StringFunctionsClientServer.SubstituteParametersToString(
				"%1.%2", FieldForSearch.Key, Selection.FieldByCondition);

			FieldAttribute = New DataCompositionField(DataPath);
			SearchProperties = UniversalSearchProperties(
				FieldAttribute, SearchParameters.SearchString, SearchParameters.ControlCharacters);
				
			DataPathPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				"%1.%2", FieldForSearch.Value, Selection.FieldByConditionPresentation);
				
			SearchOptions = New Array;
			SearchOptions.Add(SearchProperties);
			AdditionalValues.Add(SearchOptions, ViewSearchResult(DataPathPresentation,
				SearchProperties.ComparisonType, SearchParameters.SearchString));

			IndexOfAdditionalValues.Insert(FieldForSearch.Key, True);

		EndDo;

	EndDo;

	For Each ValueIndex In IndexOfSearchOptions Do
		SuitableValues.Add(ValueIndex.Value, IndexOfSearchViews[ValueIndex.Key]);
	EndDo;

	SuitableValues.SortByPresentation();
	AdditionalValues.SortByPresentation();

	CommonClientServer.SupplementList(SuitableValues, AdditionalValues);

EndProcedure

&AtClient
Procedure FindSuitableValuesBooleanUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters)

	If Not ValueIsFilled(SearchParameters.SearchString) Then
		Return;
	EndIf;

	SearchFields = SearchFieldsByType[Type("Boolean")];

	If SearchFields = Undefined Then
		Return;
	EndIf;

	ValuesSuitableForBoolean = New ValueList;
	
	// Search by column name.
	For Each FieldForSearch In SearchFields Do
		If StrStartsWith(Upper(FieldForSearch.Value), Upper(SearchParameters.SearchString)) Then
			SearchProperties = UniversalSearchProperties(FieldForSearch.Key, True, SearchParameters.ControlCharacters);
			SearchOptions = New Array;
			SearchOptions.Add(SearchProperties);
			ValuesSuitableForBoolean.Add(SearchOptions, ViewSearchResultClient(
				FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));
			SearchProperties = UniversalSearchProperties(FieldForSearch.Key, False, SearchParameters.ControlCharacters);
			SearchOptions = New Array;
			SearchOptions.Add(SearchProperties);
			ValuesSuitableForBoolean.Add(SearchOptions, ViewSearchResultClient(
				FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));
		EndIf;
	EndDo;
	
	// Search by Boolean values.
	// ACC:1391-off - Validate user input.
	If StrCompare(SearchParameters.SearchString, NStr("en = 'Yes';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'True';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'Enabled';")) = 0 Then
		For Each FieldForSearch In SearchFields Do
			SearchProperties = UniversalSearchProperties(FieldForSearch.Key, True, SearchParameters.ControlCharacters);
			SearchOptions = New Array;
			SearchOptions.Add(SearchProperties);
			ValuesSuitableForBoolean.Add(SearchOptions, ViewSearchResultClient(
				FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));
		EndDo;
	ElsIf StrCompare(SearchParameters.SearchString, NStr("en = 'No';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'False';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'Disabled';")) = 0 Then
		For Each FieldForSearch In SearchFields Do
			SearchProperties = UniversalSearchProperties(FieldForSearch.Key, False, SearchParameters.ControlCharacters);
			SearchOptions = New Array;
			SearchOptions.Add(SearchProperties);
			ValuesSuitableForBoolean.Add(SearchOptions, ViewSearchResultClient(
				FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue));
		EndDo;
	EndIf;
	// ACC:1391-on

	ValuesSuitableForBoolean.SortByPresentation();
	CommonClientServer.SupplementList(SuitableValues, ValuesSuitableForBoolean);

EndProcedure

&AtClient
Procedure FindSuitableValuesStringUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters)

	If Not ValueIsFilled(SearchParameters.SearchString) Or ValueIsFilled(SearchParameters.SearchDate)
		Or ReportSpreadsheetDocument.FindText(SearchParameters.SearchString,,,,,, True) = Undefined Then
		Return;
	EndIf;
	
	// ACC:1391-off - Validate user input.
	If StrCompare(SearchParameters.SearchString, NStr("en = 'Yes';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'True';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'Enabled';")) = 0
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'No';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'False';")) = 0 
		Or StrCompare(SearchParameters.SearchString, NStr("en = 'Disabled';")) = 0 Then
		Return;
	EndIf;
	// ACC:1391-on

	For Each FindType In SearchFieldsByType Do
		For Each FieldForSearch In FindType.Value Do
			If StrStartsWith(Upper(FieldForSearch.Value), Upper(SearchParameters.SearchString)) Then
				Return;
			EndIf;
		EndDo;
	EndDo;

	SearchFields = SearchFieldsByType[Type("String")];
	If SearchFields = Undefined Then
		Return;
	EndIf;

	ValuesSuitableForString = New ValueList;

	For Each FieldForSearch In SearchFields Do
		SearchProperties = UniversalSearchProperties(FieldForSearch.Key, SearchParameters.SearchString,
			SearchParameters.ControlCharacters);
		SearchOptions = New Array;
		SearchOptions.Add(SearchProperties);
		ResultPresentation = ViewSearchResultClient(
			FieldForSearch.Value, SearchProperties.ComparisonType, SearchProperties.RightValue);
		IsValueExist = False;
		For Each SuitableValue In SuitableValues Do
			If StrCompare(SuitableValue.Presentation, ResultPresentation) = 0 Then
				IsValueExist = True;
				Break;
			EndIf;
		EndDo;
		If IsValueExist Then
			Continue;
		EndIf;
		ValuesSuitableForString.Add(SearchOptions, ResultPresentation);
	EndDo;

	ValuesSuitableForString.SortByPresentation();
	CommonClientServer.SupplementList(SuitableValues, ValuesSuitableForString);

EndProcedure

&AtClient
Procedure FindSuitableValuesDateUniversalSearch(SuitableValues, SearchFieldsByType, SearchParameters)

	If Not ValueIsFilled(SearchParameters.SearchString) Or Not ValueIsFilled(SearchParameters.SearchDate)
		Or CommonClientServer.IsNumber(SearchParameters.SearchString) 
		Or ReportSpreadsheetDocument.FindText(SearchParameters.SearchString,,,,,, True) = Undefined Then
		Return;
	EndIf;

	SearchFields = SearchFieldsByType[Type("Date")];

	If SearchFields = Undefined Then
		Return;
	EndIf;

	ValuesSuitableForDate = New ValueList;

	For Each FieldForSearch In SearchFields Do
		SearchProperties = UniversalSearchProperties(FieldForSearch.Key, SearchParameters.SearchDate,
			SearchParameters.ControlCharacters);
		SearchOptions = New Array;
		SearchOptions.Add(SearchProperties);
		DatePresentation = ?(SearchProperties.RightValue = BegOfDay(SearchProperties.RightValue), 
			Format(SearchProperties.RightValue, "DLF=D"), SearchProperties.RightValue);
		ValuesSuitableForDate.Add(SearchOptions, ViewSearchResultClient(
			FieldForSearch.Value, SearchProperties.ComparisonType, DatePresentation));
	EndDo;

	ValuesSuitableForDate.SortByPresentation();
	CommonClientServer.SupplementList(SuitableValues, ValuesSuitableForDate);

EndProcedure

&AtServerNoContext
Function TheTextOfTheRequestForTheSearchObject(Object, SearchParameters)

	QueryTextTemplate2 =
	"SELECT ALLOWED DISTINCT TOP 5
	|	""&FullObjectName"" AS FullObjectName,
	|	Ref AS Ref,
	|	&FieldByCondition AS FieldByCondition,
	|	&FieldPresentationByCondition AS FieldByConditionPresentation,
	|	&AdditionalData AS AdditionalData
	|FROM
	|	&FullObjectName
	|WHERE
	|	&Condition
	|";

	FieldsByCondition = QueryTextFieldsBySearchObject(Object, SearchParameters);
	
	QueryText = StrReplace(QueryTextTemplate2, "&FullObjectName", Object.FullName());
	QueryText = StrReplace(QueryText, "&FieldByCondition", FieldsByCondition.Value);
	QueryText = StrReplace(QueryText, "&FieldPresentationByCondition", FieldsByCondition.Presentation);
	QueryText = StrReplace(QueryText, "&Condition", TheConditionOfTheQueryTextForTheSearchObject(Object, SearchParameters));

	Return StrReplace(QueryText, "&AdditionalData", AdditionalDataOfTheQueryTextForTheSearchObject(Object));

EndFunction

// Parameters:
//  Object - MetadataObject
//  SearchParameters - Structure:
//    * TheSearchStringIsNormalized - String
// 
// Returns:
//  Structure:
//    * Value - String
//    * Presentation - String
//
&AtServerNoContext
Function QueryTextFieldsBySearchObject(Object, SearchParameters)
	
	Result = New Structure("Value, Presentation", """""", """""");

	FieldsByCondition = New Array;
	FieldsPresentationsByCondition = New Array;
	Fields = Object.InputByString; // FieldList

	QueryFragment = "WHEN CAST(%1 AS STRING(150)) LIKE %2 ESCAPE ""~"" THEN ""%3"""; // @query-part
	SearchString = """%" + Common.GenerateSearchQueryString(SearchParameters.TheSearchStringIsNormalized) + "%""";
	
	For Each Field In Fields Do

		AttributeType = SearchAttributeType(Object, Field.Name);
		If Not AttributeType.ContainsType(Type("String")) Then
			Continue;
		EndIf;
		
		FieldByCondition = StringFunctionsClientServer.SubstituteParametersToString(QueryFragment, 
			Field.Name, SearchString, Field.Name);
		FieldsByCondition.Add(FieldByCondition);
		
		FieldPresentationByCondition = StringFunctionsClientServer.SubstituteParametersToString(QueryFragment,
			Field.Name, SearchString, FieldPresentation(Field.Name, Object));
		FieldsPresentationsByCondition.Add(FieldPresentationByCondition);

	EndDo;

	If FieldsByCondition.Count() = 0 Then
		Return Result;
	EndIf;

	FieldsByCondition.Insert(0, "CASE"); // @query-part
	FieldsByCondition.Add("ELSE """""); // @query-part
	FieldsByCondition.Add("END"); // @query-part
	Result.Value = StrConcat(FieldsByCondition, " ");
	
	FieldsPresentationsByCondition.Insert(0, "CASE"); // @query-part
	FieldsPresentationsByCondition.Add("ELSE """""); // @query-part
	FieldsPresentationsByCondition.Add("END"); // @query-part
	Result.Presentation = StrConcat(FieldsPresentationsByCondition, " ");
	
	Return Result;

EndFunction

&AtServerNoContext
Function FieldPresentation(FieldName, Object)
	
	ObjectAttribute = Object.Attributes.Find(FieldName);
	
	If ObjectAttribute = Undefined Then
		For Each StandardAttribute In Object.StandardAttributes Do
			If StrCompare(StandardAttribute.Name, FieldName) = 0 Then
				ObjectAttribute = StandardAttribute;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If ObjectAttribute <> Undefined Then
		Return ObjectAttribute.Presentation();
	EndIf;
	
	
	Return FieldName;
	
EndFunction

// Parameters:
//  Object - MetadataObject
//  SearchParameters - Structure:
//    * TheSearchStringIsNormalized - String
// 
// Returns:
//  String
//
&AtServerNoContext
Function TheConditionOfTheQueryTextForTheSearchObject(Object, SearchParameters)

	Conditions = New Array;
	Fields = Object.InputByString; // FieldList

	FieldsNames = New Array;
	For Each Field In Fields Do
		FieldsNames.Add(Field.Name);
	EndDo;
	
	// Extend the list of document fields.
	FullNameParts1 = StrSplit(Object.FullName(), ".");
	If FullNameParts1[0] = "Document" Then
		If Fields.Find("Date") = Undefined Then
			FieldsNames.Add("Date");
		EndIf;
		If Fields.Find("Number") = Undefined Then
			FieldsNames.Add("Number");
		EndIf;
	EndIf;

	For Each FieldName In FieldsNames Do

		AttributeType = SearchAttributeType(Object, FieldName);
		If AttributeType.ContainsType(Type("String")) Then

			Condition = StringFunctionsClientServer.SubstituteParametersToString(
				"CAST(%1 AS STRING(150)) LIKE %2 ESCAPE ""~""", FieldName, """%"
				+ Common.GenerateSearchQueryString(SearchParameters.TheSearchStringIsNormalized)
				+ "%""");
		ElsIf AttributeType.ContainsType(Type("Date")) And SearchParameters.SearchDate <> Date(1, 1, 1) Then
			Condition = StringFunctionsClientServer.SubstituteParametersToString(
				"BEGINOFPERIOD(%1) = &SearchDate", FieldName); //@query-part
		ElsIf AttributeType.ContainsType(Type("Number")) And SearchParameters.SearchNumber <> Undefined Then
			Condition = StringFunctionsClientServer.SubstituteParametersToString(
				"CAST(%1 AS NUMBER) = &SearchNumber", FieldName); //@query-part
		Else
			Continue;
		EndIf;

		Conditions.Add(Condition);

	EndDo;

	If Conditions.Count() = 0 Then
		Return "FALSE";
	EndIf;

	Return StrConcat(Conditions, " OR "); //@query-part

EndFunction

// Parameters:
//  Object - MetadataObject
// 
// Returns:
//  String
//
&AtServerNoContext
Function AdditionalDataOfTheQueryTextForTheSearchObject(Object)

	AdditionalData = New Array;

	Exceptions = New Array;
	Exceptions.Add("Description");
	Exceptions.Add("Number");

	Fields = Object.InputByString; // FieldList

	For Each Field In Fields Do

		If Exceptions.Find(Field.Name) <> Undefined Then
			Continue;
		EndIf;

		AttributeType = SearchAttributeType(Object, Field.Name);

		If Not AttributeType.ContainsType(Type("String")) Then
			Continue;
		EndIf;

		Data = """" + FieldPresentation(Field.Name, Object) + ": "" + " + Field.Name;
		AdditionalData.Add(Data);

	EndDo;

	If AdditionalData.Count() = 0 Then
		Return """""";
	EndIf;

	Return StrConcat(AdditionalData, " + "", """);

EndFunction

// Parameters:
//  Object - MetadataObject
//  FieldName - String
// 
// Returns:
//  - TypeDescription
//
&AtServerNoContext
Function SearchAttributeType(Object, FieldName)

	For Each AttributeDetails In Object.StandardAttributes Do

		If AttributeDetails.Name = FieldName Then
			Return AttributeDetails.Type;
		EndIf;

	EndDo;

	AttributeDetails = Object.Attributes.Find(FieldName);

	If AttributeDetails <> Undefined Then
		Return AttributeDetails.Type;
	EndIf;

	Return New TypeDescription;

EndFunction

&AtServerNoContext
Function RepresentationOfTheUniversalLinkSearch(Data, FieldForSearch, Condition, SearchString)

	ValuePresentation = String(Data.Ref);
	For Each ServiceSymbol In StrSplit("< >", " ") Do
		ValuePresentation = StrReplace(ValuePresentation, ServiceSymbol, "");
	EndDo;

	If ValueIsFilled(Data.AdditionalData) Then
		ValuePresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (%2)';"), String(Data.Ref), Data.AdditionalData);
	EndIf;

	ConditionFragment = StringFunctions.FormattedString(ConditionFragmentTemplate(Condition));

	StartOfTheSearchString = StrFind(Upper(ValuePresentation), Upper(SearchString));
	EndOfTheSearchString = StartOfTheSearchString + StrLen(SearchString);
	LengthOfTheFoundFragment = ?(StartOfTheSearchString = 0, 0, StrLen(SearchString));

	FragmentBeforeTheSearchBar = Left(ValuePresentation, StartOfTheSearchString - 1);
	FragmentOfTheSearchString = StringFunctions.FormattedString(SearchStringFragmentTemplate(
		Mid(ValuePresentation, StartOfTheSearchString, LengthOfTheFoundFragment)));
	TheFragmentAfterTheSearchString = Mid(ValuePresentation, EndOfTheSearchString);

	Return New FormattedString(FieldForSearch, ConditionFragment, FragmentBeforeTheSearchBar, FragmentOfTheSearchString,
		TheFragmentAfterTheSearchString);

EndFunction

&AtClient
Function ViewSearchResultClient(Val FieldForSearch, Val Condition, Val SearchValue)

	ConditionString = SearchConditionString(FieldForSearch, Condition, SearchValue);
	ConditionFragment = StringFunctionsClient.FormattedString(ConditionFragmentTemplate(ConditionString));
	FragmentOfTheSearchString = StringFunctionsClient.FormattedString(SearchStringFragmentTemplate(SearchValue));
	Return FormattedSearchResultString(FieldForSearch, ConditionFragment, FragmentOfTheSearchString);

EndFunction

&AtServerNoContext
Function ViewSearchResult(Val FieldForSearch, Val Condition, Val SearchValue)

	ConditionString = SearchConditionString(FieldForSearch, Condition, SearchValue);
	ConditionFragment = StringFunctions.FormattedString(ConditionFragmentTemplate(ConditionString));
	FragmentOfTheSearchString = StringFunctions.FormattedString(SearchStringFragmentTemplate(SearchValue));
	Return FormattedSearchResultString(FieldForSearch, ConditionFragment, FragmentOfTheSearchString);

EndFunction

&AtClientAtServerNoContext
Function SearchConditionString(Val FieldForSearch, Val Condition, SearchValue)

	Result = ?(TypeOf(SearchValue) = Type("Number"), UniversalSearchOperator(Condition), Lower(Condition));
	SearchValue = String(SearchValue);
	Return Result;

EndFunction

&AtClientAtServerNoContext
Function FormattedSearchResultString(Val FieldForSearch, Val ConditionFragment, Val FragmentOfTheSearchString)

	Return New FormattedString(FieldForSearch, ConditionFragment, """", FragmentOfTheSearchString, """");

EndFunction

&AtClientAtServerNoContext
Function ConditionFragmentTemplate(Condition)

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1<span style=""color: %2"">%3</span>%4';"), " ", "HiddenReportOptionColor", 
			Lower(StrReplace(Condition, "<", "&lt;")), " ");

EndFunction

&AtClientAtServerNoContext
Function SearchStringFragmentTemplate(SearchString)

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '<span style=""color: %1; font: %2"">%3</span>';"), "MyReportsOptionsColor", "ImportantLabelFont",
		SearchString);

EndFunction

&AtClientAtServerNoContext
Function UniversalSearchProperties(FieldForSearch, SearchValue, ControlCharacters)

	Condition = UniversalSearchCondition(SearchValue, ControlCharacters);

	Properties = New Structure;
	Properties.Insert("Use", True);
	Properties.Insert("LeftValue", FieldForSearch);
	Properties.Insert("ComparisonType", Condition);
	Properties.Insert("RightValue", SearchValue);

	Return Properties;

EndFunction

&AtClientAtServerNoContext
Function UniversalSearchCondition(SearchValue, ControlCharacters)

	If TypeOf(SearchValue) = Type("String") And (Not ValueIsFilled(ControlCharacters) 
		Or ControlCharacters = "=") Then
		Condition = DataCompositionComparisonType.Contains;
	ElsIf TypeOf(SearchValue) = Type("String") And (ControlCharacters = "-" Or ControlCharacters = "<>") Then
		Condition = DataCompositionComparisonType.NotContains;
	ElsIf ControlCharacters = "-" Or ControlCharacters = "<>" Then
		Condition = DataCompositionComparisonType.NotEqual;
	ElsIf ControlCharacters = ">" Then
		Condition = DataCompositionComparisonType.Greater;
	ElsIf ControlCharacters = ">=" Then
		Condition = DataCompositionComparisonType.GreaterOrEqual;
	ElsIf ControlCharacters = "<" Then
		Condition = DataCompositionComparisonType.Less;
	ElsIf ControlCharacters = "<=" Then
		Condition = DataCompositionComparisonType.LessOrEqual;
	Else
		Condition = DataCompositionComparisonType.Equal;
	EndIf;

	Return Condition;

EndFunction

&AtServerNoContext
Function UniversalSearchOperator(Condition)

	Operators = New Map;
	Operators.Insert(DataCompositionComparisonType.Equal, "=");
	Operators.Insert(DataCompositionComparisonType.NotEqual, "<>");
	Operators.Insert(DataCompositionComparisonType.Greater, ">");
	Operators.Insert(DataCompositionComparisonType.GreaterOrEqual, ">=");
	Operators.Insert(DataCompositionComparisonType.Less, "<");
	Operators.Insert(DataCompositionComparisonType.LessOrEqual, "<=");

	Operator = Operators[Condition];
	Return ?(Operator = Undefined, Lower(Condition), Operator);

EndFunction

&AtServerNoContext
Function UniversalSearchFieldsByType(SchemaURL, Val Settings)

	SearchFieldsByType = New Map;

	SettingsComposer = New DataCompositionSettingsComposer;
	ReportsServer.InitializeSettingsComposer(SettingsComposer, SchemaURL);
	SettingsComposer.LoadSettings(Settings);

	SettingsComposer2 = New DataCompositionSettingsComposer;
	ReportsServer.InitializeSettingsComposer(SettingsComposer2, SchemaURL);
	SettingsComposer2.LoadSettings(Settings);
	SettingsComposer2.ExpandAutoFields();

	Collections = New Array;
	Collections.Add(DescriptionOfReportSelections(SettingsComposer));
	Collections.Add(DescriptionOfTheReportFields(SettingsComposer.Settings, SettingsComposer2.Settings));

	For Each Collection In Collections Do
		For Each FieldDetails In Collection Do
			Types = FieldDetails.ValueType.Types();
			For Each Type In Types Do

				FieldsByType = SearchFieldsByType[Type];
				If FieldsByType = Undefined Then
					FieldsByType = New Map;
				EndIf;

				FieldsByType.Insert(FieldDetails.Field, FieldDetails.Title);
				SearchFieldsByType.Insert(Type, FieldsByType);

			EndDo;
		EndDo;
	EndDo;

	Return SearchFieldsByType;

EndFunction

&AtServerNoContext
Function DescriptionOfReportSelections(SettingsComposer, Filter = Undefined, FiltersDetails = Undefined)

	If FiltersDetails = Undefined Then
		FiltersDetails = New Array;
	EndIf;

	Settings = SettingsComposer.Settings;
	If Filter = Undefined Then
		Filter = Settings.Filter;
	EndIf;

	For Each Item In Filter.Items Do
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
			DescriptionOfReportSelections(SettingsComposer, Item, FiltersDetails);
		Else
			FieldDetails = Settings.FilterAvailableFields.FindField(Item.LeftValue);

			If FieldDetails <> Undefined Then
				FiltersDetails.Add(FieldDetails);
			EndIf;
		EndIf;
	EndDo;

	Return FiltersDetails;

EndFunction

&AtServerNoContext
Function DescriptionOfTheReportFields(Settings, Settings2)

	FieldsDetails = New Array;

	IndexOfTheReportStructure = ReportsOptionsInternal.IndexOfTheReportStructureWithoutContext(Settings, Settings2);

	IndexOfReportFields = IndexOfTheReportStructure.Copy(, "Field");
	IndexOfReportFields.GroupBy("Field");

	ReportFields = IndexOfReportFields.UnloadColumn("Field");

	For Each ReportField In ReportFields Do

		FieldDetails = Settings.SelectionAvailableFields.FindField(ReportField);

		If FieldDetails = Undefined Then
			FieldDetails = Settings.GroupAvailableFields.FindField(ReportField);
		EndIf;

		If FieldDetails <> Undefined Then
			FieldsDetails.Add(FieldDetails);
		EndIf;

	EndDo;

	Return FieldsDetails;

EndFunction

&AtClient
Procedure ApplyTheUniversalSearchValue(SearchOptions)

	ThisIsACustomSearch = False;

	If Not TheUniversalSearchValueIsAppliedToTheParameters(SearchOptions, ThisIsACustomSearch) Then
		ApplyTheUniversalSearchValueToSelections(SearchOptions, ThisIsACustomSearch);
	EndIf;

	SettingsComposer = Report.SettingsComposer;

	If Not ThisIsACustomSearch Then
		WasOptionModified = VariantModified;
		SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
		VariantModified = WasOptionModified;

		SettingsResult = ReportsClientServer.ReportFormUpdateParameters();
		SettingsResult.DCSettingsComposer = SettingsComposer;
		SettingsResult.UserSettingsModified = True;
		AttachIdleHandler("UpdateSettingsFormItemsDeferred", 0.1, True);
	EndIf;

	If ReportSettings.ResultProperties.FormationTime <= 5 Then
		ClearMessages();
		AttachIdleHandler("Generate", 0.1, True);
	Else
		ReportsClientServer.NotifyOfSettingsChange(ThisObject);
	EndIf;

	ResetUniversalSearch();

EndProcedure

&AtClient
Function TheUniversalSearchValueIsAppliedToTheParameters(SearchOptions, ThisIsACustomSearch)

	SettingsComposer = Report.SettingsComposer;
	DataParameters = SettingsComposer.Settings.DataParameters;

	ParameterField = Undefined;
	SuitableSearchOption = Undefined;

	For Each SearchMode In SearchOptions Do

		ParameterField = DataParameters.ParameterAvailableFields.FindField(SearchMode.LeftValue);
		If ParameterField <> Undefined Then
			SuitableSearchOption = SearchMode;
			Break;
		EndIf;

	EndDo;

	If ParameterField = Undefined Then
		Return False;
	EndIf;

	DescriptionOfTheParameterFieldName = StrSplit(ParameterField.Field, ".");
	DescriptionOfTheParameterName = New Array;

	For IndexOf = 1 To DescriptionOfTheParameterFieldName.UBound() Do
		DescriptionOfTheParameterName.Add(DescriptionOfTheParameterFieldName[IndexOf]);
	EndDo;

	ParameterName = StrConcat(DescriptionOfTheParameterName, ".");
	FoundParameter = DataParameters.Items.Find(ParameterName);

	If FoundParameter = Undefined Then
		Return False;
	EndIf;

	ParameterDetails = DataParameters.AvailableParameters.FindParameter(FoundParameter.Parameter);

	If ParameterDetails.ValueListAllowed Then
		FoundParameter.Value = ReportsClientServer.ValuesByList(SuitableSearchOption.RightValue);
	Else
		FoundParameter.Value = SuitableSearchOption.RightValue;
	EndIf;

	FoundParameter.Use = True;

	ThisIsACustomSearch = ValueIsFilled(FoundParameter.UserSettingID);

	If Not ThisIsACustomSearch Then
		FoundParameter.UserSettingID = String(New UUID);
	EndIf;

	FoundParameter.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;

	CustomSetting = SettingsComposer.UserSettings.Items.Find(
		FoundParameter.UserSettingID);

	CustomSetting.Value = FoundParameter.Value;
	CustomSetting.Use = FoundParameter.Use;

	Return True;

EndFunction

&AtClient
Procedure ApplyTheUniversalSearchValueToSelections(SearchOptions, ThisIsACustomSearch)

	SettingsComposer = Report.SettingsComposer;
	DisplayFilters = SettingsComposer.Settings.Filter;
	Filter = Undefined;
	SuitableSearchOption = ?(SearchOptions.Count() = 0, Undefined, SearchOptions[0]);

	For Each SearchMode In SearchOptions Do

		Filter = ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, SearchMode.LeftValue);

		If Filter <> Undefined Then

			SuitableSearchOption = SearchMode;
			Break;

		EndIf;

	EndDo;

	If SuitableSearchOption = Undefined Then
		Return;
	EndIf;

	If Filter = Undefined Then

		Filter = DisplayFilters.Items.Add(Type("DataCompositionFilterItem"));
		Filter.LeftValue = SuitableSearchOption.LeftValue;

	EndIf;

	ThisIsACustomSearch = ValueIsFilled(Filter.UserSettingID);

	If Not ThisIsACustomSearch Then

		Filter.UserSettingID = String(New UUID);
		RefineFilterProperties(Filter, SuitableSearchOption);

	EndIf;

	Filter.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;

	CustomFilter = SettingsComposer.UserSettings.Items.Find(
		Filter.UserSettingID);

	RefineFilterProperties(CustomFilter, SuitableSearchOption);

EndProcedure

&AtClient
Procedure RefineFilterProperties(Filter, Search)

	If TypeOf(Filter) <> Type("DataCompositionFilterItem") Then
		Return;
	EndIf;

	Values = ReportsClientServer.ValuesByList(Filter.RightValue);

	If Values.FindByValue(Search.RightValue) = Undefined Then
		Values.Add(Search.RightValue);
	EndIf;

	If Filter.Use And Filter.ComparisonType = DataCompositionComparisonType.Equal 
		And Search.ComparisonType = DataCompositionComparisonType.Equal And Values.Count() > 1 Then

		Filter.ComparisonType = DataCompositionComparisonType.InList;
		Filter.RightValue = Values;

	ElsIf Filter.Use And Filter.ComparisonType = DataCompositionComparisonType.InList 
		And Search.ComparisonType = DataCompositionComparisonType.Equal Then

		Filter.RightValue = Values;

	ElsIf Filter.Use And Filter.ComparisonType = DataCompositionComparisonType.NotEqual 
		And Search.ComparisonType = DataCompositionComparisonType.NotEqual And Values.Count() > 1 Then

		Filter.ComparisonType = DataCompositionComparisonType.NotInList;
		Filter.RightValue = Values;

	ElsIf Filter.Use And Filter.ComparisonType = DataCompositionComparisonType.NotInList 
		And Search.ComparisonType = DataCompositionComparisonType.NotEqual Then

		Filter.RightValue = Values;

	Else
		Filter.Use = Search.Use;
		Filter.ComparisonType = Search.ComparisonType;
		Filter.RightValue = Search.RightValue;
	EndIf;

EndProcedure

#EndRegion

#Region GroupingLevels

&AtServer
Procedure InitializeTheMenuOfGroupingLevels()

	AddressOfTheReportStructureIndex = ReportSettings.ResultProperties.AddressOfTheReportStructureIndex;
	IndexOfTheReportStructure = Undefined;

	If IsTempStorageURL(AddressOfTheReportStructureIndex) Then
		IndexOfTheReportStructure = GetFromTempStorage(AddressOfTheReportStructureIndex);
	EndIf;

	ClearTheMenuOfGroupingLevels();
	FillInTheMenuOfGroupingLevels(IndexOfTheReportStructure);

	SetTheAvailabilityOfTheGroupingLevelMenu();

EndProcedure

&AtServer
Procedure ClearTheMenuOfGroupingLevels()

	Buttons = Items.GroupsLevelsGroup.ChildItems;
	IndexOf = Buttons.Count() - 1;

	While IndexOf >= 0 Do

		Button = Buttons[IndexOf];
		IndexOf = IndexOf - 1;

		If Button = Items.ShowGroupsLevel Then
			Continue;
		EndIf;

		NameOfTheAdditionalButton = Button.Name + "More";
		AdditionalButton = Items.Find(NameOfTheAdditionalButton);

		If AdditionalButton <> Undefined Then
			Items.Delete(AdditionalButton);
		EndIf;

		TheNameOfTheContextMenuButton = Button.Name + "ContextMenu";
		ContextMenuButton = Items.Find(TheNameOfTheContextMenuButton);

		If ContextMenuButton <> Undefined Then
			Items.Delete(ContextMenuButton);
		EndIf;

		Command = Commands.Find(Button.Name);

		If Command <> Undefined Then
			Commands.Delete(Command);
		EndIf;

		Items.Delete(Button);

	EndDo;

EndProcedure

&AtServer
Procedure FillInTheMenuOfGroupingLevels(IndexOfTheReportStructure)

	If ReportSpreadsheetDocument.RowGroupLevelCount() = 0 Then
		Return;
	EndIf;

	If IndexOfTheReportStructure = Undefined Or IndexOfTheReportStructure.Count() = 0 Then
		IndexOfTheReportStructure = ReportsOptionsInternal.NewReportStructureIndex();
		NumberOfPartitions = 999;
	Else
		NumberOfPartitions = IndexOfTheReportStructure[0].NumberOfPartitions;
	EndIf;

	If NumberOfPartitions = 1 Then
		MenuProperties = PropertiesOfTheMenuOfLevelsOfGroupingsOfASimpleReport(IndexOfTheReportStructure);
	Else
		MenuProperties = PropertiesOfTheMenuOfLevelsOfGroupingsOfAComplexReport(IndexOfTheReportStructure);
	EndIf;

	For Each Properties In MenuProperties Do

		Command = Commands.Add(Properties.CommandName);
		Command.Title = Properties.RepresentationOfTheGroupingLevel;
		Command.Action = "Attachable_ShowGroupsLevel";

		Button = Items.Add(Properties.CommandName, Type("FormButton"), Items.GroupsLevelsGroup);
		Button.Type = FormButtonType.CommandBarButton;
		Button.CommandName = Properties.CommandName;
		Button.Title = Properties.RepresentationOfTheGroupingLevel;
		Button.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
		
		// "More actions" submenu.
		Button = Items.Add(Properties.CommandName + "More", Type("FormButton"), Items.GroupsLevelsGroupMore);
		Button.Type = FormButtonType.CommandBarButton;
		Button.CommandName = Properties.CommandName;
		Button.Title = Properties.RepresentationOfTheGroupingLevel;
		Button.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		
		// Report context menu.
		ContextMenuButton = Items.Add(Properties.CommandName + "ContextMenu", Type("FormButton"),
			Items.GroupsLevelsGroupContextMenu);
		ContextMenuButton.Type = FormButtonType.CommandBarButton;
		ContextMenuButton.CommandName = Properties.CommandName;
		ContextMenuButton.Title = Properties.RepresentationOfTheGroupingLevel;

	EndDo;

EndProcedure

&AtServer
Function PropertiesOfTheMenuOfLevelsOfGroupingsOfAComplexReport(IndexOfTheReportStructure)

	MenuProperties = MenuPropertiesFromReportStructure(IndexOfTheReportStructure);

	NumberOfGroupingLevels = ReportSpreadsheetDocument.RowGroupLevelCount();
	For GroupingLevel = 1 To NumberOfGroupingLevels Do

		Properties = MenuProperties.Add();
		Properties.CommandName = Items.ShowGroupsLevel.Name + GroupingLevel;
		Properties.GroupingLevel = GroupingLevel;
		Properties.RepresentationOfTheGroupingLevel = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 level';"), GroupingLevel);

	EndDo;

	MenuProperties.Sort("GroupingLevel");
	Return MenuProperties;

EndFunction

&AtServer
Function PropertiesOfTheMenuOfLevelsOfGroupingsOfASimpleReport(IndexOfTheReportStructure)

	FieldsWithHierarchicalGrouping = ReportFieldsWithHierarchicalGrouping(IndexOfTheReportStructure);

	If FieldsWithHierarchicalGrouping.Count() > 1 Then
		Return PropertiesOfTheMenuOfLevelsOfGroupingsOfAComplexReport(IndexOfTheReportStructure);
	EndIf;

	NumberOfGroupingLevels = ReportSpreadsheetDocument.RowGroupLevelCount();

	ReportDimensions = ReportGroupingsBasedOnAFieldWithAHierarchicalGrouping(
		IndexOfTheReportStructure, FieldsWithHierarchicalGrouping, NumberOfGroupingLevels);

	MenuProperties = MenuPropertiesFromReportStructure(IndexOfTheReportStructure);
	For IndexOf = 0 To Min(ReportDimensions.Count(), NumberOfGroupingLevels) - 1 Do

		GroupingLevel = IndexOf + 1;

		Properties = MenuProperties.Add();
		Properties.RepresentationOfTheGroupingLevel = ReportDimensions[IndexOf].PerformanceGroup;
		Properties.CommandName = Items.ShowGroupsLevel.Name + GroupingLevel;
		Properties.GroupingLevel = GroupingLevel;

	EndDo;

	MenuProperties.Sort("GroupingLevel");
	Return MenuProperties;

EndFunction

// Parameters:
//  IndexOfTheReportStructure - See ReportsOptionsInternal.NewReportStructureIndex 
// 
// Returns:
//  ValueTable:
//    * CommandName - String
//    * GroupingLevel - Number
//    * RepresentationOfTheGroupingLevel - String
//
&AtServerNoContext
Function MenuPropertiesFromReportStructure(IndexOfTheReportStructure)

	MenuProperties = IndexOfTheReportStructure.CopyColumns("GroupingOrder, PerformanceGroup"); // ValueTable

	MenuProperties.Columns.Insert(1, "CommandName", New TypeDescription("String"));

	Column = MenuProperties.Columns.Find("GroupingOrder"); // ValueTableColumn
	Column.Name = "GroupingLevel";

	Column = MenuProperties.Columns.Find("PerformanceGroup"); // ValueTableColumn
	Column.Name = "RepresentationOfTheGroupingLevel";

	Return MenuProperties;

EndFunction

&AtServer
Function ReportFieldsWithHierarchicalGrouping(IndexOfTheReportStructure)

	Search = New Structure;
	Search.Insert("UsedInGroupingFields", True);
	Search.Insert("GroupType", DataCompositionGroupType.Hierarchy);

	ReportFields = IndexOfTheReportStructure.Copy(Search);
	
	IndexOf = ReportFields.Count() - 1;

	While IndexOf >= 0 Do

		If StrFind(ReportFields[IndexOf].GroupingID, "/column/") > 0 Then
			ReportFields.Delete(IndexOf);
		EndIf;

		IndexOf = IndexOf - 1;

	EndDo;
	
	Return ReportFields;

EndFunction

&AtServer
Function ReportGroupingsBasedOnAFieldWithAHierarchicalGrouping(IndexOfTheReportStructure, FieldsWithHierarchicalGrouping,
	NumberOfGroupingLevels)

	ReportDimensions = IndexOfTheReportStructure.Copy(); // ValueTable

	IndexOf = ReportDimensions.Count() - 1;

	While IndexOf >= 0 Do

		If StrFind(ReportDimensions[IndexOf].GroupingID, "/column/") > 0 Then
			ReportDimensions.Delete(IndexOf);
		EndIf;

		IndexOf = IndexOf - 1;

	EndDo;

	ReportDimensions.GroupBy("GroupingOrder, PerformanceGroup");

	ReportGroupingColumns = ReportDimensions.Columns; // ValueTableColumnCollection
	ReportGroupingColumns.Add("Level", New TypeDescription("Number"));

	ReportDimensions.Sort("GroupingOrder");

	TheNumberOfLevelsOfTheFieldWithHierarchicalGrouping = NumberOfGroupingLevels - ReportDimensions.Count();

	If FieldsWithHierarchicalGrouping.Count() <> 1 Or TheNumberOfLevelsOfTheFieldWithHierarchicalGrouping = 0 Then
		Return ReportDimensions;
	EndIf;

	Search = New Structure("GroupingOrder, PerformanceGroup");
	FillPropertyValues(Search, FieldsWithHierarchicalGrouping[0]);

	FoundGrouping = ReportDimensions.FindRows(Search)[0];
	IndexOfTheFoundGrouping = ReportDimensions.IndexOf(FoundGrouping);

	GroupingViewTemplate = NStr("en = '%1 - level %2';");
	FieldLevelWithHierarchicalGrouping = 0;

	While TheNumberOfLevelsOfTheFieldWithHierarchicalGrouping > 0 Do

		FieldLevelWithHierarchicalGrouping = FieldLevelWithHierarchicalGrouping + 1;

		AdditionalGrouping = ReportDimensions.Insert(IndexOfTheFoundGrouping);
		FillPropertyValues(AdditionalGrouping, FoundGrouping);

		AdditionalGrouping.Level = FieldLevelWithHierarchicalGrouping;

		AdditionalGrouping.PerformanceGroup = StringFunctionsClientServer.SubstituteParametersToString(
			GroupingViewTemplate, AdditionalGrouping.PerformanceGroup,
			FieldLevelWithHierarchicalGrouping);

		TheNumberOfLevelsOfTheFieldWithHierarchicalGrouping = TheNumberOfLevelsOfTheFieldWithHierarchicalGrouping - 1;

	EndDo;

	FieldLevelWithHierarchicalGrouping = FieldLevelWithHierarchicalGrouping + 1;

	FoundGrouping.Level = FieldLevelWithHierarchicalGrouping;

	FoundGrouping.PerformanceGroup = StringFunctionsClientServer.SubstituteParametersToString(
		GroupingViewTemplate, FoundGrouping.PerformanceGroup,
		FieldLevelWithHierarchicalGrouping);

	ReportDimensions.Sort("GroupingOrder, Level");

	Return ReportDimensions;

EndFunction

&AtServer
Procedure SetTheAvailabilityOfTheGroupingLevelMenu()

	TheMenuIsFull = (Items.GroupsLevelsGroup.ChildItems.Count() > 1);

	Items.ShowGroupsLevel.Visible = Not TheMenuIsFull;
	Items.ShowGroupsLevelMore.Visible = Not TheMenuIsFull;
	Items.ShowGroupsLevelContextMenu.Visible = Not TheMenuIsFull;

	Items.GroupsLevelsGroup.Visible = TheMenuIsFull;
	Items.GroupsLevelsGroupMore.Visible = TheMenuIsFull;
	Items.GroupsLevelsGroupContextMenu.Visible = TheMenuIsFull;

EndProcedure

&AtClient
Procedure ShowTheSelectedGroupingLevel(GroupingLevel = Undefined)

	If GroupingLevel = Undefined Then
		GroupingLevel = ?(DetailsMode, UndefinedLevelOfGroupings(), SelectedGroupsLevel);
	EndIf;

	IndexOf = GroupingLevel - 1;
	Boundary = ReportSpreadsheetDocument.RowGroupLevelCount() - 1;

	While Boundary > IndexOf Do

		ReportSpreadsheetDocument.ShowRowGroupLevel(Boundary);
		Boundary = Boundary - 1;

	EndDo;

	ReportSpreadsheetDocument.ShowRowGroupLevel(IndexOf);

	SelectedGroupsLevel = GroupingLevel;

	ReferenceMenu = Items.GroupsLevelsGroup;
	ReferenceButton = Items.ShowGroupsLevel;

	MenuOutputAreas = New Map;
	MenuOutputAreas.Insert(ReferenceMenu, ReferenceButton);
	MenuOutputAreas.Insert(Items.GroupsLevelsGroupMore, Items.ShowGroupsLevelMore);
	MenuOutputAreas.Insert(Items.GroupsLevelsGroupContextMenu,
		Items.ShowGroupsLevelContextMenu);

	For Each Area In MenuOutputAreas Do

		Buttons = Area.Key.ChildItems;
		For Each Button In Buttons Do
			Button.Check = False;
		EndDo;

		ButtonName = ReferenceButton.Name + GroupingLevel + StrReplace(Area.Value.Name, ReferenceButton.Name, "");
		Button = Buttons.Find(ButtonName);
		If Button <> Undefined Then
			Button.Check = True;
		EndIf;

	EndDo;

	AttachIdleHandler("SaveTheSelectedGroupingLevelPostponed", 0.1, True);

EndProcedure

&AtClient
Procedure SaveTheSelectedGroupingLevelPostponed()

	If Not ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey) Then
		SettingsKey = ReportOptionSettingsKey(ReportSettings.FullName, CurrentVariantKey);
		SaveTheSelectedGroupingLevel(SettingsKey, SelectedGroupsLevel, DetailsMode);
	EndIf;

EndProcedure

&AtServerNoContext
Procedure SaveTheSelectedGroupingLevel(ValueStorageKey, SelectedGroupsLevel, DetailsMode)

	If DetailsMode Then
		Return;
	EndIf;

	Common.FormDataSettingsStorageSave(
		ValueStorageKey, "SelectedGroupsLevel", SelectedGroupsLevel);

EndProcedure

&AtServerNoContext
Procedure RestoreTheSelectedGroupingLevel(ValueStorageKey, SelectedGroupsLevel, DetailsMode)

	If DetailsMode Then
		Return;
	EndIf;

	SavedValue = Common.FormDataSettingsStorageLoad(
		ValueStorageKey, "SelectedGroupsLevel");

	If ValueIsFilled(SavedValue) Then
		SelectedGroupsLevel = SavedValue;
	Else
		SelectedGroupsLevel = UndefinedLevelOfGroupings();
	EndIf;

EndProcedure

&AtClient
Procedure ResetTheSelectedGroupingLevel()

	If DetailsMode Then
		Return;
	EndIf;

	SelectedGroupsLevel = UndefinedLevelOfGroupings();

	For Each Item In Items.GroupsLevelsGroup.ChildItems Do

		If TypeOf(Item) = Type("FormButton") Then
			Item.Check = False;
		EndIf;

	EndDo;

	AttachIdleHandler("SaveTheSelectedGroupingLevelPostponed", 0.1, True);

EndProcedure

&AtClientAtServerNoContext
Function UndefinedLevelOfGroupings()
	Return 999;
EndFunction

#EndRegion

#Region OutputOfSettingsHeaders

&AtServerNoContext
Procedure SaveTheStateOfTheOptionOutputSettingsHeaders(ValueStorageKey, OutputSettingsTitles,
	DetailsMode)

	If DetailsMode Then
		Return;
	EndIf;

	Common.FormDataSettingsStorageSave(
		ValueStorageKey, "OutputSettingsTitles", OutputSettingsTitles);

EndProcedure

&AtServerNoContext
Procedure RestoreTheStateOfTheOutputSettingsHeadersOption(ValueStorageKey, OutputSettingsTitles,
	DetailsMode)

	If DetailsMode Then
		Return;
	EndIf;

	SavedValue = Common.FormDataSettingsStorageLoad(
		ValueStorageKey, "OutputSettingsTitles");

	OutputSettingsTitles = SavedValue = Undefined Or SavedValue = True;

EndProcedure

#EndRegion

#Region SavingTheReportResult

&AtClient
Procedure SaveReportAfterFilenameSelected(Result, Context) Export

	If TypeOf(Result) = Type("Array") And Result.Count() > 0 Then
		FullNameOfTheReportFile = Result[0];
	ElsIf TypeOf(Result) = Type("String") Then
		FullNameOfTheReportFile = Result;
	Else
		Return;
	EndIf;

	If Not ValueIsFilled(FullNameOfTheReportFile) Then
		Context.Insert("FullNameOfTheReportFile", CommonClientServer.ReplaceProhibitedCharsInFileName(
			Title));
		OnCloseNotifyDescription = New NotifyDescription("AfterSaveFormatSelected", ThisObject, Context);
		FormatsList = ListOfAvailableReportSaveFormats(Context.IndexOfReportSavingFormats);
		DefaultFormat = FormatsList.FindByValue("mxl");
		FormatsList.ShowChooseItem(OnCloseNotifyDescription, NStr("en = 'Select a save format';"),
			DefaultFormat);
	Else
		Context.Insert("FullNameOfTheReportFile", FullNameOfTheReportFile);
		SelectedElement = New Structure("Value");
		AfterSaveFormatSelected(SelectedElement, Context);
	EndIf;

EndProcedure

&AtClient
Procedure AfterSaveFormatSelected(SelectedElement, Context) Export

	If SelectedElement = Undefined Then
		Return;
	EndIf;

	FullNameOfTheReportFile = Context.FullNameOfTheReportFile;
	If SelectedElement.Value <> Undefined Then
		FullNameOfTheReportFile = FullNameOfTheReportFile + "." + SelectedElement.Value;
	EndIf;

	Handler = New NotifyDescription("SaveReportAfterSavedReportResults", ThisObject,
		FullNameOfTheReportFile);

	SaveFormats = ReportSavingFormats(FullNameOfTheReportFile, Context.IndexOfReportSavingFormats);
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	ReportResult = ReportResultToSave(ReportSpreadsheetDocument, ResultProperties.Headers);
	ReportResult.BeginWriting(Handler, FullNameOfTheReportFile, SaveFormats);
EndProcedure

&AtClient
Procedure SaveReportAfterSavedReportResults(Result, FullNameOfTheReportFile) Export

	If Result <> True Then
		Return;
	EndIf;

	Handler = New NotifyDescription("SaveReportOnChooseReportFilename", ThisObject, FullNameOfTheReportFile);
	ShowUserNotification(NStr("en = 'The report is saved to the file';"), Handler, FullNameOfTheReportFile);

EndProcedure

&AtClient
Procedure SaveReportOnChooseReportFilename(FullNameOfTheReportFile) Export

	FileSystemClient.OpenFile(FullNameOfTheReportFile);

EndProcedure

&AtClient
Function ReportSavingFormats(Val FullNameOfTheReportFile, IndexOfReportSavingFormats)

	DescriptionOfTheFullFileName = StrSplit(FullNameOfTheReportFile, GetPathSeparator());
	NameOfTheReportFile = DescriptionOfTheFullFileName[DescriptionOfTheFullFileName.UBound()];

	FileNameDetails = StrSplit(NameOfTheReportFile, ".");
	ReportFileExtension = FileNameDetails[FileNameDetails.UBound()];

	Return IndexOfReportSavingFormats[ReportFileExtension];

EndFunction

&AtServerNoContext
Function AvailableFormatsForSavingTheReport(IndexOfReportSavingFormats)

	AvailableFormats = New Array;

	SaveFormats = StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings();

	SavingFormatTXT = SaveFormats.Find(SpreadsheetDocumentFileType.TXT, "SpreadsheetDocumentFileType");
	ANSITXTSaveFormat = SaveFormats.Find(SpreadsheetDocumentFileType.ANSITXT,
		"SpreadsheetDocumentFileType");

	If SavingFormatTXT <> Undefined And ANSITXTSaveFormat <> Undefined Then
		SaveFormats.Delete(ANSITXTSaveFormat);
	EndIf;

	CurrentSaveFormat = New Array;

	For Each SaveFormat In SaveFormats Do

		ExtensionOfTheSaveFormat = "*." + SaveFormat.Extension;
		PresentationOfTheSaveFormat = StrReplace(SaveFormat.Presentation, "." + SaveFormat.Extension,
			ExtensionOfTheSaveFormat);

		CurrentSaveFormat.Add(PresentationOfTheSaveFormat);
		CurrentSaveFormat.Add(ExtensionOfTheSaveFormat);

		AvailableFormats.Add(StrConcat(CurrentSaveFormat, "|"));

		CurrentSaveFormat.Clear();

		IndexOfReportSavingFormats.Insert(SaveFormat.Extension,
			SaveFormat.SpreadsheetDocumentFileType);

	EndDo;

	Return StrConcat(AvailableFormats, "|");

EndFunction

&AtServerNoContext
Function ReportResultToSave(ReportSpreadsheetDocument, Headers)

	ReportResult = CopySpreadsheetDocument(ReportSpreadsheetDocument);

	For Each HeaderIndex In Headers Do

		TitleProperties = HeaderIndex.Value;

		If Not TitleProperties.TheFieldIsSorted Then
			Continue;
		EndIf;

		Area = ReportResult.Area(HeaderIndex.Key);
		Area.Picture = Undefined;

	EndDo;

	Return ReportResult;

EndFunction

&AtServerNoContext
Function CopySpreadsheetDocument(SpreadsheetDocument)

	MemoryStream = New MemoryStream;
	SpreadsheetDocument.Write(MemoryStream);
	MemoryStream.Seek(0, PositionInStream.Begin);

	Result = New SpreadsheetDocument;
	Result.Read(MemoryStream, SpreadsheetDocumentValuesReadingMode.Value);

	Return Result;

EndFunction

&AtServer
Procedure SaveUserReportSnapshot()

	ReportResult = CopySpreadsheetDocument(ReportSpreadsheetDocument);

	InformationRegisters.ReportsSnapshots.SaveUserReportSnapshot(ReportResult, ReportSettings);

EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Procedure SetVisibilityAvailability()

	ShowOptionsSelectionCommands = ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey)
		And ReportSettings.OptionSelectionAllowed;

	ShowOptionChangingCommands = ShowOptionsSelectionCommands And ReportSettings.EditOptionsAllowed;
	CountOfAvailableSettings = ReportsServer.CountOfAvailableSettings(Report.SettingsComposer);

	Items.AllSettings.Visible = ShowOptionChangingCommands Or CountOfAvailableSettings.Typical > 0;
	Items.MoreCommandBarAllSettings.Visible = Items.AllSettings.Visible;
	Items.ReportOptionsGroup.Visible = ShowOptionsSelectionCommands;
	Items.GroupSaveReportOptionSelection.Visible = Not Common.DataSeparationEnabled()
		Or Common.SeparatedDataUsageAvailable();

	Items.ChangeQuickSettingsComposition.Visible = ShowOptionChangingCommands And Not IsMobileClient;

	If IsMobileClient Then
		Items.Move(Items.IndicatorGroup, Items.GroupForIndicators);
	EndIf;

	IsPredefinedOption = Not ReportSettings.Custom And ValueIsFilled(
		ReportSettings.PredefinedRef);

	SaveOptionAllowed = ShowOptionChangingCommands
		And Not ReportSettings.SelectAndEditOptionsWithoutSavingAllowed;

	ItIsAvailableToSaveTheCurrentVersion = ValueIsFilled(ReportSettings.OptionRef) And Not IsPredefinedOption;
	If ItIsAvailableToSaveTheCurrentVersion And Common.SubsystemExists(
		"StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		If Not ModuleAccessManagement.EditionAllowed(ReportSettings.OptionRef) Then
			ItIsAvailableToSaveTheCurrentVersion = False;
		EndIf;
	EndIf;

	CommonClientServer.SetFormItemProperty(
		Items, "SaveVariant", "Visible", SaveOptionAllowed And ItIsAvailableToSaveTheCurrentVersion);
	CommonClientServer.SetFormItemProperty(
		Items, "SaveOptionMore", "Visible", SaveOptionAllowed And ItIsAvailableToSaveTheCurrentVersion);
	CommonClientServer.SetFormItemProperty(
		Items, "SaveOptionAs", "Visible", SaveOptionAllowed);
	CommonClientServer.SetFormItemProperty(
		Items, "SaveOptionAsMore", "Visible", SaveOptionAllowed);

	Items.OtherReports.Visible = ReportSettings.OptionSelectionAllowed And Not ValueIsFilled(OptionContext);
	Items.MoreCommandBarOtherReports.Visible = Items.OtherReports.Visible;

	Items.SelectOption.Visible = ShowOptionsSelectionCommands;

	Items.GroupReportsSnapshots.Visible = ReportSettings.UseReportSnapshots;

	UseSettingsAllowed = ShowOptionsSelectionCommands And CountOfAvailableSettings.Total > 0
		And CommonClientServer.FormItemPropertyValue(Items, "SelectSettings", "Visible") = True;

	CommonClientServer.SetFormItemProperty(
		Items, "SelectSettings", "Visible", UseSettingsAllowed);
	CommonClientServer.SetFormItemProperty(
		Items, "ShouldSaveSettings", "Visible", UseSettingsAllowed);
	CommonClientServer.SetFormItemProperty(
		Items, "ShareSettings", "Visible", UseSettingsAllowed And (IsPredefinedOption
		Or ReportsOptions.FullRightsToOptions() Or ValueIsFilled(ReportSettings.OptionRef)
		And Common.ObjectAttributeValue(ReportSettings.OptionRef, "AuthorOnly") <> True));

	If ReportSettings.SelectAndEditOptionsWithoutSavingAllowed Then
		VariantModified = False;
	EndIf;

	Items.QuickSettingsPanelCommands.Visible = (CountOfAvailableSettings.QuickAccessSettingsCount > 0);
	Items.ChangeQuickSettingsCompositionMore.Visible = Items.QuickSettingsPanelCommands.Visible;
	
	// Options selection commands.
	If PanelOptionsCurrentOptionKey <> CurrentVariantKey Then
		PanelOptionsCurrentOptionKey = CurrentVariantKey;

		If ShowOptionsSelectionCommands Then
			UpdateOptionsSelectionCommands();
		EndIf;

		If OutputRight Then
			WindowOptionsKey = ReportsClientServer.UniqueKey(ReportSettings.FullName,
				CurrentVariantKey);
			ReportSettings.Print.Insert("PrintParametersKey", WindowOptionsKey);
			FillPropertyValues(ReportSpreadsheetDocument, ReportSettings.Print);
		EndIf;

		URL = "";
		If ValueIsFilled(ReportSettings.OptionRef) And Not ReportSettings.External
			And Not ReportSettings.Contextual Then
			URL = GetURL(ReportSettings.OptionRef);
		EndIf;
	EndIf;
	
	Items.RestoreDefaultSchema.Visible = ReportSettings.RestoreStandardSchemaAllowed;
	Items.EditSchema.Visible = ReportSettings.EditSchemaAllowed
		And Not Common.DataSeparationEnabled(); 
	Items.ImportSchema.Visible = ReportSettings.ImportSchemaAllowed
		And Not Common.DataSeparationEnabled();

	SetTheAvailabilityOfTheGroupingLevelMenu();
	
	ReportCurrentOptionDescription = TrimAll(ReportCurrentOptionDescription);
	If ValueIsFilled(ReportCurrentOptionDescription) Then
		Title = ReportCurrentOptionDescription;
	Else
		DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);
		Title = DescriptionOfReportSettings.Description;
	EndIf;

	If DetailsMode Then
		Title = Title + " (" + NStr("en = 'Details';") + ")";
	EndIf;
EndProcedure

&AtServer
Procedure CheckTheAvailabilityOfSharingOptionSettings(MetadataOfReport)

	SharingOptionSettingsIsAvailable = ReportsOptionsInternalClientServer.ReportOptionMode(CurrentVariantKey)
		And ReportsOptions.ReportAttachedToStorage(MetadataOfReport);

	Items.SettingsExchangeGroupMore.Visible = SharingOptionSettingsIsAvailable;
	Items.UpdateReportOptionFromFile.Visible = SharingOptionSettingsIsAvailable;
	Items.SaveReportOptionToFile.Visible = SharingOptionSettingsIsAvailable;

EndProcedure

&AtServer
Procedure LoadVariant(VariantKey, ClearStackSettings = True)
	If Not DetailsMode And Not VariantModified Then
		ObjectKey = StringFunctionsClientServer.SubstituteParametersToString("%1/%2/CurrentUserSettings", 
			ReportSettings.FullName, CurrentVariantKey);
		Common.SystemSettingsStorageSave(	ObjectKey, "", 
			Report.SettingsComposer.UserSettings);
	EndIf;

	SaveDataInSettingsOnServer();

	DetailsMode = False;
	VariantModified = False;
	UserSettingsModified = False;
	ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = True;

	PutToTempStorage(Undefined, ReportSettings.ResultProperties.AddressOfTheReportStructureIndex);

	If ClearStackSettings Then
		StackSettings.Clear();
	EndIf;

	SetCurrentVariant(VariantKey);
	ReportsClientServer.DisplayReportState(	ThisObject, 
		NStr("en = 'Another report option is selected. To run the report, click ""Generate"".';"),
		PictureLib.DialogInformation);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure DefineBehaviorInMobileClient()
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then
		Return;
	EndIf;

	Items.CommandsAndIndicators.Title = NStr("en = 'indicators';");
	Items.Move(Items.CommandsAndIndicators, ThisObject, Items.PredefinedSettingsItems);
	Items.MainGroup1.Visible = False;
	Items.ReportSettingsGroup.Visible = False;
	Items.WorkInTableGroup.Visible = False;
	Items.GroupOutput.Visible = False;
	Items.Edit.Visible = False;

	Items.IndicatorGroup.HorizontalStretch = Undefined;
	Items.Factor.Width = 0;

	Items.QuickSettingsPanel.Visible = False;
	Items.MobileClientButtonGroup.Visible = True;

	Items.CommandsAndIndicators.Visible = False;
	Items.GenerateReport.DefaultButton = False;

EndProcedure

&AtServer
Function ReportOptionContext()
	If DetailsMode Then
		Return "";
	EndIf;

	If Not IsBlankString(Parameters.OptionContext) Then
		Return Parameters.OptionContext;
	EndIf;

	InterfaceProperties = StrSplit("CommandParameter, Filter", ", ", False);
	For Each InterfaceProperty In InterfaceProperties Do

		PropertyValue = CommonClientServer.StructureProperty(Parameters, InterfaceProperty);
		If PropertyValue = Undefined Then
			Continue;
		EndIf;

		If Common.RefTypeValue(PropertyValue) Then
			Return PropertyValue.Metadata().FullName();

		ElsIf TypeOf(PropertyValue) = Type("Array") And PropertyValue.Count() > 0
			And Common.RefTypeValue(PropertyValue[0]) Then

			Return PropertyValue[0].Metadata().FullName();

		ElsIf TypeOf(PropertyValue) = Type("Structure") Then

			For Each StructureItem In PropertyValue Do
				ElementValue = StructureItem.Value;
				If Common.RefTypeValue(ElementValue) Then
					Return ElementValue.Metadata().FullName();
				ElsIf TypeOf(ElementValue) = Type("Array") And ElementValue.Count() > 0
					And Common.RefTypeValue(ElementValue[0]) Then
					Return ElementValue[0].Metadata().FullName();
				EndIf;
			EndDo;

		EndIf;
	EndDo;

	CommandDetails = CommonClientServer.StructureProperty(Parameters, "CommandDetails");
	If TypeOf(CommandDetails) = Type("Structure") Then

		ContextTypeDetails = CommonClientServer.StructureProperty(CommandDetails, "ParameterType");
		ContextTypes = ?(TypeOf(ContextTypeDetails) = Type("TypeDescription"), ContextTypeDetails.Types(),
			New Array);

		If ContextTypes.Count() > 0 Then
			Return Metadata.FindByType(ContextTypes[0]).FullName();
		EndIf;
	EndIf;

	Return Undefined;
EndFunction

&AtServer
Procedure SetPurposeUseKey()
	If ValueIsFilled(PurposeUseKey) Then
		Return;
	EndIf;

	If ValueIsFilled(Parameters.PurposeUseKey) Then
		PurposeUseKey = Parameters.PurposeUseKey;
	ElsIf ValueIsFilled(OptionContext) Then
		PurposeUseKey = OptionContext + ?(ValueIsFilled(Parameters.VariantKey), ".", "")
			+ Parameters.VariantKey;
	EndIf;
EndProcedure

&AtServer
Procedure SaveFormParameters()

	ParametersForm = ReportsOptions.StoredReportFormParameters(Parameters);
	ParametersForm.PurposeUseKey = PurposeUseKey;

EndProcedure

&AtServer
Procedure SetCurrentOptionKey(ReportFullName, ReportObject)
	PanelOptionsCurrentOptionKey = BlankOptionKey();

	Details = CommonClientServer.StructureProperty(Parameters, "Details");
	CurrentVariantKeyDetail = "";
	If TypeOf(Details) = Type("DataCompositionDetailsProcessDescription") Then
		Settings = GetFromTempStorage(Details.Data).Settings;
		CurrentVariantKeyDetail = CommonClientServer.StructureProperty(
			Settings.AdditionalProperties, "VariantKey", "");
	EndIf;

	If ValueIsFilled(CurrentVariantKeyDetail) Then
		CurrentVariantKey = CurrentVariantKeyDetail;
		If Not ValueIsFilled(PurposeUseKey) Then
			PurposeUseKey = "Details";
		EndIf;
	Else
		If ValueIsFilled(PurposeUseKey) Then
			ObjectKey = ReportFullName + "/" + PurposeUseKey + "/CurrentVariantKey";
		Else
			ObjectKey = ReportFullName + "/CurrentVariantKey";
		EndIf;

		CurrentVariantKey = Common.SystemSettingsStorageLoad(ObjectKey, "");
	EndIf;

	If Not ValueIsFilled(CurrentVariantKey) Or (ValueIsFilled(Parameters.VariantKey)
		And CurrentVariantKey <> Parameters.VariantKey) Then

		If ValueIsFilled(Parameters.VariantKey) Then
			CurrentVariantKey = Parameters.VariantKey;

		ElsIf ReportObject.DataCompositionSchema <> Undefined Then
			For Each Variant In ReportObject.DataCompositionSchema.SettingVariants Do
				CurrentVariantKey = Variant.Name;
				Break;
			EndDo;
		EndIf;

	EndIf;
	
	// Save the key of the contextual report option, which is usually hidden from the UI.
	//  (That is, "Enabled" is set to '"False".)
	If ValueIsFilled(OptionContext) Then
		ContextOption = ?(ValueIsFilled(Parameters.VariantKey), Parameters.VariantKey, CurrentVariantKey);
		ContextOptions.Add(ContextOption);
	EndIf;

	If ValueIsFilled(OptionContext) And ValueIsFilled(Parameters.VariantKey) 
		And Parameters.VariantKey <> CurrentVariantKey Then 
		Parameters.VariantKey = Undefined;
	EndIf;
EndProcedure

// Parameters:
//  ReportObject - ReportObject
//
// Returns:
//   See ReportsOptions.ReportFormSettings
//
&AtServer
Function ReportSettings(ReportObject)

	Settings = ReportsOptions.ReportFormSettings(Parameters.Report, CurrentVariantKey, ReportObject);
	Settings.SchemaURL = ReportSchemaURL(ReportObject);
	Settings.Contextual = ValueIsFilled(OptionContext) And Not Parameters.IsNonContextual;
	Settings.Subsystem  = ParametersForm.Subsystem;
	Settings.TablesToUse = CommonClientServer.StructureProperty(Parameters, "TablesToUse");
	Settings.EventsSettings = EventsSettings();
	Settings.UseReportSnapshots = AccessRight("MobileClient", Metadata);

	Return Settings;
EndFunction

// Parameters:
//  LongDesc - See ReportSettings
//
// Returns:
//   See ReportSettings
//
&AtClientAtServerNoContext
Function DescriptionOfReportSettings(LongDesc)

	Return LongDesc;

EndFunction

&AtServer
Function ReportSchemaURL(ReportObject)
	SchemaURL = CommonClientServer.StructureProperty(Parameters, "SchemaURL", "");

	Details = CommonClientServer.StructureProperty(Parameters, "Details");

	If TypeOf(Details) = Type("DataCompositionDetailsProcessDescription") Then
		Settings = GetFromTempStorage(Details.Data).Settings;
		SchemaURL = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "SchemaURL", "");
	EndIf;

	IsSchema = False;
	If IsTempStorageURL(SchemaURL) Then
		Schema = GetFromTempStorage(SchemaURL);
		IsSchema = (TypeOf(Schema) = Type("DataCompositionSchema"));

		If IsSchema Then
			SchemaURL = PutToTempStorage(Schema, UUID);
			Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		EndIf;
	EndIf;

	If Not IsSchema Then
		SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, UUID);
	EndIf;

	Return SchemaURL;
EndFunction

#Region EventsSettings

&AtServer
Function EventsSettings()

	EventsSettings = New Map;

	FindEventSettings(Items.ReportSpreadsheetDocument.ContextMenu, RefinementsEventSettings(), 
		EventSettingsExceptions(), EventsSettings);

	EventsSettings.Insert("FilterAndGenerate", NStr("en = 'Filter…';"));
	EventsSettings.Insert(ReportsOptionsInternalClientServer.NameEventFormSettings(), 
		NStr("en = 'Advanced setting';"));
	EventsSettings.Insert(ReportsOptionsInternalClientServer.EventNameQuickSettingsChangesContent(), 
		NStr("en = 'Quick settings change';"));

	Return EventsSettings;

EndFunction

&AtServer
Function RefinementsEventSettings()

	Prefixes = New Map;
	Prefixes.Insert("HighlightInYellow", NStr("en = 'Highlight in yellow';"));
	Prefixes.Insert("HighlightInRed", NStr("en = 'Highlight in red';"));
	Prefixes.Insert("HighlightInGreen", NStr("en = 'Highlight in green';"));
	Prefixes.Insert("ApplyAppearanceMore", NStr("en = 'Format (more)';"));

	Return Prefixes;

EndFunction

&AtServer
Function EventSettingsExceptions()

	Exceptions = New Array;
	Exceptions.Add("Open");
	Exceptions.Add("DecodeByDetailedRecords");
	Exceptions.Add("Decrypt");
	Exceptions.Add("Attachable_ShowGroupsLevel");
	Exceptions.Add("ReportComposeResult");

	Return Exceptions;

EndFunction

&AtServer
Procedure FindEventSettings(Menu, Clarifications, Exceptions, EventsSettings)

	For Each Item In Menu.ChildItems Do

		If TypeOf(Item) = Type("FormGroup") Then

			FindEventSettings(Item, Clarifications, Exceptions, EventsSettings);

		ElsIf EventsSettings[Item.CommandName] = Undefined 
			And Exceptions.Find(Item.CommandName) = Undefined Then

			FoundCommand = Commands.Find(Item.CommandName);
			If FoundCommand = Undefined Then
				Continue;
			EndIf;

			CommandAction = ?(ValueIsFilled(FoundCommand.Action), FoundCommand.Action,
				FoundCommand.Name);
			PresentationAction = Clarifications[CommandAction];

			If PresentationAction = Undefined Then
				PresentationAction = FoundCommand.Title;
			EndIf;

			EventsSettings.Insert(CommandAction, PresentationAction);

		EndIf;

	EndDo;

EndProcedure

#EndRegion

&AtServer
Procedure SetUserPermissions()

	ReportOptionsCommandsVisibility = CommonClientServer.StructureProperty(
		Parameters, "ReportOptionsCommandsVisibility", True);

	If ReportSettings.SelectAndEditOptionsWithoutSavingAllowed Then

		ReportSettings.EditOptionsAllowed = True;
		ReportSettings.OptionSelectionAllowed = True;

	ElsIf Not ReportOptionsCommandsVisibility Then

		ReportSettings.EditOptionsAllowed = False;
		ReportSettings.OptionSelectionAllowed = False;

	EndIf;

	If ReportSettings.EditOptionsAllowed And Not ReportsOptionsCached.InsertRight1() Then
		ReportSettings.EditOptionsAllowed = False;
	EndIf;

EndProcedure

&AtServer
Function DataOfTheDecryptionElement(Details)

	Return ReportsOptionsInternal.DataOfTheDecryptionElement(ThisObject, Details);

EndFunction

&AtServer
Procedure UpdateSettingsFormItemsAtServer(ParametersOfUpdate)
	ImportSettingsToComposer(ParametersOfUpdate);

	ReportsServer.UpdateSettingsFormItems(ThisObject, Items.SettingsComposerUserSettings, 
		ParametersOfUpdate);

	If ParametersOfUpdate.EventName <> "AfterGenerate" Then
		If ParametersOfUpdate.Regenerate And Not CheckFilling() Then
			ParametersOfUpdate.Regenerate = False;
		ElsIf ParametersOfUpdate.Regenerate Then
			ReportsClientServer.DisplayReportState(
				ThisObject, NStr("en = 'Generating report…';"), PictureLib.TimeConsumingOperation48);
		ElsIf Not ReportCreated And (ParametersOfUpdate.VariantModified
			Or ParametersOfUpdate.UserSettingsModified) Then

			ReportsClientServer.NotifyOfSettingsChange(ThisObject);
		EndIf;
	EndIf;
	
	// If a user is not allowed to change options of the report, the standard dialog box is not shown.
	If Not ReportSettings.EditOptionsAllowed Then
		VariantModified = False;
	EndIf;

	RefreshJumpMenuBetweenSettingChanges();
	SetVisibilityAvailability();
EndProcedure

&AtServer
Procedure ImportSettingsToComposer(ImportParameters)
	If ImportParameters.EventName <> ReportsClientServer.NameOfTheDefaultSettingEvent() 
		And Not ImportParameters.VariantModified Then
		ImportParameters.VariantModified = VariantModified;
	EndIf;
	If Not ImportParameters.UserSettingsModified Then
		ImportParameters.UserSettingsModified = UserSettingsModified;
	EndIf;
	ImportParameters.ReportObjectOrFullName = ReportSettings.FullName;

	ReportObject = FormAttributeToValue("Report");
	If ReportSettings.Events.BeforeFillQuickSettingsBar Then
		ReportObject.BeforeFillQuickSettingsBar(ThisObject, ImportParameters);
	EndIf;

	AvailableSettings = ReportsServer.AvailableSettings(ImportParameters, ReportSettings);
	If ImportParameters.ClearOptionSettings Then
		DownloadParametersBeforeSetCurrentOption = ImportParameters;
		LoadVariant(CurrentVariantKey, False);
		DownloadParametersBeforeSetCurrentOption = Undefined;
	EndIf;
	
	If DownloadParametersBeforeSetCurrentOption <> Undefined Then
		ImportParameters.ResetCustomSettings = 
			DownloadParametersBeforeSetCurrentOption.ResetCustomSettings;
	EndIf;

	ReportsServer.ResetCustomSettings(AvailableSettings, ImportParameters);

	ReportsServer.FillinAdditionalProperties(ReportObject, AvailableSettings.Settings, CurrentVariantKey,
		ReportSettings.PredefinedOptionKey, 
		?(ReportsOptions.ItIsAcceptableToSetContext(ThisObject), OptionContext, ""), 
		?(ReportsOptions.ItIsAcceptableToSetContext(ThisObject), ParametersForm.Filter, Undefined));

	If AvailableSettings.Settings <> Undefined And ReportSettings.Events.BeforeImportSettingsToComposer Then
		ReportObject.BeforeImportSettingsToComposer(ThisObject, ReportSettings.SchemaKey, CurrentVariantKey, 
			AvailableSettings.Settings, AvailableSettings.UserSettings);
	EndIf;

	SettingsImported = ReportsClientServer.LoadSettings(Report.SettingsComposer, AvailableSettings.Settings, 
		AvailableSettings.UserSettings, AvailableSettings.FixedSettings);
	
	// Fixed filters are set using the composer because it has the widest range of settings.
	// "BeforeImport" might be missing the parameters whose settings were not overridden.
	If SettingsImported And ReportsOptions.ItIsAcceptableToSetContext(ThisObject) 
		And TypeOf(ParametersForm.Filter) = Type("Structure") Then

		ReportsServer.SetFixedFilters(ParametersForm.Filter, Report.SettingsComposer.Settings,
			ReportSettings);
	EndIf;

	ParametersForm.FixedSettings = Report.SettingsComposer.FixedSettings;

	AdditionalProperties = Report.SettingsComposer.Settings.AdditionalProperties;
	AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);

	ReportObject = FormAttributeToValue("Report");
	If ReportSettings.Events.AfterLoadSettingsInLinker Then
		ReportObject.AfterLoadSettingsInLinker(New Structure);
	EndIf;
	If Not ReportSettings.Custom Then
		ReportObject.SettingsComposer.Settings.AdditionalProperties.Property("DescriptionOption", 
			ReportCurrentOptionDescription);
	EndIf;

	ReportsServer.SetAvailableValues(ReportObject, ThisObject);
	ReportsServer.InitializePredefinedOutputParameters(ReportSettings, Report.SettingsComposer.Settings,
		ReportsServer.ItIsRequiredToResetThePredefinedOutputParameters(ImportParameters));

	If ImportParameters.VariantModified Then
		VariantModified = True;
	EndIf;

	If ImportParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;

	AdditionalProperties = Report.SettingsComposer.Settings.AdditionalProperties;
	AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
	AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	AdditionalProperties.Insert("OptionContext", OptionContext);
	
	// Prepare for the composer preinitialization (used for details).
	If ReportSettings.SchemaModified Then
		AdditionalProperties.Insert("SchemaURL", ReportSettings.SchemaURL);
	EndIf;

	If ImportParameters.EventName = ReportsOptionsInternalClientServer.NameEventFormSettings() 
		And Not IsBlankString(ImportParameters.SettingsFormPageName) Then
		ReportSettings.SettingsFormAdvancedMode = ImportParameters.SettingsFormAdvancedMode;
		ReportSettings.SettingsFormPageName = ImportParameters.SettingsFormPageName;
	EndIf;

	ReportsServer.SetFiltersConditions(ImportParameters, Report.SettingsComposer);

	If ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox Then
		ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = False;
		Items.GenerateImmediately.Check = CommonClientServer.StructureProperty(
			Report.SettingsComposer.UserSettings.AdditionalProperties, "GenerateImmediately",
			ReportSettings.GenerateImmediately);
	EndIf;

EndProcedure

&AtServer
Procedure ShowGenerationErrors(ErrorInfo)
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		DetailErrorDescription = NStr("en = 'The report is not generated due to:';") + Chars.LF
			+ ErrorProcessing.DetailErrorDescription(ErrorInfo);
		If IsBlankString(ErrorDescription) Then
			ErrorDescription = DetailErrorDescription;
		EndIf;
	Else
		ErrorDescription = ErrorInfo;
		DetailErrorDescription = "";
	EndIf;

	ReportsClientServer.DisplayReportState(ThisObject, ErrorDescription);

	If Not IsBlankString(DetailErrorDescription) Then
		ReportsOptions.WriteToLog(EventLogLevel.Warning, DetailErrorDescription,
			ReportSettings.OptionRef);
	EndIf;
EndProcedure

&AtClient
Function IsOptionMustBeSaved()

	If VariantModified Then
		Return True;
	EndIf;

	If ReportSettings.PredefinedOptionKey <> CurrentVariantKey Then
		Return False;
	EndIf;

	AdditionalProperties = Report.SettingsComposer.Settings.AdditionalProperties;
	Return AdditionalProperties.Property("FormParametersSelection") 
		And ValueIsFilled(AdditionalProperties.FormParametersSelection) Or DetailsMode;

EndFunction

&AtClient
Procedure SaveAsNewOrOverwriteExistingReportOptionAndContinue(Command)

	If Not Items.SaveOptionAs.Visible Then
		ShowMessageBox(, NStr("en = 'Cannot perform the action as saving report options is unavailable.';"));
		Return;
	EndIf;

	If Items.SaveVariant.Visible Then
		Buttons = New ValueList;
		Buttons.Add("SaveAndResume", NStr("en = 'Save and continue';"));
		Buttons.Add("Cancel", NStr("en = 'Cancel';"));
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		QuestionParameters.DefaultButton = "SaveAndResume";
		QuestionParameters.Title = ReportCurrentOptionDescription;
		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("Attachable_CommandAfter", ThisObject, Command),
			NStr("en = 'Do you want to save the report option?';"), Buttons, QuestionParameters);
		Return;
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ObjectKey", ReportSettings.FullName);
		FormParameters.Insert("CurrentSettingsKey", CurrentVariantKey);

		OpenForm("SettingsStorage.ReportsVariantsStorage.SaveForm", FormParameters, ThisObject,,,,
			New NotifyDescription("Attachable_CommandAfterOptionSaved", ThisObject, Command));
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_CommandAfter(Response, Command) Export

	If Response = Undefined Or Response.Value <> "SaveAndResume" Then
		Return;
	EndIf;

	SaveReportOption();
	Attachable_Command(Command);

EndProcedure

&AtClient
Procedure Attachable_CommandAfterOptionSaved(Result, Command) Export

	If TypeOf(Result) <> Type("SettingsChoice") Then
		Return;
	EndIf;

	CurrentVariantKey = Result.SettingsKey;

	SaveReportOption(True);
	Attachable_Command(Command);

EndProcedure

&AtClient
Procedure SaveReportOption(AfterAddedNew = False)

	SaveReportOptionAtServer(AfterAddedNew);
	ShowUserNotification(NStr("en = 'The report option is saved';"), 
		?(Window <> Undefined, Window.GetURL(), Undefined), Title);

EndProcedure

&AtServer
Procedure SaveReportOptionAtServer(AfterAddedNew = False)

	ReportKey = ReportSettings.FullName;
	SettingsDescription = SettingsStorages.ReportsVariantsStorage.GetDescription(ReportKey, CurrentVariantKey);

	If AfterAddedNew Then
		ReportCurrentOptionDescription = SettingsDescription.Presentation;
		NewComposer = New DataCompositionSettingsComposer;
		DCSettings = NewComposer.GetSettings();
		OnSaveVariantAtServer(DCSettings);
	Else
		DCSettings = Report.SettingsComposer.Settings;
	EndIf;

	SettingsStorages.ReportsVariantsStorage.Save(ReportKey, CurrentVariantKey, DCSettings, 
		SettingsDescription);

	VariantModified = False;

EndProcedure

&AtClient
Procedure UpdateOptionsSelectionCommandsIdleHandler()

	UpdateOptionsSelectionCommands();

EndProcedure

&AtServer
Procedure UpdateOptionsSelectionCommands()
	If Common.DataSeparationEnabled() And Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;

	FormOptions = FormAttributeToValue("AddedOptions");
	FormOptions.Columns.Add("Found", New TypeDescription("Boolean"));
	AuthorizedUser = Users.AuthorizedUser();

	SearchParameters = New Structure;
	SearchParameters.Insert("Reports", ReportsServer.ValueToArray(ReportSettings.ReportRef));

	If ReportSettings.Contextual Then
		SearchParameters.Insert("Context", OptionContext);
	EndIf;
	
	SearchParameters.Insert("OnlyPersonal", True);

	VariantsTable = ReportsOptions.ReportOptionTable(SearchParameters);
	If VariantsTable.Columns.Find("Description") = Undefined Then
		VariantsTable.Columns.OptionDescription.Name = "Description";
	EndIf;

	If ReportSettings.External Then // Add predefined options of the external report to the options table.
		For Each ListItem In ReportSettings.PredefinedOptions Do
			TableRow = VariantsTable.Add();
			TableRow.Description = ListItem.Presentation;
			TableRow.VariantKey = ListItem.Value;
		EndDo;
	EndIf;

	VariantsTable.GroupBy("Ref, VariantKey, Description, Author, AuthorOnly");
	VariantsTable.Sort("Description Asc, VariantKey Asc");

	ReportsServer.AddContextOptions(ReportSettings.ReportRef, VariantsTable, ContextOptions);

	MenuBorder = FormOptions.Count() - 1;
	For Each TableRow In VariantsTable Do
		FoundItems = FormOptions.FindRows(New Structure("VariantKey, Found", TableRow.VariantKey, False));
		If FoundItems.Count() = 1 Then
			FormOption = FoundItems[0];
			FormOption.Found = True;

			Button = Items.Find(FormOption.CommandName);
			Button.Visible = True;
			Button.Title = TableRow.Description;
			Items.Move(Button, Items.ReportOptionsGroup);
			
			// "More actions" submenu (All actions).
			MoreButton = Items.Find(FormOption.CommandName + "More");
			MoreButton.Visible = True;
			MoreButton.Title = TableRow.Description;
			Items.Move(MoreButton, Items.MoreCommandBarReportOptionsGroup);
		Else
			MenuBorder = MenuBorder + 1;
			FormOption = FormOptions.Add();
			FillPropertyValues(FormOption, TableRow);
			FormOption.Found = True;
			FormOption.CommandName = "SelectOption_" + Format(MenuBorder, "NZ=0; NG=");

			Command = Commands.Add(FormOption.CommandName);
			Command.Action = "Attachable_ImportReportOption";

			Button = Items.Add(FormOption.CommandName, Type("FormButton"), Items.ReportOptionsGroup);
			Button.Type = FormButtonType.CommandBarButton;
			Button.CommandName = FormOption.CommandName;
			Button.Title = TableRow.Description;
			
			// "More actions" submenu.
			MoreButton = Items.Add(FormOption.CommandName + "More", Type("FormButton"),
				Items.MoreCommandBarReportOptionsGroup);
			MoreButton.Type = FormButtonType.CommandBarButton;
			MoreButton.CommandName = FormOption.CommandName;
			MoreButton.Title = TableRow.Description;

			ConstantCommands.Add(FormOption.CommandName);
		EndIf;

		Button.Check = (CurrentVariantKey = TableRow.VariantKey);
		Button.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;

		MoreButton.Check = (CurrentVariantKey = TableRow.VariantKey);
		MoreButton.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
	EndDo;

	FoundItems = FormOptions.FindRows(New Structure("Found", False));
	For Each FormOption In FoundItems Do
		Button = Items.Find(FormOption.CommandName);
		Button.Check = False;
		Button.Visible = False;
		
		// "More actions" submenu (All actions).
		MoreButton = Items.Find(FormOption.CommandName + "More");
		MoreButton.Check = False;
		MoreButton.Visible = False;
	EndDo;

	FormOptions.Columns.Delete("Found");
	ValueToFormAttribute(FormOptions, "AddedOptions");
EndProcedure

&AtServer
Procedure UpdateInfoOnReportOption()
	AdditionalProperties = Report.SettingsComposer.Settings.AdditionalProperties;
	AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
	AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);

	ReportSettings.OptionRef = Undefined;
	ReportSettings.MeasurementsKey = Undefined;
	ReportSettings.PredefinedRef = Undefined;
	ReportSettings.PredefinedOptionKey = Undefined;
	ReportSettings.Custom = False;
	ReportSettings.ReportType = Undefined;

	If Common.DataSeparationEnabled() And Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;

	Query = VersionOfReportByLinkAndKey(ReportSettings.ReportRef, CurrentVariantKey);

	Selection = Query.Execute().Select();
	If Not Selection.Next() Then

		If ReportSettings.External Then
			Return;
		EndIf;

		Query = VersionOfReportByLinkAndKey(ReportSettings.ReportRef);

		Selection = Query.Execute().Select();
		If Not Selection.Next() Then
		
			// The report is not attached to the Report options subsystem. Its functionality is limited. 
			Return;

		EndIf;

	EndIf;

	MeasurementsKey = Selection.MeasurementsKey;
	If Not ValueIsFilled(MeasurementsKey) Then
		MeasurementsKey = ReportsOptionsInternal.MeasurementsKey(ReportSettings.FullName, CurrentVariantKey);
	EndIf;

	FillPropertyValues(ReportSettings, Selection);
	ReportSettings.MeasurementsKey = MeasurementsKey;
	DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);

	If DetailsMode Then
		ReportCurrentOptionDescription = DescriptionOfReportSettings.Description;
	EndIf;

	AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	AdditionalProperties.Insert("PredefinedOptionKey",
		DescriptionOfReportSettings.PredefinedOptionKey);

EndProcedure

&AtServerNoContext
Function VersionOfReportByLinkAndKey(ReportRef, VariantKey = Undefined)

	QueryText =
	"SELECT ALLOWED TOP 1
	|	ReportsOptions.Ref AS OptionRef,
	|	ReportsOptions.Presentation AS Description,
	|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey,
	|	ReportsOptions.PredefinedOption AS PredefinedRef,
	|	CASE
	|		WHEN ReportsOptions.Custom
	|			THEN ISNULL(ReportsOptions.Parent.VariantKey, UNDEFINED)
	|		ELSE ReportsOptions.VariantKey
	|	END AS PredefinedOptionKey,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.ReportType
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report";

	Query = New Query;
	Query.SetParameter("Report", ReportRef);

	If VariantKey <> Undefined Then
		QueryText = QueryText + " AND ReportsOptions.VariantKey = &VariantKey"; // @Query-part1
		Query.SetParameter("VariantKey", VariantKey);
	EndIf;

	Query.Text = QueryText;

	Return Query;

EndFunction

&AtClientAtServerNoContext
Function BlankOptionKey()
	Return " - ";
EndFunction

&AtClient
Procedure UsersRights(Command)

	If CommonClient.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternalClient = CommonClient.CommonModule(
			"AccessManagementInternalClient");
		ModuleAccessManagementInternalClient.ShowReportUsersRights(
			ReportSettings.ReportRef, ReportSettings.TablesToUse);
	EndIf;

EndProcedure

&AtClient
Procedure ApplyTheSchemaFromTheConstructor(Result)

#If ThickClientOrdinaryApplication Or ThickClientManagedApplication Then
	If TypeOf(Result) <> Type("DataCompositionSchema") Then
		Return;
	EndIf;

	ReportSettings.SchemaURL = PutToTempStorage(Result, UUID);

	Path = GetTempFileName();

	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(Path, "UTF-8");
	XDTOSerializer.WriteXML(XMLWriter, Result, "dataCompositionSchema",
		"http://v8.1c.ru/8.1/data-composition-system/schema");
	XMLWriter.Close();

	BinaryData = New BinaryData(Path);
	BeginDeletingFiles(, Path);

	Report.SettingsComposer.Settings.AdditionalProperties.Insert("DataCompositionSchema", BinaryData);
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);

	FillParameters = ReportsClientServer.ReportFormUpdateParameters(ReportsClientServer.NameOfTheDefaultSettingEvent());
	FillParameters.UserSettingsModified = True;
	FillParameters.DCSettingsComposer = Report.SettingsComposer;
	UpdateSettingsFormItems(FillParameters);
#EndIf

EndProcedure

&AtClient
Procedure ApplySettingsFromTheContextMenu(Result)

	RefineReportAutoGenerationSign(Result);
	ApplySettingsAndReshapeReport(Result, Undefined);

EndProcedure

&AtClient
Procedure AfterSelectingAField(SelectedField, AdditionalParameters) Export

	ReportsOptionsInternalClient.AfterSelectingAField(SelectedField, AdditionalParameters);

EndProcedure

&AtClient
Function TitleProperties()

	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	Return ResultProperties.Headers[NameOfTheCurrentCellArea()];

EndFunction

// Returns:
//   String
//
&AtClient
Function NameOfTheCurrentCellArea()

	Area = Items.ReportSpreadsheetDocument.CurrentArea;
	If TypeOf(Area) = Type("SpreadsheetDocumentRange") 
		And Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
		Return Area.Name;
	EndIf;

	Return "";

EndFunction

&AtClient
Procedure ResetTheCurrentArea()

#If WebClient Then

	DocumentField = Items.ReportSpreadsheetDocument;
	Area = DocumentField.CurrentArea;

	If TypeOf(Area) <> Type("SpreadsheetDocumentRange") 
		Or Area.AreaType <> SpreadsheetDocumentCellAreaType.Rectangle Then
		Return;
	EndIf;

	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	TitleProperties = ResultProperties.Headers[Area.Name];
	If TypeOf(TitleProperties) <> Type("Structure") Then
		Return;
	EndIf;

	If ReportSpreadsheetDocument.PageWidth > ReportSpreadsheetDocument.TableWidth Then
		DocumentField.CurrentArea = ReportSpreadsheetDocument.Area(1, ReportSpreadsheetDocument.TableWidth + 1);

	ElsIf ReportSpreadsheetDocument.PageHeight > ReportSpreadsheetDocument.TableHeight Then
		DocumentField.CurrentArea = ReportSpreadsheetDocument.Area(ReportSpreadsheetDocument.TableHeight + 1, 1);

	EndIf;

#EndIf

EndProcedure

&AtClient
Procedure AfterChangingTheCompositionOfTheQuickSettings(Result, AdditionalParameters) Export

	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;

	If Result.VariantModified Or Result.OutputSettingsTitles <> OutputSettingsTitles Then

		OutputSettingsTitles = Result.OutputSettingsTitles;
		If Result.VariantModified Then
			ReportsOptionsInternalClient.AddSettingstoStack(ThisObject, 
				Result.DCSettingsComposer.Settings, Result.EventName);
		EndIf;

		UpdateSettingsFormItems(Result);
	EndIf;

EndProcedure

&AtClientAtServerNoContext
Function ReportOptionSettingsKey(FullReportName, VariantKey)

	Return StringFunctionsClientServer.SubstituteParametersToString("%1/%2", FullReportName, VariantKey);

EndFunction

&AtServer
Procedure SaveDataInSettingsOnServer(Settings = Undefined)

	SettingsKey = ReportOptionSettingsKey(ReportSettings.FullName, CurrentVariantKey);
	SaveTheSelectedGroupingLevel(SettingsKey, SelectedGroupsLevel, DetailsMode);
	SaveTheStateOfTheOptionOutputSettingsHeaders(SettingsKey, OutputSettingsTitles, DetailsMode);

	If TypeOf(Settings) = Type("Map") Then
		Settings["SettingsFormAdvancedMode"] = ReportSettings.SettingsFormAdvancedMode;
	EndIf;

EndProcedure

#Region TransitionBetweenStackSettings

&AtServer
Procedure RefreshJumpMenuBetweenSettingChanges()

	DeleteCommandsMenuTransitionBetweenSettingChanges();
	DetermineAvailabilityofTransitionCommandsBetweenSettingsChanges();

	StackSettings.Sort("Order Desc");

	PassedCurrentStackSetting = False;
	Next_Command = Undefined;

	For Each Record In StackSettings Do

		If Record.Check Then
			PassedCurrentStackSetting = True;
		EndIf;

		If PassedCurrentStackSetting Then

			ActionGroup1 = Items.GroupUndoChangeSettings;
			Next_Command = Items.CustomizeStandardSettings;

		Else

			ActionGroup1 = Items.GroupRedoChangeSettings;

			If ActionGroup1.ChildItems.Count() > 0 Then
				Next_Command = ActionGroup1.ChildItems[0];
			EndIf;

		EndIf;

		AddTransitionCommandBetweenSettingChanges(Record, ActionGroup1, Next_Command);

	EndDo;

	UpdateKeyboardCommandTransitionBetweenSettingChanges();

EndProcedure

&AtServer
Procedure DeleteCommandsMenuTransitionBetweenSettingChanges()

	MaxStackSizeSettings = ReportsOptionsInternalClientServer.MaxStackSizeSettings();

	For Order = 1 To MaxStackSizeSettings Do

		CommandName = CommandNameTransitionBetweenSettingChanges(Order);

		Button = Items.Find(CommandName);

		If Button <> Undefined Then
			Items.Delete(Button);
		EndIf;

		Command = Commands.Find(CommandName);

		If Command <> Undefined Then
			Commands.Delete(Command);
		EndIf;

	EndDo;

EndProcedure

&AtServer
Procedure DetermineAvailabilityofTransitionCommandsBetweenSettingsChanges()

	CurrentStackSettings = CurrentStackSettings();
	CurrentStackSettingsDefined = (CurrentStackSettings.Count() > 0);

	ButtonSetStandardSettings = Items.CustomizeStandardSettings;
	ButtonSetStandardSettings.Visible = StackSettings.Count() > 0;

	ButtonSetStandardSettings.Enabled = ButtonSetStandardSettings.Visible
		And CurrentStackSettingsDefined;

	ButtonSetStandardSettings.Check = Not ButtonSetStandardSettings.Enabled;

EndProcedure

&AtServer
Procedure AddTransitionCommandBetweenSettingChanges(WriteStackSettings, ActionGroup1, Next_Command)

	CommandName = CommandNameTransitionBetweenSettingChanges(WriteStackSettings.Order);
	CommandTitle = StringFunctionsClientServer.SubstituteParametersToString(
		"%1. %2", WriteStackSettings.Order, WriteStackSettings.PresentationAction);

	Command = Commands.Find(CommandName);

	If Command = Undefined Then
		Command = Commands.Add(CommandName);
	EndIf;

	Command.Action = "Attachable_JumpBetweenSettingsChanges";
	Command.Title = CommandTitle;

	Button = Items.Find(CommandName);

	If Button = Undefined Then
		Button = Items.Insert(CommandName, Type("FormButton"), ActionGroup1, Next_Command);
	EndIf;

	Button.CommandName = CommandName;
	Button.Title = CommandTitle;
	Button.Enabled = Not WriteStackSettings.Check;
	Button.Check = WriteStackSettings.Check;
	Button.Shortcut = New Shortcut(Key.None);

EndProcedure

&AtServer
Function CommandNameTransitionBetweenSettingChanges(Order)

	Return StringFunctionsClientServer.SubstituteParametersToString(
		"%1%2", PrefixCommandNameTransitionBetweenSettingChanges(), Order);

EndFunction

&AtClientAtServerNoContext
Function PrefixCommandNameTransitionBetweenSettingChanges()

	Return "JumpBetweenSettingsChanges";

EndFunction

&AtServer
Procedure UpdateKeyboardCommandTransitionBetweenSettingChanges()

	ButtonSetStandardSettings = Items.CustomizeStandardSettings;
	ButtonSetStandardSettings.Shortcut = New Shortcut(Key.None);

	KeyboardShortcutCancelAction = New Shortcut(Key.Z, False, True, False);
	KeyboardShortcutRepeatAction = New Shortcut(Key.Y, False, True, False);

	CurrentStackSettings = CurrentStackSettings();

	If CurrentStackSettings.Count() > 0 Then

		OrderCommandCurrentStackSettings = CurrentStackSettings[0].Order;

		KeyboardShortcutSet = SetKeyboardCommandTransitionBetweenSettingChanges(
			OrderCommandCurrentStackSettings - 1, KeyboardShortcutCancelAction);

		If Not KeyboardShortcutSet And OrderCommandCurrentStackSettings = 1
			And Not ButtonSetStandardSettings.Check Then

			ButtonSetStandardSettings.Shortcut = KeyboardShortcutCancelAction;

		EndIf;

		SetKeyboardCommandTransitionBetweenSettingChanges(
			OrderCommandCurrentStackSettings + 1, KeyboardShortcutRepeatAction);

	ElsIf StackSettings.Count() > 0 And ButtonSetStandardSettings.Check Then

		SetKeyboardCommandTransitionBetweenSettingChanges(1, KeyboardShortcutRepeatAction);

	EndIf;

EndProcedure

&AtServer
Function SetKeyboardCommandTransitionBetweenSettingChanges(CommandOrder, Shortcut)

	CommandName = CommandNameTransitionBetweenSettingChanges(CommandOrder);
	Button = Items.Find(CommandName);

	If Button = Undefined Then
		Return False;
	EndIf;

	Button.Shortcut = Shortcut;
	Return True;

EndFunction

&AtServer
Function CurrentStackSettings()

	Return StackSettings.FindRows(New Structure("Check", True));

EndFunction

#EndRegion

&AtClient
Procedure RefineReportAutoGenerationSign(ParametersOfUpdate)

	If Not ParametersOfUpdate.Regenerate Then
		AllowableTimeForReportAutoGeneration = 5; // seconds
		ReportGenerationTime = ReportSettings.ResultProperties.FormationTime;
		ParametersOfUpdate.Regenerate = (ReportGenerationTime <= AllowableTimeForReportAutoGeneration);
	EndIf;

EndProcedure

&AtServerNoContext
Function ListOfAvailableReportSaveFormats(IndexOfReportSavingFormats)

	AvailableFormats = New ValueList;

	SaveFormats = StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings();

	For Each SaveFormat In IndexOfReportSavingFormats Do
		FoundDetails = SaveFormats.Find(SaveFormat.Key, "Extension");
		AvailableFormats.Add(FoundDetails.Extension, FoundDetails.Presentation,,
			FoundDetails.Picture);
	EndDo;

	Return AvailableFormats;

EndFunction

&AtServer
Procedure UpdateDetailsDataAdditionalProperties()

	If ValueIsFilled(ReportDetailsData) And IsTempStorageURL(ReportDetailsData) Then
		DetailsData = GetFromTempStorage(ReportDetailsData);
		If TypeOf(DetailsData) = Type("DataCompositionDetailsData") Then
			AdditionalProperties = DetailsData.Settings.AdditionalProperties;
			AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
			AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
			AdditionalProperties.Insert("OptionContext", OptionContext);
			DeleteFromTempStorage(ReportDetailsData);
			ReportDetailsData = PutToTempStorage(DetailsData, UUID);
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure FillPathToExternalReportFileOnClient(ReportObject)

	If ReportSettings.ReportType = Enums.ReportsTypes.Additional Then
		Return;
	EndIf;

	ObjectStructure = New Structure("UsedFileName", Undefined);
	FillPropertyValues(ObjectStructure, ReportObject);

	If Not ValueIsFilled(ObjectStructure.UsedFileName)
	 Or StrStartsWith(ObjectStructure.UsedFileName, "e1cib/")
	 Or StrStartsWith(ObjectStructure.UsedFileName, "e1cib\") Then
		Return;
	EndIf;

	PathToExternalReportFileAtClient = ObjectStructure.UsedFileName;

EndProcedure

#EndRegion