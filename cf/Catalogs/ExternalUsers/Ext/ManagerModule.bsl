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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	NotAttributesToEdit = New Array;
	NotAttributesToEdit.Add("AuthorizationObject");
	NotAttributesToEdit.Add("SetRolesDirectly");
	NotAttributesToEdit.Add("IBUserID");
	NotAttributesToEdit.Add("ServiceUserID");
	NotAttributesToEdit.Add("DeleteInfobaseUserProperties");
	
	Return NotAttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.TextForExternalUsers1 =
	"AllowRead
	|WHERE
	|	ValueAllowed(Ref)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	IsAuthorizedUser(Ref)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("Invalid") Then
		Parameters.Filter.Insert("Invalid", False);
	EndIf;
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ObjectForm" And Parameters.Property("AuthorizationObject") Then
		
		StandardProcessing = False;
		SelectedForm = "ItemForm";
		
		FoundExternalUser = Undefined;
		CanAddExternalUser = False;
		
		AuthorizationObjectIsInUse = UsersInternal.AuthorizationObjectIsInUse(
			Parameters.AuthorizationObject,
			Undefined,
			FoundExternalUser,
			CanAddExternalUser);
		
		If AuthorizationObjectIsInUse Then
			Parameters.Insert("Key", FoundExternalUser);
			
		ElsIf CanAddExternalUser Then
			
			Parameters.Insert(
				"NewExternalUserAuthorizationObject", Parameters.AuthorizationObject);
		Else
			ErrorAsWarningDetails =
				NStr("en = 'The right to log in is not granted.';");
				
			Raise ErrorAsWarningDetails;
		EndIf;
		
		Parameters.Delete("AuthorizationObject");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ListOfExternalUsers = UsersInternal.ExternalUsersToEnablePasswordRecovery();
	
	If ListOfExternalUsers.Count() > 0 Then
		InfobaseUpdate.MarkForProcessing(Parameters, ListOfExternalUsers);
	EndIf;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	
	ExternalUserLink = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.ExternalUsers");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	ErrorList = New Array;
	
	While ExternalUserLink.Next() Do
		
		AuthorizationObject = Common.ObjectAttributeValue(ExternalUserLink.Ref, "AuthorizationObject");
		Result = UsersInternal.UpdateEmailForPasswordRecovery(ExternalUserLink.Ref, AuthorizationObject);
		
		If Result.Status = "Error" Then
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			ErrorList.Add(Result.ErrorText);
		Else
			ObjectsProcessed = ObjectsProcessed + 1;
			InfobaseUpdate.MarkProcessingCompletion(ExternalUserLink.Ref);
		EndIf;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.ExternalUsers");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some external users: %1
				|%2';"), ObjectsWithIssuesCount, StrConcat(ErrorList, Chars.LF));
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.ExternalUsers,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of external users is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion


#EndIf
