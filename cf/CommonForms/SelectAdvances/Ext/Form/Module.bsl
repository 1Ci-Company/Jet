
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty = Parameters.Counterparty;
	ExchangeRate = Parameters.ExchangeRate;
	Multiplier = Parameters.Multiplier;
	Currency = Parameters.Currency;
	InvoiceRef = Parameters.InvoiceRef;
	InvoiceAmount = Parameters.InvoiceAmount;
	IsCustomerAdvance = Parameters.IsCustomerAdvance;
	AddressInStorage = Parameters.AddressInStorage;
	
	PresentationCurrency = JetServer.GetPresentationCurrency();
	
	GetAdvClearingFromStorage();
	
	FillAdvanceBalance();
	
	If Currency = PresentationCurrency Then
		Items.AdvanceBalanceAmountCur.Visible = False;
		Items.ClearingAmountCur.Visible = False;
		Items.TotalAmountCur.Visible = False;
	Else
		Items.AdvanceBalanceAmountCur.Visible = True;
		Items.ClearingAmountCur.Visible = True;
		Items.TotalAmountCur.Visible = True;
		
		AmountCurTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Amount (%1)'"),
			Currency);
		Items.AdvanceBalanceAmountCur.Title = AmountCurTitle;
		Items.ClearingAmountCur.Title = AmountCurTitle;
		Items.TotalAmountCur.Title = AmountCurTitle;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CalculateTotals();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAdvanceBalance

&AtClient
Procedure AdvanceBalanceValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	AdvanceBalanceChoiceProcessing();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAdvClearingTable

&AtClient
Procedure AdvClearingTableOnChange(Item)
	
	CalculateTotals();
	FillAdvanceBalance();
	
EndProcedure

&AtClient
Procedure AdvClearingTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ClearingAmountOnChange(Item)
	
	CurrentData = Items.AdvClearingTable.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.AmountCur = JetClientServer.CalculateFromCurrencyToCurrency(CurrentData.Amount,
			1,
			1,
			ExchangeRate,
			Multiplier);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearingAmountCurOnChange(Item)
	
	CurrentData = Items.AdvClearingTable.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Amount = JetClientServer.CalculateFromCurrencyToCurrency(CurrentData.AmountCur,
			ExchangeRate,
			Multiplier);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UpdateAdvances(Command)
	
	FillAdvanceBalance();
	
EndProcedure

&AtClient
Procedure FillInAdvClearing(Command)
	
	AdvClearingTable.Clear();
	FillInAdvClearingServer();
	CalculateTotals();
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	PutAdvClearingToStorage();
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillAdvanceBalance()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdvClearTable.Document AS Document,
	|	AdvClearTable.Amount AS Amount,
	|	AdvClearTable.AmountCur AS AmountCur
	|INTO InvoiceAdvanceClearing
	|FROM
	|	&AdvClearingTable AS AdvClearTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BalanceTable.Document AS Document,
	|	BalanceTable.AmountBalance AS Amount,
	|	CASE
	|		WHEN &ExchangeRate = 0
	|			THEN 0
	|		ELSE CAST(BalanceTable.AmountBalance / &ExchangeRate * &Multiplier AS NUMBER(15, 2))
	|	END AS AmountCur
	|INTO TmpAdvanceBalance
	|FROM
	|	AccumulationRegister.CustomerBalance.Balance(
	|			,
	|			LiabilityType = VALUE(Enum.LiabilityTypes.Advance)
	|				AND Counterparty = &Counterparty) AS BalanceTable
	|
	|UNION ALL
	|
	|SELECT
	|	BalanceRecords.Document,
	|	CASE
	|		WHEN BalanceRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -BalanceRecords.Amount
	|		ELSE BalanceRecords.Amount
	|	END,
	|	CASE
	|		WHEN &ExchangeRate = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN BalanceRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN -(CAST(BalanceRecords.Amount / &ExchangeRate * &Multiplier AS NUMBER(15, 2)))
	|				ELSE CAST(BalanceRecords.Amount / &ExchangeRate * &Multiplier AS NUMBER(15, 2))
	|			END
	|	END
	|FROM
	|	AccumulationRegister.CustomerBalance AS BalanceRecords
	|WHERE
	|	BalanceRecords.Recorder = &Ref
	|	AND BalanceRecords.Counterparty = &Counterparty
	|	AND BalanceRecords.LiabilityType = VALUE(Enum.LiabilityTypes.Advance)
	|
	|UNION ALL
	|
	|SELECT
	|	InvoiceAdvanceClearing.Document,
	|	InvoiceAdvanceClearing.Amount,
	|	InvoiceAdvanceClearing.AmountCur
	|FROM
	|	InvoiceAdvanceClearing AS InvoiceAdvanceClearing
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TmpAdvanceBalance.Document AS Document,
	|	-SUM(TmpAdvanceBalance.Amount) AS Amount,
	|	-SUM(TmpAdvanceBalance.AmountCur) AS AmountCur
	|FROM
	|	TmpAdvanceBalance AS TmpAdvanceBalance
	|
	|GROUP BY
	|	TmpAdvanceBalance.Document
	|
	|HAVING
	|	SUM(TmpAdvanceBalance.Amount) < 0
	|
	|ORDER BY
	|	Document";
	
	If Not IsCustomerAdvance Then
		Query.Text = StrReplace(Query.Text, "AccumulationRegister.CustomerBalance", "AccumulationRegister.SupplierBalance");
	EndIf;
	
	Query.SetParameter("AdvClearingTable", AdvClearingTable.Unload());
	Query.SetParameter("ExchangeRate", ExchangeRate);
	Query.SetParameter("Multiplier", Multiplier);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Ref", InvoiceRef);
	
	QueryResult = Query.Execute();
	
	AdvanceBalance.Load(QueryResult.Unload());
	
EndProcedure

&AtServer
Procedure FillAdvClearingTable(Val AmountToAllocate)
	
	If AmountToAllocate = 0 Then
		Return;
	EndIf;
	
	For Each AdvanceRow In AdvanceBalance Do
		
		If AmountToAllocate = 0 Then
			Break;
		EndIf;
		
		If AdvanceRow.AmountCur <= AmountToAllocate Then
			NewRow = AdvClearingTable.Add();
			FillPropertyValues(NewRow, AdvanceRow);
			AmountToAllocate = AmountToAllocate - AdvanceRow.AmountCur;
		Else
			NewRow = AdvClearingTable.Add();
			FillPropertyValues(NewRow, AdvanceRow);
			NewRow.AmountCur = AmountToAllocate;
			NewRow.Amount = JetClientServer.CalculateFromCurrencyToCurrency(NewRow.AmountCur, ExchangeRate, Multiplier);
			AmountToAllocate = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillInAdvClearingServer()
	
	FillAdvanceBalance();
	FillAdvClearingTable(InvoiceAmount);
	FillAdvanceBalance();
	
EndProcedure

&AtServer
Procedure PutAdvClearingToStorage()
	
	PutToTempStorage(AdvClearingTable.Unload(), AddressInStorage);
	
EndProcedure

&AtServer
Procedure GetAdvClearingFromStorage()
	
	AdvClearingTable.Load(GetFromTempStorage(AddressInStorage));
	
EndProcedure

&AtClient
Procedure AdvanceBalanceChoiceProcessing()
	
	CurrentData = Items.AdvanceBalance.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FilterStructure = New Structure("Document", CurrentData.Document);
	AdvRows = AdvClearingTable.FindRows(FilterStructure);
	
	If AdvRows.Count() > 0 Then
		NewRow = AdvRows[0];
	Else
		NewRow = AdvClearingTable.Add();
		NewRow.Document = CurrentData.Document;
	EndIf;
	
	NewRow.Amount = NewRow.Amount + CurrentData.Amount;
	NewRow.AmountCur = NewRow.AmountCur + CurrentData.AmountCur;
	
	Items.AdvClearingTable.CurrentRow = NewRow.GetID();
	
	CalculateTotals();
	FillAdvanceBalance();
	
EndProcedure

&AtClient
Procedure CalculateTotals()
	
	TotalAmount = AdvClearingTable.Total("Amount");
	TotalAmountCur = AdvClearingTable.Total("AmountCur");
	
EndProcedure

#EndRegion