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
	
	Report = FilesOperationsInternal.FilesImportGenerateReport(Parameters.ArrayOfFilesNamesWithErrors);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportSelection(Item, Area, StandardProcessing)
	
#If Not WebClient Then
	// Path to file.
	If StrFind(Area.Text, ":\") > 0 Or StrFind(Area.Text, ":/") > 0 Then
		FilesOperationsInternalClient.OpenExplorerWithFile(Area.Text);
	EndIf;
#EndIf
	
EndProcedure

#EndRegion
