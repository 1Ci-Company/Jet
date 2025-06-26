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
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Quick access to ""%1"" command';"), Parameters.CommandPresentation);
	
	FillTables();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAllUsers

&AtClient
Procedure AllUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(AllUsers, ShortListUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure AllUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersShortListUsers

&AtClient
Procedure ShortListUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(ShortListUsers, AllUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure ShortListUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RevokeCommandAccessFromAllUsers(Command)
	
	ItemsToDragArray = New Array;
	
	For Each RowDescription In ShortListUsers Do
		ItemsToDragArray.Add(RowDescription);
	EndDo;
	
	MoveUsers(AllUsers, ShortListUsers, ItemsToDragArray);
	
EndProcedure

&AtClient
Procedure RevokeCommandAccessFromSelectedUsers(Command)
	
	ItemsToDragArray = New Array;
	
	For Each SelectedRow In Items.ShortListUsers.SelectedRows Do
		ItemsToDragArray.Add(Items.ShortListUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(AllUsers, ShortListUsers, ItemsToDragArray);
	
EndProcedure

&AtClient
Procedure GrantAccessToAllUsers(Command)
	
	ItemsToDragArray = New Array;
	
	For Each RowDescription In AllUsers Do
		ItemsToDragArray.Add(RowDescription);
	EndDo;
	
	MoveUsers(ShortListUsers, AllUsers, ItemsToDragArray);
	
EndProcedure

&AtClient
Procedure GrantCommandAccessToSelectedUsers(Command)
	
	ItemsToDragArray = New Array;
	
	For Each SelectedRow In Items.AllUsers.SelectedRows Do
		ItemsToDragArray.Add(Items.AllUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(ShortListUsers, AllUsers, ItemsToDragArray);
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	SelectionResult = New ValueList;
	
	For Each CollectionItem In ShortListUsers Do
		SelectionResult.Add(CollectionItem.User);
	EndDo;
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillTables()
	SelectedItemsList = Parameters.UsersWithQuickAccess;
	Query = New Query("SELECT Ref FROM Catalog.Users WHERE NOT DeletionMark AND NOT Invalid AND NOT IsInternal");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If SelectedItemsList.FindByValue(Selection.Ref) = Undefined Then
			AllUsers.Add().User = Selection.Ref;
		Else
			ShortListUsers.Add().User = Selection.Ref;
		EndIf;
	EndDo;
	AllUsers.Sort("User Asc");
	ShortListUsers.Sort("User Asc");
EndProcedure

&AtClient
Procedure MoveUsers(Receiver, Source, ItemsToDragArray)
	
	For Each ItemToDrag In ItemsToDragArray Do
		NewUser = Receiver.Add();
		NewUser.User = ItemToDrag.User;
		Source.Delete(ItemToDrag);
	EndDo;
	
	Receiver.Sort("User Asc");
	
EndProcedure

#EndRegion
