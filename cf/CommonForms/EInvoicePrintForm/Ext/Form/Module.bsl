
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HTML = Parameters.DocumentString;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Print(Command)
	
	Items.HTML.Document.execCommand("Print");
	
EndProcedure

#EndRegion