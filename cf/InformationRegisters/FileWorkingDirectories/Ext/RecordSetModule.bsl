///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() = 1 Then
		Folder = Get(0).Folder;
		Path = Get(0).Path;
		
		If IsBlankString(Path) Then
			Return;
		EndIf;						
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FilesFolders.Ref,
			|	FilesFolders.Description
			|FROM
			|	Catalog.FilesFolders AS FilesFolders
			|WHERE
			|	FilesFolders.Parent = &Ref";
		
		Query.SetParameter("Ref", Folder);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			WorkingDirectory = Path;
			// Add the slash sign (same as before) if it's missing. 
			//  It's required on the client side, and "BeforeWrite" runs on the server.
			WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
			
			WorkingDirectory = WorkingDirectory + Selection.Description;
			WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
			
			FilesOperationsInternal.SaveFolderWorkingDirectory(
				Selection.Ref, WorkingDirectory);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf