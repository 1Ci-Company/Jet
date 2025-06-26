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

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Importance");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Comment");
	Result.Add("EmailRecipients.Presentation");
	Result.Add("EmailRecipients.Contact");
	Result.Add("CCRecipients.Presentation");
	Result.Add("CCRecipients.Contact");
	Result.Add("ReplyRecipients.Presentation");
	Result.Add("ReplyRecipients.Contact");
	Result.Add("BccRecipients.Presentation");
	Result.Add("BccRecipients.Contact");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.Interactions

// Gets email addressees.
//
// Parameters:
//  Ref  - DocumentRef.OutgoingEmail - a document whose subscriber is to be received.
//
// Returns:
//   ValueTable   - Table containing the columns Contact, Presentation, and Address.
//
Function GetContacts(Ref) Export
	
	QueryText = 
	"SELECT
	|	EmailOutgoingEmailRecipients.Address,
	|	EmailOutgoingEmailRecipients.Presentation,
	|	EmailOutgoingEmailRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.EmailRecipients AS EmailOutgoingEmailRecipients
	|WHERE
	|	EmailOutgoingEmailRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EMailOutgoingCopyRecipients.Address,
	|	EMailOutgoingCopyRecipients.Presentation,
	|	EMailOutgoingCopyRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.CCRecipients AS EMailOutgoingCopyRecipients
	|WHERE
	|	EMailOutgoingCopyRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EmailOutgoingReplyRecipients.Address,
	|	EmailOutgoingReplyRecipients.Presentation,
	|	EmailOutgoingReplyRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.ReplyRecipients AS EmailOutgoingReplyRecipients
	|WHERE
	|	EmailOutgoingReplyRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EmailOutgoingRecipientsOfHiddenCopies.Address,
	|	EmailOutgoingRecipientsOfHiddenCopies.Presentation,
	|	EmailOutgoingRecipientsOfHiddenCopies.Contact
	|FROM
	|	Document.OutgoingEmail.BccRecipients AS EmailOutgoingRecipientsOfHiddenCopies
	|WHERE
	|	EmailOutgoingRecipientsOfHiddenCopies.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	TableOfContacts = Query.Execute().Unload();
	
	Return Interactions.ConvertContactsTableToArray(TableOfContacts);
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmployeeResponsible, Disabled AS FALSE)
	|	OR ValueAllowed(Author, Disabled AS FALSE)
	|	OR CASE WHEN Account.AccountOwner = VALUE(Catalog.Users.EmptyRef) THEN
	|			ValueAllowed(Account, Disabled AS FALSE)
	|		ELSE
	|			IsAuthorizedUser(Account.AccountOwner)
	|		END";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defines the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	Documents.Meeting.AddGenerateCommand(GenerationCommands);
	Documents.PlannedInteraction.AddGenerateCommand(GenerationCommands);
	Documents.SMSMessage.AddGenerateCommand(GenerationCommands);
	Documents.PhoneCall.AddGenerateCommand(GenerationCommands);
	
EndProcedure

// Intended for use by the AddGenerationCommands procedure in other object manager modules.
// Adds this object to the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	Command = GenerateFrom.AddGenerationCommand(GenerationCommands, Metadata.Documents.OutgoingEmail);
	If Command <> Undefined Then
		Command.Importance = "SeeAlso";
	EndIf;
	
	Return Command;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.OutgoingEmail.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

#Region UpdateHandlers

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText ="
	|SELECT
	|	OutgoingEmail.Ref AS Ref
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.TextType = VALUE(Enum.EmailTextTypes.HTML)
	|	AND CASE
	|			WHEN (CAST(OutgoingEmail.Text AS STRING(1))) = """"
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|	AND CASE
	|			WHEN (CAST(OutgoingEmail.HTMLText AS STRING(1))) <> """"
	|				THEN TRUE
	|			ELSE FALSE
	|		END";
	
	Query = New Query(QueryText);
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

// A handler of the update to version 3.1.5.147:
// - — fills in the Text attribute for the HTML emails where it is not filled in.
//
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	FullObjectName = "Document.OutgoingEmail";
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DocumentTable.Ref     AS Ref
	|FROM
	|	&TTDocumentsToProcess AS ReferencesToProcess
	|		LEFT JOIN Document.OutgoingEmail AS DocumentTable
	|		ON (DocumentTable.Ref = ReferencesToProcess.Ref)";
	
	TempTablesManager = New TempTablesManager;
	Result = InfobaseUpdate.CreateTemporaryTableOfRefsToProcess(Parameters.Queue, FullObjectName, TempTablesManager);
	If Not Result.HasDataToProcess Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	If Not Result.HasRecordsInTemporaryTable Then
		Parameters.ProcessingCompleted = False;
		Return;
	EndIf; 
	
	Query.Text = StrReplace(Query.Text, "&TTDocumentsToProcess", Result.TempTableName);
	Query.TempTablesManager = TempTablesManager;
	
	ObjectsForProcessing = Query.Execute().Select();
	
	While ObjectsForProcessing.Next() Do
		RepresentationOfTheReference = String(ObjectsForProcessing.Ref);
		BeginTransaction();
		
		Try
			
			// Setting a managed lock to post object responsible reading.
			Block = New DataLock;
			
			LockItem = Block.Add(FullObjectName);
			LockItem.SetValue("Ref", ObjectsForProcessing.Ref);
			
			Block.Lock();
			
			Object = ObjectsForProcessing.Ref.GetObject();
			
			If Object = Undefined Then
				InfobaseUpdate.MarkProcessingCompletion(ObjectsForProcessing.Ref);
			Else
				
				If Object.TextType = Enums.EmailTextTypes.HTML
					And Not IsBlankString(Object.HTMLText)
					And IsBlankString(Object.Text) Then
					
					Object.Text = Interactions.GetPlainTextFromHTML(Object.HTMLText);
					
				EndIf;
			
				InfobaseUpdate.WriteData(Object);
				
			EndIf;
			
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
			
		Except
			RollbackTransaction();
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				ObjectsForProcessing.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
		
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t update (skipped) outgoing email data: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			Metadata.Documents.OutgoingEmail,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Another batch of outgoing emails is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullObjectName);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
