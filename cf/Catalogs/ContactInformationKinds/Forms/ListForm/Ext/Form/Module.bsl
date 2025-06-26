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
	
	SetConditionalAppearance();
	
	If Parameters.ContactInformationOwner <> Undefined Then
		SetFilterByContactInfoOwner(Parameters.ContactInformationOwner);
	EndIf;

	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	If CurrentLanguageSuffix = Undefined Then
		
		ListProperties = Common.DynamicListPropertiesStructure();
		
		ListProperties.QueryText = "SELECT
			|	CASE
			|		WHEN CatalogContactInformationKinds.IsFolder
			|			THEN CASE
			|				WHEN CatalogContactInformationKinds.DeletionMark
			|					THEN 1
			|				WHEN CatalogContactInformationKinds.Predefined
			|					THEN 2
			|				ELSE 0
			|			END
			|		WHEN CatalogContactInformationKinds.DeletionMark
			|			THEN 4
			|		WHEN CatalogContactInformationKinds.Predefined
			|			THEN CASE CatalogContactInformationKinds.Type
			|				WHEN VALUE(Enum.ContactInformationTypes.Phone)
			|					THEN 14
			|				WHEN VALUE(Enum.ContactInformationTypes.Email)
			|					THEN 15
			|				WHEN VALUE(Enum.ContactInformationTypes.WebPage)
			|					THEN 16
			|				WHEN VALUE(Enum.ContactInformationTypes.Fax)
			|					THEN 17
			|				WHEN VALUE(Enum.ContactInformationTypes.Other)
			|					THEN 18
			|				WHEN VALUE(Enum.ContactInformationTypes.Address)
			|					THEN 19
			|				WHEN VALUE(Enum.ContactInformationTypes.Skype)
			|					THEN 21
			|				ELSE 3
			|			END
			|		ELSE CASE CatalogContactInformationKinds.Type
			|			WHEN VALUE(Enum.ContactInformationTypes.Phone)
			|				THEN 7
			|			WHEN VALUE(Enum.ContactInformationTypes.Email)
			|				THEN 8
			|			WHEN VALUE(Enum.ContactInformationTypes.WebPage)
			|				THEN 9
			|			WHEN VALUE(Enum.ContactInformationTypes.Fax)
			|				THEN 10
			|			WHEN VALUE(Enum.ContactInformationTypes.Other)
			|				THEN 11
			|			WHEN VALUE(Enum.ContactInformationTypes.Address)
			|				THEN 12
			|			WHEN VALUE(Enum.ContactInformationTypes.Skype)
			|				THEN 20
			|			ELSE 3
			|		END
			|	END AS IconIndex,
			|	CatalogContactInformationKinds.Ref AS Ref,
			|	CASE
			|		WHEN &IsMainLanguage
			|			THEN CatalogContactInformationKinds.Description
			|		ELSE CAST(ISNULL(TypesOfPresentationContactInformation.Description,
			|			CatalogContactInformationKinds.Description) AS STRING(150))
			|	END AS Description,
			|	CatalogContactInformationKinds.AddlOrderingAttribute AS AddlOrderingAttribute,
			|	CatalogContactInformationKinds.Used AS Used,
			|	CatalogContactInformationKinds.IsFolder AS IsFolder
			|FROM
			|	Catalog.ContactInformationKinds AS CatalogContactInformationKinds
			|		LEFT JOIN Catalog.ContactInformationKinds.Presentations AS TypesOfPresentationContactInformation
			|		ON (TypesOfPresentationContactInformation.Ref = CatalogContactInformationKinds.Ref)
			|		AND (TypesOfPresentationContactInformation.LanguageCode = &LanguageCode)
			|WHERE
			|	CatalogContactInformationKinds.Used
			|	AND ISNULL(CatalogContactInformationKinds.Parent.Used, TRUE)";
			
		Common.SetDynamicListProperties(Items.List, ListProperties);
			
		List.Parameters.SetParameterValue("IsMainLanguage", Common.IsMainLanguage());
		List.Parameters.SetParameterValue("LanguageCode", CurrentLanguage().LanguageCode);
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	// Check whether the group is copied.
	If Copy And Var_Group Then
		Cancel = True;
		
		ShowMessageBox(, NStr("en = 'Adding new groups to the catalog is prohibited.';"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData = Items.List.CurrentData;
	If CurrentData.IsFolder Then
		StandardProcessing = False;
		GoToList(Undefined);
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GoToList(Command)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	OpenForm(ListFormName(Items.List.CurrentData.Ref));
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Used");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtServer
Procedure SetFilterByContactInfoOwner(ContactInformationOwner)

	RefType = TypeOf(ContactInformationOwner);
	CatalogMetadata = Metadata.FindByType(RefType);
	If CatalogMetadata = Undefined Then
		Return;
	EndIf;
	CIKindsGroup = ContactsManagerInternalCached.ContactInformationKindGroupByObjectName(
		CatalogMetadata.FullName());

	FilterElement = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Parent");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.Use = True;
	FilterElement.RightValue = CIKindsGroup;

	Items.List.Representation = TableRepresentation.List;
	Title = ?(CIKindsGroup = Undefined, "", CIKindsGroup.Description);

EndProcedure

&AtServerNoContext
Function ListFormName(ContactInformationKindRef)
	
	IsFolder = Common.ObjectAttributesValues(ContactInformationKindRef, "IsFolder,Parent");
	KindGroupRef = ?(IsFolder.IsFolder, ContactInformationKindRef, IsFolder.Parent);
	
	Query = New Query(
		"SELECT
		|CASE
		|	WHEN ContactInformationKinds.PredefinedKindName <> """"
		|	THEN ContactInformationKinds.PredefinedKindName
		|	ELSE ContactInformationKinds.PredefinedDataName
		|END AS PredefinedKindName
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.Ref = &KindGroupRef");
	
	Query.SetParameter("KindGroupRef", KindGroupRef);
	PredefinedKindName = Upper(Query.Execute().Unload().UnloadColumn("PredefinedKindName")[0]);

	BaseTypesNames = New Array;
	BaseTypesNames.Add("Catalog");
	BaseTypesNames.Add("Document");
	BaseTypesNames.Add("BusinessProcess");
	BaseTypesNames.Add("Task");
	BaseTypesNames.Add("ChartOfAccounts");
	BaseTypesNames.Add("ExchangePlan");
	BaseTypesNames.Add("ChartOfCharacteristicTypes");
	BaseTypesNames.Add("ChartOfCalculationTypes");
	For Each BaseTypeName In BaseTypesNames Do
		If StrStartsWith(PredefinedKindName, Upper(BaseTypeName)) Then
			 Return BaseTypeName + "." 
			 	+ Mid(PredefinedKindName, StrLen(BaseTypeName) + 1, StrLen(PredefinedKindName)) 
				+ ".ListForm";
		EndIf;	
	EndDo;
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot go to the %1 list';"), ContactInformationKindRef);
	
EndFunction	
	
#EndRegion