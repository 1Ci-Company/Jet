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
	
	Volume = Parameters.Volume;
	
	// Determining available file storages.
	FillFileStorageNames();
	
	If FileStorageNames.Count() = 0 Then
		Raise NStr("en = 'Cannot find the file storages.';");
		
	ElsIf FileStorageNames.Count() = 1 Then
		Items.FileStoragePresentation.Visible = False;
	EndIf;
	
	FileStorageName = Common.CommonSettingsStorageLoad(
		"CommonForm.FilesInVolume.FilterByStorages", 
		String(Volume.UUID()) );
	
	If FileStorageName = ""
	 Or FileStorageNames.FindByValue(FileStorageName) = Undefined Then
	
		FileVersionItem = FileStorageNames.FindByValue("FilesVersions");
		
		If FileVersionItem = Undefined Then
			FileStorageName = FileStorageNames[0].Value;
			FileStoragePresentation = FileStorageNames[0].Presentation;
		Else
			FileStorageName = FileVersionItem.Value;
			FileStoragePresentation = FileVersionItem.Presentation;
		EndIf;
	Else
		FileStoragePresentation = FileStorageNames.FindByValue(FileStorageName).Presentation;
	EndIf;
	
	SetUpDynamicList(FileStorageName);
	
	If Common.IsMobileClient() Then
		Items.FileStoragePresentation.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FileStoragePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("FileStoragePresentationStartChoiceSelectionMade", ThisObject);
	ShowChooseFromList(NotifyDescription, FileStorageNames, Items.FileStoragePresentation,
		FileStorageNames.FindByValue(FileStorageName));
		
EndProcedure

&AtClient
Procedure FileStoragePresentationStartChoiceSelectionMade(CurrentStorage, AdditionalParameters) Export
	
	If TypeOf(CurrentStorage) = Type("ValueListItem") Then
		FileStorageName = CurrentStorage.Value;
		FileStoragePresentation = CurrentStorage.Presentation;
		SetUpDynamicList(FileStorageName);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	OpenFileCard();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetUpDynamicList(Val StorageName)
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText =
	"SELECT
	|	FileRepository.Ref AS Ref,
	|	FileRepository.PictureIndex AS PictureIndex,
	|	FileRepository.PathToFile AS PathToFile,
	|	FileRepository.Size AS Size,
	|	FileRepository.Author AS Author,
	|	&AreAttachedFiles AS AreAttachedFiles
	|FROM
	|	&CatalogName AS FileRepository
	|WHERE
	|	FileRepository.Volume = &Volume";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + StorageName);
	QueryText = StrReplace(QueryText, "&AreAttachedFiles", ?(
		Upper(StorageName) = Upper("FilesVersions"), "FALSE", "TRUE"));
		
	ListProperties.MainTable = "Catalog." + StorageName;
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	List.Parameters.SetParameterValue("Volume", Volume);
	
	SaveSelectionSettings(Volume, FileStorageName);
	
EndProcedure

&AtServer
Procedure FillFileStorageNames()
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		MetadataCatalogs = Metadata.Catalogs;
		FileStorageNames.Add(MetadataCatalogs.FilesVersions.Name, MetadataCatalogs.FilesVersions.Presentation());
		
		For Each Catalog In Metadata.Catalogs Do
			If StrEndsWith(Catalog.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles()) Then
				FileStorageNames.Add(Catalog.Name, Catalog.Presentation());
			EndIf;
		EndDo;
	EndIf;
	
	FileStorageNames.SortByPresentation();
	
EndProcedure

&AtServerNoContext
Procedure SaveSelectionSettings(Volume, CurrentSettings)
	
	Common.CommonSettingsStorageSave(
		"CommonForm.FilesInVolume.FilterByStorages",
		String(Volume.UUID()),
		CurrentSettings);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AreAttachedFiles Then
		FilesOperationsClient.OpenFileForm(CurrentData.Ref);
	Else
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

#EndRegion
