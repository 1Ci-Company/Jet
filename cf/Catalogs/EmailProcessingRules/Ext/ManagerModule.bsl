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
	
	Result = New Array;
	Result.Add("Code");
	Result.Add("Description");
	Result.Add("SettingsComposer");
	Result.Add("PutInFolder");
	Result.Add("AddlOrderingAttribute");
	Result.Add("FilterPresentation");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Owner)
	|	OR ValueAllowed(Owner.AccountOwner, EmptyRef AS FALSE)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Internal

// Applies email processing rules.
//
// Parameters:
//  ExportingParameters  - Structure:
//    * ForEmailsInFolder     - CatalogRef.EmailMessageFolders - mail messages in this folder will be processed.
//    * IncludingSubordinates - Boolean - shows that emails in subordinate folders must be processed.
//    * RulesTable      - ValueTable - a table of rules that must be applied.
//  StorageAddress - String - a message about the rule application result.
//
Procedure ApplyRules(ExportingParameters, StorageAddress) Export
	
	Query = New Query(
		"SELECT
		|	SelectedRules.Rule,
		|	SelectedRules.Apply
		|INTO SelectedRules
		|FROM
		|	&SelectedRules AS SelectedRules
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SelectedRules.Rule AS Ref,
		|	EmailProcessingRules.Owner AS Account,
		|	EmailProcessingRules.Description AS RuleDescription,
		|	EmailProcessingRules.SettingsComposer,
		|	EmailProcessingRules.PutInFolder
		|FROM
		|	SelectedRules AS SelectedRules
		|		INNER JOIN Catalog.EmailProcessingRules AS EmailProcessingRules
		|		ON SelectedRules.Rule = EmailProcessingRules.Ref
		|WHERE
		|	SelectedRules.Apply
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	IncomingEmail.Ref,
		|	InteractionsFolderSubjects.EmailMessageFolder AS Folder
		|FROM
		|	Document.IncomingEmail AS IncomingEmail
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		ON InteractionsFolderSubjects.Interaction = IncomingEmail.Ref
		|WHERE
		|	&ConditionByFolder
		|
		|UNION ALL
		|
		|SELECT
		|	OutgoingEmail.Ref,
		|	InteractionsFolderSubjects.EmailMessageFolder
		|FROM
		|	Document.OutgoingEmail AS OutgoingEmail
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		ON InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref
		|WHERE
		|	&ConditionByFolder");
	
	Query.Text = StrReplace(Query.Text, "&ConditionByFolder", 
		?(ExportingParameters.IncludingSubordinates, 
			"InteractionsFolderSubjects.EmailMessageFolder IN HIERARCHY(&EmailMessageFolder)", 
			"InteractionsFolderSubjects.EmailMessageFolder = &EmailMessageFolder"));
	Query.SetParameter("SelectedRules", ExportingParameters.RulesTable);
	Query.SetParameter("EmailMessageFolder", ExportingParameters.ForEmailsInFolder);
	
	Result = Query.ExecuteBatch();
	If Result[2].IsEmpty() Then
		MessageText = NStr("en = 'The selected folder is empty.';");
		PutToTempStorage(MessageText, StorageAddress);
		Return;
	EndIf;
	
	EmailsTable = Result[2].Unload();
	EmailMessagesToProcess = EmailsTable.UnloadColumn("Ref");
	FoldersToProcess = EmailsTable.UnloadColumn("Folder");
	FoldersToProcess = CommonClientServer.CollapseArray(FoldersToProcess);
	
	MailFolders = New ValueTable;
	MailFolders.Columns.Add("Folder");
	MailFolders.Columns.Add("MailMessage");
	
	SelectedRule = Result[1].Select();
	While SelectedRule.Next() Do
		
		Try
			ProcessingRulesSchema = GetTemplate("EmailProcessingRuleScheme");
			
			TemplateComposer = New DataCompositionTemplateComposer();
			SettingsComposer = New DataCompositionSettingsComposer;
			SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProcessingRulesSchema));
			SettingsComposer.LoadSettings(SelectedRule.SettingsComposer.Get());
			SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
			CommonClientServer.SetFilterItem(SettingsComposer.Settings.Filter,
				"Ref", EmailMessagesToProcess, DataCompositionComparisonType.InList);
			CommonClientServer.SetFilterItem(SettingsComposer.Settings.Filter,
				"Ref.Account", ExportingParameters.Account, DataCompositionComparisonType.Equal);
			
			DataCompositionTemplate = TemplateComposer.Execute(ProcessingRulesSchema,
				SettingsComposer.GetSettings(),,, Type("DataCompositionValueCollectionTemplateGenerator"));
			
			QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
			QueryRule = New Query(QueryText);
			For Each Parameter In DataCompositionTemplate.ParameterValues Do
				QueryRule.Parameters.Insert(Parameter.Name, Parameter.Value);
			EndDo;
			
			// @skip-check query-in-loop - Batch processing of email messages by user accounts.
			EmailResult = QueryRule.Execute();
		
		Except
			
			ErrorMessageTemplate = NStr("en = 'Cannot apply the ""%1"" mailbox rule to the ""%2"" account due to: 
			                                |%3
			                                |Correct the mailbox rule.';", Common.DefaultLanguageCode());
		
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorMessageTemplate, 
				SelectedRule.RuleDescription,
				SelectedRule.Account,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EmailManagement.EventLogEvent(), 
				EventLogLevel.Error, , SelectedRule.Ref, ErrorMessageText);
			Continue;
			
		EndTry;
		
		If Not EmailResult.IsEmpty() Then
			SelectedEmailMessage = EmailResult.Select();
			While SelectedEmailMessage.Next() Do
				
				NewTableRow = MailFolders.Add();
				NewTableRow.Folder = SelectedRule.PutInFolder;
				NewTableRow.MailMessage = SelectedEmailMessage.Ref;
				
				IndexOf = EmailMessagesToProcess.Find(SelectedEmailMessage.Ref);
				If IndexOf <> Undefined Then
					EmailMessagesToProcess.Delete(IndexOf);
				EndIf;
			EndDo;
		EndIf;
		
	EndDo;
	
	Interactions.SetEmailFolders(MailFolders, False);
	CommonClientServer.SupplementArray(FoldersToProcess, MailFolders.UnloadColumn("Folder"), True);
	Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(FoldersToProcess, "Folder"));
	
	If MailFolders.Count() > 0 Then
		MessageText = NStr("en = 'All messages are moved to the folders.';");
	Else
		MessageText =  NStr("en = 'No messages were moved.';");
	EndIf;
	
	PutToTempStorage(MessageText, StorageAddress);
	
EndProcedure

#EndRegion

#EndIf
