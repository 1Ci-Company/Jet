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
	
	AttributesToEdit = New Array;
	AttributesToEdit.Add("Used");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
// Parameters:
//  Parameters - Structure - Internal parameter to pass to the InfobaseUpdate.MarkForProcessing procedure.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText =
	"SELECT
	|	PrintFormTemplates.Ref
	|FROM
	|	Catalog.PrintFormTemplates AS PrintFormTemplates
	|WHERE
	|	PrintFormTemplates.DataSource <> UNDEFINED";
	
	Query = New Query(QueryText);
	Templates = Query.Execute().Unload().UnloadColumn("Ref");

	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	InfobaseUpdate.MarkForProcessing(Parameters, Templates, AdditionalParameters);
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Parameters:
//  Template - UUID
//  
// Returns:
//  Array of String
// 
Function LayoutLanguages(Template) Export 
	
	QueryText = 
	"SELECT
	|	PrintFormTemplates.Template AS Template,
	|	&DefaultLanguageCode AS LanguageCode
	|FROM
	|	Catalog.PrintFormTemplates AS PrintFormTemplates
	|WHERE
	|	PrintFormTemplates.Id = &Id
	|
	|UNION ALL
	|
	|SELECT
	|	LayoutsPrintedFormsPresentation.Template,
	|	LayoutsPrintedFormsPresentation.LanguageCode
	|FROM
	|	Catalog.PrintFormTemplates.Presentations AS LayoutsPrintedFormsPresentation
	|		LEFT JOIN Catalog.PrintFormTemplates AS PrintFormTemplates
	|		ON LayoutsPrintedFormsPresentation.Ref = PrintFormTemplates.Ref
	|WHERE
	|	PrintFormTemplates.Id = &Id";
	
	Query = New Query(QueryText);
	Query.SetParameter("Id", Template);
	Query.SetParameter("DefaultLanguageCode", Common.DefaultLanguageCode());
	
	Result = New Array;

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.Template.Get() <> Undefined Then
			Result.Add(Selection.LanguageCode);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.PrintFormTemplates");
	While Selection.Next() Do
		Block = New DataLock;
		LockItem = Block.Add("Catalog.PrintFormTemplates");
		LockItem.SetValue("Ref", Selection.Ref);
		
		RepresentationOfTheReference = String(Selection.Ref);
		
		BeginTransaction();
		Try
			Block.Lock();
			
			Template = Selection.Ref.GetObject(); // CatalogObject.PrintFormTemplates
			TableRow = Template.DataSources.Add();
			TableRow.DataSource = Template.DataSource;
			Template.DataSource = Undefined;
			InfobaseUpdate.WriteData(Template);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				Selection.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "InformationRegister.UserPrintTemplates");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some print templates: %1';"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information, Metadata.InformationRegisters.UserPrintTemplates,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Another batch of print templates is processed: %1';"),
			ObjectsProcessed));
	EndIf;
	
EndProcedure

Function WriteTemplate(TemplateDetails) Export
	
	Ref = TemplateDetails.Ref;
	If ValueIsFilled(Ref) Then
		Object = Ref.GetObject();
	Else
		Object = CreateItem();
		Object.TemplateType = TemplateDetails.TemplateType;
		Object.Id = New UUID;
	EndIf;
	
	Object.DataSources.Clear();
	For Each DataSource In TemplateDetails.DataSources Do
		NewRow = Object.DataSources.Add();
		NewRow.DataSource = DataSource;
	EndDo;
	
	Description = TemplateDetails.Description;
	LanguageCode = TemplateDetails.LanguageCode;
	Template = New ValueStorage(GetFromTempStorage(TemplateDetails.TemplateAddressInTempStorage));

	Common.SetAttributeValue(Object, "Description", Description, LanguageCode);
	Common.SetAttributeValue(Object, "Template", Template, LanguageCode);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.PrintFormTemplates");
	If ValueIsFilled(Ref) Then
		LockItem.SetValue("Ref", Ref);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		Object.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return "PF_" + String(Object.Id);
	
EndFunction

// Parameters:
//  Template - CatalogRef.PrintFormTemplates
//  Used - Boolean
//
Procedure SetUseLayout(Template, Used) Export
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.PrintFormTemplates");
	LockItem.SetValue("Ref", Template);
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Object = Template.GetObject();
		Object.Used = Used;
		Object.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function TemplateExists(Id) Export
	
	QueryText = 
	"SELECT
	|	Ref 
	|FROM
	|	Catalog.PrintFormTemplates AS PrintFormTemplates
	|WHERE
	|	PrintFormTemplates.Id = &Id";
	
	Query = New Query(QueryText);
	Query.SetParameter("Id", Id);

	Return Not Query.Execute().IsEmpty();

EndFunction

Function FindTemplate(TemplatePath, LanguageCode) Export
	
	Id = IdentifierOfTemplate(TemplatePath);
	If Id <> Undefined Then
		Return PrintableFormLayoutByID(Id, LanguageCode);
	EndIf;
	
	Return Undefined;
	
EndFunction

Function PrintableFormLayoutByID(Id, LanguageCode)
	
	QueryText =
	"SELECT
	|	LayoutsPrintedFormsPresentation.Template
	|FROM
	|	Catalog.PrintFormTemplates.Presentations AS LayoutsPrintedFormsPresentation
	|		LEFT JOIN Catalog.PrintFormTemplates AS PrintFormTemplates
	|		ON LayoutsPrintedFormsPresentation.Ref = PrintFormTemplates.Ref
	|WHERE
	|	PrintFormTemplates.Id = &Id
	|	AND LayoutsPrintedFormsPresentation.LanguageCode = &LanguageCode
	|
	|UNION ALL
	|
	|SELECT
	|	PrintFormTemplates.Template
	|FROM
	|	Catalog.PrintFormTemplates AS PrintFormTemplates
	|WHERE
	|	PrintFormTemplates.Id = &Id";
	
	Query = New Query(QueryText);
	Query.SetParameter("Id", Id);
	Query.SetParameter("LanguageCode", LanguageCode);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Template = Selection.Template.Get(); // ValueStorage
		If Template = Undefined Then
			Continue;
		EndIf;
		If TypeOf(Template) <> Type("BinaryData") Then
			Template.LanguageCode = Common.DefaultLanguageCode();
		EndIf;
		Return Template;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function IdentifierOfTemplate(TemplatePath) Export
	
	PathParts = StrSplit(TemplatePath, ".", True);
	
	TemplateName = PathParts[PathParts.UBound()];
	If StrStartsWith(TemplateName, "PF_") Then
		Id = Mid(TemplateName, 4);
		If StringFunctionsClientServer.IsUUID(Id) Then
			Return New UUID(Id);
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns:
//  CatalogRef.PrintFormTemplates
//
Function RefTemplate(TemplatePath) Export
	
	Id = IdentifierOfTemplate(TemplatePath);
	If Id = Undefined Then
		Return Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	PrintFormTemplates.Ref AS Ref
	|FROM
	|	Catalog.PrintFormTemplates AS PrintFormTemplates
	|WHERE
	|	PrintFormTemplates.Id = &Id";
	
	Query = New Query(QueryText);
	Query.SetParameter("Id", Id);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure DeleteTemplate(Ref, LanguageCode = Undefined) Export
	
	Object = Ref.GetObject();
	If LanguageCode = Undefined Or LanguageCode = Common.DefaultLanguageCode() Then
		Object.SetDeletionMark(True);
	Else
		Common.SetAttributeValue(Object, "Template", New ValueStorage(Undefined), LanguageCode);
	EndIf;

	Block = New DataLock;
	LockItem = Block.Add("Catalog.PrintFormTemplates");
	LockItem.SetValue("Ref", Ref);
	
	BeginTransaction();
	Try
		Block.Lock();
		Object.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Function TemplateDataSource(TemplatePath) Export

	Id = IdentifierOfTemplate(TemplatePath);
	If Id = Undefined Then
		Return Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	PrintFormTemplatesDataSources.DataSource AS DataSource
	|FROM
	|	Catalog.PrintFormTemplates.DataSources AS PrintFormTemplatesDataSources
	|		LEFT JOIN Catalog.PrintFormTemplates AS PrintFormTemplates
	|		ON PrintFormTemplatesDataSources.Ref = PrintFormTemplates.Ref
	|WHERE
	|	PrintFormTemplates.Id = &Id";
	
	Query = New Query(QueryText);
	Query.SetParameter("Id", Id);

	TemplateDataSource = Query.Execute().Unload().UnloadColumn("DataSource");
	
	Return TemplateDataSource;

EndFunction

Procedure OnAddUpdateHandlers(Handlers) Export

	Handler = Handlers.Add();
	Handler.Procedure = "Catalogs.PrintFormTemplates.ProcessDataForMigrationToNewVersion";
	Handler.Version = "3.1.8.48";
	Handler.ExecutionMode = "Deferred";
	Handler.Id = New UUID("959d09e5-1dc3-4f32-833a-05ff17365e30");
	Handler.UpdateDataFillingProcedure = "Catalogs.PrintFormTemplates.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Fills information about print data sources for custom print forms. Some print forms might be unavailable until processing is completed.';");
	
	ItemsToRead = New Array;
	ItemsToRead.Add(Metadata.Catalogs.PrintFormTemplates.FullName());
	Handler.ObjectsToRead = StrConcat(ItemsToRead, ",");
	
	Editable1 = New Array;
	Editable1.Add(Metadata.Catalogs.PrintFormTemplates.FullName());
	Handler.ObjectsToChange = StrConcat(Editable1, ",");
	
	ToLock = New Array;
	ToLock.Add(Metadata.Catalogs.PrintFormTemplates.FullName());
	Handler.ObjectsToLock = StrConcat(ToLock, ",");

EndProcedure

#EndRegion

#EndIf