
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GenerateAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If MobileClient Then
		Items.Sales.VerticalStretch = False;
		Items.SalesByProduct.VerticalStretch = False;
	#EndIf
	
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
	
	DataCompositionTemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = DataCompositionTemplateComposer.Execute(CompositionSchema,
		Report.SettingsComposer.GetSettings());
	
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

#EndRegion