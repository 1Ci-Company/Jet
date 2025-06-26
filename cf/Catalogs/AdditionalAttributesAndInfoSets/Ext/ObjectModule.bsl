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

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Or Not ValueIsFilled(Parent) Then
		For Each AdditionalAttribute In AdditionalAttributes Do
			If AdditionalAttribute.PredefinedSetName <> PredefinedSetName Then
				AdditionalAttribute.PredefinedSetName = PredefinedSetName;
			EndIf;
		EndDo;
		
		For Each AdditionalInfoItem In AdditionalInfo Do
			If AdditionalInfoItem.PredefinedSetName <> PredefinedSetName Then
				AdditionalInfoItem.PredefinedSetName = PredefinedSetName;
			EndIf;
		EndDo;
	EndIf;
	
	If Not IsFolder Then
		// Deleting duplicates and empty rows.
		SelectedProperties = New Map;
		PropertiesToDelete = New Array;
		
		// Additional attributes.
		BankingDetails_ = 0;
		LabelsCount = 0;
		Properties = AdditionalAttributes.Unload().UnloadColumn("Property");
		PropertiesKinds = Common.ObjectsAttributesValues(Properties, "PropertyKind");
		For Each AdditionalAttribute In AdditionalAttributes Do
			
			If AdditionalAttribute.Property.IsEmpty()
			 Or SelectedProperties.Get(AdditionalAttribute.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalAttribute);
			Else
				SelectedProperties.Insert(AdditionalAttribute.Property, True);
			EndIf;
			
			If AdditionalAttribute.DeletionMark Then
				Continue;
			EndIf;
			
			Property = PropertiesKinds.Get(AdditionalAttribute.Property);
			If Not ValueIsFilled(Property) Then
				Continue;
			EndIf;
			
			If Property.PropertyKind = Enums.PropertiesKinds.Labels Then
				LabelsCount = LabelsCount + 1;
			Else
				BankingDetails_ = BankingDetails_ + 1;
			EndIf;
			
		EndDo;
		AttributesCount = Format(BankingDetails_, "NG=");
		LabelCount   = Format(LabelsCount, "NG=");
		
		For Each PropertyToDelete In PropertiesToDelete Do
			AdditionalAttributes.Delete(PropertyToDelete);
		EndDo;
		
		SelectedProperties.Clear();
		PropertiesToDelete.Clear();
		
		// Additional information records.
		For Each AdditionalInfoItem In AdditionalInfo Do
			
			If AdditionalInfoItem.Property.IsEmpty()
			 Or SelectedProperties.Get(AdditionalInfoItem.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalInfoItem);
			Else
				SelectedProperties.Insert(AdditionalInfoItem.Property, True);
			EndIf;
		EndDo;
		
		For Each PropertyToDelete In PropertiesToDelete Do
			AdditionalInfo.Delete(PropertyToDelete);
		EndDo;
		
		// Calculating the number of properties not marked for deletion.
		InfoCount   = Format(AdditionalInfo.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		// Updates content of the top group to use fields
		// of the dynamic list and its settings (filters, …) upon customization.
		If ValueIsFilled(Parent) Then
			PropertyManagerInternal.CheckRefreshGroupPropertiesContent(Parent);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure OnReadPresentationsAtServer() Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf