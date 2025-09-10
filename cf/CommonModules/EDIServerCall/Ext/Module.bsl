#Region Public

Function EDIExecuteCommandTimeConsumingOperation(DocumentsArray, Handler) Export
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DocumentsArray", DocumentsArray);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'EDI exchange'; tr = 'EDI değişimi'");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(Handler,
		ProcedureParameters,
		ExecutionParameters);
	
	Return TimeConsumingOperation;
	
EndFunction

Procedure CheckConnection(Company, EDIProvider, HasErrors) Export
	
	EDIServer.CheckConnection(Company, EDIProvider, HasErrors);
	
EndProcedure

Function EDICommandDescription(CommandName, CommandsAddressInTempStorage) Export
	
	EDICommands = GetFromTempStorage(CommandsAddressInTempStorage);
	
	For Each EDICommand In EDICommands.FindRows(New Structure("CommandNameAtForm", CommandName)) Do
		Return Common.ValueTableRowToStructure(EDICommand);
	EndDo;
	
EndFunction

Function GetEDIState(Document) Export
	
	Return EDIServer.GetEDIState(Document);
	
EndFunction

Function DocumentWasSent(DocumentRef) Export
	
	Return EDIServer.DocumentSent(DocumentRef);
	
EndFunction

Function CounterpartyInfoToCheck(Counterparty) Export
	
	Return EDIServer.CounterpartyInfoToCheck(Counterparty);
	
EndFunction

Procedure PrintDocument(DocumentArray, DecodedString, HasError) Export
	
	EDIServer.PrintDocument(DocumentArray, DecodedString, HasError);
	
EndProcedure

Function GetDocumentID(Document) Export
	
	Return EDIServer.GetDocumentID(Document);
	
EndFunction

Function DownloadDocument(DocumentArray, Path) Export
	
	Return EDIServer.DownloadDocument(DocumentArray, Path);
	
EndFunction

Procedure CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError) Export
	
	EDIServer.CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError);
	
EndProcedure

Function IsTaxpayer(TIN, EDocumentType, Identifier = Undefined) Export
	
	Return  EDIServer.IsTaxpayer(TIN, EDocumentType, Identifier);
	
EndFunction

#EndRegion