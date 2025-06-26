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
	
	DefineSettings();
	
	If ValueIsFilled(Parameters.FilterObject) Then
		MainObject = Parameters.FilterObject;
	EndIf;
	
	InitialObject = MainObject;
	
	If ValueIsFilled(MainObject) Then
		UpdateHierarchicalTree();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	OutputHierarchy();
	
EndProcedure

&AtClient
Procedure OutputForCurrentDocument(Command)
	
	CurrentObject = Items.ReportTable.CurrentArea.Details;
	
	If Not ValueIsFilled(CurrentObject) Then
		Return;
	EndIf;
	
	MainObject = CurrentObject;
	
	OutputHierarchy();
	
EndProcedure

&AtClient
Procedure ChangeDeletionMark(Command)
	
	ClearMessages();
	
	SelectedItems = SelectedItems();
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	Statistics = StatisticsBySelectedItems(SelectedItems);
	
	Scenario = DeletionMarkEditScenario(SelectedItems, Statistics);
	Scenario.Insert("SelectedItems", SelectedItems);
	
	Handler = New NotifyDescription("ExecuteDeletionMarkChangeScenario", ThisObject, Scenario);
	ShowQueryBox(Handler, Scenario.DoQueryBox, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure Post(Command)
	
	ChangeDocumentsPosting(DocumentWriteMode.Posting);
	
EndProcedure

&AtClient
Procedure CancelPosting(Command)
	
	ChangeDocumentsPosting(DocumentWriteMode.UndoPosting);
	
EndProcedure

#EndRegion

#Region Private

//////////////////////////////////////////////////////////////////////////////////////////////
// Procedures for output to a spreadsheet document.

&AtServer
Procedure OutputSpreadsheetDocument()

	ReportTable.Clear();
	
	Template = GetCommonTemplate("SubordinationStructure");
	
	OutputParentTreeItems(TreeParentObjects.GetItems(), Template);
	OutputCurrentObject(Template);
	OutputSubordinateTreeItems(TreeSubordinateObjects.GetItems(), Template);
	
EndProcedure

// Parameters:
//  TreeRows - FormDataTreeItemCollection
//  Template - SpreadsheetDocument
//  RecursionLevels - Number
//
&AtServer
Procedure OutputParentTreeItems(TreeRows, Template, RecursionLevels = 1)
	
	Counter =  TreeRows.Count();
	While Counter > 0 Do
		
		CurrentTreeRow = TreeRows.Get(Counter - 1);
		
		SubordinateTreeRowItems = CurrentTreeRow.GetItems();
		OutputParentTreeItems(SubordinateTreeRowItems, Template, RecursionLevels + 1);
		
		For Level = 1 To RecursionLevels Do
			
			If Level = RecursionLevels Then
				
				If TreeRows.IndexOf(CurrentTreeRow) < (TreeRows.Count() - 1) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else
					Area = Template.GetArea("ConnectorRightBottom");
				EndIf;
				
			Else
				
				If OutputVerticalConnector(RecursionLevels - Level + 1, CurrentTreeRow, False) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
				EndIf;
				
			EndIf;
			
			If Level = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;
		
		OutputPresentationAndPicture(CurrentTreeRow, Template, False, False);		
		Counter = Counter - 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure OutputPresentationAndPicture(TreeRow, Template, IsCurrentObject = False, IsSubordinateDocument = Undefined)
	
	ObjectMetadata = TreeRow.Ref.Metadata();
	IsDocument       = Common.IsDocument(ObjectMetadata);
	
	HasParentsCumulative = TreeParentObjects.GetItems().Count() > 0;
	HasSubordinateItemsCumulative = TreeSubordinateObjects.GetItems().Count() > 0;
	HasSubordinateItems = TypeOf(TreeRow) = Type("FormDataTreeItem")
		And TreeRow.GetItems().Count() > 0;
	
	// Output picture.
	If TreeRow.Posted Then
		If IsCurrentObject Then
			If HasSubordinateItemsCumulative And HasParentsCumulative Then
				PictureArea = Template.GetArea("DocumentPostedConnectorTopBottom");
			ElsIf HasSubordinateItemsCumulative Then
				PictureArea = Template.GetArea("DocumentPostedConnectorBottom");
			Else
				PictureArea = Template.GetArea("DocumentPostedConnectorTop");
			EndIf;
		ElsIf IsSubordinateDocument = True Then
			If HasSubordinateItems Then
				PictureArea = Template.GetArea("DocumentPostedConnectorLeftBottom");
			Else
				PictureArea = Template.GetArea("DocumentPosted");
			EndIf;
		Else
			If HasSubordinateItems Then
				PictureArea = Template.GetArea("DocumentPostedConnectorLeftTop");
			Else
				PictureArea = Template.GetArea("DocumentPosted");
			EndIf;
		EndIf;
	ElsIf TreeRow.DeletionMark Then
		If IsCurrentObject Then
			If HasSubordinateItemsCumulative And HasParentsCumulative  Then
				AreaName = ?(IsDocument, "DocumentMarkedForDeletionConnectorTopBottom", "CatalogCCTMarkedForDeletionConnectorTopBottom");
				PictureArea = Template.GetArea(AreaName);
			ElsIf HasSubordinateItemsCumulative Then
				AreaName = ?(IsDocument, "DocumentMarkedForDeletionConnectorBottom", "CatalogCCTMarkedForDeletionConnectorBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentMarkedForDeletionConnectorTop", "CatalogCCTMarkedForDeletionConnectorTop");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		ElsIf IsSubordinateDocument = True Then
			If HasSubordinateItems Then
				AreaName = ?(IsDocument, "DocumentMarkedForDeletionConnectorLeftBottom", "CatalogCCTMarkedForDeletionConnectorLeftBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentMarkedForDeletion", "CatalogCCTMarkedForDeletionConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		Else
			If HasSubordinateItems Then
				AreaName = ?(IsDocument, "DocumentMarkedForDeletionConnectorLeftTop", "CatalogCCTMarkedForDeletionConnectorLeftTop");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentMarkedForDeletion", "CatalogCCTMarkedForDeletionConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		EndIf;
	Else
		If IsCurrentObject Then
			If HasSubordinateItemsCumulative And HasParentsCumulative Then
				AreaName = ?(IsDocument, "DocumentWrittenConnectorTopBottom", "CatalogCCTConnectorTopBottom");
				PictureArea = Template.GetArea(AreaName);
			ElsIf HasSubordinateItemsCumulative Then
				AreaName = ?(IsDocument, "DocumentWrittenConnectorDown", "CatalogCCTConnectorBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentWrittenConnectorTop", "CatalogCCTConnectorTop");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		ElsIf IsSubordinateDocument = True Then
			If HasSubordinateItems Then
				AreaName = ?(IsDocument, "DocumentWrittenConnectorLeftBottom", "CatalogCCTConnectorLeftBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentWritten", "CatalogCCTConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		Else
			If HasSubordinateItems Then
				AreaName = ?(IsDocument, "DocumentWrittenConnectorLeftTop", "CatalogCCTConnectorLeftTop");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?(IsDocument, "DocumentWritten", "CatalogCCTConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		EndIf;
	EndIf;
	
	If IsCurrentObject Then
		ReportTable.Put(PictureArea) 
	Else
		ReportTable.Join(PictureArea);
	EndIf;
	
	// Output object.
	ObjectArea = Template.GetArea(?(IsCurrentObject, "CurrentObject", "Object"));
	ObjectArea.Parameters.ObjectPresentation = TreeRow.Presentation;
	ObjectArea.Parameters.Object = TreeRow.Ref;
	ReportTable.Join(ObjectArea);
	
EndProcedure

// Determines whether a vertical connector is to be output to the spreadsheet.
//
// Parameters:
//  LevelUp  - Number - how many levels higher is the 
//                 parent, from which the vertical connector will be drawn.
//  TreeRow  - FormDataTreeItem - an original value tree row
//                  that starts the count.
// Returns:
//   Boolean   - indicates whether output in the vertical connector area is required.
//
&AtServer
Function OutputVerticalConnector(LevelUp, TreeRow, SearchSubordinateDocuments = True)
	
	CurrentRow = TreeRow;
	
	For Indus = 1 To LevelUp Do
		
		CurrentRow = CurrentRow.GetParent();
		If Indus = LevelUp Then
			SearchParent = CurrentRow;
		ElsIf Indus = (LevelUp-1) Then
			SearchRow = CurrentRow;
		EndIf;
		
	EndDo;
	
	If SearchParent = Undefined Then
		If SearchSubordinateDocuments Then
			SubordinateParentItems1 =  TreeSubordinateObjects.GetItems(); 
		Else
			SubordinateParentItems1 =  TreeParentObjects.GetItems();
		EndIf;
	Else
		SubordinateParentItems1 =  SearchParent.GetItems(); 
	EndIf;
	
	Return SubordinateParentItems1.IndexOf(SearchRow) < (SubordinateParentItems1.Count()-1);
	
EndFunction

// Outputs a row with the document, for which a hierarchy is being generated, to the spreadsheet document.
//
// Parameters:
//  Template - SpreadsheetDocument
//
&AtServer
Procedure OutputCurrentObject(Template)
	
	Selection = QueryByObjectsAttributes(MainObject).Execute().Select();
	If Selection.Next() Then
		
		OverridablePresentation = ObjectPresentationForOutput(Selection);
		If OverridablePresentation <> Undefined Then
			AttributesStructure1 = Common.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure1.Presentation = OverridablePresentation;
			OutputPresentationAndPicture(AttributesStructure1, Template, True);
		Else
			AttributesStructure1 = Common.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure1.Presentation = ObjectPresentationForReportOutput(Selection);
			OutputPresentationAndPicture(AttributesStructure1, Template, True);
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  Selection - QueryResultSelection
//          - FormDataTreeItem - a data set used to generate a presentation.
//
// Returns:
//   String - a generated presentation.
//
&AtServer
Function ObjectPresentationForReportOutput(Selection)
	
	ObjectPresentation = Selection.Presentation;
	ObjectMetadata = Selection.Ref.Metadata();
	
	If Common.IsDocument(ObjectMetadata) Then
		If (Selection.DocumentAmount <> 0) And (Selection.DocumentAmount <> NULL) Then
			ObjectPresentation = ObjectPresentation
				+ " " + NStr("en = 'in the amount of';")
				+ " " + Selection.DocumentAmount
				+ " " + Selection.Currency;
		EndIf;
	Else
		ObjectPresentation = ObjectPresentation + " (" + Common.ObjectPresentation(ObjectMetadata) + ")";
	EndIf;
	
	Return ObjectPresentation;
	
EndFunction

// Parameters:
//  TreeRows - FormDataTreeItemCollection
//  Template - SpreadsheetDocument
//  RecursionLevels - Number
//
&AtServer
Procedure OutputSubordinateTreeItems(TreeRows, Template, RecursionLevels = 1)

	For Each TreeRow In TreeRows Do
		
		IsInitialObject = (TreeRow.Ref = InitialObject);
		SubordinateTreeItems = TreeRow.GetItems();
		
		// Output connectors.
		For Level = 1 To RecursionLevels Do
			
			If RecursionLevels > Level Then
				
				If OutputVerticalConnector(RecursionLevels - Level + 1,TreeRow) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
				EndIf;
				
			Else 
				
				If TreeRows.Count() > 1 And (TreeRows.IndexOf(TreeRow) <> (TreeRows.Count() - 1)) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else
					Area = Template.GetArea("ConnectorTopRight");
				EndIf;
				
			EndIf;
			
			Area.Parameters.Document = ?(IsInitialObject, Undefined, TreeRow.Ref);
			
			If Level = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;
		
		OutputPresentationAndPicture(TreeRow, Template, False, True);		
		OutputSubordinateTreeItems(SubordinateTreeItems, Template, RecursionLevels + 1);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OutputHierarchy()

	UpdateHierarchicalTree();

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// Procedures for generating a hierarchical tree of documents.

&AtServer
Procedure UpdateHierarchicalTree()

	If Not MainDocumentAvailable() Then
		
		MessageText = NStr("en = 'The source document is no longer available.';");
		Common.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	Title = Metadata.CommonForms.RelatedDocuments.Presentation()
		+ ": " + Common.SubjectString(MainObject);
	
	GenerateDocumentsTrees();
	OutputSpreadsheetDocument();
	
EndProcedure

&AtServer
Procedure GenerateDocumentsTrees()

	TreeParentObjects.GetItems().Clear();
	TreeSubordinateObjects.GetItems().Clear();
	
	DisplayedObjects = New Map;
	
	OutputParentObjects(MainObject, TreeParentObjects, DisplayedObjects);
	OutputSubordinateObjects(MainObject, TreeSubordinateObjects, DisplayedObjects);
	
EndProcedure

&AtServer
Function MainDocumentAvailable()

	Query = New Query(
	"SELECT ALLOWED
	|	1
	|FROM
	|	&TableName AS Tab
	|WHERE
	|	Tab.Ref = &CurrentObject
	|");
	Query.Text = StrReplace(Query.Text, "&TableName", MainObject.Metadata().FullName()); 
	Query.SetParameter("CurrentObject", MainObject);
	Return Not Query.Execute().IsEmpty();

EndFunction

// Parameters:
//  ListOfObjects - Array
//                 - DocumentRef
//                 - CatalogRef
//                 - ChartOfCharacteristicTypesRef
//
// Returns:
//   Query
//
&AtServer
Function QueryByObjectsAttributes(ListOfObjects)
	
	ObjectsByType = New Map;
	If TypeOf(ListOfObjects) = Type("Array") Then
		For Each CurrentObject In ListOfObjects Do
			Objects = ObjectsByType[CurrentObject.Metadata()];
			If Objects = Undefined Then
				Objects = New Array;
				ObjectsByType[CurrentObject.Metadata()] = Objects;
			EndIf;
			Objects.Add(CurrentObject);
		EndDo; 
	Else
		ObjectsByType[ListOfObjects.Metadata()] = CommonClientServer.ValueInArray(ListOfObjects);
	EndIf;
	
	Query = New Query;
	QueriesTexts = New Array;
	
	For Each ObjectType In ObjectsByType Do

		QueryText = 
			"SELECT ALLOWED
			|	&Date AS Date,
			|	Ref,
			|	&Posted AS Posted,
			|	DeletionMark,
			|	&Sum AS DocumentAmount,
			|	&Currency AS Currency,
			|	&Presentation
			|FROM
			|	&TableName
			|WHERE
			|	Ref IN (&Ref)
			|";
		
		ObjectMetadata = ObjectType.Key;
		QueryText = StrReplace(QueryText, "&TableName", ObjectMetadata.FullName());
		If Common.IsDocument(ObjectMetadata) Then
			AttributeNameAmount    = DocumentAttributeName(ObjectMetadata, "DocumentAmount");
			AttributeNameCurrency   = DocumentAttributeName(ObjectMetadata, "Currency");
			AttributeNamePosted = "Posted";
			TheNameOfThePropsDate     = "Date";
		Else
			AttributeNameAmount    = Undefined;
			AttributeNameCurrency   = Undefined;
			AttributeNamePosted = "False";
			TheNameOfThePropsDate     = "False";
		EndIf;
		
		ReplaceQueryText(QueryText, ObjectMetadata, "&Date", TheNameOfThePropsDate, True);
		ReplaceQueryText(QueryText, ObjectMetadata, "&Posted", AttributeNamePosted, True);
		ReplaceQueryText(QueryText, ObjectMetadata, "&Sum", AttributeNameAmount);
		ReplaceQueryText(QueryText, ObjectMetadata, "&Currency", AttributeNameCurrency);
		
		AddAttributes = AttributesForPresentation(ObjectMetadata.FullName(), ObjectMetadata.Name);
		TextPresentation = "Presentation AS Presentation"; // @query-part
		For IndexOf = 1 To 3 Do
			TextPresentation = TextPresentation + ",
				|	" + ?(AddAttributes.Count() >= IndexOf, AddAttributes[IndexOf - 1], "NULL") 
				+ " AS AdditionalAttribute" + IndexOf; // @query-part
		EndDo;
		QueryText = StrReplace(QueryText, "&Presentation", TextPresentation);
		
		ParameterName = "Ref" + StrReplace(ObjectMetadata.FullName(), ".", "_");
		QueryText = StrReplace(QueryText, "&Ref", "&" + ParameterName);
		Query.SetParameter(ParameterName, ObjectType.Value);
		
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "SELECT"); // @query-part-1, @query-part-2
		EndIf;

		QueriesTexts.Add(QueryText);
		
	EndDo;
	
	Query.Text = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF); // @query-part
	Return Query; 
	
EndFunction

&AtServer
Procedure OutputParentObjects(CurrentObject, ParentTree, DisplayedObjects,
	ServiceObjects = Undefined, IndexOfObjectRelationships = Undefined)
	
	ObjectMetadata = CurrentObject.Metadata();
	AttributesList  = New Array;
	
	If ServiceObjects = Undefined Then 
		ServiceObjects = New Map;
	EndIf;
	
	If IndexOfObjectRelationships = Undefined Then 
		IndexOfObjectRelationships = New Map;
	EndIf;
	
	For Each Attribute In ObjectMetadata.Attributes Do
		
		If Not Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
			Continue;
		EndIf;
		
		For Each Current_Type In Attribute.Type.Types() Do
			
			AttributeMetadata = MetadataOfPropsType(Current_Type);
			If AttributeMetadata.Metadata = Undefined Then
				Continue;
			EndIf;
			
			AttributeValue = CurrentObject[Attribute.Name];
			If ValueIsFilled(AttributeValue)
				And TypeOf(AttributeValue) = Current_Type
				And AttributeValue <> CurrentObject
				And AttributesList.Find(AttributeValue) = Undefined Then
				
				AttributesList.Add(AttributeValue);
			EndIf;
		EndDo;
		
	EndDo;
	
	For Each TabularSection In ObjectMetadata.TabularSections Do
		
		AttributesNames = "";
		TSContent = CurrentObject[TabularSection.Name].Unload(); // ValueTable
		For Each Attribute In TabularSection.Attributes Do

			If Not Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
				Continue;
			EndIf;
				
			For Each Current_Type In Attribute.Type.Types() Do
				AttributeMetadata = MetadataOfPropsType(Current_Type);
				If AttributeMetadata.Metadata = Undefined Then
					Continue;
				EndIf;
	
				AttributesNames = AttributesNames + ?(AttributesNames = "", "", ", ") + Attribute.Name;
				Break;
			EndDo;
			
		EndDo;
		
		TSContent.GroupBy(AttributesNames);
		For Each TSColumn In TSContent.Columns Do
			
			For Each TSRow In TSContent Do
			
				AttributeValue = TSRow[TSColumn.Name];
				ValueMetadata = MetadataOfPropsType(TypeOf(AttributeValue));
				If ValueMetadata.Metadata = Undefined Then
					Continue;
				EndIf;
				
				If AttributeValue = CurrentObject
					Or AttributesList.Find(AttributeValue) <> Undefined Then
					Continue;
				EndIf;
				
				AttributesList.Add(AttributeValue);
			EndDo;
		EndDo;
	EndDo;
	
	If AttributesList.Count() > 0 Then
		ObjectsToOutput = QueryByObjectsAttributes(AttributesList).Execute().Unload();
		ObjectsToOutput.Sort("Date");
		For Each ObjectToOutput In ObjectsToOutput Do 
			
			If IndexOfObjectRelationships[CurrentObject] = ObjectToOutput.Ref Then 
				Continue;
			EndIf;
			
			IndexOfObjectRelationships[CurrentObject] = ObjectToOutput.Ref;
			
			NewRow = AddRowToTree(ParentTree, ObjectToOutput, DisplayedObjects);			
			If NewRow <> Undefined
				And Not ObjectToAddIsAmongParents(ParentTree, ObjectToOutput.Ref) Then
				
				// @skip-check query-in-loop - Recursive algorithm to process a tree.
				OutputParentObjects(ObjectToOutput.Ref, NewRow, DisplayedObjects,
					ServiceObjects, IndexOfObjectRelationships);
				
			ElsIf ServiceObjects[ObjectToOutput.Ref] = Undefined Then 
				
				ServiceObjects[ObjectToOutput.Ref] = True;
				// @skip-check query-in-loop - Recursive algorithm to process a tree.
				OutputParentObjects(ObjectToOutput.Ref, ParentTree, DisplayedObjects,
					ServiceObjects, IndexOfObjectRelationships);
				
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Parameters:
//  AttributeType - Type
// 
// Returns:
//  Structure:
//   * Metadata - MetadataObject
//   * IsDocument - Boolean
//
&AtServerNoContext
Function MetadataOfPropsType(AttributeType)

	Result = New Structure("Metadata, IsDocument", Undefined, False); 
	
	AttributeMetadata = Metadata.FindByType(AttributeType);
	If AttributeMetadata = Undefined Then
		Return Result;
	EndIf;
	
	If Not Common.MetadataObjectAvailableByFunctionalOptions(AttributeMetadata) 
		Or Not AccessRight("View", AttributeMetadata) Then
		Return Result;
	EndIf;
	
	Result.IsDocument = Metadata.Documents.Contains(AttributeMetadata);
	If Not Result.IsDocument
		And Not Metadata.Catalogs.Contains(AttributeMetadata)
		And Not Metadata.ChartsOfCharacteristicTypes.Contains(AttributeMetadata) Then
		Return Result;
	EndIf;
	Result.Metadata = AttributeMetadata;
	Return Result;

EndFunction

// Parameters:
//  ParentRow  - FormDataTree
//                  - FormDataTreeItem
//  SearchObject  - AnyRef
//
// Returns:
//   Boolean
//
&AtServer
Function ObjectToAddIsAmongParents(ParentRow, SearchObject)
	
	If SearchObject = MainObject Then
		Return True;
	EndIf;
	
	If TypeOf(ParentRow) = Type("FormDataTree") Then
		Return False; 
	EndIf;
	
	CurrentParent = ParentRow;
	While CurrentParent <> Undefined Do
		If CurrentParent.Ref = SearchObject Then
			Return True;
		EndIf;
		CurrentParent = CurrentParent.GetParent();
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure ReplaceQueryText(QueryText, ObjectMetadata, WhatToReplace1, Var_AttributeName, DoNotSearchAttributes = False)

	ThereAreProps = DoNotSearchAttributes Or ObjectMetadata.Attributes.Find(Var_AttributeName) <> Undefined; 
	QueryText = StrReplace(QueryText, WhatToReplace1, ?(ThereAreProps, Var_AttributeName,  "NULL"));

EndProcedure

// Returns links to related objects.
// 
// Returns:
//   ValueTable:
//     * Ref - CatalogRef
//              - DocumentRef
//
&AtServer
Function ObjectsByFilterCriteria(FilterCriteriaValue)

	QueryTemplate = "SELECT ALLOWED
	|	TablePresentation.Ref AS Ref
	|FROM
	|	TableName AS TablePresentation
	|WHERE
	|	TablePresentation.AttributeName = &FilterCriteriaValue";

	MergeQueryTemplate = "SELECT
	|	TablePresentation.Ref AS Ref
	|FROM
	|	TableName AS TablePresentation
	|WHERE
	|	TablePresentation.AttributeName = &FilterCriteriaValue";

	QueryParts = New Array;
	TextOfRequestPart = "";

	For Each CompositionItem In Metadata.FilterCriteria.RelatedDocuments.Content Do

		If Not CompositionItem.Type.ContainsType(TypeOf(FilterCriteriaValue)) Then
			Continue;
		EndIf;

		DataPath = CompositionItem.FullName();
		
		If StrFind(DataPath, "TabularSection") Then
			MetadataObject = CompositionItem.Parent().Parent();
		Else
			MetadataObject = CompositionItem.Parent();
		EndIf;
				
		If Not AccessRight("Read", MetadataObject) Then
			Continue;
		EndIf;

		Point = StrFind(DataPath, ".", SearchDirection.FromEnd);
		AttributeName = Mid(DataPath, Point + 1);

		TableName = CompositionItem.Parent().FullName();
		TableName = StrReplace(TableName, "TabularSection.", "");

		Point = StrFind(TableName, ".", SearchDirection.FromEnd);
		TablePresentation = Mid(TableName, Point + 1);

		TextOfRequestPart = ?(TextOfRequestPart = "", QueryTemplate, MergeQueryTemplate);
		TextOfRequestPart = StrReplace(TextOfRequestPart, "TableName", TableName);
		TextOfRequestPart = StrReplace(TextOfRequestPart, "TablePresentation", TablePresentation);
		TextOfRequestPart = StrReplace(TextOfRequestPart, "AttributeName", AttributeName);

		QueryParts.Add(TextOfRequestPart);

	EndDo;

	If QueryParts.Count() > 0 Then
		Query = New Query;
		Separator = Chars.LF + "UNION" + Chars.LF;
		Query.Text = StrConcat(QueryParts, Separator);
		Query.SetParameter("FilterCriteriaValue", FilterCriteriaValue);
		Return Query.Execute().Unload();
	Else
		Return New ValueTable;
	EndIf;

EndFunction

&AtServer
Procedure OutputSubordinateObjects(CurrentObject, ParentTree, DisplayedObjects,
	ServiceObjects = Undefined, IndexOfObjectRelationships = Undefined)
	
	Table = ObjectsByFilterCriteria(CurrentObject);
	If Table = Undefined Then
		Return;
	EndIf;
	
	If ServiceObjects = Undefined Then 
		ServiceObjects = New Map;
	EndIf;
	
	If IndexOfObjectRelationships = Undefined Then 
		IndexOfObjectRelationships = New Map;
	EndIf;
	
	ListOfObjects = New Array;
	For Each TableRow In Table Do

		CurrentRef = TableRow.Ref; // CatalogRef, DocumentRef		
		ObjectMetadata = CurrentRef.Metadata();
		If Not AccessRight("View", ObjectMetadata) Then
			Continue;
		EndIf;

		ListOfObjects.Add(CurrentRef);
	EndDo;
	
	If ListOfObjects.Count() = 0 Then
		Return;
	EndIf;
	
	ObjectsToOutput = QueryByObjectsAttributes(ListOfObjects).Execute().Unload();
	ObjectsToOutput.Sort("Date");

	For Each ObjectToOutput In ObjectsToOutput Do
		
		If IndexOfObjectRelationships[CurrentObject] = ObjectToOutput.Ref Then 
			Continue;
		EndIf;
		
		IndexOfObjectRelationships[CurrentObject] = ObjectToOutput.Ref;
		
		NewRow = AddRowToTree(ParentTree, ObjectToOutput, DisplayedObjects, True);		
		If NewRow <> Undefined
			And Not ObjectToAddIsAmongParents(ParentTree, ObjectToOutput.Ref) Then
			
			// @skip-check query-in-loop - Recursive algorithm to process a tree.
			OutputSubordinateObjects(ObjectToOutput.Ref, NewRow, DisplayedObjects,
				ServiceObjects, IndexOfObjectRelationships);
			
		ElsIf ServiceObjects[ObjectToOutput.Ref] = Undefined Then 
			
			ServiceObjects.Insert(ObjectToOutput.Ref, True);
			// @skip-check query-in-loop - Recursive algorithm to process a tree.
			OutputSubordinateObjects(ObjectToOutput.Ref, ParentTree, DisplayedObjects,
				ServiceObjects, IndexOfObjectRelationships);
			
		EndIf;
		
	EndDo;

EndProcedure

&AtServer
Function AddRowToTree(Parent, Data, DisplayedObjects, IsSubordinateDocument = False)
	
	SetObjectOutputFrequency(Data.Ref, DisplayedObjects, IsSubordinateDocument);	
	If Not NeedOutputCurrentObject(Parent, Data.Ref, DisplayedObjects, IsSubordinateDocument) Then 
		Return Undefined;
	EndIf;
	
	NewRow = Parent.GetItems().Add();
	CommonProperties = "Ref, Presentation, DocumentAmount, Currency, Posted, DeletionMark";
	FillPropertyValues(NewRow, Data, CommonProperties);
	
	OverriddenPresentation = ObjectPresentationForOutput(Data);
	If OverriddenPresentation <> Undefined Then
		NewRow.Presentation = OverriddenPresentation;
	Else
		NewRow.Presentation = ObjectPresentationForReportOutput(Data);
	EndIf;
	
	Return NewRow;
	
EndFunction

&AtServer
Function NeedOutputCurrentObject(Parent, CurrentObject, DisplayedObjects, IsSubordinateDocument, Cancel = False)
	
	WasOutput = DisplayedObjects[CurrentObject];
	If WasOutput = Undefined Then 
		WasOutput = NewObjectOutputFrequencyProperties();
	EndIf;
	
	ObjectProperties = NewObjectProperties();
	ObjectProperties.IsMain2 = (CurrentObject = MainObject);
	ObjectProperties.IsSubordinateDocument = IsSubordinateDocument;
	ObjectProperties.WasOutput = WasOutput;
	
	If ObjectProperties.IsMain2
		Or TheCurrentObjectWasDisplayedInTheBranch(Parent, CurrentObject) Then 
		
		Cancel = True;
	EndIf;
	
	SubordinationStructureOverridable.BeforeOutputLinkedObject(CurrentObject, ObjectProperties, Cancel);
	
	Return Not Cancel;
	
EndFunction

&AtServer
Function NewObjectProperties()
	
	ObjectProperties = New Structure;
	ObjectProperties.Insert("IsMain2", False);
	ObjectProperties.Insert("IsInternal", False);
	ObjectProperties.Insert("IsSubordinateDocument", False);
	ObjectProperties.Insert("WasOutput", NewObjectOutputFrequencyProperties());
	
	Return ObjectProperties;
	
EndFunction

&AtServer
Function TheCurrentObjectWasDisplayedInTheBranch(Parent, CurrentObject, WasOutput = False)
	
	If Parent = Undefined Then 
		Return WasOutput;
	EndIf;
	
	IsString = (TypeOf(Parent) = Type("FormDataTreeItem"));
	
	If IsString And CurrentObject = Parent.Ref Then 
		WasOutput = True;
		Return WasOutput;
	EndIf;

	For Each Item In Parent.GetItems() Do 
		If CurrentObject = Item.Ref Then 
			WasOutput = True;
			Break;
		EndIf;
	EndDo;
	
	If IsString And Not WasOutput Then 
		TheCurrentObjectWasDisplayedInTheBranch(Parent.GetParent(), CurrentObject, WasOutput);
	EndIf;

	Return WasOutput;
	
EndFunction

&AtServer
Procedure SetObjectOutputFrequency(CurrentObject, DisplayedObjects, IsSubordinateDocument)
	
	WasOutput = DisplayedObjects[CurrentObject];
	If WasOutput = Undefined Then 
		WasOutput = NewObjectOutputFrequencyProperties();
	EndIf;
	
	WasOutput.InTotal = WasOutput.InTotal + 1;
	If IsSubordinateDocument Then 
		WasOutput.InSubordinates = WasOutput.InSubordinates + 1;
	EndIf;
	
	DisplayedObjects.Insert(CurrentObject, WasOutput);
	
EndProcedure

&AtServer
Function NewObjectOutputFrequencyProperties()
	
	OutputFrequencyProperties = New Structure;
	OutputFrequencyProperties.Insert("InTotal", 0);
	OutputFrequencyProperties.Insert("InSubordinates", 0);	
	Return OutputFrequencyProperties;
	
EndFunction

&AtServer
Function DocumentAttributeName(Val ObjectMetadata, Val Var_AttributeName) 
	
	AttributesNames = Settings.Attributes[ObjectMetadata.FullName()];
	If AttributesNames <> Undefined Then
		Result = AttributesNames[Var_AttributeName];
		Return ?(Result <> Undefined, Result, Var_AttributeName);
	EndIf;	
	
	// For backward compatibility purposes.
	DocumentAttributeName = SubordinationStructureOverridable.DocumentAttributeName(ObjectMetadata.Name, Var_AttributeName); // ACC:223
	If Var_AttributeName = "DocumentAmount" Then
		Return ?(DocumentAttributeName = Undefined, "DocumentAmount", DocumentAttributeName);
	ElsIf Var_AttributeName = "Currency" Then
		Return ?(DocumentAttributeName = Undefined, "Currency", DocumentAttributeName);
	EndIf;
	
EndFunction

&AtServer
Procedure DefineSettings()
	
	SubsystemSettings = New Structure;
	SubsystemSettings.Insert("Attributes", New Map);
	SubsystemSettings.Insert("AttributesForPresentation", New Map);
	SubordinationStructureOverridable.OnDefineSettings(SubsystemSettings);
	
	Settings = SubsystemSettings;

EndProcedure

&AtServer
Function AttributesForPresentation(Val FullMetadataObjectName, Val MetadataObjectName)
	
	Result = Settings.AttributesForPresentation[FullMetadataObjectName];
	If Result <> Undefined Then
		Return Result;
	EndIf;
	
	// For backward compatibility purposes.
	Return SubordinationStructureOverridable.ObjectAttributesArrayForPresentationGeneration(MetadataObjectName); // ACC:223
	
EndFunction

&AtServer
Function ObjectPresentationForOutput(Data) 
	
	Result = "";
	StandardProcessing = True;	
	SubordinationStructureOverridable.OnGettingPresentation(TypeOf(Data.Ref), Data, Result, StandardProcessing);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	
	// For backward compatibility purposes.
	Return SubordinationStructureOverridable.ObjectPresentationForReportOutput(Data); // ACC:223
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////////////////
// Object state change procedures.

&AtClient
Function SelectedItems()
	
	SelectedItems = New Array;
	
	SelectedAreas = Items.ReportTable.GetSelectedAreas();
	
	For Each SelectedArea1 In SelectedAreas Do 
		
		If TypeOf(SelectedArea1) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		Boundaries = SelectedAreaBorders(SelectedArea1);
		
		For ColumnNumber = Boundaries.Left To Boundaries.Right Do
			
			For LineNumber = Boundaries.Top To Boundaries.Bottom Do
				
				Cell = ReportTable.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				
				If ValueIsFilled(Cell.Details) Then 
					SelectedItems.Add(Cell.Details);
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return SelectedItems;
	
EndFunction

&AtClient
Function SelectedAreaBorders(SelectedArea1)
	
	Boundaries = New Structure("Left, Top, Bottom, Right");
	FillPropertyValues(Boundaries, SelectedArea1);
	
	If Boundaries.Left = 0 Then 
		Boundaries.Left = 1;
	EndIf;
	
	If Boundaries.Top = 0 Then 
		Boundaries.Top = 1;
	EndIf;
	
	If Boundaries.Bottom = 0 Then 
		Boundaries.Bottom = 1;
	EndIf;
	
	If Boundaries.Right = 0 Then 
		Boundaries.Right = 1;
	EndIf;
	
	Return Boundaries;
	
EndFunction

// Modify the deletion mark.

&AtServerNoContext
Function StatisticsBySelectedItems(SelectedItems)
	
	Statistics = New Structure;
	Statistics.Insert("WithDeletionMark", New Map);
	Statistics.Insert("NoDeletionMark", New Map);
	
	ItemsProperties = Common.ObjectsAttributesValues(SelectedItems, "DeletionMark, Presentation");
	
	For Each Item In SelectedItems Do 
		
		ItemProperties = ItemsProperties[Item];
		
		If ItemProperties.DeletionMark Then 
			Statistics.WithDeletionMark.Insert(Item, ItemProperties.Presentation);
		Else
			Statistics.NoDeletionMark.Insert(Item, ItemProperties.Presentation);
		EndIf;
		
	EndDo;
	
	Return Statistics;
	
EndFunction

// Returns:
//  Structure:
//   * Explanation - String
//   * Ref - String
//   * Notification - String
//   * DoQueryBox - String
//   * Check - Boolean
//
&AtClient
Function DeletionMarkEditScenario(SelectedItems, StatisticsBySelectedItems)
	
	Scenario = New Structure;
	Scenario.Insert("Check", False);
	Scenario.Insert("DoQueryBox", "");
	Scenario.Insert("Notification", "");
	Scenario.Insert("Ref", "");
	Scenario.Insert("Explanation", "");
	
	SelectedItemsCount = SelectedItems.Count();
	ObjectsMarkedForDeletionCount = StatisticsBySelectedItems.WithDeletionMark.Count();
	
	If SelectedItemsCount = 1 Then 
		
		Item = SelectedItems[0];
		Scenario.Ref = GetURL(Item);
		
		If ObjectsMarkedForDeletionCount = 0 Then 
			
			ItemPresentation = StatisticsBySelectedItems.NoDeletionMark[Item];
			
			Scenario.Check = True;
			Scenario.Notification = NStr("en = 'Deletion mark set';");
			Scenario.Explanation = ItemPresentation;
			Scenario.DoQueryBox = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to mark %1 for deletion?';"), ItemPresentation);
			
		Else
			
			ItemPresentation = StatisticsBySelectedItems.WithDeletionMark[Item];
			
			Scenario.Notification = NStr("en = 'Deletion mark cleared';");
			Scenario.Explanation = ItemPresentation;
			Scenario.DoQueryBox = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to clear the deletion mark from ""%1""?';"), ItemPresentation);
			
		EndIf;
		
	Else
		
		Scenario.Explanation = Title;
		
		If ObjectsMarkedForDeletionCount = 0 Then 
			
			Scenario.Check = True;
			Scenario.DoQueryBox = NStr("en = 'Do you want to mark the selected items for deletion?';");
			Scenario.Notification = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Deletion mark set (%1)';"), SelectedItemsCount);
		
		ElsIf ObjectsMarkedForDeletionCount = SelectedItemsCount Then 
			
			Scenario.DoQueryBox = NStr("en = 'Clear marks for deletion of the selected items?';");
			Scenario.Notification = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Deletion mark cleared (%1)';"), SelectedItemsCount);
			
		Else
			
			// If some of the items are marked for deletion, 1C:Enterprise will process only them and will clear the deletion mark.
			SelectedItems.Clear();
			
			For Each Item In StatisticsBySelectedItems.WithDeletionMark Do 
				SelectedItems.Add(Item.Key);
			EndDo;
			
			Scenario = DeletionMarkEditScenario(SelectedItems, StatisticsBySelectedItems);
			
		EndIf;
		
	EndIf;
	
	Return Scenario;
	
EndFunction

// Parameters:
//  Response - DialogReturnCode
//  Scenario - See DeletionMarkEditScenario
//
&AtClient
Procedure ExecuteDeletionMarkChangeScenario(Response, Scenario) Export 
	
	If Response <> DialogReturnCode.Yes Then 
		Return;
	EndIf;
	
	Errors = ChangeItemsDeletionMark(Scenario.SelectedItems, Scenario.Check);
	If Errors.Count() > 0 Then 
		WarnAboutAnErrorWhenChangingElements(Errors, "DeletionMark");
	Else
		ShowUserNotification(
			Scenario.Notification,
			Scenario.Ref,
			Scenario.Explanation,
			PictureLib.DialogInformation);
	EndIf;
	CommonClient.NotifyObjectsChanged(Scenario.SelectedItems);
	
EndProcedure

&AtServer
Function ChangeItemsDeletionMark(SelectedItems, Check)
	
	Errors = New Array;
	For Each Item In SelectedItems Do 
		
		BeginTransaction();
		
		Try
			
			Block = New DataLock;
			LockItem = Block.Add(Item.Metadata().FullName());
			LockItem.SetValue("Ref", Item);
			Block.Lock();
			
			SelectedObject = Item.GetObject();
			LockDataForEdit(Item);
			SelectedObject.SetDeletionMark(Check);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Related documents.Change deletion mark';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,, Item,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Errors.Add(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
	EndDo;
	
	UpdateHierarchicalTree();
	Return Errors;
	
EndFunction

&AtClient
Procedure ChangeDocumentsPosting(Mode)
	
	ClearMessages();
	
	SelectedDocuments = SelectedItems();
	If SelectedDocuments.Count() = 0 Then
		Return;
	EndIf;
	
	Errors = New Array;
	ProcessedDocuments = ProcessedDocuments(SelectedDocuments, Mode, Errors);
	ProcessedDocumentsCount = ProcessedDocuments.Count();
	
	If Errors.Count() > 0 Then
		WarnAboutAnErrorWhenChangingElements(Errors, "Posting");
		Return;
	EndIf;
	
	If ProcessedDocumentsCount = 0 Then 
		Return;
	EndIf;
	
	If ProcessedDocumentsCount = 1 Then 
		Document = SelectedDocuments[0];
		Notification = NStr("en = 'Change';");
		Ref = GetURL(Document);
		Explanation = ProcessedDocuments[Document];
	Else
		Ref = "";
		Explanation = Title;
		Notification = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Change (%1)';"), ProcessedDocumentsCount);
	EndIf;
	
	ShowUserNotification(Notification, Ref, Explanation, PictureLib.DialogInformation);
	CommonClient.NotifyObjectsChanged(SelectedDocuments);
	
EndProcedure

&AtServer
Function ProcessedDocuments(SelectedDocuments, Mode, Errors)
	
	ProcessedDocuments = New Map;
	IndexOf = SelectedDocuments.UBound();
	While IndexOf >= 0 Do 
		
		ObjectMetadata = SelectedDocuments[IndexOf].Metadata();
		HoldingIsAllowed = Metadata.ObjectProperties.Posting.Allow;
		
		If Not Common.IsDocument(ObjectMetadata)
			Or ObjectMetadata.Posting <> HoldingIsAllowed Then 
			
			SelectedDocuments.Delete(IndexOf);
		EndIf;
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	If SelectedDocuments.Count() = 0 Then 
		Return ProcessedDocuments;
	EndIf;
	
	DocumentsProperties = Common.ObjectsAttributesValues(SelectedDocuments, "Posted, Presentation");
	IndexOf = SelectedDocuments.UBound();
	While IndexOf >= 0 Do 
		
		Document = SelectedDocuments[IndexOf];
		DocumentProperties = DocumentsProperties[Document];
		If Mode = DocumentWriteMode.UndoPosting And Not DocumentProperties.Posted Then 
			SelectedDocuments.Delete(IndexOf);
			IndexOf = IndexOf - 1;
			Continue;
		EndIf;
		IndexOf = IndexOf - 1;
			
		BeginTransaction();
		Try
			
			Block = New DataLock;
			LockItem = Block.Add(Document.Metadata().FullName());
			LockItem.SetValue("Ref", Document);
			Block.Lock();
			
			SelectedObject = Document.GetObject(); // DocumentObject
			If SelectedObject.CheckFilling() Then 
				LockDataForEdit(Document);
				SelectedObject.Write(Mode);
			EndIf;
			
			ProcessedDocuments.Insert(Document, DocumentProperties.Presentation);
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Related documents.Post documents';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,, Document,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Errors.Add(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
	EndDo;
	
	UpdateHierarchicalTree();
	Return ProcessedDocuments;
	
EndFunction

// Common.

&AtClient
Procedure WarnAboutAnErrorWhenChangingElements(Errors, Scenario)
	
	ErrorsAreMinimized = CommonClientServer.CollapseArray(Errors);
	If ErrorsAreMinimized.Count() = 1 Then 
		WarningText = ErrorsAreMinimized[0];
	Else
		WarningTemplate = ?(Scenario = "DeletionMark", 
			NStr("en = 'Cannot change the following document deletion mark:
				|%1';"),
			NStr("en = 'Cannot post the documents:
				|%1';"));
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			WarningTemplate, StrConcat(ErrorsAreMinimized, Chars.LF));
	EndIf;
	
	ShowMessageBox(, WarningText);
	
EndProcedure

#EndRegion
