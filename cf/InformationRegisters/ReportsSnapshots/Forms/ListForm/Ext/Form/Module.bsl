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
	
	If Not Parameters.Property("User", User) Then
		Common.MessageToUser(NStr(
			"en = 'The report snapshot list is available only from a report form or report panel.';"), , , , Cancel);
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	Parameters.Property("CatalogNameReportOptions", CatalogNameReportOptions);
	
	FillReportsSnapshots();
	
#If Not MobileStandaloneServer Then
	If Users.IsFullUser() Then
		Items.ShowAllReportsSnapshots.Visible = True;
	EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

#If MobileClient Then
	CommandBarLocation = FormCommandBarLabelLocation.None;
	Items.MobileClientButtonGroup.Visible = True;
	Items.ReportsSnapshots.CommandBarLocation = FormItemCommandBarLabelLocation.None;
	
	If MainServerAvailable() = False Then
		Items.GroupSaveReportsSnapshots.Enabled = False;
		Items.ReportsSnapshotsSaveReportSnapshot.Enabled = False;
	EndIf;
#EndIf
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
 
&AtClient
Procedure ShowAllReportsSnapshotsOnChange(Item)
	
	FillReportsSnapshots();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectAllCommand(Command)
	
	For Each RowReport In ReportsSnapshots Do
		RowReport.Check = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAllIetmsCommand(Command)
	
	For Each RowReport In ReportsSnapshots Do
		RowReport.Check = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateReportsSnapshots(Command)
	
	RowsIDs = New Array;
	For Each RowReport In ReportsSnapshots Do
		If RowReport.Check Then
			RowsIDs.Add(RowReport.GetID());
		EndIf;
	EndDo;
	
	If RowsIDs.Count() = 0 Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("AfterReportsSnapshotsUpdated", ThisObject);
	TimeConsumingOperation = Undefined;
	IdleParameters = Undefined;
	
#If MobileClient Then
	Execute("TimeConsumingOperation = UpdateReportsSnapshotsAtServer(RowsIDs)");
	Execute("IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject)");
	Execute("TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters)");
#Else
	TimeConsumingOperation = UpdateReportsSnapshotsAtServer(RowsIDs);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
#EndIf
	
EndProcedure


#If Not MobileStandaloneServer Then

&AtServer
Function UpdateReportsSnapshotsAtServer(RowsIDs)
	
	FillParameters = New Structure;
	FillParameters.Insert("User", User);
	FillParameters.Insert("CatalogNameReportOptions", CatalogNameReportOptions);
	
	UserReportsSnapshots = ReportsSnapshots.Unload(, "User, Report, Variant, UserSettingsHash");
	UserReportsSnapshots.Clear();
	For Each RowID In RowsIDs Do
		RowReport = ReportsSnapshots.FindByID(RowID);
		NewRow = UserReportsSnapshots.Add();
		FillPropertyValues(NewRow, RowReport);
	EndDo;
	FillParameters.Insert("ReportsSnapshots", UserReportsSnapshots);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update user report snapshots';");
	ExecutionParameters.RefinementErrors = NStr("en = 'Cannot update the report snapshots due to:';");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ReportsSnapshots.UpdateUserReportsSnapshots",
		FillParameters, ExecutionParameters);
	
	Return ExecutionResult;
	
EndFunction

#EndIf

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterReportsSnapshotsUpdated(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
#If MobileClient Then
		Execute("StandardSubsystemsClient.OutputErrorInfo(Result.ErrorInfo)");
#Else
		StandardSubsystemsClient.OutputErrorInfo(Result.ErrorInfo);
#EndIf
		Return;
	EndIf;

	NotificationText1 = NStr("en = 'Report snapshots are updated.';");
	ShowUserNotification(NStr("en = 'Snapshots updated';"), , NotificationText1);
	
	FillReportsSnapshots();
	
EndProcedure

&AtClient
Procedure DeleteReportsSnapshots(Command)
	
	RowsIDs = New Array;
	For Each RowReport In ReportsSnapshots Do
		If RowReport.Check Then
			RowsIDs.Add(RowReport.GetID());
		EndIf;
	EndDo;

	If RowsIDs.Count() > 0 Then
		DeleteReportsSnapshotsAtServer(RowsIDs);
	EndIf;

EndProcedure

&AtServer
Procedure DeleteReportsSnapshotsAtServer(RowsIDs)
	
	For Each RowID In RowsIDs Do
		RowReport = ReportsSnapshots.FindByID(RowID);
		RecordManager = InformationRegisters.ReportsSnapshots.CreateRecordManager();
		FillPropertyValues(RecordManager, RowReport);
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
		ReportsSnapshots.Delete(RowReport);
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenReportSnapshot(Command)
	
	RecordStructure = New Structure("User,Report,Variant,UserSettingsHash,UpdateDate");
	
	RowReport = Items.ReportsSnapshots.CurrentData;
	FillPropertyValues(RecordStructure, RowReport);
	
	OpenForm("InformationRegister.ReportsSnapshots.RecordForm",
		New Structure("RecordStructure", RecordStructure), ThisObject, UUID);

EndProcedure

&AtClient
Procedure UpdateReportSnapshot(Command)
	
	RowsIDs = New Array;
	RowsIDs.Add(Items.ReportsSnapshots.CurrentRow);
	
	NotifyDescription = New NotifyDescription("AfterReportsSnapshotsUpdated", ThisObject);
	TimeConsumingOperation = Undefined;
	IdleParameters = Undefined;
	
#If MobileClient Then
	Execute("TimeConsumingOperation = UpdateReportsSnapshotsAtServer(RowsIDs)");
	Execute("IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject)");
	Execute("TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters)");
#Else
	TimeConsumingOperation = UpdateReportsSnapshotsAtServer(RowsIDs);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
#EndIf
	
EndProcedure

#EndRegion

#Region ReportsSnapshotsFormTableEventHandlers

&AtClient
Procedure ReportsSnapshotsListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	RowReport = ReportsSnapshots.FindByID(RowSelected);
	RowReport.Check = Not RowReport.Check;
	
EndProcedure

&AtClient
Procedure ReportsSnapshotsBeforeDeleteRow(Item, Cancel)
	
	RowsIDs = New Array;
	RowsIDs.Add(Items.ReportsSnapshots.CurrentRow);
	
	DeleteReportsSnapshotsAtServer(RowsIDs);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportsSnapshotsUser.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ShowAllReportsSnapshots");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Visible", False);

EndProcedure

&AtServer
Procedure FillReportsSnapshots()

	ReportsSnapshots.Load(InformationRegisters.ReportsSnapshots.UserReportsSnapshots(
		?(ShowAllReportsSnapshots, Undefined, User), CatalogNameReportOptions));

EndProcedure

#EndRegion