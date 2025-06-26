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
	
	TooBigFiles = Parameters.TooBigFiles;
	
	MaxFileSize = Int(FilesOperations.MaxFileSize() / (1024 * 1024));
	
	Message = StringFunctionsClientServer.SubstituteParametersToString(
	    NStr("en = 'Some files exceed the size limit (%1 MB) and will not be added to the storage.
	               |Do you want to continue the upload?';"),
	    String(MaxFileSize) );
	
	Title = Parameters.Title;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion
