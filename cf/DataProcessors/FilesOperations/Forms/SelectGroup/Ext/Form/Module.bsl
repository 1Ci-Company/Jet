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
	
	SetUpDynamicList();
	SetConditionalAppearance();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	List.ConditionalAppearance.Items.Clear();
	List.Group.Items.Clear();
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("FileOwner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Parameters.FilesOwner;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	GroupItem2 = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem2.Use = True;
	GroupItem2.Field = New DataCompositionField("FileOwner");
	
EndProcedure

&AtServer
Procedure SetUpDynamicList()
	
	FilesOwner = Parameters.FilesOwner;
	
	ErrorTitle = NStr("en = 'An error occurred when configuring the dynamic list of attachments.';");
	ErrorEnd = NStr("en = 'Cannot configure the dynamic list.';");
	FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, "", ErrorTitle, ErrorEnd);
	
	FileCatalogType = Type("CatalogRef." + FilesStorageCatalogName);
	MetadataOfCatalogWithFiles = Metadata.FindByType(FileCatalogType);
	CanCreateFileGroups = MetadataOfCatalogWithFiles.Hierarchical;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark AS DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN ISNULL(Files.PictureIndex, 2) + 1
	|		ELSE ISNULL(Files.PictureIndex, 2)
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	&IsFolder AS IsFolder,
	|	Files.FileOwner AS FileOwner
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FilesOwner
	|	AND &FilterGroups";
	
	FullCatalogName = "Catalog." + FilesStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	QueryText = StrReplace(QueryText, "&FilterGroups", "Files.IsFolder");
	ListProperties.QueryText = StrReplace(QueryText, "&IsFolder",
		?(CanCreateFileGroups, "Files.IsFolder", "FALSE"));
		
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	List.Parameters.SetParameterValue("FilesOwner", FilesOwner);
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	MoveFilesToGroup(Parameters.FilesToMove, Value);
	NotifyChanged(TypeOf(Parameters.FilesToMove[0]));
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	Notify("Write_File", FileWriteNotificationParameters, Parameters.FilesToMove);
	Close();
	
EndProcedure

&AtServerNoContext
Procedure MoveFilesToGroup(Val Files, Val Group)
	
	If Files.Count() = 0 Then
		Return;
	EndIf;
	
	TableName = Files[0].Metadata().FullName();
	
	Block = New DataLock;
	For Each FileRef In Files Do
		LockItem = Block.Add(TableName);
		LockItem.SetValue("Ref", FileRef);
	EndDo;
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		For Each FileRef In Files Do
			
			LockDataForEdit(FileRef);
			
			FileObject1 = FileRef.GetObject();
			FileObject1.Parent = Group;
			FileObject1.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure CreateFolder(Command)
	Parent = Undefined;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		Parent = CurrentData.Ref;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Parent",       Parent);
	FormParameters.Insert("FileOwner",  FilesOwner);
	FormParameters.Insert("IsNewGroup", True);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	
	OpenForm("DataProcessor.FilesOperations.Form.FilesGroup", FormParameters, ThisObject);
EndProcedure

#EndRegion
