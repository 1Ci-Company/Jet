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

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
// Parameters:
//  Parameters - Structure - an internal parameter to pass to the InfobaseUpdate.MarkForProcessing procedure.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText =
	"SELECT
	|	UserPrintTemplates.TemplateName AS TemplateName,
	|	UserPrintTemplates.Object AS Object
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates";
	
	Query = New Query(QueryText);
	UserTemplates = Query.Execute().Unload();
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName = "InformationRegister.UserPrintTemplates";
	
	InfobaseUpdate.MarkForProcessing(Parameters, UserTemplates, AdditionalParameters);
	
EndProcedure

Procedure ProcessUserTemplates(Parameters) Export
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	TemplatesInDOCXFormat = New Array;
	SSLSubsystemsIntegration.OnPrepareTemplateListInOfficeDocumentServerFormat(TemplatesInDOCXFormat);
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, "InformationRegister.UserPrintTemplates");
		
	While Selection.Next() Do
		Record = CreateRecordManager();
		Record.TemplateName = Selection.TemplateName;
		Record.Object = Selection.Object;
		Record.Read();
		ModifiedTemplate = Record.Template.Get();
		
		IsCommonTemplate = StrSplit(Selection.Object, ".", True).Count() < 2;
		
		If IsCommonTemplate Then
			TemplateMetadataObjectName = "CommonTemplate." + Selection.TemplateName;
		Else
			TemplateMetadataObjectName = Selection.Object + ".Template." + Selection.TemplateName;
		EndIf;
		
		FullTemplateName = Selection.Object + "." + Selection.TemplateName;
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.Object);
		RecordSet.Filter.TemplateName.Set(Selection.TemplateName);
		
		If Metadata.FindByFullName(TemplateMetadataObjectName) = Undefined Then
			EventName = NStr("en = 'Print';", Common.DefaultLanguageCode());
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Custom template not registered in configuration metadata found:
					|%1.';"), TemplateMetadataObjectName);
			WriteLogEvent(EventName, EventLogLevel.Warning, , TemplateMetadataObjectName, ErrorText);
			InfobaseUpdate.MarkProcessingCompletion(RecordSet);
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			Continue;
		EndIf;
		
		If IsCommonTemplate Then
			TemplateFromMetadata = GetCommonTemplate(Selection.TemplateName);
		Else
			SetSafeModeDisabled(True);
			SetPrivilegedMode(True);
		
			TemplateFromMetadata = Common.ObjectManagerByFullName(Selection.Object).GetTemplate(Selection.TemplateName);
			
			SetPrivilegedMode(False);
			SetSafeModeDisabled(False);
		EndIf;
		
		If Not PrintManagement.TemplatesDiffer(TemplateFromMetadata, ModifiedTemplate) Then
			InfobaseUpdate.WriteData(RecordSet);
		ElsIf TemplatesInDOCXFormat.Find(FullTemplateName) <> Undefined
			And TypeOf(TemplateFromMetadata) = Type("BinaryData") And TypeOf(ModifiedTemplate) = Type("BinaryData")
			And OfficeDocumentsTemplatesTypesDiffer(TemplateFromMetadata, ModifiedTemplate) Then
			PrintManagement.DisableUserTemplate(FullTemplateName);
		Else
			InfobaseUpdate.MarkProcessingCompletion(RecordSet);
		EndIf;
		ObjectsProcessed = ObjectsProcessed + 1;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "InformationRegister.UserPrintTemplates");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some custom templates: %1';"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information, Metadata.InformationRegisters.UserPrintTemplates,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Another batch of custom templates is processed: %1';"),
			ObjectsProcessed));
	EndIf;
	
EndProcedure

Function GetTemplateRecordKey(IdentifierOfTemplate) Export
	ArrayOfIDWords = StrSplit(IdentifierOfTemplate, ".", False);
		
	TemplateName = ArrayOfIDWords[ArrayOfIDWords.UBound()];
	ArrayOfIDWords.Delete(ArrayOfIDWords.UBound());
	ObjectName = StrConcat(ArrayOfIDWords, ".");
	
	QueryText = 
		"SELECT TOP 1
		|	UserPrintTemplates.Object AS Object,
		|	UserPrintTemplates.TemplateName AS TemplateName
		|FROM
		|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
		|WHERE
		|	UserPrintTemplates.Object = &Object
		|	AND UserPrintTemplates.TemplateName LIKE &TemplateName
		|	AND UserPrintTemplates.Use";
		
		Query = New Query(QueryText);
		Query.Parameters.Insert("Object", ObjectName);
		Query.Parameters.Insert("TemplateName", TemplateName + "%");
		Result = Query.Execute();
		Selection = Result.Select();
		
		
		If Selection.Next() Then
			KeyStructure1 = New Structure("Object, TemplateName");			
			FillPropertyValues(KeyStructure1, Selection);
			KeyOfEditObject = CreateRecordKey(KeyStructure1);
			Return KeyOfEditObject;
		Else
			Return Undefined
		EndIf;
EndFunction

#EndRegion

#Region Private

Function OfficeDocumentsTemplatesTypesDiffer(InitialTemplate, ModifiedTemplate)
	
	Return PrintManagementInternal.DefineDataFileExtensionBySignature(InitialTemplate) <> PrintManagementInternal.DefineDataFileExtensionBySignature(ModifiedTemplate);
	
EndFunction

Procedure SetModifiedTemplatesUsage(Templates, ChangedTemplateUsed) Export
	
	TableToSearch = New ValueTable;
	TableToSearch.Columns.Add("TemplateName", New TypeDescription("String", ,
	   New StringQualifiers(100, AllowedLength.Variable)));
	TableToSearch.Columns.Add("OwnerName", New TypeDescription("String", ,
	   New StringQualifiers(255, AllowedLength.Variable)));
	
	For Each TemplateMetadataObjectName In Templates Do
		TableRow = TableToSearch.Add();
		NameParts = StrSplit(TemplateMetadataObjectName, ".");
		TableRow.TemplateName = NameParts[NameParts.UBound()];
		
		OwnerName = "";
		For PartNumber = 0 To NameParts.UBound()-1 Do
			If Not IsBlankString(OwnerName) Then
				OwnerName = OwnerName + ".";
			EndIf;
			OwnerName = OwnerName + NameParts[PartNumber];
		EndDo;
		
		TableRow.OwnerName = OwnerName;
	EndDo;
		
	QueryText = 
	"SELECT
	|	TableToSearch.TemplateName TemplateName,
	|	TableToSearch.OwnerName OwnerName
	|INTO TTTableForSearch
	|FROM
	|	&TableToSearch AS TableToSearch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableToSearch.OwnerName,
	|	TableToSearch.TemplateName AS TemplateNameForSearch,
	|	UserPrintTemplates.TemplateName
	|FROM
	|	TTTableForSearch AS TableToSearch
	|		LEFT JOIN InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|		ON UserPrintTemplates.Object = TableToSearch.OwnerName";
	 
	Query = New Query(QueryText);
	
	Query.SetParameter("TableToSearch", TableToSearch);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If StrStartsWith(Selection.TemplateName, Selection.TemplateNameForSearch) Then
			Record = CreateRecordManager();
			Record.Object = Selection.OwnerName;
			Record.TemplateName = Selection.TemplateName;
			Record.Read();
			If Record.Selected() Then
				Record.Use = ChangedTemplateUsed;
				Record.Write();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  ObjectName - String
//
Function ObjectTemplates(ObjectName) Export
	
	If ObjectName = "CommonTemplates" Then
		MetadataObjectID = Catalogs.MetadataObjectIDs.EmptyRef();
	Else
		MetadataObjectID = Common.MetadataObjectID(ObjectName);
	EndIf;
	
	Return ObjectsTemplates(CommonClientServer.ValueInArray(MetadataObjectID));
	
EndFunction

// Returns:
//  ValueTable
//
Function ObjectsTemplates(MetadataObjectIDs) Export
	
	TemplatesList = New ValueTable();
	TemplatesList.Columns.Add("SourceOfTemplate");
	TemplatesList.Columns.Add("DataSources");
	TemplatesList.Columns.Add("Id");
	TemplatesList.Columns.Add("Presentation");
	TemplatesList.Columns.Add("Owner");
	TemplatesList.Columns.Add("TemplateType");
	TemplatesList.Columns.Add("Picture");
	TemplatesList.Columns.Add("PictureGroup");
	TemplatesList.Columns.Add("SearchString");
	TemplatesList.Columns.Add("AvailableLanguages");
	TemplatesList.Columns.Add("Changed");
	TemplatesList.Columns.Add("ChangedTemplateUsed");
	TemplatesList.Columns.Add("UsagePicture");
	TemplatesList.Columns.Add("AvailableTranslation");
	TemplatesList.Columns.Add("Ref");
	TemplatesList.Columns.Add("Used");
	TemplatesList.Columns.Add("AvailableSettingVisibility");
	TemplatesList.Columns.Add("Supplied");
	TemplatesList.Columns.Add("IsPrintForm");
	TemplatesList.Columns.Add("AvailableCreate");
	TemplatesList.Columns.Add("TemplateMetadataObjectName");
	
	TemplatesList.Indexes.Add("Owner");
	
	AddUserTemplates(TemplatesList, , MetadataObjectIDs);
	AddTemplatesFromMetadata(TemplatesList, MetadataObjectIDs);
	
	TemplatesList.Sort("Presentation");
	
	Return TemplatesList;
	
EndFunction

Procedure AddTemplatesFromMetadata(TemplatesList, MetadataObjectIDs)
	
	MetadataObjectsByIDs = Common.MetadataObjectsByIDs(MetadataObjectIDs, False);
	If MetadataObjectIDs.Find(Catalogs.MetadataObjectIDs.EmptyRef()) <> Undefined Then
		MetadataObjectsByIDs.Insert(Catalogs.MetadataObjectIDs.EmptyRef(), Metadata.CommonTemplates);
	EndIf;
	
	MetadataObjects = New Array;
	For Each MetadataObjectDetails In MetadataObjectsByIDs Do
		MetadataObject = MetadataObjectDetails.Value;
		MetadataObjects.Add(MetadataObject);
	EndDo;
	
	ModifiedTemplates = ModifiedTemplates();
	
	AvailableforTranslationLayouts = New Map;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		AvailableforTranslationLayouts = PrintManagementModuleNationalLanguageSupport.AvailableforTranslationLayouts();
	EndIf;
	
	For Each MetadataObjectDetails In MetadataObjectsByIDs Do

		MetadataObjectTemplateOwner = MetadataObjectDetails.Value;
		Owner =  ?(Metadata.CommonTemplates = MetadataObjectTemplateOwner, 
					Catalogs.MetadataObjectIDs.EmptyRef(), MetadataObjectDetails.Key);

		CollectionOfTemplates = New Array;
		If Metadata.CommonTemplates = MetadataObjectTemplateOwner Then
			CollectionOfTemplates.Add(Metadata.CommonTemplates);
		Else
			CollectionOfTemplates.Add(MetadataObjectTemplateOwner.Templates);
			AttachedTemplates = AttachedTemplates(MetadataObjectDetails.Key);
			CollectionOfTemplates.Add(AttachedTemplates);
		EndIf;
		
		For Each TemplatesCollection In CollectionOfTemplates Do
			For Each Item In TemplatesCollection Do
				OwnerName = ?(Metadata.CommonTemplates = MetadataObjectTemplateOwner, 
					"CommonTemplate", MetadataObjectTemplateOwner.FullName());
				
				MetadataObjectTemplate = Item;
				SourceOfTemplate = OwnerName;
				DataSources = OwnerName;
				
				If TypeOf(TemplatesCollection) = Type("ValueTable") Then
					MetadataObjectTemplate = Item.MetadataObject;
					SourceOfTemplate = Item.SourceOfTemplate;
					DataSources = Item.DataSources;
				EndIf;
				
				If Not StrFind(MetadataObjectTemplate.Name, "PF_") Then
					Continue;
				EndIf;
				
				TemplateMetadataObjectName = SourceOfTemplate + "." + MetadataObjectTemplate.Name;
				TemplatePresentation = MetadataObjectTemplate.Presentation();
				
				TemplateType = TemplateType(MetadataObjectTemplate.Name, SourceOfTemplate);
				
				Template = TemplatesList.Add();
				Template.SourceOfTemplate = SourceOfTemplate;
				Template.DataSources = DataSources;
				Template.Id = TemplateMetadataObjectName;
				Template.Presentation = TemplatePresentation;
				Template.Owner = Owner;
				Template.TemplateType = TemplateType;
				Template.Picture = PictureIndex(TemplateType);
				Template.PictureGroup = TemplateImage(TemplateType);
				Template.Changed = ModifiedTemplates[TemplateMetadataObjectName] <> Undefined;
				Template.ChangedTemplateUsed = Template.Changed And ModifiedTemplates[TemplateMetadataObjectName];
				Template.AvailableTranslation = AvailableforTranslationLayouts[MetadataObjectTemplate] = True;
				Template.Used = True;
				Template.Supplied = True;
	
				If ValueIsFilled(Template.Owner) Then
					Template.IsPrintForm = PrintManagement.IsPrintForm(Template.Id, Template.Owner);
					Template.AvailableTranslation = Template.AvailableTranslation Or Template.IsPrintForm;
				EndIf;
				
				Template.TemplateMetadataObjectName = Template.Id;
				Template.AvailableLanguages = AvailableLayoutLanguages(Template.Id);
				Template.UsagePicture = -1;
				If Template.Changed Then
					Template.UsagePicture = Number(Template.Changed) + Number(Template.ChangedTemplateUsed);
				EndIf;
				Template.SearchString = Lower(Template.Presentation + " " + Template.TemplateType);
				Template.AvailableCreate = MetadataObjectTemplateOwner <> Metadata.CommonTemplates 
					And Common.IsRefTypeObject(MetadataObjectTemplateOwner);
				
			EndDo;
		EndDo;
	EndDo;
	
EndProcedure

Function AttachedTemplates(MetadataObjectID)
	
	Result = New ValueTable;
	Result.Columns.Add("MetadataObject");
	Result.Columns.Add("SourceOfTemplate");
	Result.Columns.Add("DataSources");
	
	If TypeOf(MetadataObjectID) <> Type("CatalogRef.MetadataObjectIDs") Then
		Return Result;
	EndIf;
	
	AttachedReportsAndDataProcessors = AttachableCommands.AttachedObjects(MetadataObjectID);
	For Each AttachedObject In AttachedReportsAndDataProcessors Do
		DataSources = New Array;
		For Each MetadataObject In AttachedObject.Location Do
			DataSources.Add(MetadataObject.FullName());
		EndDo;
		For Each Template In AttachedObject.Metadata.Templates Do
			If StrStartsWith(Template.Name, "PF_") Then
				TemplateDetails = Result.Add();
				TemplateDetails.MetadataObject = Template;
				TemplateDetails.SourceOfTemplate = AttachedObject.Metadata.FullName();
				TemplateDetails.DataSources = StrConcat(DataSources, ",");
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Function ModifiedTemplates(MetadataObjects = Undefined)
	
	QueryText =
	"SELECT
	|	ModifiedTemplates.TemplateName,
	|	ModifiedTemplates.Object,
	|	ModifiedTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS ModifiedTemplates
	|WHERE
	|	NOT &FilterIs_Specified
	|	OR ModifiedTemplates.Object IN(&Objects)";
	
	ObjectsNames = Undefined;
	If MetadataObjects <> Undefined Then
		ObjectsNames = New Array;
		For Each MetadataObject In MetadataObjects Do
			ObjectsNames.Add(MetadataObject.FullName());
		EndDo;
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("FilterIs_Specified", ValueIsFilled(ObjectsNames));
	Query.SetParameter("Objects", ObjectsNames);
	ModifiedTemplates = Query.Execute().Unload();
	
	PrintFormsLanguages = CommonClientServer.ValueInArray(Common.DefaultLanguageCode());
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		PrintFormsLanguages = PrintManagementModuleNationalLanguageSupport.AvailableLanguages();
	EndIf;
	
	Result = New Map;
	
	For Each Template In ModifiedTemplates Do
		TemplateName = Template.TemplateName;
		
		TemplateNames = New Array;
		TemplateNames.Add(TemplateName);
		
		For Each LanguageCode In PrintFormsLanguages Do
			If StrFind(TemplateName, "_MXL_") And StrEndsWith(TemplateName, "_" + LanguageCode) Then
				TemplateName = Left(TemplateName, StrLen(TemplateName) - StrLen(LanguageCode) - 1);
				TemplateNames.Add(TemplateName);
				Break;
			EndIf;
		EndDo;
		
		For Each TemplateName In TemplateNames Do
			TemplateMetadataObjectName = Template.Object + "." + TemplateName;
			Result.Insert(TemplateMetadataObjectName, Template.Use);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure AddUserTemplates(TemplatesList, Val Id = Undefined, Val DataSources = Undefined) Export
	
	If ValueIsFilled(Id) Then
		Id = New UUID(Mid(Id, 4));
	Else
		Id = New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
	QueryText =
	"SELECT
	|	PrintFormTemplates.Ref,
	|	PrintFormTemplates.Presentation,
	|	PrintFormTemplates.Used,
	|	PrintFormTemplates.TemplateType,
	|	PrintFormTemplates.Id,
	|	PrintFormTemplatesDataSources.DataSource AS Owner
	|FROM
	|	Catalog.PrintFormTemplates.DataSources AS PrintFormTemplatesDataSources
	|		LEFT JOIN Catalog.PrintFormTemplates AS PrintFormTemplates
	|		ON PrintFormTemplatesDataSources.Ref = PrintFormTemplates.Ref
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON PrintFormTemplatesDataSources.Ref = MetadataObjectIDs.Ref
	|		LEFT JOIN Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|		ON PrintFormTemplatesDataSources.Ref = ExtensionObjectIDs.Ref
	|WHERE
	|	NOT PrintFormTemplates.DeletionMark
	|	AND ((NOT &FilterByDataSourcesSet
	|	OR PrintFormTemplatesDataSources.DataSource IN (&DataSources))
	|	AND (NOT &FilterByIDIsSet
	|	OR PrintFormTemplates.Id = &Id))";
	
	Query = New Query(QueryText);
	Query.SetParameter("FilterByIDIsSet", ValueIsFilled(Id));
	Query.SetParameter("Id", Id);
	Query.SetParameter("FilterByDataSourcesSet", DataSources <> Undefined);
	Query.SetParameter("DataSources", DataSources);
	
	TableOfTemplates = Query.Execute().Unload();
	For Each TableRow In TableOfTemplates Do
		Template = TemplatesList.Add();
		FillPropertyValues(Template, TableRow);
		
		FoundRows = TableOfTemplates.FindRows(New Structure("Id", Template.Id));
		DataSources = New Array;
		For Each FoundRow In FoundRows Do
			DataSources.Add(FoundRow.Owner);
		EndDo;
		
		MetadataObjectsByIDs = Common.MetadataObjectsByIDs(DataSources, False);
		
		DataSources = New Array;
		For Each MetadataObject In MetadataObjectsByIDs Do
			If MetadataObject.Value <> Undefined Then
				DataSources.Add(MetadataObject.Value.FullName());
			EndIf;
		EndDo;
		
		Template.DataSources = StrConcat(DataSources, ",");
		Template.Changed = True;
		Template.ChangedTemplateUsed = True;
		Template.AvailableTranslation = True;
		Template.Id = "PF_" + String(Template.Id);
		Template.AvailableSettingVisibility = True;
		Template.IsPrintForm = True;
		
		Template.TemplateMetadataObjectName = Template.Id;
		Template.AvailableLanguages = AvailableLayoutLanguages(Template.Id);

		Template.Picture = PictureIndex(Template.TemplateType);
		Template.PictureGroup = TemplateImage(Template.TemplateType);
		Template.UsagePicture = -1;

		If Template.Changed Then
			Template.UsagePicture = Number(Template.Changed) + Number(Template.ChangedTemplateUsed);
		EndIf;
		Template.SearchString = Lower(Template.Presentation + " " + Template.TemplateType);
		If ValueIsFilled(Template.Owner) Then
			MetadataObjectTemplateOwner = Common.MetadataObjectByID(Template.Owner);
			Template.AvailableCreate = Common.IsRefTypeObject(MetadataObjectTemplateOwner);
		EndIf;
	EndDo;
	
EndProcedure

Function AvailableLayoutLanguages(Val TemplateMetadataObjectName) Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		Return PrintManagementModuleNationalLanguageSupport.RepresentationOfLayoutLanguages(TemplateMetadataObjectName);
	EndIf;
	
	Return "";
	
EndFunction

Function TemplateType(TemplateMetadataObjectName, ObjectName = "CommonTemplate")
	
	Position = StrFind(TemplateMetadataObjectName, "PF_");
	If Position = 0 Then
		Return Undefined;
	EndIf;
	
	If ObjectName = "CommonTemplate" Then
		PrintFormTemplate = GetCommonTemplate(TemplateMetadataObjectName);
	Else
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		PrintFormTemplate = Common.ObjectManagerByFullName(ObjectName).GetTemplate(TemplateMetadataObjectName);
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	EndIf;
	
	TemplateType = Undefined;
	
	If TypeOf(PrintFormTemplate) = Type("SpreadsheetDocument") Then
		TemplateType = "MXL";
	ElsIf TypeOf(PrintFormTemplate) = Type("BinaryData") Then
		TemplateType = Upper(PrintManagementInternal.DefineDataFileExtensionBySignature(PrintFormTemplate));
	EndIf;
	
	Return TemplateType;
	
EndFunction

Function PictureIndex(Val TemplateType) Export
	
	TemplateTypes = New Map;
	TemplateTypes.Insert("DOC", 0);
	TemplateTypes.Insert("DOCX", 0);
	TemplateTypes.Insert("ODT", 1);
	TemplateTypes.Insert("MXL", 2);
	
	Result = TemplateTypes[Upper(TemplateType)];
	Return ?(Result = Undefined, -1, Result);
	
EndFunction 

Function TemplateImage(Val TemplateType)
	
	TemplateTypes = New Map;
	TemplateTypes.Insert("DOC", PictureLib.WordFormat);
	TemplateTypes.Insert("DOCX", PictureLib.WordFormat2007);
	TemplateTypes.Insert("ODT", PictureLib.OpenOfficeCalcFormat);
	TemplateTypes.Insert("MXL", PictureLib.MXLFormat);
	
	Result = TemplateTypes[Upper(TemplateType)];
	Return ?(Result = Undefined, New Picture, Result);
	
EndFunction 

#EndRegion

#EndIf
