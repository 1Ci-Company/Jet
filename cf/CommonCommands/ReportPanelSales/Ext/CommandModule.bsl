
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecutionParameters)
	
	ReportsOptionsClient.ShowReportBar("Sales", ExecutionParameters);
	
EndProcedure

#EndRegion
