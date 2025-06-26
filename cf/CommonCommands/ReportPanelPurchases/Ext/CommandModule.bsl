
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecutionParameters)
	
	ReportsOptionsClient.ShowReportBar("Purchases", ExecutionParameters);
	
EndProcedure

#EndRegion
