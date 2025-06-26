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
	
	FormTitleText = Parameters.FormCaption;
	DefaultTitle = IsBlankString(FormTitleText);
	If Not DefaultTitle Then
		Title = FormTitleText;
	EndIf;
	
	TitleText = "";
	
	If Parameters.TaskCount > 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2)';"),
			?(DefaultTitle, NStr("en = 'Selected tasks';"), FormTitleText),
			String(Parameters.TaskCount));
	ElsIf Parameters.TaskCount = 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 %2';"),
			?(DefaultTitle, NStr("en = 'Selected task';"), FormTitleText),
			String(Parameters.Task));
	Else
		Items.TitleDecoration.Visible = False;
	EndIf;
	Items.TitleDecoration.Title = TitleText;
	
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If AddressingType = 0 Then
		If Not ValueIsFilled(Performer) Then
			Common.MessageToUser(NStr("en = 'The task assignee is not specified.';"),,,
				"Performer", Cancel);
		EndIf;
		Return;
	EndIf;
	
	If Role.IsEmpty() Then
		Common.MessageToUser(NStr("en = 'The task assignee role is not specified.';"),,,
			"Role", Cancel);
		Return;
	EndIf;
	
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesAreSet And MainAddressingObject = Undefined Then
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" field is required.';"),	
				Common.ObjectAttributeValue(Role, "MainAddressingObjectTypes")),,,
				"MainAddressingObject", Cancel);
		Return;
	ElsIf TypesOfAditionalAddressingObjectAreSet And AdditionalAddressingObject = Undefined Then
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" field is required.';"), 
				Common.ObjectAttributeValue(Role, "AdditionalAddressingObjectTypes")),,,
				"AdditionalAddressingObject", Cancel);
		Return;
	EndIf;
	
	If Not IgnoreWarnings 
		And Not BusinessProcessesAndTasksServer.HasRolePerformers(Role, MainAddressingObject, AdditionalAddressingObject) Then
		Common.MessageToUser(
			NStr("en = 'No assignee is assigned to the specified role. (To ignore this warning, select the check box).';"),,,
			"Role", Cancel);
		Items.IgnoreWarnings.Visible = True;
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	AddressingType = 0;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtClient
Procedure RoleOnChange(Item)
	
	AddressingType = 1;
	Performer = Undefined;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtClient
Procedure AddressingTypeOnChange(Item)
	SetItemsState();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Forward(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	Close(ClosingParameters());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAddressingObjectTypes()
	
	MainAddressingObjectTypes = Undefined;
	AdditionalAddressingObjectTypes = Undefined;
	UsedByAddressingObjects = False;
	UsedWithoutAddressingObjects = False;
	
	If Not Role.IsEmpty() Then
		InfoAboutRole = Common.ObjectAttributesValues(Role, 
			"UsedByAddressingObjects,UsedWithoutAddressingObjects,MainAddressingObjectTypes,AdditionalAddressingObjectTypes");
		UsedByAddressingObjects = InfoAboutRole.UsedByAddressingObjects;
		UsedWithoutAddressingObjects = InfoAboutRole.UsedWithoutAddressingObjects;
		If UsedByAddressingObjects Then
			MainAddressingObjectTypes = Common.ObjectAttributeValue(InfoAboutRole.MainAddressingObjectTypes, "ValueType");
			AdditionalAddressingObjectTypes = Common.ObjectAttributeValue(InfoAboutRole.AdditionalAddressingObjectTypes, "ValueType");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetItemsState()
	
	Items.Performer.MarkIncomplete = False;
	Items.Performer.AutoMarkIncomplete = AddressingType = 0;
	Items.Performer.Enabled = AddressingType = 0;
	
	Items.Role.MarkIncomplete = False;
	Items.Role.AutoMarkIncomplete = AddressingType <> 0;
	Items.Role.Enabled = AddressingType <> 0;
	
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
		
	InfoAboutRole = Common.ObjectAttributesValues(Role, 
		"MainAddressingObjectTypes,AdditionalAddressingObjectTypes");
	Items.MainAddressingObject.Title = String(InfoAboutRole.MainAddressingObjectTypes);
	Items.OneMainAddressingObject.Title = String(InfoAboutRole.MainAddressingObjectTypes);
	Items.AdditionalAddressingObject.Title = String(InfoAboutRole.AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesAreSet And TypesOfAditionalAddressingObjectAreSet Then
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = True;
	ElsIf MainAddressingObjectTypesAreSet Then
		Items.OneAddressingObjectGroup.Visible = True;
		Items.TwoAddressingObjectsGroup.Visible = False;
	Else	
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = False;
	EndIf;
		
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		And Not UsedWithoutAddressingObjects;
	Items.OneMainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		And Not UsedWithoutAddressingObjects;
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		And Not UsedWithoutAddressingObjects;
	Items.OneMainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	
EndProcedure

&AtClient
Function ClosingParameters()
	
	Result = New Structure;
	Result.Insert("Performer", ?(ValueIsFilled(Performer), Performer, Undefined));
	Result.Insert("PerformerRole", Role);
	Result.Insert("MainAddressingObject", MainAddressingObject);
	Result.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	Result.Insert("Comment", Comment);
	
	If Result.MainAddressingObject <> Undefined And Result.MainAddressingObject.IsEmpty() Then
		Result.MainAddressingObject = Undefined;
	EndIf;
	
	If Result.AdditionalAddressingObject <> Undefined And Result.AdditionalAddressingObject.IsEmpty() Then
		Result.AdditionalAddressingObject = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
