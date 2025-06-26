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
	
	SubsystemSettings  = InfobaseUpdateInternal.SubsystemSettings();
	FormAddressInApplication = SubsystemSettings.ApplicationChangeHistoryLocation;
	
	If ValueIsFilled(FormAddressInApplication) Then
		Items.FormAddressInApplication.Title = FormAddressInApplication;
	EndIf;
	
	If Not Parameters.ShowOnlyChanges Then
		Items.FormAddressInApplication.Visible = False;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'What''s new in %1';"), Metadata.Synonym);
	
	If ValueIsFilled(Parameters.UpdateStartTime) Then
		UpdateStartTime = Parameters.UpdateStartTime;
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
	Sections = InfobaseUpdateInternal.NotShownUpdateDetailSections();
	LatestVersion1 = InfobaseUpdateInternal.SystemChangesDisplayLastVersion();
	
	If Sections.Count() = 0 Then
		DocumentUpdatesDetails = Metadata.CommonTemplates.Find("SystemReleaseNotes");
		If DocumentUpdatesDetails <> Undefined
			And (LatestVersion1 = Undefined
				Or Not Parameters.ShowOnlyChanges) Then
			AllSections = InfobaseUpdateInternal.UpdateDetailsSections();
			If TypeOf(AllSections) = Type("ValueList")
				And AllSections.Count() <> 0 Then
				For Each Item In AllSections Do
					Sections.Add(Item.Presentation);
				EndDo;
				DocumentUpdatesDetails = InfobaseUpdateInternal.DocumentUpdatesDetails(Sections);
			Else
				DocumentUpdatesDetails = GetCommonTemplate(DocumentUpdatesDetails);
			EndIf;
		Else
			DocumentUpdatesDetails = New SpreadsheetDocument();
		EndIf;
	Else
		DocumentUpdatesDetails = InfobaseUpdateInternal.DocumentUpdatesDetails(Sections);
	EndIf;
	
	If DocumentUpdatesDetails.TableHeight = 0 Then
		Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The application is updated to version %1.';"), Metadata.Version);
		DocumentUpdatesDetails.Area("R1C1:R1C1").Text = Text;
	EndIf;
	
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For Each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If Not ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnPrepareUpdateDetailsTemplate(DocumentUpdatesDetails);
	EndDo;
	InfobaseUpdateOverridable.OnPrepareUpdateDetailsTemplate(DocumentUpdatesDetails);
	
	UpdatesDetails.Clear();
	UpdatesDetails.Put(DocumentUpdatesDetails);
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdateStartTime = UpdateInfo.UpdateStartTime;
	UpdateEndTime = UpdateInfo.UpdateEndTime;
	
	If Not Common.SeparatedDataUsageAvailable()
		Or UpdateInfo.DeferredUpdateCompletedSuccessfully <> Undefined
		Or UpdateInfo.HandlersTree <> Undefined
			And UpdateInfo.HandlersTree.Rows.Count() = 0 Then
		Items.DeferredUpdate.Visible = False;
	EndIf;
	
	If Common.FileInfobase() Then
		MessageTitle = NStr("en = 'Additional data processing required';");
		Items.DeferredDataUpdate.Title = MessageTitle;
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Items.DeferredDataUpdate.Title =
			NStr("en = 'Additional data processing skipped';");
	EndIf;
	
	Items.TechnicalInformationOnUpdateResult.Visible = 
		(Users.IsFullUser() And Not Common.DataSeparationEnabled())
		And (ValueIsFilled(UpdateStartTime) Or ValueIsFilled(UpdateEndTime));
	
	ClientServerInfobase = Not Common.FileInfobase();
	
	// Displaying the information on disabled scheduled jobs.
	If Not ClientServerInfobase
		And Users.IsFullUser(, True) Then
		ClientLaunchParameter = StandardSubsystemsServer.ClientParametersAtServer().Get("LaunchParameter");
		ScheduledJobsDisabled = StrFind(ClientLaunchParameter, "ScheduledJobsDisabled2") <> 0;
		If Not ScheduledJobsDisabled Then
			Items.ScheduledJobsDisabledGroup.Visible = False;
		EndIf;
	Else
		Items.ScheduledJobsDisabledGroup.Visible = False;
	EndIf;
	
	Items.UpdatesDetails.HorizontalScrollBar = ScrollBarUse.DontUse;
	
	InfobaseUpdateInternal.SetShowDetailsToCurrentVersionFlag();
	
	If Common.IsMobileClient() Then
		Items.CommandBarForm.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ClientServerInfobase Then
		AttachIdleHandler("UpdateDeferredUpdateStatus", 60);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UpdatesDetailsSelection(Item, Area, StandardProcessing)
	
	If TypeOf(Area) = Type("SpreadsheetDocumentRange")
		And (StrFind(Area.Text, "http://") = 1 Or StrFind(Area.Text, "https://") = 1) Then
		FileSystemClient.OpenURL(Area.Text);
	EndIf;
	
	InfobaseUpdateClientOverridable.OnClickUpdateDetailsDocumentHyperlink(Area);
	
EndProcedure

&AtClient
Procedure ShowUpdateResultInfoClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowErrorsAndWarnings", True);
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure DeferredDataUpdate(Command)
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.ApplicationUpdateResult");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateDeferredUpdateStatus()
	
	UpdateDeferredUpdateStatusAtServer();
	
EndProcedure

&AtServer
Procedure UpdateDeferredUpdateStatusAtServer()
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdatesEndTime <> Undefined Then
		Items.DeferredUpdate.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsDisabledURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	Notification = New NotifyDescription("ScheduledJobsDisabledURLProcessingCompletion", ThisObject);
	QueryText = NStr("en = 'Restart the app?';");
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo,, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure ScheduledJobsDisabledURLProcessingCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		NewStartupParameter = StrReplace(LaunchParameter, "ScheduledJobsDisabled2", "");
		NewStartupParameter = StrReplace(NewStartupParameter, "StartInfobaseUpdate", "");
		NewStartupParameter = StrConcat(StrSplit(NewStartupParameter, ";", False), ";");
		NewStartupParameter = "/C """ + NewStartupParameter + """";
		Terminate(True, NewStartupParameter);
	EndIf;
	
EndProcedure

#EndRegion
