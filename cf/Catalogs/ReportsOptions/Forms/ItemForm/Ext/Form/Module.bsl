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
Var IsFormNotificationTriggered;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	ReportFormOpeningParameters = Parameters.ReportFormOpeningParameters;
	If ReportFormOpeningParameters <> Undefined Then
		Return;
	EndIf;

	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);

	Available = ?(Object.AuthorOnly, "ToAuthor", "ToAll");

	FullRightsToOptions = ReportsOptions.FullRightsToOptions();
	RightToThisOption = FullRightsToOptions Or Object.Author = Users.AuthorizedUser();
	If Not RightToThisOption Then
		ReadOnly = True;
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;

	If Object.DeletionMark Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;

	If Not Object.Custom Then
		Items.Description.ReadOnly = True;
		Items.Author.AutoMarkIncomplete = False;
		Items.Available.Visible = False;
	EndIf;

	IsExternal = (Object.ReportType = Enums.ReportsTypes.External);
	If IsExternal Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;

	Items.Available.ReadOnly = Not FullRightsToOptions;
	Items.NotifyUsers.Visible = FullRightsToOptions;
	Items.Users.Visible = FullRightsToOptions Or Available = "ToAll";
	Items.Author.ReadOnly = Not FullRightsToOptions;
	Items.TechnicalInformation.Visible = FullRightsToOptions;
	
	// Populate the report name for the View command.
	If Object.ReportType = Enums.ReportsTypes.BuiltIn
		Or Object.ReportType = Enums.ReportsTypes.Extension Then
		ReportName = Common.ObjectAttributeValue(Object.Report, "Name");
	ElsIf Object.ReportType = Enums.ReportsTypes.Additional Then
		ReportName = Common.ObjectAttributeValue(Object.Report, "ObjectName");
	Else
		ReportName = Object.Report;
	EndIf;

	RefillTree(False);

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject, Object);
	EndIf;

	ReportsOptions.DefineReportOptionUsersListBehavior(ThisObject);
	ReportsOptions.DisplayTheFlagForNotifyingUsersOfTheReportVariant(Items.NotifyUsers);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	If ReportFormOpeningParameters <> Undefined Then
		Cancel = True;
		ReportsOptionsClient.OpenReportForm(Undefined, ReportFormOpeningParameters);
	EndIf;

	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject, False);

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If IsFormNotificationTriggered <> True And (EventName = ReportsOptionsClient.EventNameChangingOption() 
		Or EventName = "Write_ConstantsSet") Then
		RefillTree(True);
		Items.SubsystemsTree.Expand(SubsystemsTree.GetItems()[0].GetID(), True);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	AskAboutUserNotification(Cancel);

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Write properties associated with the predefined report option.
	DetailsChanged = False;
	If IsPredefined Then

		PredefinedOption = CurrentObject.PredefinedOption.GetObject();

		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(PredefinedOption);
		EndIf;

		DetailsChanged = Not IsBlankString(Object.LongDesc) 
			And Lower(TrimAll(Object.LongDesc)) <> Lower(TrimAll(PredefinedOption.LongDesc));
		If Not DetailsChanged Then
			CurrentObject.LongDesc = "";
			For Each VariantPresentation In CurrentObject.Presentations Do
				VariantPresentation.LongDesc = "";
			EndDo;
		EndIf;
	EndIf;
	
	// Write the subsystem tree.
	DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	If CurrentObject.IsNew() Then
		ChangedSections = DestinationTree.Rows.FindRows(New Structure("Use", 1), True);
	Else
		ChangedSections = DestinationTree.Rows.FindRows(New Structure("Modified", True), True);
	EndIf;
	ReportsOptions.SubsystemsTreeWrite(CurrentObject, ChangedSections);

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.BeforeWriteAtServer(CurrentObject);
	EndIf;

	If IsPredefined And Not DetailsChanged Then
		CurrentObject.Presentations.Clear();
	EndIf;

	CurrentObject.AdditionalProperties.Insert("OptionUsers", OptionUsers);
	CurrentObject.AdditionalProperties.Insert("NotifyUsers", NotifyUsers);

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

	RefillTree(False);
	FillFromPredefinedOption(CurrentObject);

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	IsFormNotificationTriggered = True;
	ReportsOptionsClient.UpdateOpenForms(, Object.Ref);
	IsFormNotificationTriggered = False;
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "SubsystemsTree", "*", True);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

	FillFromPredefinedOption(CurrentObject);

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;

	InformationRegisters.ReportOptionsSettings.ReadReportOptionAvailabilitySettings(
		CurrentObject.Ref, OptionUsers, UseUserGroups, UseExternalUsers);

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure LongDescStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "LongDesc",
		NStr("en = 'Details';"));
EndProcedure

&AtClient
Procedure AvailableOnChange(Item)

	Object.AuthorOnly = (Available = "ToAuthor");

	ReportsOptionsClient.CheckTheUsersOfTheReportOption(ThisObject);
	ReportsOptionsClient.RegisterReportOptionUsers(ThisObject, False);

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

	If Not UseUserGroups And Not UseExternalUsers Then

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

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	ReportsOptions.SetConditionalAppearanceOfReportOptionUsersList(ThisObject);
	ReportsOptions.SetSubsystemsTreeConditionalAppearance(ThisObject);

EndProcedure

&AtServer
Function RefillTree(Read)
	SelectedRows = ReportsServer.RememberSelectedRows(ThisObject, "SubsystemsTree", "Ref");
	If Read Then
		Read();
	EndIf;
	DestinationTree = ReportsOptions.SubsystemsTreeGenerate(ThisObject, Object);
	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
	ReportsServer.RestoreSelectedRows(ThisObject, "SubsystemsTree", SelectedRows);
	Return True;
EndFunction

&AtServer
Procedure FillFromPredefinedOption(OptionObject)

	IsPredefined = ReportsOptions.IsPredefinedReportOption(OptionObject);

	If Not IsPredefined Then
		Return;
	EndIf;

	PredefinedOption = OptionObject.PredefinedOption.GetObject();

	OptionObject.Description = PredefinedOption.Description;
	OptionObject.LongDesc = PredefinedOption.LongDesc;

EndProcedure

&AtClient
Procedure AskAboutUserNotification(Cancel)

	If Not NotifyUsers Or UsersNotificationQuestionSpecified Then

		Return;
	EndIf;

	UsersCount = NumberOfUsersReportOption(OptionUsers);

	If UsersCount < 10 Then
		Return;
	EndIf;

	Cancel = True;
	UsersNotificationQuestionSpecified = True;

	Handler = New NotifyDescription("AfterAQuestionAboutNotifyingUsers", ThisObject);
	ReportsOptionsInternalClient.AskAboutUserNotification(Handler, UsersCount);

EndProcedure

&AtClient
Procedure AfterAQuestionAboutNotifyingUsers(Response, AdditionalParameters) Export

	If Response = DialogReturnCode.No Then
		NotifyUsers = False;
	EndIf;

	Write();

EndProcedure

&AtServerNoContext
Function NumberOfUsersReportOption(OptionUsers)

	Return InformationRegisters.ReportOptionsSettings.NumberOfUsersReportOption(OptionUsers);

EndFunction

#EndRegion