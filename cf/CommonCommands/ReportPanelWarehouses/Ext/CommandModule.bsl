
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecutionParameters)
	
	ReportsOptionsClient.ShowReportBar("Warehouses", ExecutionParameters);
	
EndProcedure

#EndRegion
