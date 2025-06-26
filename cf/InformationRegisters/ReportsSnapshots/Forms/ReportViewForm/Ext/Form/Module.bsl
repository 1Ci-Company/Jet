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
	
	InformationSecurityUserSUID = InfoBaseUsers.CurrentUser().UUID;
	User = Catalogs.Users.FindByAttribute("IBUserID",
		New UUID(InformationSecurityUserSUID));
	
	CatalogNameReportOptions = "";
	Parameters.Property("CatalogNameReportOptions", CatalogNameReportOptions);
		
	ReportVariant = Undefined;
	If Parameters.Property("ReportVariant", ReportVariant) Then
		For Each SubordinateItem In Items.ButtonGroupViewReportsNested.ChildItems Do
			If SubordinateItem.Name <> "GroupButtonsDeleteReportSnapshot" Then
				SubordinateItem.Enabled = False;
			EndIf;
		EndDo;
	EndIf;
		
	UpdateReportsSnapshots(CatalogNameReportOptions, ReportVariant);

	If ReportsSnapshots.Count() > 0 Then
		CurrentReportSnapshot = 1;
		ReadReportSnapshot();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ReportsSnapshots(Command)
	
	OpenForm("InformationRegister.ReportsSnapshots.ListForm",
				New Structure("User", User));
	
EndProcedure

&AtClient
Procedure GoToEnd(Command)
	
	CurrentReportSnapshot = ReportsSnapshots.Count();
	ReadReportSnapshot();
	
EndProcedure

&AtClient
Procedure GoToBegin(Command)

	If ReportsSnapshots.Count() > 0 Then
		CurrentReportSnapshot = 1;
		ReadReportSnapshot();
	EndIf;

EndProcedure

&AtClient
Procedure GoBack(Command)
	
	If CurrentReportSnapshot > 1 Then
		CurrentReportSnapshot = CurrentReportSnapshot - 1;
		ReadReportSnapshot();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoForward(Command)
	
	If CurrentReportSnapshot < ReportsSnapshots.Count() Then
		CurrentReportSnapshot = CurrentReportSnapshot + 1;
		ReadReportSnapshot();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteReportSnapshot(Command)
	
	If CurrentReportSnapshot <> 0 Then
		DeleteReportSnapshotAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateReportsSnapshots(CatalogNameReportOptions, ReportVariant)
	
	UserReportsSnapshots = InformationRegisters.ReportsSnapshots.UserReportsSnapshots(User, CatalogNameReportOptions);
	UserReportsSnapshots.FillValues(User, "User");
	
	If ValueIsFilled(ReportVariant) Then
		Counter = 0;
		While Counter < UserReportsSnapshots.Count() Do
			If UserReportsSnapshots[Counter].Variant = ReportVariant Then
				Counter = Counter + 1;
			Else
				UserReportsSnapshots.Delete(Counter);
			EndIf;
		EndDo;
	EndIf;	
	
	ReportsSnapshots.Load(UserReportsSnapshots);
	
EndProcedure

&AtServer
Procedure ReadReportSnapshot()
	
	RowReport = ReportsSnapshots[CurrentReportSnapshot-1];
	
	ReportSpreadsheetDocument.Clear();
	UpdateDate = Undefined;
	
	RecordManager = InformationRegisters.ReportsSnapshots.CreateRecordManager();
	FillPropertyValues(RecordManager, RowReport);
	RecordManager.Read();
	If RecordManager.Selected() Then
		If RecordManager.ReportUpdateError Then
			Common.MessageToUser(NStr(
				"en = 'An error occurred when saving the report snapshot: save the snapshot again.';"));
		Else
			ReportResult = RecordManager.ReportResult.Get();
			If TypeOf(ReportResult) = Type("SpreadsheetDocument") Then
				ReportSpreadsheetDocument.Put(ReportResult);
				RecordManager.LastViewedDate = CurrentSessionDate();
				RecordManager.Write();
			Else
				Common.MessageToUser(NStr(
					"en = 'An error occurred when reading the report snapshot: the data is incorrect.';"));
			EndIf;
		EndIf;
		UpdateDate = RecordManager.UpdateDate;
	Else
		Common.MessageToUser(NStr("en = 'An error occurred when reading the report snapshot: the report is deleted.';"));
	EndIf;
	
	Title = NStr("en = 'Last updated';") + ": " + UpdateDate;
	
EndProcedure

&AtServer
Procedure DeleteReportSnapshotAtServer()
	
	RowReport = ReportsSnapshots[CurrentReportSnapshot-1];
	
	ReportSpreadsheetDocument.Clear();
	
	RecordManager = InformationRegisters.ReportsSnapshots.CreateRecordManager();
	FillPropertyValues(RecordManager, RowReport);
	RecordManager.Read();
	If RecordManager.Selected() Then
		RecordManager.Delete();
	EndIf;
	
	ReportsSnapshots.Delete(RowReport);
	
	If CurrentReportSnapshot > ReportsSnapshots.Count() Then
		CurrentReportSnapshot = ReportsSnapshots.Count();
	EndIf;
	
	If CurrentReportSnapshot > 0 Then
		ReadReportSnapshot();
	EndIf;
	
EndProcedure

#EndRegion