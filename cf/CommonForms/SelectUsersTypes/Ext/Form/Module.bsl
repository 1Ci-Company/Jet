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
	
	Title = Parameters.Title;
	
	PresentationsArray = ?(Parameters.IsFilter,
		StringFunctionsClientServer.SplitStringIntoSubstringsArray(Parameters.Purpose, ", "),
		Undefined);
	
	If Parameters.SelectUsersAllowed Then
		AddTypeRow(Catalogs.Users.EmptyRef(), Type("CatalogRef.Users"), PresentationsArray);
	EndIf;
	
	If ExternalUsers.UseExternalUsers() Then
		
		BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
		For Each EmptyRef In BlankRefs Do
			AddTypeRow(EmptyRef, TypeOf(EmptyRef), PresentationsArray);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	Close(Purpose);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddTypeRow(Value, Type, PresentationsArray)
	
	Presentation = Metadata.FindByType(Type).Synonym;
	
	If Parameters.IsFilter Then
		Check = PresentationsArray.Find(Presentation) <> Undefined;
	Else
		FilterParameters = New Structure;
		FilterParameters.Insert("UsersType", Value);
		FoundRows = Parameters.Purpose.FindRows(FilterParameters);
		Check = FoundRows.Count() = 1;
	EndIf;
	
	Purpose.Add(Value, Presentation, Check);
	
EndProcedure

#EndRegion