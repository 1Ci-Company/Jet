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

	If Not HasUserSettings(Parameters.Variants) Then
		ErrorText = NStr("en = 'Custom settings for the %1selected report options have not been defined or have been reset.';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, 
			Format(Parameters.Variants.Count(), "NZ=0; NG=0"));
		Return;
	EndIf;

	DefineBehaviorInMobileClient();
	OptionsToAssign.LoadValues(Parameters.Variants);
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
	OptionsCount = OptionsToAssign.Count();
	If OptionsCount = 0 Then
		ShowMessageBox(, NStr("en = 'No report options provided.';"));
		Return;
	EndIf;

	ResetUserSettingsServer(OptionsToAssign);
	If OptionsCount = 1 Then
		OptionRef1 = OptionsToAssign[0].Value;
		NotificationTitle1 = NStr("en = 'Custom settings for the report option have been reset.';");
		NotificationRef    = GetURL(OptionRef1);
		NotificationText     = String(OptionRef1);
		ShowUserNotification(NotificationTitle1, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("en = 'Custom settings for %1 report options
							   |have been reset.';");
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NotificationText, 
			Format(OptionsCount, "NZ=0; NG=0"));
		ShowUserNotification(,, NotificationText);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServerNoContext
Procedure ResetUserSettingsServer(Val OptionsToAssign)
	BeginTransaction();
	Try
		Block = New DataLock;
		For Each ListItem In OptionsToAssign Do
			LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", ListItem.Value);
		EndDo;
		Block.Lock();

		InformationRegisters.ReportOptionsSettings.ResetSettings(OptionsToAssign.UnloadValues());

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
	If Not Common.IsMobileClient() Then
		Return;
	EndIf;

	CommandBarLocation = FormCommandBarLabelLocation.Auto;
EndProcedure

&AtServer
Function HasUserSettings(OptionsArray)
	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsArray);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS HasUserSettings
	|FROM
	|	InformationRegister.ReportOptionsSettings AS Settings
	|WHERE
	|	Settings.Variant IN(&OptionsArray)";

	HasUserSettings = Not Query.Execute().IsEmpty();
	Return HasUserSettings;
EndFunction

#EndRegion