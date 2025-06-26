
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Product", CommandParameter);
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "AvailableStockContext");
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);
	
	OpenForm("Report.AvailableStock.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
