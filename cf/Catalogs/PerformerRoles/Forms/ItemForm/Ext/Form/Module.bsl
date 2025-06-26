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
	
	Items.GroupOfAddressing.Enabled = Not Object.Predefined;
	If Not Object.Predefined Then
		Items.AddressingObjectsTypesGroup.Enabled = Object.UsedByAddressingObjects;
	EndIf;
	
	UpdateAvailability1();
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject, Object);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.BeforeWriteAtServer(CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("WriteRoleAddressing", WriteParameters, Object.Ref);
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectExchangePlanNodes") Then
		If ValueIsFilled(ValueSelected) Then
			Object.ExchangeNode = ValueSelected;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.UsedByAddressingObjects And Not Object.UsedWithoutAddressingObjects Then
		For Each TableRow In Object.Purpose Do
			If TypeOf(TableRow.UsersType) <> TypeOf(Catalogs.Users.EmptyRef()) Then
				PurposeDescription = Metadata.FindByType(TypeOf(TableRow.UsersType)).Presentation();
				Common.MessageToUser( 
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot use the Role with the refinement: %1.';"), PurposeDescription ),,,
						"UsedByAddressingObjects", Cancel);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsedInOtherAddressingDimensionsContextOnChange(Item)
	Items.AddressingObjectsTypesGroup.Enabled = Object.UsedByAddressingObjects;
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
EndProcedure

&AtClient
Procedure Attachable_Opening(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClient = CommonClient.CommonModule("NationalLanguageSupportClient");
		ModuleNationalLanguageSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectPurpose(Command)
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("en = 'Select role assignment';"),,, NotifyDescription);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateAvailability1()
	
	Items.UsedWithoutOtherAddressingDimensionsContext.Enabled = True;
	Items.UsedInOtherAddressingDimensionsContext.Enabled = True;
	Items.MainAddressingObjectTypes.Enabled = True;
	Items.AdditionalAddressingObjectTypes.Enabled = True;
	
	If GetFunctionalOption("UseExternalUsers") Then
		If Object.Purpose.Count() > 0 Then
			SynonymArray = New Array;
			For Each TableRow In Object.Purpose Do
				SynonymArray.Add(TableRow.UsersType.Metadata().Synonym);
			EndDo;
			Items.SelectPurpose.Title = StrConcat(SynonymArray, ", ");
		EndIf;
	Else
		Items.AssignmentGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Modified = True;
	EndIf;
EndProcedure

#EndRegion
