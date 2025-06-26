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

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Author)
	|	OR NOT AuthorOnly";
	
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
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("GenerateFrom");
		Command = ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.Catalogs.MessageTemplates);
		If Command <> Undefined Then
			Command.FunctionalOptions = "UseMessageTemplates";
		EndIf;
		Return Command;
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)

	If Parameters.Property("TemplateOwner") And ValueIsFilled(Parameters.TemplateOwner) Then
		Parameters.Insert("TemplateOwner", Parameters.TemplateOwner);
		If Parameters.Property("New") And Parameters.New <> True Then
			Parameters.Insert("Key", MessageTemplatesInternal.TemplateByOwner(Parameters.TemplateOwner));
		EndIf;
		SelectedForm = "Catalog.MessageTemplates.ObjectForm";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion


#Region Internal

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateInternal.ItemsFillingSettings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	MessageTemplatesOverridable.OnSetUpInitialItemsFilling(Settings);
	
	Settings.OnInitialItemFilling = True;
	Settings.KeyAttributeName          = "Ref";
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	MessageTemplatesOverridable.OnInitialItemsFilling(LanguagesCodes, Items, TabularSections);
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
//
// Parameters:
//  Object                  - CatalogObject.ContactInformationKinds - Object to populate.
//  Data                  - ValueTableRow - Object fill data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - Data populated in the OnInitialItemsFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
	MessageTemplatesOverridable.OnInitialItemFilling(Object, Data, AdditionalParameters);

EndProcedure

#EndRegion

#Region Private

#Region InfobaseUpdate

// Registers message templates for processing.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MessageTemplates.Ref AS Ref,
		|	MessageTemplates.InputOnBasisParameterTypeFullName AS InputOnBasisParameterTypeFullName
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.ForInputOnBasis = TRUE";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	TemplatesToProcess1 = QueryResult.Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, TemplatesToProcess1);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		If ModuleContactsManagerInternal.TheTypesOfContactInformationAreUpdated(Parameters.Queue) Then
			Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.MessageTemplates");
			Return;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		If ModuleAdditionalReportsAndDataProcessors.AdditionalReportsAndProcessingAreUpdated(Parameters.Queue) Then
			Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.MessageTemplates");
			Return;
		EndIf;
	EndIf;
	
	Template = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.MessageTemplates");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While Template.Next() Do
		RepresentationOfTheReference = String(Template.Ref);
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.MessageTemplates");
		LockItem.SetValue("Ref", Template.Ref);
		
		BeginTransaction();
		Try
			
			Block.Lock();
			
			TemplateObject1 = Template.Ref.GetObject();
			If TemplateObject1 = Undefined Then // the object may have been deleted in other sessions
				InfobaseUpdate.MarkProcessingCompletion(Template.Ref);
				ObjectsProcessed = ObjectsProcessed + 1;
				CommitTransaction();
				Continue;
			EndIf;
			
			TemplateParameters = MessageTemplatesInternal.TemplateParameters(Template.Ref);
			TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
			
			MetadataObject3 = Common.MetadataObjectByFullName(TemplateParameters.FullAssignmentTypeName);
			
			If MetadataObject3 = Undefined Then
				InfobaseUpdate.MarkProcessingCompletion(Template.Ref);
				ObjectsProcessed = ObjectsProcessed + 1;
				CommitTransaction();
				Continue;
			EndIf;
			
			ParametersToReplace = New Map;
			Prefix = MetadataObject3.Name + ".";
			
			FormulaIDsAreFilledIn = True;
			
			For Each RelatedObjectAttribute In MetadataObject3.Attributes Do
				If RelatedObjectAttribute.Type.Types().Count() = 1 Then
					ObjectType = Metadata.FindByType(RelatedObjectAttribute.Type.Types()[0]);
					If ObjectType <> Undefined And StrStartsWith(ObjectType.FullName(), "Catalog") Then
						MetadataOfAttachedObject = Metadata.FindByFullName(ObjectType.FullName());
						AttachedSubject = Common.ObjectManagerByFullName(ObjectType.FullName()).EmptyRef();
						PreparePropertyAndCIParameters(MetadataOfAttachedObject, AttachedSubject, 
							ParametersToReplace, Prefix + RelatedObjectAttribute.Name + ".", FormulaIDsAreFilledIn);
					EndIf;
				EndIf;
			EndDo;
			
			SubjectOf = Common.ObjectManagerByFullName(TemplateParameters.FullAssignmentTypeName).EmptyRef();
			PreparePropertyAndCIParameters(MetadataObject3, SubjectOf, ParametersToReplace, Prefix, FormulaIDsAreFilledIn);
			
			GenerateParametersToReplace(TemplateInfo.CommonAttributes.Rows, ParametersToReplace, "", FormulaIDsAreFilledIn);
			If FormulaIDsAreFilledIn Then
			
				If TemplateParameters.TemplateType = "MailMessage" Then
					
					For Each AttributeToReplace In ParametersToReplace Do
						TemplateObject1.EmailSubject =
							StrReplace(TemplateObject1.EmailSubject, AttributeToReplace.Key, AttributeToReplace.Value);
						TemplateObject1.HTMLEmailTemplateText =
							StrReplace(TemplateObject1.HTMLEmailTemplateText, AttributeToReplace.Key, AttributeToReplace.Value);
						TemplateObject1.MessageTemplateText =
							StrReplace(TemplateObject1.MessageTemplateText, AttributeToReplace.Key, AttributeToReplace.Value);
					EndDo;
					
				ElsIf TemplateParameters.TemplateType = "SMS" Then
					
					For Each AttributeToReplace In ParametersToReplace Do
						TemplateObject1.SMSTemplateText =
							StrReplace(TemplateObject1.SMSTemplateText, AttributeToReplace.Key, AttributeToReplace.Value);
					EndDo;
					
				Else
					
					For Each AttributeToReplace In ParametersToReplace Do
						TemplateObject1.TemplateTextArbitrary =
							StrReplace(TemplateObject1.TemplateTextArbitrary, AttributeToReplace.Key, AttributeToReplace.Value);
					EndDo;
					
				EndIf;
				
				InfobaseUpdate.WriteObject(TemplateObject1);
				
				ObjectsProcessed = ObjectsProcessed + 1;
			Else
				ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			EndIf;
			
			CommitTransaction();
		Except
			// If message template procession failed, try again.
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				Template.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.MessageTemplates");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some message templates: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.MessageTemplates,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'A batch of message templates is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

Procedure GenerateParametersToReplace(Rows, AttributesToReplace, Prefix, FormulaIDsAreFilledIn)
	
	For Each RelatedObjectAttribute In Rows Do
			
		If RelatedObjectAttribute.Type.Types().Count() = 1 Then
			ObjectType = Metadata.FindByType(RelatedObjectAttribute.Type.Types()[0]);
			If ObjectType <> Undefined And StrStartsWith(ObjectType.FullName(), "Catalog") Then
				MetadataOfAttachedObject = Metadata.FindByFullName(ObjectType.FullName());
				AttachedSubject = Common.ObjectManagerByFullName(ObjectType.FullName()).EmptyRef();
				PreparePropertyAndCIParameters(MetadataOfAttachedObject, AttachedSubject,
					AttributesToReplace, Prefix + RelatedObjectAttribute.Name + ".", FormulaIDsAreFilledIn);
				Continue;
			EndIf;
		EndIf;
		
		If RelatedObjectAttribute.Rows.Count() > 0 Then
			GenerateParametersToReplace(RelatedObjectAttribute.Rows, AttributesToReplace, Prefix, FormulaIDsAreFilledIn);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PreparePropertyAndCIParameters(Val MetadataObject3, Val SubjectOf, Val AttributesToReplace, Prefix, FormulaIDsAreFilledIn)
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds1 = ModuleContactsManager.ObjectContactInformationKinds(SubjectOf);
		If ContactInformationKinds1.Count() > 0 Then
			For Each ContactInformationKind1 In ContactInformationKinds1 Do
				
				If IsBlankString(ContactInformationKind1.IDForFormulas) 
					And Not Common.ObjectAttributeValue(ContactInformationKind1.Ref, "IsFolder")  Then
					FormulaIDsAreFilledIn = False;
					Return;
				EndIf;
				AttributesToReplace.Insert("[" + Prefix + ContactInformationKind1.Description + "]", "[" + Prefix + "~KI." + ContactInformationKind1.IDForFormulas + "]");
				
			EndDo;
		EndIf;
	EndIf;
	
	Properties = New Array;
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		GetAddlInfo = ModulePropertyManager.UseAddlInfo(SubjectOf);
		GetAddlAttributes = ModulePropertyManager.UseAddlAttributes(SubjectOf);
		
		If GetAddlAttributes Or GetAddlInfo Then
			Properties = ModulePropertyManager.ObjectProperties(SubjectOf, GetAddlAttributes, GetAddlInfo);
			For Each Property In Properties Do
				
				If IsBlankString(Property.IDForFormulas) Then
						FormulaIDsAreFilledIn = False;
					Return;
					
				EndIf;
				
				AttributesToReplace.Insert("[" + Prefix + Property.Description + "]", "[" + Prefix + "~Property." + Property.IDForFormulas + "]");
			EndDo;
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#EndRegion


#EndIf
