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

#Region Internal

// The procedure updates the register data during the full update of auxiliary data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters()
	   And CanExecuteBackgroundJobs() Then
		
		UpdateRegisterDataInBackground(HasChanges);
	Else
		UpdateRegisterDataNotInBackground(HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function CanExecuteBackgroundJobs()
	
	If CurrentRunMode() = Undefined
	   And Common.FileInfobase() Then
		
		Session = GetCurrentInfoBaseSession();
		If Session.ApplicationName = "COMConnection"
		 Or Session.ApplicationName = "BackgroundJob" Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

Procedure UpdateRegisterDataNotInBackground(HasChanges)
	
	AccessManagementInternal.ActiveAccessRestrictionParameters(Undefined,
		Undefined, True, False, False, HasChanges);
	
EndProcedure

Procedure UpdateRegisterDataInBackground(HasChanges)
	
	CurrentSession = GetCurrentInfoBaseSession();
	JobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Access management: Update access restriction parameters (from session %1 started on %2)';",
			Common.DefaultLanguageCode()),
		Format(CurrentSession.SessionNumber, "NG="),
		Format(CurrentSession.SessionStarted, "DLF=DT"));
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(Undefined);
	OperationParametersList.BackgroundJobDescription = JobDescription;
	OperationParametersList.WithDatabaseExtensions = True;
	OperationParametersList.WaitCompletion = Undefined;
	
	ProcedureName = "InformationRegisters.AccessRestrictionParameters.HandlerForLongTermUpdateOperationInBackground";
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(ProcedureName, Undefined, OperationParametersList);
	ErrorTitle = NStr("en = 'Cannot update access restriction parameters due to:';") + Chars.LF;
	
	If TimeConsumingOperation.Status <> "Completed2" Then
		If TimeConsumingOperation.Status = "Error" Then
			ErrorText = TimeConsumingOperation.DetailErrorDescription;
		ElsIf TimeConsumingOperation.Status = "Canceled" Then
			ErrorText = NStr("en = 'The background job is canceled.';");
		Else
			ErrorText = NStr("en = 'Background job error';");
		EndIf;
		Raise ErrorTitle + ErrorText;
	EndIf;
	
	Result = GetFromTempStorage(TimeConsumingOperation.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		ErrorText = NStr("en = 'Background job did not return the result';");
		Raise ErrorTitle + ErrorText;
	EndIf;
	
	If Result.SessionRestartRequired Then
		AccessManagementInternal.CheckWhetherTheMetadataIsUpToDate();
		StandardSubsystemsServer.InstallRequiresSessionRestart(Result.ErrorText);
		Raise ErrorTitle + Result.ErrorText;
	EndIf;
	
	If ValueIsFilled(Result.ErrorText) Then
		Raise ErrorTitle + Result.ErrorText;
	EndIf;
	
	If Result.HasChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Parameters:
//  Parameters - Undefined
//  ResultAddress - String
//
Procedure HandlerForLongTermUpdateOperationInBackground(Parameters, ResultAddress) Export
	
	Result = New Structure;
	Result.Insert("HasChanges", False);
	Result.Insert("ErrorText", "");
	Result.Insert("SessionRestartRequired", False);
	
	Try
		UpdateRegisterDataNotInBackground(Result.HasChanges);
	Except
		ErrorInfo = ErrorInfo();
		If StandardSubsystemsServer.SessionRestartRequired(Result.ErrorText) Then
			Result.SessionRestartRequired = True;
		EndIf;
		If Not Result.SessionRestartRequired
		 Or Not StandardSubsystemsServer.ThisErrorRequirementRestartSession(ErrorInfo) Then
			Result.ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		EndIf;
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Updates the version of access restriction texts.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if changes are found
//                  True is set, otherwise, it is not changed.
//
Procedure UpdateAccessRestrictionTextsVersion(HasChanges = Undefined) Export
	
	TextsVersion = AccessRestrictionTextsVersion();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion",
			TextsVersion, HasCurrentChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Updates auxiliary register data after changing
// rights based on access values saved to access restriction parameters.
//
Procedure ScheduleAccessUpdateByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		
		LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion");
			
		If LastChanges = Undefined Then
			UpdateRequired = True;
		Else
			UpdateRequired = False;
			For Each ChangesPart In LastChanges Do
				
				If TypeOf(ChangesPart) = Type("FixedStructure")
				   And ChangesPart.Property("HasChanges")
				   And TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
					
					If ChangesPart.HasChanges Then
						UpdateRequired = True;
						Break;
					EndIf;
				Else
					UpdateRequired = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If UpdateRequired Then
			AccessManagementInternal.ScheduleAccessRestrictionParametersUpdate(
				"ScheduleAccessUpdateByConfigurationChanges");
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//  OldCacheStructureVersion - String
//  NewParameters - See AccessManagementInternal.NewStoredWriteParametersStructure
//
Procedure OnChangeCacheStructureVersion(OldCacheStructureVersion, NewParameters) Export
	
	OldVersion = VersionComposition(OldCacheStructureVersion);
	
	If OldVersion.Main < 19 Then
		ScheduleUpdate(NewParameters, True, True, "NewCacheStructure19");
		ScheduleAccessGroupsSetsUpdate(NewParameters, "NewCacheStructure19");
	EndIf;
	
	If OldVersion.Main < 25 Then
		InformationRegisters.UsedAccessKinds.ScheduleUpdateOnChangeAccessKindsUsage();
		ScheduleUpdate(NewParameters, False, True, "NewCacheStructure25");
	EndIf;
	
	If OldVersion.Main < 26 Then
		ScheduleUpdate1(NewParameters, "NewCacheStructure26");
		ScheduleUpdate2(NewParameters, "NewCacheStructure26");
		ScheduleUpdate3(NewParameters, "NewCacheStructure26");
	EndIf;
	
EndProcedure

Function VersionComposition(Version)
	
	VersionParts = StrSplit(StrSplit(Version, "/", True)[0], ".", False);
	
	Result = New Structure;
	Result.Insert("Main", 0);
	Result.Insert("Additional", 0);
	
	If VersionParts.Count() > 0
	   And CommonClientServer.IsNumber(VersionParts[0]) Then
		
		Result.Main = Number(VersionParts[0]);
	EndIf;
	
	If VersionParts.Count() > 1
	   And CommonClientServer.IsNumber(VersionParts[1]) Then
		
		Result.Additional = Number(VersionParts[1]);
	EndIf;
	
	Return Result;
	
EndFunction

// For the UpdateRegisterDataByConfigurationChanges procedure.
Procedure ScheduleUpdate(Parameters, DataAccessKeys, AllowedAccessKeys, LongDesc)
	
	DataRestrictionsDetails = AccessManagementInternal.DataRestrictionsDetails();
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	For Each KeyAndValue In DataRestrictionsDetails Do
		Lists.Add(KeyAndValue.Key);
		If ExternalUsersEnabled Then
			ListsForExternalUsers.Add(KeyAndValue.Key);
		EndIf;
	EndDo;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	PlanningParameters.ListsRestrictionsVersions = Parameters.ListsRestrictionsVersions;
	
	PlanningParameters.DataAccessKeys = DataAccessKeys;
	PlanningParameters.AllowedAccessKeys = AllowedAccessKeys;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// Intended for procedure "UpdateRegisterDataByConfigurationChanges".
Procedure ScheduleAccessGroupsSetsUpdate(Parameters, LongDesc)
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters(False);
	PlanningParameters.ListsRestrictionsVersions = Parameters.ListsRestrictionsVersions;
	
	PlanningParameters.AllowedAccessKeys = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate("Catalog.SetsOfAccessGroups",
		PlanningParameters);
	
EndProcedure

// Intended for procedure "UpdateRegisterDataByConfigurationChanges".
Procedure ScheduleUpdate1(Parameters, LongDesc)
	
	AdditionalContext = Parameters.AdditionalContext;
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	AddLists1(Lists, AdditionalContext.ForUsers);
	If ExternalUsersEnabled Then
		AddLists1(ListsForExternalUsers,
			AdditionalContext.ForExternalUsers);
	EndIf;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	PlanningParameters.ListsRestrictionsVersions = Parameters.ListsRestrictionsVersions;
	
	PlanningParameters.DataAccessKeys = False;
	PlanningParameters.AllowedAccessKeys = True;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// Intended for procedure "ShouldScheduleUpdate1".
Procedure AddLists1(Lists, AdditionalContext)
	
	ListsWithKeysRecordForDependentListsWithoutKeys =
		AdditionalContext.ListsWithKeysRecordForDependentListsWithoutKeys;
	
	For Each KeyAndValue In AdditionalContext.ListsWithDisabledRestriction Do
		If ListsWithKeysRecordForDependentListsWithoutKeys.Get(KeyAndValue.Key) = Undefined Then
			Continue;
		EndIf;
		MetadataObject = Common.MetadataObjectByFullName(KeyAndValue.Key);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Lists.Add(MetadataObject.FullName());
	EndDo;
	
EndProcedure

// Intended for procedure "UpdateRegisterDataByConfigurationChanges".
Procedure ScheduleUpdate2(Parameters, LongDesc)
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	AddLists2(Lists, False);
	If ExternalUsersEnabled Then
		AddLists2(ListsForExternalUsers, True);
	EndIf;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	PlanningParameters.ListsRestrictionsVersions = Parameters.ListsRestrictionsVersions;
	
	PlanningParameters.DataAccessKeys = True;
	PlanningParameters.AllowedAccessKeys = False;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// Intended for procedure "ShouldScheduleUpdate2".
Procedure AddLists2(Lists, ForExternalUsers)
	
	Query = New Query;
	Query.SetParameter("ForExternalUsers", ForExternalUsers);
	Query.Text =
	"SELECT DISTINCT
	|	AccessKeys.List AS List
	|FROM
	|	Catalog.AccessKeys AS AccessKeys
	|WHERE
	|	AccessKeys.FieldsComposition >= 16
	|	AND AccessKeys.ForExternalUsers = &ForExternalUsers";
	
	Lists = Query.Execute().Unload().UnloadColumn("List");
	
EndProcedure

// Intended for procedure "UpdateRegisterDataByConfigurationChanges".
Procedure ScheduleUpdate3(Parameters, LongDesc)
	
	AdditionalContext = Parameters.AdditionalContext;
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	AddLists3(Lists, AdditionalContext.ForUsers);
	If ExternalUsersEnabled Then
		AddLists3(ListsForExternalUsers,
			AdditionalContext.ForExternalUsers);
	EndIf;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	PlanningParameters.ListsRestrictionsVersions = Parameters.ListsRestrictionsVersions;
	
	PlanningParameters.DataAccessKeys = False;
	PlanningParameters.AllowedAccessKeys = True;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// Intended for procedure "ShouldScheduleUpdate3".
Procedure AddLists3(Lists, AdditionalContext)
	
	For Each KeyAndValue In AdditionalContext.ListRestrictionsProperties Do
		If Not KeyAndValue.Value.CalculateUserRights Then
			Continue;
		EndIf;
		MetadataObject = Common.MetadataObjectByFullName(KeyAndValue.Key);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Lists.Add(MetadataObject.FullName());
	EndDo;
	
EndProcedure

// For the UpdateAccessRestrictionTextsVersion procedure.
Function AccessRestrictionTextsVersion(RestrictionsDetails = Undefined) Export
	
	If RestrictionsDetails = Undefined Then
		RestrictionsDetails = AccessManagementInternal.DataRestrictionsDetails();
	EndIf;
	
	AllTexts = New ValueList;
	For Each RestrictionDetails In RestrictionsDetails Do
		Restriction = RestrictionDetails.Value;
		Texts = New Array;
		Texts.Add(RestrictionDetails.Key);
		AddProperty(Texts, Restriction, "Text");
		AddProperty(Texts, Restriction, "TextForExternalUsers1");
		AddProperty(Texts, Restriction, "ByOwnerWithoutSavingAccessKeys");
		AddProperty(Texts, Restriction, "ByOwnerWithoutSavingAccessKeysForExternalUsers");
		AddProperty(Texts, Restriction, "TextInManagerModule");
		AllTexts.Add(StrConcat(Texts, Chars.LF), RestrictionDetails.Key);
	EndDo;
	AllTexts.SortByPresentation();
	AllTexts.Insert(0, AccessManagementInternal.CacheStructureVersion());
	WholeText = StrConcat(AllTexts.UnloadValues(), Chars.LF +  Chars.LF);
	
	Hashing = New DataHashing(HashFunction.SHA256);
	Hashing.Append(WholeText);
	
	Return Base64String(Hashing.HashSum);
	
EndFunction

// For the AccessRestrictionTextsVersion function.
Procedure AddProperty(Texts, Restriction, PropertyName)
	
	
	Value = Restriction[PropertyName];
	If TypeOf(Value) = Type("String") Then
		Rows = StrSplit(Value, Chars.LF);
		Text = ?(Rows.Count() > 1, Chars.LF + "		", "")
			+ StrConcat(Rows, Chars.LF + "		");
	ElsIf Value = Undefined Then
		Text = "Undefined"; // ACC:1297 - A value name (must not be wrapped in "NStr").
	ElsIf Value = True Then
		Text = "True"; // ACC:1297 - A value name (must not be wrapped in "NStr").
	ElsIf Value = False Then
		Text = "False"; // ACC:1297 - A value name (must not be wrapped in "NStr").
	Else
		Text = XMLString(Value);
	EndIf;
	
	Texts.Add("	" + PropertyName + ": " + Text);
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// Data registration is not required.
	Return;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	EnableUniversalRecordLevelAccessRestriction();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

Procedure EnableUniversalRecordLevelAccessRestriction() Export
	
	If Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	Constants.LimitAccessAtRecordLevelUniversally.Set(True);
	
EndProcedure

#EndRegion

#EndIf
