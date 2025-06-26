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
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		Items.FileVersionsComparisonMethod.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object", "FileComparisonSettings");
	Item.Insert("Setting", "FileVersionsComparisonMethod");
	Item.Insert("Value", FileVersionsComparisonMethod);
	StructuresArray.Add(Item);
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	
	SelectionResult = DialogReturnCode.OK;
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion
