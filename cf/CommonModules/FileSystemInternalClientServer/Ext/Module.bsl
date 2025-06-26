///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

Function UniqueFileName(Val FileName) Export
	
	File = New File(FileName);
	BaseName = File.BaseName;
	Extension = File.Extension;
	DirectoryName = File.Path;
	
	Counter = 1;
	While File.Exists() Do
		Counter = Counter + 1;
		File = New File(DirectoryName + BaseName + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.FullName;

EndFunction

#EndRegion