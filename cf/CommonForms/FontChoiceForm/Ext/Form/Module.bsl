///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormCommandsEventHandlers

&AtClient
Procedure Font_Arial(Command)
	
	Close("Arial");
	
EndProcedure

&AtClient
Procedure Font_Verdana(Command)
	
	Close("Verdana");
	
EndProcedure

&AtClient
Procedure Font_TimesNewRoman(Command)
	
	Close("Times New Roman");
	
EndProcedure

&AtClient
Procedure Other(Command)
	
	Close(-1);
	
EndProcedure

&AtClient
Procedure DefaultFont(Command)
	
	NewShreadsheet = New SpreadsheetDocument;
	Font = NewShreadsheet.Area(1,1,1,1).Font; 
	Close(Font.Name);
	
EndProcedure

#EndRegion
