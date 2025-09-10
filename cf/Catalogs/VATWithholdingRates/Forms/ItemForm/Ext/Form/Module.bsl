
#Region FormEventHandlers

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.RateNumerator > Object.RateDenominator Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The rate numerator bigger than the denomenator'; tr = 'Oran paydası paydadan daha büyük'"),
			Object.Ref,
			"Object.RateNumerator",
			,
			Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RateNumeratorOnChange(Item)
	
	SetDescription();
	
EndProcedure

&AtClient
Procedure RateDenominatorOnChange(Item)
	
	SetDescription();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetDescription()
	
	Object.Description = Format(Object.RateNumerator, "") + "/" + Format(Object.RateDenominator, "");
	
EndProcedure

#EndRegion
