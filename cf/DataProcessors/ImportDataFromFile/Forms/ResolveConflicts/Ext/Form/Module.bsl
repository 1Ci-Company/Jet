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
	
	SetDataAppearance();
	
	If Parameters.ImportType = "TabularSection" And ValueIsFilled(Parameters.FullTabularSectionName) Then 
		ConflictsList = New Array; // Array of CatalogRef
		
		ObjectArray = StringFunctionsClientServer.SplitStringIntoWordArray(Parameters.FullTabularSectionName);
		If ObjectArray[0] = "Document" Then
			ObjectManager = Documents[ObjectArray[1]];
		ElsIf ObjectArray[0] = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray[1]];
		Else
			Cancel = True;
			Return;
		EndIf;
		
		ObjectManager.FillInListOfAmbiguities(Parameters.FullTabularSectionName, ConflictsList, Parameters.Name, Parameters.ValuesOfColumnsToImport, Parameters.AdditionalParameters);
		
		Items.ConflictResolutionOption.Visible = False;
		Items.TitleDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(Items.TitleDecoration.Title, Parameters.Name);
		Items.TitleDecoration.Visible = True;
		Items.ImportFromFileDecoration.Visible = False;
		Items.CatalogItems.CommandBar.ChildItems.CatalogItemsNewItem.Visible = False;
		For Each Column In Parameters.ValuesOfColumnsToImport Do 
			MappingColumns.Add(Column.Key);
		EndDo;
		Items.TitleRefSearchDecoration.Visible = False;
		
	ElsIf Parameters.ImportType = "PastingFromClipboard" Then
		Items.DataFromFileGroup.Visible = False;
		Items.TitleDecoration.Visible = False;
		Items.ImportFromFileDecoration.Visible = False;
		Items.TitleRefSearchDecoration.Visible = True;
		ConflictsList = Parameters.ConflictsList.UnloadValues();
		MappingColumns = Parameters.MappingColumns;
	Else
		ConflictsList = Parameters.ConflictsList.UnloadValues();
		MappingColumns = Parameters.MappingColumns;
		Items.TitleDecoration.Visible = False;
		Items.ImportFromFileDecoration.Visible = True;
		Items.TitleRefSearchDecoration.Visible = False;
	EndIf;
	IndexOf = 0;
	
	If ConflictsList.Count() = 0 Then
		Cancel = True;
		Return;
	EndIf;
	
	TemporarySpecification = FormAttributeToValue("CatalogItems");
	TemporarySpecification.Columns.Clear();
	AttributesArray = New Array;

	TheFirstControl = ConflictsList.Get(0);
	MetadataObject3 = TheFirstControl.Metadata();
	
	For Each Attribute In TheFirstControl.Metadata().Attributes Do
		If Attribute.Type.Types().Find(Type("ValueStorage")) = Undefined Then
			TemporarySpecification.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
			AttributesArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
		EndIf;
	EndDo;
	
	For Each Attribute In MetadataObject3.StandardAttributes Do
		TemporarySpecification.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		AttributesArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
	EndDo;
	
	For Each Item In Parameters.TableRow Do
		AttributesArray.Add(New FormAttribute("PL_" + Item[IndexOf], New TypeDescription("String"),, Item[1]));
	EndDo;
	
	ChangeAttributes(AttributesArray);
	
	Items.CatalogItems.Height = ConflictsList.Count() + 3;
	
	For Each Item In ConflictsList Do
		String = SelectionOptions.GetItems().Add();
		String.Presentation = String(Item);
		String.Ref = Item.Ref;
		MetadataObject3 = Item.Metadata();
		
		For Each Attribute In MetadataObject3.StandardAttributes Do
			If Attribute.Name = "Code" Or Attribute.Name = "Description" Then
				Substring = String.GetItems().Add();
				Substring.Presentation = Attribute.Presentation() + ":";
				Substring.Value = Item[Attribute.Name];
				Substring.Ref = Item.Ref;
			EndIf;
		EndDo;
		
		For Each Attribute In MetadataObject3.Attributes Do
			Substring = String.GetItems().Add();
			Substring.Presentation = Attribute.Presentation() + ":";
			Substring.Value = Item[Attribute.Name];
			Substring.Ref = Item.Ref;
		EndDo;
	
	EndDo;
	
	For Each Item In ConflictsList Do
		MetadataObject3 = Item.Metadata();
		
		String = CatalogItems.Add();
		String.Presentation = String(Item);
		For Each Column In TemporarySpecification.Columns Do
			If MetadataObject3.Attributes.Find(Column.Name) <> Undefined Then
				Types = New Array;
				Types.Add(TypeOf(String[Column.Name]));
				TypeDetails = New TypeDescription(Types);
				String[Column.Name] = TypeDetails.AdjustValue(Item[Column.Name]);
			EndIf;
		EndDo;
	EndDo;
	
	For Each Column In TemporarySpecification.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.CatalogItems);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "CatalogItems." + Column.Name;
		NewItem.Title = Column.Title;
	EndDo;
	
	If Parameters.ImportType = "PastingFromClipboard" Then
		Separator = "";
		RowWithValues = "";
		For Each Item In Parameters.TableRow Do
			RowWithValues = RowWithValues + Separator + Item[2];
			Separator = ", ";
		EndDo;
		If StrLen(RowWithValues) > 70 Then
			RowWithValues = Left(RowWithValues, 70) + "...";
		EndIf;
		Items.TitleRefSearchDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(Items.TitleRefSearchDecoration.Title,
				RowWithValues);
	Else
		ConvertedItemsCount = 0;
		For Each Item In Parameters.TableRow Do
			
			If Parameters.TableRow.Count() > 3 Then 
				If MappingColumns.FindByValue(Item[IndexOf]) = Undefined Then
					Items_Group = Items.OtherDataFromFile;
					ConvertedItemsCount = ConvertedItemsCount + 1;
				Else
					Items_Group = Items.BasicDataFromFile;
				EndIf;
			Else
				Items_Group = Items.BasicDataFromFile;
			EndIf;
			
			NewItem2 = Items.Add(Item[IndexOf] + "_Val_", Type("FormField"), Items_Group);
			NewItem2.DataPath = "PL_"+Item[IndexOf];
			NewItem2.Title = Item[1];
			NewItem2.Type = FormFieldType.InputField;
			NewItem2.ReadOnly = True;
			ThisObject["PL_" + Item[IndexOf]] = Item[2];
		EndDo;
	EndIf;
	
	Items.OtherDataFromFile.Title = Items.OtherDataFromFile.Title + " (" +String(ConvertedItemsCount) + ")";
	Height = Parameters.TableRow.Count() + ConflictsList.Count() + 7;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CatalogItemsSelection(Item, RowSelected, Field, StandardProcessing)
	CurrentChoiceData = Items.CatalogItems.CurrentData; // AnyRef
	Close(CurrentChoiceData.Ref);
EndProcedure

&AtClient
Procedure ConflictResolutionOptionOnChange(Item)
	Items.CatalogItems.ReadOnly = Not ConflictResolutionOption;
EndProcedure

&AtClient
Procedure SelectionOptionsSelection(Item, RowSelected, Field, StandardProcessing)
	If ValueIsFilled(Item.CurrentData.Ref) And Field.Name="SelectionOptionsValue" Then
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.Ref);
	ElsIf ValueIsFilled(Item.CurrentData.Ref) And Field.Name="SelectionOptionsPresentation" Then
		StandardProcessing = False;
		Close(Items.SelectionOptions.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	Close(Items.SelectionOptions.CurrentData.Ref);
EndProcedure

&AtClient
Procedure NewItem(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDataAppearance()
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("SelectionOptionsValue");
	AppearanceField.Use = True;
	
	FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("SelectionOptions.Value"); 
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled; 
	FilterElement.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

#EndRegion
