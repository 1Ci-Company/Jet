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
	
	SetConditionalAppearance();
	
	DefineBehaviorInMobileClient();
	
	PrototypeKey = Parameters.CurrentSettingsKey;
	ReportInformation = ReportsOptions.ReportInformation(Parameters.ObjectKey, True);
	
	Context = New Structure;
	Context.Insert("CurrentUser", Users.AuthorizedUser());
	Context.Insert("FullRightsToOptions", ReportsOptions.FullRightsToOptions());
	Context.Insert("ReportRef", ReportInformation.Report);
	Context.Insert("ReportShortName", ReportInformation.ReportShortName);
	Context.Insert("ReportType", ReportInformation.ReportType);
	Context.Insert("IsExternal", ReportInformation.ReportType = Enums.ReportsTypes.External);
	Context.Insert("SearchByDescription", New Map);
	
	FillOptionsList();
	
	InformationRegisters.ReportOptionsSettings.ReadReportOptionAvailabilitySettings(
		OptionRef, OptionUsers, UseUserGroups, UseExternalUsers);
	
	Items.Available.ReadOnly = Not Context.FullRightsToOptions;
	Items.NotifyUsers.Visible = Context.FullRightsToOptions;
	Items.GroupAvailability.Visible = Context.FullRightsToOptions Or Available = "ToAll";
	
	If Context.IsExternal Then
		
		Items.Back.Visible = False;
		Items.Next.Visible = False;
		Items.Available.Visible = False;
		Items.NextStepInfoNewOptionDecoration.Title = NStr("en = 'The report option will be saved as a new option.';");
		Items.NextStepInfoOverwriteOptionDecoration.Title = NStr("en = 'The current report option will be overwritten.';");
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject, Object);
	EndIf;
	
	Items.LongDesc.ChoiceButton = Not Items.LongDesc.OpenButton;
	
	ReportsOptions.DefineReportOptionUsersListBehavior(ThisObject);
	ReportsOptions.DisplayTheFlagForNotifyingUsersOfTheReportVariant(Items.NotifyUsers);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CurrentItem = Items.Description;
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject, False);
	
	IsContextReportOption = FormOwner.FormName = "CommonForm.ReportForm"
		And ValueIsFilled(FormOwner.OptionContext);
	
	If IsContextReportOption Then 
		Items.Back.Visible = False;
		Items.Next.Visible = False;
		
		ContextOptions = FormOwner.ContextOptions;
		AttachIdleHandler("FillOptionsListDeferred", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not ValueIsFilled(Object.Description) Then
		Common.MessageToUser(
			NStr("en = 'Description is not populated';"),, "Description");
		Cancel = True;
	ElsIf ReportsOptions.DescriptionIsUsed(Context.ReportRef, OptionRef, Object.Description) Then
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" is taken. Enter another description.';"),
				Object.Description),
			,
			"Description");
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Source = FormName Then
		Return;
	EndIf;
	
	If EventName = ReportsOptionsClient.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Or EventName = "Write_ReportsOptions" Then
		FillOptionsList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	DescriptionModified = True;
	SetOptionSavingScenario(True);
	
	ReportsOptionsClient.CheckTheUsersOfTheReportOption(ThisObject);
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject, False);
	
EndProcedure

&AtClient
Procedure AvailableOnChange(Item)
	
	Object.AuthorOnly = (Available = "ToAuthor");
	
	ReportsOptionsClient.CheckTheUsersOfTheReportOption(ThisObject);
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject, False);
	
EndProcedure

&AtClient
Procedure LongDescStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("LongDescStartChoiceCompletion", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(
		Notification, Items.LongDesc.EditText, NStr("en = 'Details';"));
	
EndProcedure

&AtClient
Procedure LongDescOnChange(Item)
	
	DetailsModified = True;
	
EndProcedure

&AtClient
Procedure Attachable_Opening(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClient = CommonClient.CommonModule("NationalLanguageSupportClient");
		ModuleNationalLanguageSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOptionUsers

&AtClient
Procedure OptionUsersOnChange(Item)
	
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject);
	
EndProcedure

&AtClient
Procedure OptionUsersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure OptionUsersBeforeDeleteRow(Item, Cancel)
	
	If Not UseUserGroups
		And Not UseExternalUsers Then 
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OptionUsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ReportsOptionsClient.ReportOptionUsersChoiceProcessing1(ThisObject, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure OptionUsersCheckBoxOnChange(Item)
	
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeUseOnChange(Item)
	
	ReportsOptionsClient.SubsystemsTreeUseOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure SubsystemsTreeImportanceOnChange(Item)
	
	ReportsOptionsClient.SubsystemsTreeImportanceOnChange(ThisObject, Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure PickUsers(Command)
	
	ReportsOptionsClient.PickReportOptionUsers(ThisObject, UseUserGroups);
	
EndProcedure

&AtClient
Procedure PickExternalUsersGroups(Command)
	
	ReportsOptionsClient.PickReportOptionUsers(
		ThisObject, Items.OptionUsersPickGroup.Visible, True);
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	GoToPage31();
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	Package = New Structure;
	Package.Insert("CheckPage1", True);
	Package.Insert("GoToPage32", True);
	Package.Insert("FillPage2Server", True);
	Package.Insert("CheckAndWriteServer", False);
	Package.Insert("CloseAfterWrite", False);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
	
EndProcedure

&AtClient
Procedure Save(Command)
	
	SaveAndLoad();
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure ExecuteBatch(Result, Package) Export
	
	If Not Package.Property("OptionIsNew") Then
		Package.Insert("OptionIsNew", Not ValueIsFilled(OptionRef));
	EndIf;
	
	If Not ContinueExecutingThePackage(Result, Package) Then 
		Return;
	EndIf;
	
	// Perform the next step.
	If Package.CheckPage1 = True Then
		// Description is missing.
		If Not ValueIsFilled(Object.Description) Then
			ErrorText = NStr("en = 'Description is not populated';");
			CommonClient.MessageToUser(ErrorText, , "Object.Description");
			Return;
		EndIf;
		
		// Description of the existing report option is entered.
		If Not Package.OptionIsNew Then
			FoundItems = ReportOptions.FindRows(New Structure("Ref", OptionRef));
			Variant = FoundItems[0];
			If Not RightToWriteOption(Variant, Context.FullRightsToOptions) Then
				ErrorText = NStr("en = 'Insufficient rights to modify option ""%1"". Save it under a different name or select another report option.';");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Object.Description);
				CommonClient.MessageToUser(ErrorText, , "Object.Description");
				Return;
			EndIf;
			
			If AskAboutOverwritingAReportVariant(Package, Variant) Then 
				Return;
			EndIf;
		EndIf;
		
		// Check is completed.
		Package.CheckPage1 = False;
	EndIf;
	
	If AskAboutUserNotification(Package) Then 
		Return;
	EndIf;
	
	If Package.GoToPage32 = True Then
		// For external reports, only fill checks are executed without switching the page.
		If Not Context.IsExternal Then
			Items.Pages.CurrentPage = Items.More;
			Items.Back.Enabled        = True;
			Items.Next.Enabled        = False;
		EndIf;
		
		// Switch is completed.
		Package.GoToPage32 = False;
	EndIf;
	
	If Package.FillPage2Server = True
		Or Package.CheckAndWriteServer = True Then
		
		ExecuteBatchServer(Package);
		
		TreeRows = SubsystemsTree.GetItems();
		For Each TreeRow In TreeRows Do
			Items.SubsystemsTree.Expand(TreeRow.GetID(), True);
		EndDo;
		
		If Package.Cancel = True Then
			GoToPage31();
			Return;
		EndIf;
		
	EndIf;
	
	If Package.CloseAfterWrite = True Then
		ReportsOptionsClient.UpdateOpenForms(, OptionRef);
		Close(New SettingsChoice(ReportOptionOptionKey));
		Package.CloseAfterWrite = False;
	EndIf;
	
EndProcedure

&AtClient
Function ContinueExecutingThePackage(Result, Package)
	
	CurrentStep = Package.CurrentStep;
	
	Package.CurrentStep = Undefined;
	
	If CurrentStep = "PromptForOverwrite" Then
		
		If Result <> DialogReturnCode.Yes Then
			Return False;
		EndIf;
		
		Package.Insert("PromptForOverwriteConfirmed", True);
		
	ElsIf CurrentStep = "QuestionAboutNotifyingUsers" Then
		
		If Result = DialogReturnCode.Yes Then
			Package.Insert("UsersNotificationQuestionSpecified", True);
		Else
			NotifyUsers = False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Function AskAboutOverwritingAReportVariant(Package, Variant)
	
	If Package.Property("PromptForOverwriteConfirmed") Then
		Return False;
	EndIf;
	
	Package.CurrentStep = "PromptForOverwrite";
	
	If Variant.DeletionMark = True Then
		
		DefaultButton = DialogReturnCode.No;
		QuestionTextTemplate = NStr("en = 'Report option %1 is marked for deletion.
			|Do you want to overwrite it?';");
	Else
		DefaultButton = DialogReturnCode.Yes;
		QuestionTextTemplate = NStr("en = 'Do you want to overwrite report option %1?';");
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QuestionTextTemplate, Object.Description);
	
	Handler = New NotifyDescription("ExecuteBatch", ThisObject, Package);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DefaultButton);
	
	Return True;
	
EndFunction

&AtClient
Function AskAboutUserNotification(Package)
	
	If Not NotifyUsers
		Or Package.Property("UsersNotificationQuestionSpecified") Then 
		
		Return False;
	EndIf;
	
	UsersCount = NumberOfUsersReportOption(OptionUsers);
	
	If UsersCount < 10 Then
		Return False;
	EndIf;

	Package.CurrentStep = "QuestionAboutNotifyingUsers";
	
	Handler = New NotifyDescription("ExecuteBatch", ThisObject, Package);
	ReportsOptionsInternalClient.AskAboutUserNotification(Handler, UsersCount);
	
	Return True;
	
EndFunction

&AtClient
Procedure GoToPage31()
	
	Items.Pages.CurrentPage = Items.IsMain;
	Items.Back.Enabled        = False;
	Items.Next.Title          = "";
	Items.Next.Enabled        = True;
	
EndProcedure

&AtClient
Procedure SaveAndLoad()
	
	AdditionalPageFilled = (Items.Pages.CurrentPage = Items.More);
	
	Package = New Structure;
	Package.Insert("CheckPage1",       Not AdditionalPageFilled);
	Package.Insert("GoToPage32",       Not AdditionalPageFilled);
	Package.Insert("FillPage2Server", Not AdditionalPageFilled);
	Package.Insert("CheckAndWriteServer", True);
	Package.Insert("CloseAfterWrite",       True);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
	
EndProcedure

&AtClient
Procedure LongDescStartChoiceCompletion(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;

	Object.LongDesc = EnteredText;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client and server.

// Returns the flag of the available report option change rights.
//
// Parameters:
//   Variant - FormDataCollection:
//     * Ref - CatalogRef.ReportsOptions
//   FullRightsToOptions - Boolean
//
// Returns:
//   Boolean
//
&AtClientAtServerNoContext
Function RightToConfigureOption(Variant, FullRightsToOptions)
	
	Return (FullRightsToOptions Or Variant.CurrentUserIsAuthor) And ValueIsFilled(Variant.Ref);
	
EndFunction

&AtClientAtServerNoContext
Function RightToWriteOption(Variant, FullRightsToOptions)
	
	Return Variant.Custom And RightToConfigureOption(Variant, FullRightsToOptions);
	
EndFunction

// Returns a unique report option name.
// 
// Parameters:
//   Variant - FormDataCollection:
//     * Ref - CatalogRef.ReportsOptions
//     * Description - String
//   ReportOptions - FormDataCollection
//
// Returns:
//   String
//
&AtClientAtServerNoContext
Function GenerateFreeDescription(Variant, ReportOptions)
	
	OptionNameTemplate = TrimAll(Variant.Description) + " - " + NStr("en = 'copy';");
	
	FreeDescription = OptionNameTemplate;
	FoundItems = ReportOptions.FindRows(New Structure("Description", FreeDescription));
	If FoundItems.Count() = 0 Then
		Return FreeDescription;
	EndIf;
	
	OptionNumber = 1;
	While True Do
		OptionNumber = OptionNumber + 1;
		FreeDescription = OptionNameTemplate +" (" + Format(OptionNumber, "") + ")";
		FoundItems = ReportOptions.FindRows(New Structure("Description", FreeDescription));
		If FoundItems.Count() = 0 Then
			Return FreeDescription;
		EndIf;
	EndDo;
	
	Return OptionNameTemplate;
	
EndFunction

&AtClient
Procedure FillOptionsListDeferred()
	
	If ContextOptions.Count() > 0 Then 
		FillOptionsList();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServerNoContext
Function NumberOfUsersReportOption(OptionUsers)
	
	Return InformationRegisters.ReportOptionsSettings.NumberOfUsersReportOption(OptionUsers);
	
EndFunction

&AtServer
Procedure ExecuteBatchServer(Package)
	
	Package.Insert("Cancel", False);
	
	If Package.FillPage2Server = True Then
		If Not Context.IsExternal Then
			RefillAdditionalPage(Package);
		EndIf;
		Package.FillPage2Server = False;
	EndIf;
	
	If Package.CheckAndWriteServer = True Then
		CheckAndWriteReportOption(Package);
		Package.CheckAndWriteServer = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefillAdditionalPage(Package)
	If Package.OptionIsNew Then
		OptionBasis = PrototypeRef;
	Else
		OptionBasis = OptionRef;
	EndIf;
	
	DestinationTree = ReportsOptions.SubsystemsTreeGenerate(ThisObject, OptionBasis);
	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
EndProcedure

&AtServer
Procedure CheckAndWriteReportOption(Package)
	
	IsNewReportOption = Not ValueIsFilled(OptionRef);
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		If Not IsNewReportOption Then
			LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", OptionRef);
		ElsIf TypeOf(PrototypeRef) = Type("CatalogRef.ReportsOptions") And Not PrototypeRef.IsEmpty() Then
			LockItem = Block.Add(PrototypeRef.Metadata().FullName());
			LockItem.SetValue("Ref", PrototypeRef);
			LockItem.Mode = DataLockMode.Shared;
		EndIf;
		Block.Lock();
		
		If IsNewReportOption And ReportsOptions.DescriptionIsUsed(Context.ReportRef, OptionRef, Object.Description) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" is taken. Enter another description.';"), 
				Object.Description);
			Common.MessageToUser(ErrorText, , "Object.Description");
			Package.Cancel = True;
			RollbackTransaction();
			Return;
		EndIf;
		
		If IsNewReportOption Then
			
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.Report = Context.ReportRef;
			OptionObject.ReportType = Context.ReportType;
			OptionObject.VariantKey = String(New UUID());
			OptionObject.Custom = True;
			OptionObject.Author = Context.CurrentUser;
			
			If PrototypePredefined Then
				OptionObject.Parent = PrototypeRef;
			ElsIf TypeOf(PrototypeRef) = Type("CatalogRef.ReportsOptions") And Not PrototypeRef.IsEmpty() Then
				OptionObject.Parent = Common.ObjectAttributeValue(PrototypeRef, "Parent");
			Else
				OptionObject.FillInParent();
			EndIf;
			
		Else
			OptionObject = OptionRef.GetObject();
		EndIf;
		
		If Context.IsExternal Then
			OptionObject.Location.Clear();
		Else
			DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
			If IsNewReportOption Then
				ChangedSections = DestinationTree.Rows.FindRows(New Structure("Use", 1), True);
			Else
				ChangedSections = DestinationTree.Rows.FindRows(New Structure("Modified", True), True);
			EndIf;
			ReportsOptions.SubsystemsTreeWrite(OptionObject, ChangedSections);
		EndIf;
		
		OptionObject.Description = Object.Description;
		OptionObject.LongDesc = Object.LongDesc;
		OptionObject.AuthorOnly = Object.AuthorOnly;
		OptionObject.Purpose = Object.Purpose;
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			
			MultilingualObjectAttributes =  ModuleNationalLanguageSupportServer.MultilingualObjectAttributes(OptionObject.Ref);
			If MultilingualObjectAttributes.Count() > 0 Then
			
				MultilingualPropsSet = New Array;
				For Each AttributeDetails In MultilingualObjectAttributes Do
					MultilingualPropsSet.Add(AttributeDetails.Key + "Language1"); 
					MultilingualPropsSet.Add(AttributeDetails.Key + "Language2");
				EndDo;
				ListOfMultilingualDetails  = StrConcat(MultilingualPropsSet, ",");
				
				FillPropertyValues(OptionObject, Object, ListOfMultilingualDetails);
				
			EndIf;
			
			For Each TableRow In Object.Presentations Do
				NewRow = OptionObject.Presentations.Add();
				FillPropertyValues(NewRow, TableRow);
			EndDo;
			
			ModuleNationalLanguageSupportServer.BeforeWriteAtServer(OptionObject);
			
		EndIf;
		
		OptionObject.AdditionalProperties.Insert("OptionUsers", OptionUsers);
		OptionObject.AdditionalProperties.Insert("NotifyUsers", NotifyUsers);
		
		OptionObject.Write();
		
		OptionRef       = OptionObject.Ref;
		ReportOptionOptionKey = OptionObject.VariantKey;
		
		If ResetSettings Then
			ReportsOptions.ResetCustomSettings(OptionObject.Ref);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure DefineBehaviorInMobileClient()
	
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then 
		Return;
	EndIf;
	
	CommandBarLocation = FormCommandBarLabelLocation.Auto;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	ReportsOptions.SetConditionalAppearanceOfReportOptionUsersList(ThisObject);
	ReportsOptions.SetSubsystemsTreeConditionalAppearance(ThisObject);
	
EndProcedure

&AtServer
Procedure FillOptionsList()
	
	FilterReports = New Array;
	FilterReports.Add(Context.ReportRef);
	SearchParameters = New Structure("Reports, OnlyPersonal, OptionKeyWithoutConditions",
		FilterReports, False, PrototypeKey);
	VariantsTable = ReportsOptions.ReportOptionTable(SearchParameters);
	
	ReportsServer.AddContextOptions(Context.ReportRef, VariantsTable, ContextOptions);
	
	// Populate autocalculated columns.
	ReportOptions.Load(VariantsTable);
	For Each Variant In ReportOptions Do
		Variant.CurrentUserIsAuthor = (Variant.Author = Context.CurrentUser);
		
		If Variant.VariantKey = PrototypeKey Then
			PrototypeRef = Variant.Ref;
			PrototypePredefined = Not Variant.Custom;
			Object.Purpose = Variant.Purpose;
		EndIf;
	EndDo;
	If Not ValueIsFilled(PrototypeRef) And ValueIsFilled(PrototypeKey) Then
		Query = New Query;
		Query.SetParameter("Report", FilterReports);
		Query.SetParameter("VariantKey", PrototypeKey);
		Query.Text =
		"SELECT
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.Purpose AS Purpose
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Report IN (&Report)
		|	AND ReportsOptions.VariantKey = &VariantKey";
		
		SetPrivilegedMode(True);
		Selection = Query.Execute().Select();
		SetPrivilegedMode(False);
		If Selection.Next() Then
			PrototypeRef = Selection.Ref;
			PrototypePredefined = Not Selection.Custom;
			Object.Purpose = Selection.Purpose;
		EndIf;
	EndIf;
	
	If Context.IsExternal
		And Not SettingsStorages.ReportsVariantsStorage.AddExternalReportOptions(
			ReportOptions, Context.ReportRef, Context.ReportShortName) Then
		Return;
	EndIf;
	
	SetOptionSavingScenario();
	
EndProcedure

&AtServer
Procedure SetOptionSavingScenario(DescriptionOnChange = False)
	
	NewObjectWillBeWritten = False;
	ExistingObjectWillBeOverwritten = False;
	CannotOverwrite = False;
	
	If DescriptionModified Then 
		Search = New Structure("Description", Object.Description);
	Else
		Search = New Structure("VariantKey", PrototypeKey);
	EndIf;
	
	FoundOptions = ReportOptions.FindRows(Search);
	
	If FoundOptions.Count() = 0 Then
		
		NewObjectWillBeWritten = True;
		If Not ValueIsFilled(Object.Description) And ValueIsFilled(PrototypeRef) Then
			Object.Description = GenerateFreeDescription(PrototypeRef, ReportOptions);
		EndIf;
		OptionRef = Undefined;
		Object.Author = Context.CurrentUser;
		
		If Not DetailsModified Then
			Object.LongDesc = "";
		EndIf;
		
		If Not Context.FullRightsToOptions Then
			Object.AuthorOnly = True;
		EndIf;
		
	Else
		
		Variant = FoundOptions[0]; // FormDataCollectionItem
		RightToWriteOption = RightToWriteOption(Variant, Context.FullRightsToOptions);
		
		FillPresentations(Variant.Ref);
		
		If RightToWriteOption Then
			
			ExistingObjectWillBeOverwritten = True;
			DescriptionModified = False;
			Object.Description = Variant.Description;
			Object.Purpose = Variant.Purpose;
			
			OptionRef = Variant.Ref;
			Object.Author = Variant.Author;
			If Not Context.FullRightsToOptions
			   And Object.AuthorOnly
			   And Not Variant.AuthorOnly Then
				InformationRegisters.ReportOptionsSettings.ReadReportOptionAvailabilitySettings(
					OptionRef, OptionUsers);
			EndIf;
			If Not Context.FullRightsToOptions
			 Or Not DescriptionOnChange Then
				Object.AuthorOnly = Variant.AuthorOnly;
			EndIf;
			
			If Not DetailsModified Then
				Object.LongDesc = Variant.LongDesc;
			EndIf;
			
		Else
			
			If DescriptionModified Then
				CannotOverwrite = True;
			Else
				NewObjectWillBeWritten = True;
				Object.Description = GenerateFreeDescription(Variant, ReportOptions);
			EndIf;
			
			OptionRef = Undefined;
			Object.Author = Context.CurrentUser;
			Object.AuthorOnly = True;
			
			If Not DetailsModified Then
				Object.LongDesc = "";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Available = ?(Object.AuthorOnly, "ToAuthor", "ToAll");
	
	If NewObjectWillBeWritten Then
		
		Items.NextStepInfo.CurrentPage = Items.New;
		Items.ResetSettings.Visible = False;
		Items.Next.Enabled     = True;
		Items.Save.Enabled = True;
		
	ElsIf ExistingObjectWillBeOverwritten Then
		
		Items.NextStepInfo.CurrentPage = Items.OverwriteOption;
		Items.ResetSettings.Visible = True;
		Items.Next.Enabled     = True;
		Items.Save.Enabled = True;
		
	ElsIf CannotOverwrite Then
		
		Items.NextStepInfo.CurrentPage = Items.CannotOverwrite;
		Items.ResetSettings.Visible = False;
		Items.Next.Enabled     = False;
		Items.Save.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPresentations(Variant)
	
	QueryText = "SELECT ALLOWED TOP 1
	|	CASE
	|		WHEN NOT FromConfiguration.Description IS NULL
	|			THEN FromConfiguration.Description
	|		WHEN NOT FromExtensions.Description IS NULL
	|			THEN FromExtensions.Description
	|		ELSE UserSettings2.Description
	|	END AS Description,
	|	CASE
	|		WHEN SUBSTRING(UserSettings2.LongDesc, 1, 1) <> """"
	|			THEN UserSettings2.LongDesc
	|		WHEN NOT FromConfiguration.LongDesc IS NULL
	|			THEN FromConfiguration.LongDesc
	|		WHEN NOT FromExtensions.LongDesc IS NULL
	|			THEN FromExtensions.LongDesc
	|		ELSE CAST("""" AS STRING(1000))
	|	END AS LongDesc, 
	|	&NationalLanguageSupport
	|FROM
	|	Catalog.ReportsOptions AS UserSettings2
	|	LEFT JOIN Catalog.PredefinedReportsOptions AS FromConfiguration
	|		ON FromConfiguration.Ref = UserSettings2.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS FromExtensions
	|		ON FromExtensions.Ref = UserSettings2.PredefinedOption
	|WHERE
	|	UserSettings2.Ref = &Variant";
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		
		QueryTextMultilingualAttributes = "CASE
		|		WHEN NOT FromConfiguration.DescriptionLanguage1 IS NULL
		|			THEN FromConfiguration.DescriptionLanguage1
		|		WHEN NOT FromExtensions.DescriptionLanguage1 IS NULL
		|			THEN FromExtensions.DescriptionLanguage1
		|		ELSE UserSettings2.DescriptionLanguage1
		|	END AS DescriptionLanguage1,
		|	CASE
		|		WHEN NOT FromConfiguration.DescriptionLanguage2 IS NULL
		|			THEN FromConfiguration.DescriptionLanguage2
		|		WHEN NOT FromExtensions.DescriptionLanguage2 IS NULL
		|			THEN FromExtensions.DescriptionLanguage2
		|		ELSE UserSettings2.DescriptionLanguage2
		|	END AS DescriptionLanguage2,
		|	CASE
		|		WHEN SUBSTRING(UserSettings2.LongDescLanguage1, 1, 1) <> """"
		|			THEN UserSettings2.LongDescLanguage1
		|		WHEN NOT FromConfiguration.LongDescLanguage1 IS NULL
		|			THEN FromConfiguration.LongDescLanguage1
		|		WHEN NOT FromExtensions.LongDescLanguage1 IS NULL
		|			THEN FromExtensions.LongDescLanguage1
		|		ELSE CAST("""" AS STRING(1000))
		|	END AS LongDescLanguage1,
		|	CASE
		|		WHEN SUBSTRING(UserSettings2.LongDescLanguage2, 1, 1) <> """"
		|			THEN UserSettings2.LongDescLanguage2
		|		WHEN NOT FromConfiguration.LongDescLanguage2 IS NULL
		|			THEN FromConfiguration.LongDescLanguage2
		|		WHEN NOT FromExtensions.LongDescLanguage2 IS NULL
		|			THEN FromExtensions.LongDescLanguage2
		|		ELSE CAST("""" AS STRING(1000))
		|	END AS LongDescLanguage2";
	Else
		QueryTextMultilingualAttributes  = "TRUE";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&NationalLanguageSupport", QueryTextMultilingualAttributes );
	
	Query = New Query(QueryText);
	Query.SetParameter("Variant", Variant);
	
	Selection = Query.Execute().Unload();
	
	If Selection.Count() = 0 Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, Selection[0]);
	
EndProcedure


#EndRegion
