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
	
	AttributesTable = GetFromTempStorage(Parameters.ObjectAttributes);
	ValueToFormAttribute(AttributesTable, "ObjectAttributes");
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectCommand(Command)
	SelectItemAndClose();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

&AtClient
Procedure ObjectAttributesSelection(Item, RowSelected, Field, StandardProcessing)
	SelectItemAndClose();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectItemAndClose()
	RowSelected = Items.ObjectAttributes.CurrentData;
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Attribute", RowSelected.Attribute);
	ChoiceParameters.Insert("Presentation", RowSelected.Presentation);
	ChoiceParameters.Insert("ValueType", RowSelected.ValueType);
	ChoiceParameters.Insert("ChoiceMode", RowSelected.ChoiceMode);
	
	Notify("PropertiesObjectAttributeSelection", ChoiceParameters);
	
	Close();
EndProcedure

#EndRegion