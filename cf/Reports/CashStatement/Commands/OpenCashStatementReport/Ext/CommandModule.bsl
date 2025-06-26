
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("BankCashAccount", CommandParameter);
	If TypeOf(CommandParameter) = Type("CatalogRef.CashAccounts") Then
		FilterStructure.Insert("CashType", PredefinedValue("Enum.CashTypes.Cash"));
	Else
		FilterStructure.Insert("CashType", PredefinedValue("Enum.CashTypes.NonCash"));
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "CashStatementContext");
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);
	
	OpenForm("Report.CashStatement.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion