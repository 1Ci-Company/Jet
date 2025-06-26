
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
	OpenForm("Catalog.Companies.ObjectForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion