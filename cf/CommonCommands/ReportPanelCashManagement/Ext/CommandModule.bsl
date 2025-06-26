
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecutionParameters)
	
	ReportsOptionsClient.ShowReportBar("CashManagement", ExecutionParameters);
	
EndProcedure

#EndRegion
