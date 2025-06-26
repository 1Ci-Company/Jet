///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Fills in a value of an additional order attribute for the object.
//
// Parameters:
//  Object - CatalogObject
//         - ChartOfCharacteristicTypesObject - Object to assign an order attribute value to.
//                                          
//
Procedure SetOrderingAttributeValue(Object) Export
	
	If StandardSubsystemsServer.IsMetadataObjectID(Object) Then
		Return;
	EndIf;
	
	// Checking whether the object has an additional order attribute.
	Information = GetInformationForMoving(Object.Ref.Metadata());
	If Not ObjectHasAdditionalOrderingAttribute(Object, Information) Then
		Return;
	EndIf;
	
	// The order is reassigned upon moving an item to another group.
	If Information.HasParent And Common.ObjectAttributeValue(Object.Ref, "Parent") <> Object.Parent Then
		Object.AddlOrderingAttribute = 0;
	EndIf;
	
	// Calculating a new item order value.
	If Object.AddlOrderingAttribute = 0 Then
		Object.AddlOrderingAttribute =
			ItemOrderSetupInternal.GetNewAdditionalOrderingAttributeValue(
					Information,
					?(Information.HasParent, Object.Parent, Undefined),
					?(Information.HasOwner, Object.Owner, Undefined));
	EndIf;
	
EndProcedure

// Resets a value of an additional order attribute for the object.
//
// Parameters:
//  Source          - CatalogObject
//                    - ChartOfCharacteristicTypesObject - Object copy.
//  CopiedObject - CatalogRef
//                    - ChartOfCharacteristicTypesRef - Object that was copied.
//
Procedure ClearOrderAttributeValue(Source, CopiedObject) Export
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	Information = GetInformationForMoving(Source.Ref.Metadata());
	If ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Source.AddlOrderingAttribute = 0;
	EndIf;
	
EndProcedure

// Returns a structure with information on object metadata.
// 
// Parameters:
//  ObjectMetadata - MetadataObject - metadata of the object being moved.
//
// Returns:
//  Structure - Metadata object information.
//
Function GetInformationForMoving(ObjectMetadata) Export
	
	Information = New Structure;
	
	AttributeMetadata = ObjectMetadata.Attributes.AddlOrderingAttribute;
	
	Information.Insert("FullName",    ObjectMetadata.FullName());
	
	IsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	IsCCT        = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If IsCatalog Or IsCCT Then
		
		Information.Insert("HasGroups", ObjectMetadata.Hierarchical
			And ?(IsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		
		Information.Insert("ForGroups",     (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HasParent",  ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop", ?(Not Information.HasParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HasOwner", ?(IsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("HasGroups",   False);
		Information.Insert("ForGroups",     False);
		Information.Insert("ForItems", True);
		Information.Insert("HasParent", False);
		Information.Insert("HasOwner", False);
		Information.Insert("FoldersOnTop", False);
		
	EndIf;
	
	Return Information;
	
EndFunction

#EndRegion

#Region Internal

// Moves an item up or down in a list.
// 
// Parameters:
//  Ref - CatalogRef
//         - ChartOfCharacteristicTypesRef - the item to be moved
//  ExecutionParameters - See AttachableCommandsClientServer.CommandExecuteParameters
//
Procedure Attachable_MoveItem(Ref, ExecutionParameters) Export
	Direction = ExecutionParameters.CommandDetails.Id;
	ErrorText = ItemOrderSetupInternal.MoveItem(ExecutionParameters.Source, Ref, Direction);
	ExecutionParameters.Result.Text = ErrorText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "ItemOrderSetup";
	Kind.SubmenuName  = "ItemOrderSetup";
	Kind.Title   = NStr("en = 'Item order setup';");
	Kind.FormGroupType = FormGroupType.ButtonGroup;
	Kind.Representation = ButtonGroupRepresentation.Compact;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	ObjectsWithCustomizableOrder = New Array;
	For Each Type In Metadata.DefinedTypes.ObjectWithCustomOrder.Type.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		ObjectsWithCustomizableOrder.Add(MetadataObject.FullName());
	EndDo;
	
	NeedOutputCommands = False;
	For Each Source In Sources.Rows Do
		If ObjectsWithCustomizableOrder.Find(Source.FullName) <> Undefined Then
			NeedOutputCommands = AccessRight("Update", Source.Metadata);
			Break;
		EndIf;
	EndDo;
	If Not NeedOutputCommands Then
		Return;
	EndIf;
	
	Command = Commands.Add();
	Command.Kind = "ItemOrderSetup";
	Command.Id = ItemMovementDirectionUp();
	Command.Presentation = NStr("en = 'Move item up';");
	Command.Order = 1;
	Command.Picture = PictureLib.MoveUp;
	Command.ChangesSelectedObjects = True;
	Command.MultipleChoice = False;
	Command.Handler = "ItemOrderSetup.Attachable_MoveItem";
	Command.ButtonRepresentation = ButtonRepresentation.Picture;
	Command.Purpose = "ForList";
	
	Command = Commands.Add();
	Command.Kind = "ItemOrderSetup";
	Command.Id = ItemMovementDirectionDown();
	Command.Presentation = NStr("en = 'Move item down';");
	Command.Order = 2;
	Command.Picture = PictureLib.MoveDown;
	Command.ChangesSelectedObjects = True;
	Command.MultipleChoice = False;
	Command.Handler = "ItemOrderSetup.Attachable_MoveItem";
	Command.ButtonRepresentation = ButtonRepresentation.Picture;
	Command.Purpose = "ForList";
	
EndProcedure

Function ItemMovementDirectionUp() Export
	Return "Up";
EndFunction

Function ItemMovementDirectionDown() Export
	Return "Down";
EndFunction


#EndRegion

#Region Private

Function ObjectHasAdditionalOrderingAttribute(Object, Information)
	
	If Not Information.HasParent Then
		// The catalog is non-hierarchical, it means that the attribute exists.
		Return True;
		
	ElsIf Object.IsFolder And Not Information.ForGroups Then
		// This is a group, but the order is not assigned to groups.
		Return False;
		
	ElsIf Not Object.IsFolder And Not Information.ForItems Then
		// This is an item, the order is not assigned to items.
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction

// FillOrderingAttributeValue event subscription handler.
// Fills in a value of an additional order attribute for the object.
//
// Parameters:
//  Source - CatalogObject
//           - ChartOfCharacteristicTypesObject - Object being written.
//  Cancel    - Boolean - indicates whether the object record is canceled.
//
Procedure FillOrderingAttributeValue(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return; 
	EndIf;
	
	// Skipping the calculation of a new order if the cancellation flag is set in the handler.
	If Cancel Then
		Return;
	EndIf;
	
	SetOrderingAttributeValue(Source);
	
EndProcedure

#EndRegion
