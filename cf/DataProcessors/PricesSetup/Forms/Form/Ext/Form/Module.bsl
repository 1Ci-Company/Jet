#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PriceAdjustmentMethod = "IncByPercent";
	EffectiveDate = CurrentSessionDate();
	PrevEffectiveDate = EffectiveDate;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EffectiveDateOnChange(Item)
	
	EffectiveDateChangeProcessing();
	
EndProcedure

&AtClient
Procedure PriceTypeOnChange(Item)
	
	PriceTypeChangeProcessing();
	
EndProcedure

&AtClient
Procedure PriceAdjustmentMethodOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ApplyNewPrices(Command)
	
	ModifyProductPrices();
	
EndProcedure

&AtClient
Procedure FillIn(Command)
	
	FillInProcessing();
	
EndProcedure

&AtClient
Procedure Set(Command)
	
	SetPrices();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	Items.AdjustmentPercent.Visible = (PriceAdjustmentMethod = "IncByPercent" Or PriceAdjustmentMethod = "DecByPercent");
	Items.AdjustmentAmount.Visible = (PriceAdjustmentMethod = "IncByAmount" Or PriceAdjustmentMethod = "DecByAmount");
	
EndProcedure

&AtClient
Async Procedure FillInProcessing()
	
	If ProductPrices.Count() > 0 Then
		QuestionText = NStr("en = 'The product list will be filled in again. Continue?'");
		Response = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
		If Response <> DialogReturnCode.Yes Then
			Return;
		EndIf;
	EndIf;
	
	ProductPrices.Clear();
	
	SourcePriceType = Await InputValueAsync(SourcePriceType, NStr("en = 'Select the source price type'"));
	If ValueIsFilled(SourcePriceType) Then
		FillInProcessingAtServer(SourcePriceType);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInProcessingAtServer(PriceTypeToCopy)
	
	Query = New Query;
	Query.SetParameter("Period", EffectiveDate);
	Query.SetParameter("PriceType", PriceType);
	
	If ValueIsFilled(PriceType) And PriceTypeToCopy = PriceType Then
		Query.Text =
		"SELECT
		|	PricesSliceLast.Product AS Product,
		|	PricesSliceLast.Price AS CurrentPrice,
		|	PricesSliceLast.Price AS NewPrice
		|FROM
		|	InformationRegister.Prices.SliceLast(&Period, PriceType = &PriceType) AS PricesSliceLast";
	Else
		Query.Text =
		"SELECT
		|	PricesSliceLast.Product AS Product,
		|	PricesSliceLast.Price AS CurrentPrice
		|INTO TmpCurrentPrices
		|FROM
		|	InformationRegister.Prices.SliceLast(&Period, PriceType = &PriceType) AS PricesSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PricesSliceLast.Product AS Product,
		|	PricesSliceLast.Price AS NewPrice,
		|	ISNULL(TmpCurrentPrices.CurrentPrice, 0) AS CurrentPrice
		|FROM
		|	InformationRegister.Prices.SliceLast(&Period, PriceType = &PriceTypeToCopy) AS PricesSliceLast
		|		LEFT JOIN TmpCurrentPrices AS TmpCurrentPrices
		|		ON PricesSliceLast.Product = TmpCurrentPrices.Product";
		
		Query.SetParameter("PriceTypeToCopy", PriceTypeToCopy);
	EndIf;
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Common.MessageToUser(NStr("en = 'There are no prices for the selected price type.'"));
	Else
		ProductPrices.Load(QueryResult.Unload());
	EndIf;
	
EndProcedure

&AtClient
Procedure ModifyProductPrices()
	
	If (PriceAdjustmentMethod = "IncByPercent" Or PriceAdjustmentMethod = "DecByPercent") And AdjustmentPercent = 0 Then
		CommonClient.MessageToUser(NStr("en = 'Percent is not filled in.'"), ,
			"AdjustmentPercent");
		Return;
	EndIf;
	
	If (PriceAdjustmentMethod = "IncByAmount" Or PriceAdjustmentMethod = "DecByAmount") And AdjustmentAmount = 0 Then
		CommonClient.MessageToUser(NStr("en = 'Amount is not filled in.'"), ,
			"AdjustmentAmount");
		Return;
	EndIf;
	
	For Each PriceRow In ProductPrices Do
		
		If PriceAdjustmentMethod = "IncByPercent" Then
			NewPrice = PriceRow.NewPrice + Round(PriceRow.NewPrice / 100 * AdjustmentPercent, 2);
		ElsIf PriceAdjustmentMethod = "DecByPercent" Then
			NewPrice = PriceRow.NewPrice - Round(PriceRow.NewPrice / 100 * AdjustmentPercent, 2);
		ElsIf PriceAdjustmentMethod = "IncByAmount" Then
			NewPrice = PriceRow.NewPrice + AdjustmentAmount;
		ElsIf PriceAdjustmentMethod = "DecByAmount" Then
			NewPrice = PriceRow.NewPrice - AdjustmentAmount;
		EndIf;
		
		If NewPrice < 0 Then
			NewPrice = 0;
		EndIf;
		
		PriceRow.NewPrice = NewPrice;
		
	EndDo;
	
EndProcedure

&AtClient
Async Procedure SetPrices()
	
	If Not ValueIsFilled(PriceType) Then
		CommonClient.MessageToUser(NStr("en = 'Price type is required.'"), , "PriceType");
		Return;
	EndIf;
	
	If Not ValueIsFilled(EffectiveDate) Then
		CommonClient.MessageToUser(NStr("en = 'Effective date is requred.'"), , "EffectiveDate");
		Return;
	EndIf;
	
	If CheckPricesExist() Then
		QuestionText = NStr("en = 'As of %1, there are saved prices for %2 for products not included in the list. Setting the new prices will delete them. Continue?'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText,
			Format(EffectiveDate, "DLF=D"),
			PriceType);
		Response = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
		If Response <> DialogReturnCode.Yes Then
			Return;
		EndIf;
	EndIf;
	
	SetPricesAtServer();
	
EndProcedure

&AtServer
Procedure SetPricesAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	&EffectiveDate AS Period,
	|	&PriceType AS PriceType,
	|	ProductTable.Product AS Product,
	|	ProductTable.NewPrice AS Price
	|INTO ProductTable
	|FROM
	|	&ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductTable.Product AS Product,
	|	COUNT(*) AS Counter
	|INTO ProductTableCounter
	|FROM
	|	ProductTable AS ProductTable
	|
	|GROUP BY
	|	ProductTable.Product
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductTableCounter.Product AS Product,
	|	ProductTableCounter.Counter AS Counter
	|FROM
	|	ProductTableCounter AS ProductTableCounter
	|WHERE
	|	ProductTableCounter.Counter > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductTable.Period AS Period,
	|	ProductTable.PriceType AS PriceType,
	|	ProductTable.Product AS Product,
	|	ProductTable.Price AS Price
	|FROM
	|	ProductTable AS ProductTable
	|WHERE
	|	ProductTable.Price > 0";
		
	Query.SetParameter("PriceType", PriceType);
	Query.SetParameter("EffectiveDate", EffectiveDate);
	Query.SetParameter("ProductTable", ProductPrices.Unload());
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[2].Select();
	Cancel = False;
	
	While Selection.Next() Do
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 is duplicated.'"),
			Selection.Product);
		Common.MessageToUser(MessageText, , , , Cancel);
	EndDo;
	
	If Cancel Then
		Common.MessageToUser(NStr("en = 'Price changes are not applied.'"));
		Return;
	EndIf;
	
	ResultTable = ResultsArray[3].Unload();
	If ResultTable.Count() > 0 Then
		RecordSet = InformationRegisters.Prices.CreateRecordSet();
		RecordSet.Filter.Period.Set(EffectiveDate);
		RecordSet.Filter.PriceType.Set(PriceType);
		RecordSet.Load(ResultTable);
		RecordSet.Write();
	EndIf;
	
EndProcedure

&AtServer
Function CheckPricesExist()
	
	Result = False;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductTable.Product AS Product
	|INTO ProductTable
	|FROM
	|	&ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TRUE AS VrtField
	|FROM
	|	InformationRegister.Prices AS Prices
	|		LEFT JOIN ProductTable AS ProductTable
	|		ON Prices.Product = ProductTable.Product
	|WHERE
	|	Prices.Period = &EffectiveDate
	|	AND Prices.PriceType = &PriceType
	|	AND ProductTable.Product IS NULL";
	
	Query.SetParameter("PriceType", PriceType);
	Query.SetParameter("EffectiveDate", EffectiveDate);
	Query.SetParameter("ProductTable", ProductPrices.Unload());
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Async Procedure EffectiveDateChangeProcessing()
	
	If PrevEffectiveDate = EffectiveDate Then
		Return;
	EndIf;
	
	If ProductPrices.Count() > 0 Then
		QuestionText = ProductListClearQuestionText();
		Response = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
		If Response <> DialogReturnCode.Yes Then
			EffectiveDate = PrevEffectiveDate;
			Return;
		EndIf;
	EndIf;
	
	ProductPrices.Clear();
	
	PrevEffectiveDate = EffectiveDate;
	
EndProcedure

&AtClient
Async Procedure PriceTypeChangeProcessing()
	
	If PrevPriceType = PriceType Then
		Return;
	EndIf;
	
	If ProductPrices.Count() > 0 Then
		QuestionText = ProductListClearQuestionText();
		Response = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
		If Response <> DialogReturnCode.Yes Then
			PriceType = PrevPriceType;
			Return;
		EndIf;
	EndIf;
	
	ProductPrices.Clear();
	
	PrevPriceType = PriceType;
	
EndProcedure

&AtClient
Function ProductListClearQuestionText()
	
	Return NStr("en = 'The product list will be cleared. Continue?'");
	
EndFunction

#EndRegion