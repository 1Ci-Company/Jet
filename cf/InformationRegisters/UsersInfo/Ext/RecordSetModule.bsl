///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var OldRecords; // Filled "BeforeWrite" to use "OnWrite".

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// ACC:75-off - "DataExchange.Import" check must follow the change records in the Event log.
	PrepareChangesForLogging(ThisObject, Replacing, OldRecords);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// ACC:75-off - "DataExchange.Import" check must follow the change records in the Event log.
	DoLogChanges(ThisObject, Replacing, OldRecords);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure PrepareChangesForLogging(Var_ThisObject, Replacing, OldRecords)
	
	RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
	
	If Replacing Then
		For Each FilterElement In Filter Do
			If FilterElement.Use Then
				RecordSet.Filter[FilterElement.Name].Set(FilterElement.Value);
			EndIf;
		EndDo;
		RecordSet.Read();
	EndIf;
	
	OldRecords = RecordSet.Unload();
	
EndProcedure

Procedure DoLogChanges(RecordSet, Replacing, OldRecords)
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	FieldList = "User,
		|UserMustChangePasswordOnAuthorization,
		|UnlimitedValidityPeriod,
		|ValidityPeriod,
		|InactivityPeriodBeforeDenyingAuthorization";
	
	NewRecords = Unload();
	Table = NewRecords.Copy(, FieldList);
	Table.Columns.Add("LineChangeType", New TypeDescription("Number"));
	Table.FillValues(1, "LineChangeType");
	
	For Each NewRecord In Table Do
		If OldRecords.Find(NewRecord.User, "User") = Undefined Then
			OldRecords.Add().User = NewRecord.User;
		EndIf;
	EndDo;
	
	For Each OldRecord In OldRecords Do
		NewRow = Table.Add();
		FillPropertyValues(NewRow, OldRecord);
		NewRow.LineChangeType = -1;
	EndDo;
	
	If RecordSet.AdditionalProperties.Property("UserProperties")
	   And TypeOf(RecordSet.AdditionalProperties.UserProperties) = Type("Structure") Then
		
		UserProperties = RecordSet.AdditionalProperties.UserProperties;
	Else
		UserProperties = New Structure;
	EndIf;
	
	Table.GroupBy(FieldList, "LineChangeType");
	UnchangedRows = Table.FindRows(New Structure("LineChangeType", 0));
	If Table.Count() = UnchangedRows.Count()
	   And Not UserProperties.Property("ShouldLogChanges") Then
		Return;
	EndIf;
	
	If UserProperties.Property("IBUserID")
	   And TypeOf(UserProperties.IBUserID) = Type("UUID")
	   And RecordSet.Count() = 1 Then
		
		UsersProperties = New ValueTable;
		UsersProperties.Columns.Add("User");
		UsersProperties.Columns.Add("IBUserID");
		UsersProperties.Columns.Add("DeletionMark");
		UsersProperties.Columns.Add("Invalid");
		UsersProperties.Columns.Add("Department");
		UsersProperties.Columns.Add("Individual");
		NewRow = UsersProperties.Add();
		FillPropertyValues(NewRow, UserProperties);
		NewRow.User = RecordSet[0].User;
		PreviousValues1 = UserProperties.PreviousValues1;
	Else
		Query = New Query;
		Query.SetParameter("UsersList", Table.UnloadColumn("User"));
		Query.Text =
		"SELECT
		|	Users.Ref AS User,
		|	Users.IBUserID AS IBUserID,
		|	Users.DeletionMark AS DeletionMark,
		|	Users.Invalid AS Invalid,
		|	Users.Department AS Department,
		|	Users.Individual AS Individual
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.Ref IN(&UsersList)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.IBUserID,
		|	ExternalUsers.DeletionMark,
		|	ExternalUsers.Invalid,
		|	UNDEFINED,
		|	UNDEFINED
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&UsersList)";
		
		UsersProperties = Query.Execute().Unload();
		UsersProperties.Indexes.Add("User");
		PreviousValues1 = Undefined;
	EndIf;
	
	ProcessedUsers = New Map;
	IBUserAdditionalProperties = "UserMustChangePasswordOnAuthorization,
		|UnlimitedValidityPeriod, ValidityPeriod, InactivityPeriodBeforeDenyingAuthorization";
	
	For Each String In Table Do
		If Not ValueIsFilled(String.User)
		 Or ProcessedUsers.Get(String.User) <> Undefined Then
			Continue;
		EndIf;
		ProcessedUsers.Insert(String.User, True);
		
		Data = New Structure;
		Data.Insert("DataStructureVersion", 2);
		Data.Insert("Ref", SerializedRef(String.User));
		Data.Insert("RefType", String.User.Metadata().FullName());
		Data.Insert("LinkID", Lower(String.User.UUID()));
		Data.Insert("IBUserID");
		Data.Insert("Name");
		Data.Insert("UserMustChangePasswordOnAuthorization", False);
		Data.Insert("UnlimitedValidityPeriod", False);
		Data.Insert("ValidityPeriod", '00010101');
		Data.Insert("InactivityPeriodBeforeDenyingAuthorization", 0);
		Data.Insert("DeletionMark");
		Data.Insert("Invalid");
		Data.Insert("Department");
		Data.Insert("DepartmentPresentation");
		Data.Insert("Individual");
		Data.Insert("IndividualPresentation");
		Data.Insert("OldPropertyValues", New Structure);
		
		CurrentValues = UsersProperties.Find(String.User, "User");
		If CurrentValues <> Undefined Then
			Data.IBUserID = Lower(CurrentValues.IBUserID);
			Data.DeletionMark = CurrentValues.DeletionMark;
			Data.Invalid  = CurrentValues.Invalid;
			Data.Department   = SerializedRef(CurrentValues.Department);
			Data.Individual  = SerializedRef(CurrentValues.Individual);
			Data.DepartmentPresentation  = RepresentationOfTheReference(CurrentValues.Department);
			Data.IndividualPresentation = RepresentationOfTheReference(CurrentValues.Individual);
			IBUser = InfoBaseUsers.FindByUUID(
				CurrentValues.IBUserID);
			If IBUser <> Undefined Then
				Data.Name = IBUser.Name;
			EndIf;
		EndIf;
		If PreviousValues1 <> Undefined Then
			If CurrentValues.IBUserID <> PreviousValues1.IBUserID Then
				Data.OldPropertyValues.Insert("IBUserID",
					Lower(PreviousValues1.IBUserID));
			EndIf;
			If CurrentValues.DeletionMark <> PreviousValues1.DeletionMark Then
				Data.OldPropertyValues.Insert("DeletionMark", PreviousValues1.DeletionMark);
			EndIf;
			If CurrentValues.Invalid <> PreviousValues1.Invalid Then
				Data.OldPropertyValues.Insert("Invalid", PreviousValues1.Invalid);
			EndIf;
			If CurrentValues.Department <> PreviousValues1.Department Then
				Data.OldPropertyValues.Insert("Department",
					SerializedRef(PreviousValues1.Department));
				Data.OldPropertyValues.Insert("DepartmentPresentation",
					RepresentationOfTheReference(PreviousValues1.Department));
			EndIf;
			If CurrentValues.Individual <> PreviousValues1.Individual Then
				Data.OldPropertyValues.Insert("Individual",
					SerializedRef(PreviousValues1.Individual));
				Data.OldPropertyValues.Insert("IndividualPresentation",
					RepresentationOfTheReference(PreviousValues1.Individual));
			EndIf;
		EndIf;
		
		If String.LineChangeType >= 0 Then
			NewRecord = NewRecords.Find(String.User, "User");
			FillPropertyValues(Data, NewRecord, IBUserAdditionalProperties);
		EndIf;
		If String.LineChangeType <> 0 Then
			OldRecord = OldRecords.Find(String.User, "User");
			PropertyStructure = New Structure(IBUserAdditionalProperties);
			For Each KeyAndValue In PropertyStructure Do
				If Data[KeyAndValue.Key] <> OldRecord[KeyAndValue.Key] Then
					Data.OldPropertyValues.Insert(KeyAndValue.Key, OldRecord[KeyAndValue.Key]);
				EndIf;
			EndDo;
		EndIf;
		
		WriteLogEvent(
			UsersInternal.EventNameChangeAdditionalForLogging(),
			EventLogLevel.Information,
			Metadata.InformationRegisters.UsersInfo,
			Common.ValueToXMLString(Data),
			,
			EventLogEntryTransactionMode.Transactional);
	EndDo;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

// See UsersInternal.SerializedRef
Function SerializedRef(Ref)
	Return UsersInternal.SerializedRef(Ref);
EndFunction

// See UsersInternal.RepresentationOfTheReference
Function RepresentationOfTheReference(Ref)
	Return UsersInternal.RepresentationOfTheReference(Ref);
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf