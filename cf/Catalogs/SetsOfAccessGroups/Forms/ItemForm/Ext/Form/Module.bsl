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
	
	ReadOnly = True;
	
	ChoiceList = Items.SetItemsType.ChoiceList;
	AddListItem(ChoiceList, "AccessGroups");
	AddListItem(ChoiceList, "UserGroups");
	AddListItem(ChoiceList, "Users");
	AddListItem(ChoiceList, "ExternalUsersGroups");
	AddListItem(ChoiceList, "ExternalUsers");
	
	SetAttributesPageByType(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SetItemsTypeOnChange(Item)
	
	SetAttributesPageByType(ThisObject);
	Object.Groups.Clear();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
	ShowMessageBox(,
		NStr("en = 'It is recommended that you do not change the access group set as it is mapped to different access keys.
		           |To resolve the issue, delete the access group set or
		           |delete the mapping between the set and the access keys in the registers, and then run the access update.';"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddListItem(ChoiceList, CatalogName)
	
	BlankID = CommonClientServer.BlankUUID();
	
	ChoiceList.Add(Catalogs[CatalogName].GetRef(BlankID),
		Metadata.Catalogs[CatalogName].Presentation());
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetAttributesPageByType(Form)
	
	If TypeOf(Form.Object.SetItemsType) = Type("CatalogRef.Users")
	 Or TypeOf(Form.Object.SetItemsType) = Type("CatalogRef.ExternalUsers") Then
		
		Form.Items.SetsAttributes.CurrentPage = Form.Items.SingleUserSetAttributes;
	Else
		Form.Items.SetsAttributes.CurrentPage = Form.Items.GroupsSetAttributes;
	EndIf;
	
EndProcedure

#EndRegion
