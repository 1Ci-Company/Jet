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

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Title = "";
	Name       = "";
	IDForFormulas = "";
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		TitleLanguage1 = "";
		TitleLanguage2 = "";
	EndIf;
	
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ControlIDFillingForFormulas(Cancel);
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then 
	
		Position = CheckedAttributes.Find("TitleLanguage1");
		If Position<> Undefined Then
			CheckedAttributes.Delete(Position);
		EndIf; 
		
		Position = CheckedAttributes.Find("TitleLanguage2");
		If Position<> Undefined Then
			CheckedAttributes.Delete(Position);
		EndIf;

	EndIf;

EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PropertyManagerInternal.ValueTypeContainsPropertyValues(ValueType) Then
		
		Query = New Query;
		Query.SetParameter("ValuesOwner", Ref);
		Query.Text =
		"SELECT
		|	Properties.Ref AS Ref,
		|	Properties.ValueType AS ValueType
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|WHERE
		|	Properties.AdditionalValuesOwner = &ValuesOwner";
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			NewValueType = Undefined;
			
			If ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
			   And Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectsPropertiesValues",
					"CatalogRef.ObjectPropertyValueHierarchy");
				
			ElsIf ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
			        And Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectPropertyValueHierarchy",
					"CatalogRef.ObjectsPropertiesValues");
				
			EndIf;
			
			If NewValueType <> Undefined Then
				Block = New DataLock;
				LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
				LockItem.SetValue("Ref", Selection.Ref);
				Block.Lock();
				
				CurrentObject = Selection.Ref.GetObject();
				CurrentObject.ValueType = NewValueType;
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
	// Check if the deletion mark was toggled not from the list.
	// Sets of additional attributes and information records.
	ObjectProperties = Common.ObjectAttributesValues(Ref, "DeletionMark");
	Query = New Query;
	Query.Text =
		"SELECT
		|	Sets.Ref AS Ref
		|FROM
		|	&TableName AS Properties
		|		LEFT JOIN Catalog.AdditionalAttributesAndInfoSets AS Sets
		|		ON (Properties.Ref = Sets.Ref)
		|WHERE
		|	Properties.Property = &Property
		|	AND Properties.DeletionMark <> &DeletionMark";
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		TableName = "Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo";
	Else
		TableName = "Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes";
	EndIf;
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Property", Ref);
	Query.SetParameter("DeletionMark", ObjectProperties.DeletionMark);
	
	Result = Query.Execute().Unload();
	
	For Each ResultString1 In Result Do
		PropertySetObject = ResultString1.Ref.GetObject();// CatalogObject.AdditionalAttributesAndInfoSets,
		If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
			FillPropertyValues(PropertySetObject.AdditionalInfo.Find(Ref, "Property"), ObjectProperties);
		Else
			FillPropertyValues(PropertySetObject.AdditionalAttributes.Find(Ref, "Property"), ObjectProperties);
		EndIf;
		
		PropertySetObject.Write();
	EndDo;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Property", Ref);
	Query.Text =
	"SELECT
	|	PropertiesSets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSets
	|WHERE
	|	PropertiesSets.Property = &Property
	|
	|UNION ALL
	|
	|SELECT
	|	PropertiesSets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS PropertiesSets
	|WHERE
	|	PropertiesSets.Property = &Property";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", Selection.Ref);
		Block.Lock();
		
		CurrentObject = Selection.Ref.GetObject();
		// Delete additional attributes.
		IndexOf = CurrentObject.AdditionalAttributes.Count()-1;
		While IndexOf >= 0 Do
			If CurrentObject.AdditionalAttributes[IndexOf].Property = Ref Then
				CurrentObject.AdditionalAttributes.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		// Delete additional information records.
		IndexOf = CurrentObject.AdditionalInfo.Count()-1;
		While IndexOf >= 0 Do
			If CurrentObject.AdditionalInfo[IndexOf].Property = Ref Then
				CurrentObject.AdditionalInfo.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		If CurrentObject.Modified() Then
			CurrentObject.DataExchange.Load = True;
			CurrentObject.Write();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Internal

Procedure OnReadPresentationsAtServer() Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(ThisObject);
	EndIf;
EndProcedure

#EndRegion

#Region Private

Procedure ControlIDFillingForFormulas(Cancel)
	If Not AdditionalProperties.Property("IDCheckForFormulasCompleted") Then
		// Application record.
		If ValueIsFilled(IDForFormulas) Then
			ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.CheckIDUniqueness(IDForFormulas, Ref, Cancel);
		Else
			// Set an ID.
			IDForFormulas = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.UUIDForFormulas(
				TitleForIDGeneration(), Ref);
		EndIf;
	EndIf;
EndProcedure

Function TitleForIDGeneration()

	TitleForID = Title;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
	
		LanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		If ValueIsFilled(LanguageSuffix) Then
			
			If ValueIsFilled(ThisObject["Title" + LanguageSuffix]) Then
				TitleForID = ThisObject["Title" + LanguageSuffix];
			EndIf;
		EndIf;
	EndIf;
	
	Return TitleForID;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf