///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Defines the metadata objects in whose manager modules attribute edition is disabled using the
// GetObjectAttributesToLock export function.
//
// For the GetObjectAttributesToLock return value,
// See ObjectAttributesLock.DescriptionOfAttributeToLock
//
// By default, the label field related to the attribute is not locked.
// To lock it, specify the label name in the details of the attribute.
//
// Parameters:
//   Objects - Map of KeyAndValue:
//     * Key - String - a full name of the metadata object attached to the subsystem;
//     * Value - String - empty string.
//
// Example:
//   Object.Insert(Metadata.Documents.SalesOrder.FullName(), "");
//
//   Example of the code to be placed in the object manager module:
//   // See ObjectAttributesLockOverridable.OnDefineLockedAttributes.LockedAttributes
//   
//   	Function GetObjectAttributesToLock() Export
//   	AttributesToLock = New Array;
//   	AttributesToLock.Add("Company");
//   	AttributesToLock.Add("Partner;Partner");
//   	Attribute = ObjectAttributesLock.NewAttributeToLock();
//   	Attribute.Name = "Counterparty";
//   	Attribute.Warning = NStr("en = 'It is not recommended that you change this field if there are documents created'");
//   	AttributesToLock.Add(Attribute);
//   	...
//   Return AttributesToLock;
//   EndFunction
//
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	
	
	
EndProcedure

// Allows overriding the list of locked attributes specified in the object manager module.
//
// Parameters:
//   MetadataObjectName - String - for example, "Catalog.Files".
//   LockedAttributes - Array of See ObjectAttributesLock.DescriptionOfAttributeToLock
//
Procedure OnDefineLockedAttributes(MetadataObjectName, LockedAttributes) Export
	
EndProcedure

#EndRegion
