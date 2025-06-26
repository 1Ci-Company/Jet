
#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RateOnChange(Item)
	
	If Not ValueIsFilled(Object.Description) Then
		Object.Description = String(Object.Rate) + "%";
	EndIf;
	
EndProcedure

#EndRegion
