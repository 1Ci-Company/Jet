///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Returns the metadata object selection parameters for the procedure  
// "StandardSubsystemsClient.SelectMetadataObjects".
// 
// Returns:
//  Structure:
//    * MetadataObjectsToSelectCollection - ValueList - Filter by the types of metadata objects that can be selected. 
//				For example, to select only Catalogs and Documents:
//					MetadataObjectsToSelectCollection = New ValueList;
//					MetadataObjectsToSelectCollection.Add("Catalogs");
//					MetadataObjectsToSelectCollection.Add("Documents");
//
//    * FilterByMetadataObjects - ValueList - Filter by selectable metadata objects. 
//				For example:
//					FilterByMetadataObjects = New ValueList;
//					FilterByMetadataObjects.Add("Catalog.Goods");
//					FilterByMetadataObjects.Add("Document.ProformaInvoice");
//    * SelectedMetadataObjects - ValueList - Full names of the metadata objects that should be marked 
//    			in the metadata tree.
//    * ChoiceInitialValue - String - The full name of the metadata object where the pointer is positioned by default
//              when the form opens. For example, "Catalog.Partners".
//    * SelectSingle - Boolean - Set to "True" to select a single metadata object. In this case, the user cannot select multiple rows,
//              only double-click one row. By default, it is set to "False".
//    * ChooseRefs - Boolean - Set to "True" to return references to metadata object IDs
//    			instead of their names. By default, it is set to "False".
//    			See "Common.MetadataObjectIDs".
//    * SelectCollectionsWhenAllObjectsSelected - Boolean - By default, "False". When grouping objects by kind, set the parameter to "True"
//    			to make sure that the return value includes metadata object types 
//    			(Configuration, Catalogs, Documents, etc.) in case all their child rows are selected.
//    * ShouldSelectExternalDataSourceTables - Boolean - By default, it is set to "False" for compatibility. 
//    * Title - String - If not specified, the form opens with the default title: "Select metadata objects".
//    * ObjectsGroupMethod - String - Set to "BySections" to display the metadata object tree by API sections
//    			(that is, subsystems that are part of the API) instead of type-wise grouping (Catalogs, Documents, etc.).
//    			By default, it is set to "ByKinds". Also, you can set it to "BySections,ByKinds" or "ByKinds,BySections".
//    			In this case, the form has radio buttons for switching the grouping option. 
//    			
//    * ParentSubsystems - ValueList - Specify a list of child subsystems that should be displayed 
//				on the form. 
//    * SubsystemsWithCIOnly - Boolean - Set to "True" to keep only API subsystems (API sections) in the list. 
//				By default, "False".
//    * UUIDSource - UUID - (Optional) The form's UID to be passed to the notification "SelectMetadataObjects"
//				as the "Source" parameter.
//				 
// 
Function MetadataObjectsSelectionParameters() Export
	
	FormParameters = New Structure;
	FormParameters.Insert("MetadataObjectsToSelectCollection", New ValueList);
	FormParameters.Insert("FilterByMetadataObjects", New ValueList);
	FormParameters.Insert("SelectedMetadataObjects", New ValueList);
	FormParameters.Insert("ChoiceInitialValue", "");
	FormParameters.Insert("SelectSingle", False);
	FormParameters.Insert("ChooseRefs", False);
	FormParameters.Insert("SelectCollectionsWhenAllObjectsSelected", False);
	FormParameters.Insert("ShouldSelectExternalDataSourceTables", False);
	FormParameters.Insert("Title", "");
	FormParameters.Insert("ObjectsGroupMethod", "ByKinds");
	FormParameters.Insert("ParentSubsystems", New ValueList);
	FormParameters.Insert("SubsystemsWithCIOnly", False);
	FormParameters.Insert("UUIDSource", Undefined);
	Return FormParameters;	
	
EndFunction

#EndRegion
