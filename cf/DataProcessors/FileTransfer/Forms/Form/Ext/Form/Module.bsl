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
	
	CreationDateComparisonOperator = "before";
	InitializeAdditionalConditions();
	FillPossibleOwnersList(Items.FilesOwner.ChoiceList);
	FilesOperationsInternal.FillListWithFilesTypes(Items.FilesExtensions.ChoiceList);
	
	StorageVolumesCount = StorageVolumesCount();
	StoreFilesInVolumesOnHardDrive = FilesOperationsInVolumesInternal.StoreFilesInVolumesOnHardDrive();
	
	If Not StoreFilesInVolumesOnHardDrive
		And StorageVolumesCount > 0 Then
		
		Action = "MoveToInfobase";
		Items.Action.Enabled = False;
	Else
		Action = ?(StorageVolumesCount = 1, "MoveToVolumes", "MoveBetweenVolumes");
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If StorageVolumesCount = 0 Then
		NotifyDescription = New NotifyDescription("WhenOpeningAfterClosingTheWarning", ThisObject);
		ShowMessageBox(NotifyDescription, NStr("en = 'Cannot move the files between volumes since there is no volume available for storing files.';"));	
		Return;
	EndIf;
	
	FormItemsManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ActionOnChange(Item)
	
	If Action = "MoveBetweenVolumes"
		And StorageVolumesCount = 1 Then
		
		Action = "MoveToVolumes";
		ShowMessageBox(, NStr("en = 'Cannot move the files between volumes as only one file storage volume is defined in the settings.';"));
	EndIf;
	
	FormItemsManagement();
	
EndProcedure

&AtClient
Procedure DestinationStorageVolumeOnChange(Item)
	
	MoveToVolume = ValueIsFilled(DestinationStorageVolume);
	
EndProcedure

&AtClient
Procedure StorageVolumeSourceOnChange(Item)
	
	MoveFromVolume = ValueIsFilled(StorageVolumeSource);
	
EndProcedure

&AtClient
Procedure FilesOwnerOnChange(Item)
	
	MoveOwnerFiles = Not IsBlankString(FilesOwner);
	
EndProcedure

&AtClient
Procedure FilesExtensionsOnChange(Item)
	
	MoveByExtension = Not IsBlankString(FilesExtensions);
	
EndProcedure

&AtClient
Procedure FilesExtensionsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	FilesExtensions = FilesOperationsInternalClient.ExtensionsByFileType(ValueSelected);
	MoveByExtension = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExecuteTransfer(Command)
	
	If Action = "MoveBetweenVolumes" And Not ValueIsFilled(DestinationStorageVolume) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify the destination volume.';"), , "DestinationStorageVolume");
		Return;
	EndIf;
	
	TimeConsumingOperation = ExecuteTransferAtServer();
	CallbackOnCompletion = New NotifyDescription("ExecuteTransferCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion);

EndProcedure

#EndRegion

#Region Private

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ExecuteTransferCompletion(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
		
	TransferResult = GetFromTempStorage(Result.ResultAddress); // See DataProcessors.FileTransfer.ExecuteFileTransfer
	If TransferResult.TransferErrors.Count() = 0 Then
		If TransferResult.FilesTransferred > 0 Then
			Explanation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The files are moved. Total files: %1.';"),
				Format(TransferResult.FilesTransferred, "NZ=0; NG="));
		Else
			Explanation = NStr("en = 'There are no files matching the specified conditions.';");
			If AdditionalConditions.Settings.Filter.Items.Count() > 1 Then
				Explanation = Explanation + Chars.LF + NStr("en = 'Consider that additional conditions are grouped by ""AND"" if they are not grouped into an ""Or"" group.';");
			EndIf;
		EndIf;
		ShowMessageBox(, Explanation);
	Else
		Explanation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Moved files: %1, failed to move: %2';"),
			TransferResult.FilesTransferred, TransferResult.TransferErrors.Count());
		
		FormParameters = New Structure;
		FormParameters.Insert("Explanation", Explanation);
		FormParameters.Insert("FilesWithErrors", TransferResult.TransferErrors);
		OpenForm("DataProcessor.FileTransfer.Form.ReportForm", FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure FormItemsManagement()
	
	SourceAvailability = True;
	DestinationAvailability = True;
	
	If Action = "MoveBetweenVolumes" Then
		MoveToVolume = True;
	ElsIf Action = "MoveToVolumes" Then
		MoveFromVolume = False;
		StorageVolumeSource = Undefined;
		SourceAvailability = False;
	ElsIf Action = "MoveToInfobase" Then
		MoveToVolume = False;
		DestinationStorageVolume = Undefined;
		DestinationAvailability = False;
	EndIf;
	
	Items.MoveToVolume.Enabled = Not Action = "MoveBetweenVolumes";
	
	Items.SourceSettings.Enabled = SourceAvailability;
	Items.DestinationSettings.Enabled = DestinationAvailability;
	
EndProcedure

&AtClient
Procedure WhenOpeningAfterClosingTheWarning(Result) Export
	
	Close();
	
EndProcedure

&AtServer
Function ExecuteTransferAtServer()
	
	SelectCheckBoxesCorrectly();
	
	FileTransferOptions = DataProcessors.FileTransfer.FileTransferOptions();
	FileTransferOptions.Action = Action;
	FileTransferOptions.MoveToVolume = MoveToVolume;
	FileTransferOptions.DestinationStorageVolume = DestinationStorageVolume;
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(UUID);
	
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "DataProcessors.FileTransfer.ExecuteFileTransfer",
		FilesToTransfer(), FileTransferOptions);
	
EndFunction

&AtServer
Procedure InitializeAdditionalConditions()
	
	CompositionSchema = CompositionSchema();
	CompositionSchemaAddress = PutToTempStorage(
		CompositionSchema, UUID); // DataCompositionSchema
	AdditionalConditions.Initialize(
		New DataCompositionAvailableSettingsSource(CompositionSchemaAddress));
	AdditionalConditions.LoadSettings(CompositionSchema.DefaultSettings);
	AdditionalConditions.Refresh();
	
EndProcedure

&AtServer
Procedure SelectCheckBoxesCorrectly()
	
	If Not ValueIsFilled(DestinationStorageVolume) Then
		MoveToVolume = False;
	EndIf;
	
	If Not ValueIsFilled(StorageVolumeSource) Then
		MoveFromVolume = False;
	EndIf;
	
	If Not ValueIsFilled(CreationDate) Then
		MoveByCreationDate = False;
	EndIf;
	
	If IsBlankString(FilesExtensions) Then
		MoveByExtension = False;
	EndIf;
	
EndProcedure

&AtServer
Function FilesToTransfer()
	
	DataCompositionSchema = CompositionSchema(False,
		?(MoveOwnerFiles And Not IsBlankString(FilesOwner), FilesOwner, ""));
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.LoadSettings(AdditionalConditions.Settings);
	
	FilterByAction = ?(Action = "MoveToVolumes",
		Enums.FileStorageTypes.InInfobase,
		Enums.FileStorageTypes.InVolumesOnHardDrive);
	
	AddFilterSetting(SettingsComposer, "FileStorageType",
		DataCompositionComparisonType.Equal, FilterByAction);
	
	If MoveToVolume Then
		AddFilterSetting(SettingsComposer, "Volume",
			DataCompositionComparisonType.NotEqual, DestinationStorageVolume);
	EndIf;
		
	If MoveFromVolume Then
		AddFilterSetting(SettingsComposer, "Volume",
			DataCompositionComparisonType.Equal, StorageVolumeSource);
	EndIf;
	
	If MoveByCreationDate Then
		
		AddFilterSetting(SettingsComposer, "CreationDate",
			?(CreationDateComparisonOperator = "before", DataCompositionComparisonType.LessOrEqual,
			DataCompositionComparisonType.GreaterOrEqual), CreationDate);
	EndIf;
	
	If MoveByExtension Then
		
		FilterByExtension = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
			FilesExtensions, " ", True, True);
			
		For Each Extension In FilterByExtension Do
			Extension = Lower(Extension);
		EndDo;
		
		AddFilterSetting(SettingsComposer, "Extension",
			DataCompositionComparisonType.InList, FilterByExtension);
		
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
		SettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(DataCompositionTemplate);
	
	FilesToTransfer = New ValueTable;
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(FilesToTransfer);
	OutputProcessor.Output(CompositionProcessor);
	
	Return FilesToTransfer;
	
EndFunction

&AtServerNoContext
Function CompositionSchema(FilesCatalogsOnly = True, FilesOwner = "")
	
	If FilesCatalogsOnly Then
		QueryText = "";
	Else
		
		If Not IsBlankString(FilesOwner) Then
			SeparatorPosition = StrFind(FilesOwner, ".");
			OwnerTypeAsString = Left(FilesOwner, SeparatorPosition - 1)
				+ "Ref" + Mid(FilesOwner, SeparatorPosition);
		EndIf;
		
		QueryText = 
		"SELECT
		|	FilesVersions.Ref AS Ref,
		|	FilesVersions.Description AS Description,
		|	FilesVersions.DeletionMark AS DeletionMark,
		|	FilesVersions.Author AS Author,
		|	FilesVersions.Owner.FileOwner AS FileOwner,
		|	FilesVersions.CreationDate AS CreationDate,
		|	&IsInternal AS IsInternal,
		|	FilesVersions.Owner.ChangedBy AS ChangedBy,
		|	FilesVersions.Size AS Size,
		|	FilesVersions.Extension AS Extension,
		|	FilesVersions.Volume AS Volume,
		|	FilesVersions.Owner.StoreVersions AS StoreVersions,
		|	FilesVersions.FileStorageType AS FileStorageType,
		|	FilesVersions.TextExtractionStatus AS TextExtractionStatus
		|FROM
		|	Catalog.FilesVersions AS FilesVersions";
		
		FilterByOwnerSet = IsBlankString(FilesOwner);
		VersionsOwnersMetadataTypes = Metadata.Catalogs.FilesVersions.StandardAttributes.Owner.Type;
		For Each MetadataType In VersionsOwnersMetadataTypes.Types() Do
			
			OwnerMetadata = Metadata.FindByType(MetadataType);
			If OwnerMetadata.Attributes.Find("IsInternal") <> Undefined Then
				
				QueryText = StrReplace(QueryText, "&IsInternal", "ISNULL(FilesVersions.Owner.IsInternal, FALSE)");
				If FilterByOwnerSet Then
					Break;
				EndIf;
				
			EndIf;
			
			If Not FilterByOwnerSet
				And OwnerMetadata.Attributes.FileOwner.Type.ContainsType(Type(OwnerTypeAsString)) Then
				
				FilterByOwnerSet = True;
				AdditionalCondition = "
					|WHERE
					|	FilesVersions.Owner.FileOwner REFS Catalog.Files"; // @query-part
				AdditionalCondition = StrReplace(AdditionalCondition, "Catalog.Files", FilesOwner);
				QueryText = QueryText + AdditionalCondition;
				
			EndIf;
			
		EndDo;
		
		If Not IsBlankString(FilesOwner)
			And Not FilterByOwnerSet Then
			QueryText = "";
		Else
			QueryText = StrReplace(QueryText, "&IsInternal", "FALSE");
		EndIf;
		
	EndIf;
	
	SubqueryText =
	"SELECT
	|	FilesCatalog.Ref,
	|	FilesCatalog.Description,
	|	FilesCatalog.DeletionMark,
	|	FilesCatalog.Author,
	|	FilesCatalog.FileOwner,
	|	FilesCatalog.CreationDate,
	|	&IsInternal,
	|	FilesCatalog.ChangedBy,
	|	FilesCatalog.Size,
	|	FilesCatalog.Extension,
	|	FilesCatalog.Volume,
	|	FilesCatalog.StoreVersions,
	|	FilesCatalog.FileStorageType,
	|	FilesCatalog.TextExtractionStatus
	|FROM
	|	&TableOfFiles AS FilesCatalog";
	
	If Not IsBlankString(FilesOwner) Then
		
		SubqueryText = SubqueryText + "
			|WHERE
			|	FilesCatalog.FileOwner Ref " + FilesOwner;
		
	EndIf;
	
	AttachedFilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	For Each FileType In AttachedFilesTypes Do
		
		If FileType = Type("CatalogRef.FilesVersions")
			Or FileType = Type("CatalogRef.MetadataObjectIDs")
			Or (Not FilesCatalogsOnly
			And VersionsOwnersMetadataTypes.ContainsType(FileType)) Then
			
			Continue;
		EndIf;
		
		MetadataObject = Metadata.FindByType(FileType);
		If Not IsBlankString(FilesOwner) Then
			
			SeparatorPosition = StrFind(FilesOwner, ".");
			OwnerTypeAsString = Left(FilesOwner, SeparatorPosition - 1)
				+ "Ref" + Mid(FilesOwner, SeparatorPosition);
				
			If Not MetadataObject.Attributes.FileOwner.Type.ContainsType(Type(OwnerTypeAsString)) Then
				Continue;
			EndIf;
			
		EndIf;
		
		OwnerQueryText = StrReplace(SubqueryText, "&TableOfFiles", MetadataObject.FullName());
		OwnerQueryText = StrReplace(OwnerQueryText, "&IsInternal", 
			?(MetadataObject.Attributes.Find("IsInternal") <> Undefined, "FilesCatalog.IsInternal", "FALSE"));
		
		If MetadataObject.Attributes.Find("FileOwner") = Undefined Then
			Raise "";
		EndIf;
		
		QueryText = QueryText
			+ ?(IsBlankString(QueryText), "", "
			|
			|UNION ALL
			|
			|") + OwnerQueryText;
		
	EndDo;
	
	CompositionSchema = New DataCompositionSchema;
	
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.Name = "FilesDataSource";
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSetFiles";
	DataSet.Query = QueryText;
	DataSet.DataSource = DataSource.Name;
	
	CompositionGroup1 = CompositionSchema.DefaultSettings.Structure.Add(Type("DataCompositionGroup"));
	
	GroupingField = CompositionGroup1.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupingField.Field = New DataCompositionField("Ref");
	
	CompositionGroup1.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	CompositionSchema.TotalFields.Clear();
	
	Return CompositionSchema;
	
EndFunction

&AtServerNoContext
Function StorageVolumesCount()
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Return Query.Execute().Unload().Count();
	
EndFunction

&AtServerNoContext
Procedure AddFilterSetting(SettingsComposer, FieldName, Var_ComparisonType, Value)
	
	Filter = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.LeftValue = New DataCompositionField(FieldName);
	Filter.ComparisonType = Var_ComparisonType;
	Filter.RightValue = Value;
	Filter.Use = True;
	
EndProcedure

&AtServerNoContext
Procedure FillPossibleOwnersList(FilesOwners)
	
	OwnersTypes = Metadata.DefinedTypes.AttachedFilesOwner.Type.Types();
	For Each OwnerType In OwnersTypes Do
		
		If OwnerType = Type("CatalogRef.MetadataObjectIDs") Then
			Continue;
		EndIf;
		
		MetadataObject = Metadata.FindByType(OwnerType);
		FilesOwners.Add(MetadataObject.FullName(), MetadataObject.Synonym);
		
	EndDo;
	
	FilesOwners.SortByPresentation();
	
EndProcedure

#EndRegion