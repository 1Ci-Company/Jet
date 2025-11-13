
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	#If MobileClient Then
		Items.Sales.VerticalStretch = False;
		Items.SalesByProduct.VerticalStretch = False;
	#EndIf
	
	OpenFormProcessing();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodOnChange(Item)
	
	PeriodChangeProcessing();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	GenerateAtServer();
	
EndProcedure

&AtClient
Procedure GenerateReportSales(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("VariantKey", "SalesByDate");
	
	OpenForm("Report.Sales.Form", FormParameters, ThisObject, "SalesByDate");
	
EndProcedure

&AtClient
Procedure GenerateReportSalesByProduct(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("VariantKey", "SalesByProduct");
	
	OpenForm("Report.Sales.Form", FormParameters, ThisObject, "SalesByProduct");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateAtServer()
	
	ReportObject = FormAttributeToValue("Report");
	CompositionSchema = ReportObject.GetTemplate("MainDataCompositionSchema");
	
	ReportSettings = Report.SettingsComposer.GetSettings();
	DataCompositionTemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = DataCompositionTemplateComposer.Execute(CompositionSchema, ReportSettings);
	
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate,,, True);
	
	ResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	ReportResult = New SpreadsheetDocument;
	ResultOutputProcessor.SetDocument(ReportResult);
	ResultOutputProcessor.Output(DataCompositionProcessor);
	
	FillInCharts(ReportResult);
	
EndProcedure

&AtServer
Procedure FillInCharts(ReportResult)
	
	SalesChart = ReportResult.Drawings[0].Object;
	
	SalesByProductChart = ReportResult.Drawings[1].Object;
	SalesByProductChart.PointCount = Min(SalesByProductChart.PointCount, 6);
	
EndProcedure

&AtServer
Procedure OpenFormProcessing()
	
	UserSettings = Report.SettingsComposer.UserSettings;
	ParameterPeriod = New DataCompositionParameter("ItmPeriod");
	
	For Each Item In UserSettings.Items Do
		If Item.Parameter = ParameterPeriod Then
			Period = Item.Value;
			Break;
		EndIf;
	EndDo;
	
	GenerateAtServer();
	
EndProcedure

&AtServer
Procedure PeriodChangeProcessing()
	
	UserSettings = Report.SettingsComposer.UserSettings;
	ParameterPeriod = New DataCompositionParameter("ItmPeriod");
	
	For Each Item In UserSettings.Items Do
		If Item.Parameter = ParameterPeriod Then
			Item.Value = Period;
			UserSettingsModified = True;
			Break;
		EndIf;
	EndDo;
	
	GenerateAtServer();
	
EndProcedure

#EndRegion