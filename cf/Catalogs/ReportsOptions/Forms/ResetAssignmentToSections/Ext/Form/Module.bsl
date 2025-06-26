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
	If TypeOf(Parameters.Variants) <> Type("Array") Then
		ErrorText = NStr("en = 'No report options provided.';");
		Return;
	EndIf;

	DefineBehaviorInMobileClient();
	OptionsToAssign.LoadValues(Parameters.Variants);
	Filter();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(ErrorText) Then
		Cancel = True;
		ShowMessageBox(, ErrorText);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ResetCommand(Command)
	SelectedOptionsCount = OptionsToAssign.Count();
	If SelectedOptionsCount = 0 Then
		ShowMessageBox(, NStr("en = 'No report options provided.';"));
		Return;
	EndIf;

	OptionsCount = ResetAssignmentSettingsServer(OptionsToAssign);
	If OptionsCount = 1 And SelectedOptionsCount = 1 Then
		OptionRef1 = OptionsToAssign[0].Value;
		NotificationTitle1 = NStr("en = 'Report option location settings have been reset.';");
		NotificationRef    = GetURL(OptionRef1);
		NotificationText     = String(OptionRef1);
		ShowUserNotification(NotificationTitle1, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("en = 'Location settings for %1 report options
							   |have been reset.';");
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NotificationText, Format(
			OptionsCount, "NZ=0; NG=0"));
		ShowUserNotification(,, NotificationText);
	EndIf;
	ReportsOptionsClient.UpdateOpenForms();
	Close();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServerNoContext
Function ResetAssignmentSettingsServer(Val OptionsToAssign)
	OptionsCount = 0;
	BeginTransaction();
	Try
		Block = New DataLock;
		For Each ListItem In OptionsToAssign Do
			LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", ListItem.Value);
		EndDo;
		Block.Lock();

		For Each ListItem In OptionsToAssign Do
			OptionObject = ListItem.Value.GetObject(); // CatalogObject.ReportsOptions
			If ReportsOptions.ResetReportOptionSettings(OptionObject) Then
				OptionObject.Write();
				OptionsCount = OptionsCount + 1;
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	Return OptionsCount;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure DefineBehaviorInMobileClient()
	If Not Common.IsMobileClient() Then
		Return;
	EndIf;

	CommandBarLocation = FormCommandBarLabelLocation.Auto;
EndProcedure

&AtServer
Procedure Filter()

	CountBeforeFilter = OptionsToAssign.Count();

	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsToAssign.UnloadValues());
	Query.SetParameter("InternalType", Enums.ReportsTypes.BuiltIn);
	Query.SetParameter("ExtensionType", Enums.ReportsTypes.Extension);
	Query.Text =
	"SELECT DISTINCT
	|	ReportOptionsPlacement.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportOptionsPlacement
	|WHERE
	|	ReportOptionsPlacement.Ref IN(&OptionsArray)
	|	AND ReportOptionsPlacement.Custom = FALSE
	|	AND ReportOptionsPlacement.ReportType IN (&InternalType, &ExtensionType)
	|	AND ReportOptionsPlacement.DeletionMark = FALSE";

	OptionsArray = Query.Execute().Unload().UnloadColumn("Ref");
	OptionsToAssign.LoadValues(OptionsArray);

	CountAfterFilter = OptionsToAssign.Count();
	If CountBeforeFilter <> CountAfterFilter Then
		If CountAfterFilter = 0 Then
			ErrorText = NStr("en = 'You do not have to reset location settings for selected report options due to one or more of the following reasons:
							   |- Selected report options are custom options.
							   |- Selected report options are marked for deletion.
							   |- Selected report options are additional or external reports.';");
			Return;
		EndIf;
	EndIf;

EndProcedure

#EndRegion