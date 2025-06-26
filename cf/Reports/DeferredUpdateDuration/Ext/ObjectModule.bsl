///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.HideBulkEmailCommands                              = True;
	Settings.GenerateImmediately                                   = False;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing, StorageAddress)
	
	UpdateStatistics = UpdateStatistics();
	
	StatisticsForChart = UpdateStatistics.Copy();
	UpdateStatistics.GroupBy("Handler, Order, Status", "Duration");
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdateCompletedSuccessfully <> Undefined Then
		LastCheckInformation = NStr("en = 'The report is generated on %1';");
	Else
		LastCheckInformation = NStr("en = 'The report is generated on %1
			|Update is in progress. The information might be incomplete';");
	EndIf;
	LastCheckInformation = StringFunctionsClientServer.SubstituteParametersToString(LastCheckInformation, CurrentSessionDate());
	
	ReportSettings   = SettingsComposer.GetSettings();
	HandlersCount = ReportSettings.DataParameters.Items.Find("MostLongRunningHandlers").Value;
	
	SettingsComposer.Settings.DataParameters.SetParameterValue("LastCheckInformation", LastCheckInformation);
	
	Query = New Query;
	Query.SetParameter("UpdateStatistics", UpdateStatistics);
	Query.Text =
		"SELECT
		|	UpdateStatistics.Handler AS Handler,
		|	UpdateStatistics.Order AS Order,
		|	UpdateStatistics.Duration AS Duration,
		|	UpdateStatistics.Status AS Status
		|INTO UpdateStatistics
		|FROM
		|	&UpdateStatistics AS UpdateStatistics
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 10
		|	UpdateStatistics.Handler AS Handler,
		|	UpdateStatistics.Order AS Order,
		|	UpdateStatistics.Duration AS Duration,
		|	UpdateStatistics.Status AS Status
		|FROM
		|	UpdateStatistics AS UpdateStatistics
		|
		|ORDER BY
		|	Duration DESC";
	If HandlersCount <> 10 Then
		Query.Text = StrReplace(Query.Text, "10", HandlersCount);
	EndIf;
	UpdateStatistics = Query.Execute().Unload();
	
	StandardProcessing = False;
	DCSettings = SettingsComposer.GetSettings();
	ExternalDataSets = New Structure("UpdateStatistics", UpdateStatistics);
	
	DCTemplateComposer = New DataCompositionTemplateComposer;
	DCTemplate = DCTemplateComposer.Execute(DataCompositionSchema, DCSettings, DetailsData);
	
	DCProcessor = New DataCompositionProcessor;
	DCProcessor.Initialize(DCTemplate, ExternalDataSets, DetailsData, True);
	
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	DCResultOutputProcessor.SetDocument(ResultDocument);
	DCResultOutputProcessor.Output(DCProcessor);
	
	ResultDocument.FixedTop = 0;
	ResultDocument.FixedLeft  = 0;
	
	GanttChart(StatisticsForChart, ResultDocument);
	
	ChartTemplate = Undefined;
	For Each Drawing In ResultDocument.Drawings Do
		If Drawing.DrawingType = SpreadsheetDocumentDrawingType.Chart Then
			ChartTemplate = Drawing;
			Break;
		EndIf;
	EndDo;
	
	If ResultDocument.Areas.Count() <> 0 Then
		ResultDocument.Areas.GanttChart.Top = ChartTemplate.Top;
		If ChartTemplate.Width < 200 Then
			ResultDocument.Areas.GanttChart.Width = 200;
		Else
			ResultDocument.Areas.GanttChart.Width = ChartTemplate.Width;
		EndIf;
		ResultDocument.Areas.GanttChart.Height = ChartTemplate.Height;
	EndIf;
	
	ResultDocument.Drawings.Delete(ChartTemplate);
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", UpdateStatistics.Count() = 0);
	
EndProcedure

#EndRegion

#Region Private

Function StatisticsTable1()
	
	Statistics = New ValueTable;
	Statistics.Columns.Add("Begin", New TypeDescription("Date"));
	Statistics.Columns.Add("End", New TypeDescription("Date"));
	Statistics.Columns.Add("Duration", New TypeDescription("Number"));
	Statistics.Columns.Add("Handler", New TypeDescription("String"));
	Statistics.Columns.Add("Order", New TypeDescription("String"));
	Statistics.Columns.Add("Status", New TypeDescription("EnumRef.UpdateHandlersStatuses"));
	
	Return Statistics;
	
EndFunction

Function UpdateStatistics()
	
	StatisticsTable1 = StatisticsTable1();
	
	Query = New Query(
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.Status AS Status,
		|	UpdateHandlers.Version AS Version,
		|	UpdateHandlers.LibraryName AS LibraryName,
		|	UpdateHandlers.ProcessingDuration AS ProcessingDuration,
		|	UpdateHandlers.ExecutionMode AS ExecutionMode,
		|	UpdateHandlers.RegistrationVersion AS RegistrationVersion,
		|	UpdateHandlers.VersionOrder AS VersionOrder,
		|	UpdateHandlers.Id AS Id,
		|	UpdateHandlers.AttemptCount AS AttemptCount,
		|	UpdateHandlers.ExecutionStatistics AS ExecutionStatistics,
		|	UpdateHandlers.ErrorInfo AS ErrorInfo,
		|	UpdateHandlers.Comment AS Comment,
		|	UpdateHandlers.Priority AS Priority,
		|	UpdateHandlers.CheckProcedure AS CheckProcedure,
		|	UpdateHandlers.UpdateDataFillingProcedure AS UpdateDataFillingProcedure,
		|	UpdateHandlers.DeferredProcessingQueue AS DeferredProcessingQueue,
		|	UpdateHandlers.ExecuteInMasterNodeOnly AS ExecuteInMasterNodeOnly,
		|	UpdateHandlers.RunAlsoInSubordinateDIBNodeWithFilters AS RunAlsoInSubordinateDIBNodeWithFilters,
		|	UpdateHandlers.Multithreaded AS Multithreaded,
		|	UpdateHandlers.BatchProcessingCompleted AS BatchProcessingCompleted,
		|	UpdateHandlers.UpdateGroup AS UpdateGroup,
		|	UpdateHandlers.StartIteration AS StartIteration,
		|	UpdateHandlers.DataToProcess AS DataToProcess,
		|	UpdateHandlers.DeferredHandlerExecutionMode AS DeferredHandlerExecutionMode,
		|	UpdateHandlers.Order AS Order
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers");
	HandlersInfoRecords = Query.Execute().Unload();
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	DurationOfUpdateSteps = UpdateInfo.DurationOfUpdateSteps;
	
	For Each HandlerRow In HandlersInfoRecords Do
		HandlerName = HandlerRow.HandlerName;
		ExecutionStatistics = HandlerRow.ExecutionStatistics.Get();
		
		If ExecutionStatistics = Undefined Then
			Continue;
		EndIf;
		
		HandlerProcedureStart = ExecutionStatistics["HandlerProcedureStart"];
		HandlerProcedureCompletion = ExecutionStatistics["HandlerProcedureCompletion"];
		HandlerProcedureDuration = ExecutionStatistics["HandlerProcedureDuration"];
		
		OffsetFromUniDate = CurrentSessionDate() - CurrentUniversalDate();
		
		If HandlerRow.Order = Enums.OrderOfUpdateHandlers.Crucial Then
			OrderAsString = "CriticalOnes";
		ElsIf HandlerRow.Order = Enums.OrderOfUpdateHandlers.Normal Then
			OrderAsString = "Regular";
		Else
			OrderAsString = "NonCriticalOnes";
		EndIf;
		
		If HandlerProcedureStart = Undefined Or HandlerProcedureCompletion = Undefined Then
			StatisticsRow = StatisticsTable1.Add();
			StatisticsRow.Handler = HandlerName;
			StatisticsRow.Begin = ExecutionStatistics["DataProcessingStart"];
			StatisticsRow.End = ExecutionStatistics["DataProcessingCompletion"];
			StatisticsRow.Duration = ExecutionStatistics["ExecutionDuration"];
			StatisticsRow.Status = HandlerRow.Status;
			StatisticsRow.Order = OrderAsString;
		Else
			For IndexOf = 0 To HandlerProcedureStart.UBound() Do
				StatisticsRow = StatisticsTable1.Add();
				StatisticsRow.Handler = HandlerName;
				If HandlerRow.Order = Enums.OrderOfUpdateHandlers.Normal
					And DurationOfUpdateSteps.NonCriticalOnes.Begin <> Undefined
					And HandlerProcedureStart[IndexOf] + OffsetFromUniDate >= DurationOfUpdateSteps.NonCriticalOnes.Begin Then
					StatisticsRow.Handler = StatisticsRow.Handler + "_" + "Noncritical";
					StatisticsRow.Order = "NonCriticalOnes";
				Else
					StatisticsRow.Order = OrderAsString;
				EndIf;
				StatisticsRow.Status = HandlerRow.Status;
				StatisticsRow.Begin = HandlerProcedureStart[IndexOf];
				StatisticsRow.End = HandlerProcedureCompletion[IndexOf];
				StatisticsRow.Duration = HandlerProcedureDuration[IndexOf];
			EndDo;
		EndIf;
	EndDo;
	
	StatisticsTable1.Sort("Begin, Duration DESC");
	
	Return StatisticsTable1;
	
EndFunction

Procedure GanttChart(StatisticsTable1, ResultDocument)
	
	Template = GetTemplate("GanttChart");
	ChartArea = Template.GetArea("Chart");
	GanttChart = ChartArea.Drawings.GanttChart.Object; // GanttChart
	GanttChart.RefreshEnabled = False;
	
	MinimumDuration = 0;
	
	Generator = New RandomNumberGenerator(12);
	Colors = New Map;
	Series = GanttChart.SetSeries(NStr("en = 'Duration';"));
	TooltipTemplate = NStr("en = '%1 sec, from %2 to %3%4';");
	
	InformationRecords = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdateCompleted = (InformationRecords.DeferredUpdateCompletedSuccessfully <> Undefined);
	DurationOfUpdateSteps = InformationRecords.DurationOfUpdateSteps;
	OffsetFromUniDate  = CurrentSessionDate() - CurrentUniversalDate();
	TotalDuration = TotalDuration(DurationOfUpdateSteps);
	DotsParent = New Array;
	StartUpdates = Undefined;
	UpdateEnd  = Undefined;
	For Each UpdateStep In DurationOfUpdateSteps Do
		Begin = UpdateStep.Value.Begin; // Date
		End  = UpdateStep.Value.End; // Date
		If Not ValueIsFilled(Begin) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(End) And Not UpdateCompleted Then
			End = CurrentSessionDate();
		EndIf;
		
		If Not ValueIsFilled(End) Then
			Continue;
		EndIf;
		
		If End - Begin = 0 Then
			Continue;
		EndIf;
		
		StageDuration = End - Begin;
		StepDurationAsString = InfobaseUpdateInternal.StepDurationAsString(StageDuration);
		If UpdateCompleted Then
			PercentageFromTotalDuration = Int((StageDuration / TotalDuration) * 100);
			Var_54_Template = NStr("en = '%1, %2% of the total duration';");
			StepDurationAsString = StringFunctionsClientServer.SubstituteParametersToString(Var_54_Template,
				StepDurationAsString, PercentageFromTotalDuration);
		EndIf;
		
		Point = GanttChart.SetPoint(String(UpdateStep.Key));
		Value = GanttChart.GetValue(Point, Series);
		DurationInterval = Value.Add();
		DurationInterval.Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Start: %1
			|End: %2
			|Duration: %3';"), Begin, End, StepDurationAsString);
		DurationInterval.Begin = Begin - OffsetFromUniDate;
		DurationInterval.End = End - OffsetFromUniDate;
		DurationInterval.Color = NextColor(Colors, UpdateStep.Key, Generator, True);
		
		If ValueIsFilled(Begin)
			And StartUpdates = Undefined Then
			StartUpdates = Begin - OffsetFromUniDate;
		EndIf;
		
		If ValueIsFilled(End) Then
			UpdateEnd = End - OffsetFromUniDate;
		EndIf;
		
		If DotsParent.Find(Point) = Undefined Then
			Point.Font = StyleFonts.ImportantLabelFont;
			DotsParent.Add(Point);
		EndIf;
	EndDo;
	
	AllPoints   = New Array;
	HasData = False;
	For Each StatisticsRow In StatisticsTable1 Do
		If StatisticsRow.Duration = 0 Then
			Continue;
		EndIf;
		
		HasData = True;
		DurationSec = StatisticsRow.Duration / 1000;
		
		If DurationSec >= MinimumDuration Then
			Point = GanttChart.SetPoint(StatisticsRow.Handler, StatisticsRow.Order);
			Value = GanttChart.GetValue(Point, Series);
			
			If AllPoints.Find(Point) = Undefined Then
				AllPoints.Add(Point);
			EndIf;
			
			ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(TooltipTemplate,
				DurationSec,
				StatisticsRow.Begin + OffsetFromUniDate,
				StatisticsRow.End + OffsetFromUniDate);
			
			DurationInterval = Value.Add();
			DurationInterval.Text = ToolTipText;
			DurationInterval.Begin = StatisticsRow.Begin;
			DurationInterval.End = StatisticsRow.End;
			DurationInterval.Color = NextColor(Colors, StatisticsRow.Handler, Generator, True);
		EndIf;
	EndDo;
	
	For Each Point In DotsParent Do
		GanttChart.CollapsePoint(Point, True);
	EndDo;
	GanttChart.LegendArea.Placement = ChartLegendPlacement.None;
	GanttChart.AutoDetectWholeInterval = False;
	GanttChart.VerticalScroll = True;
	If ValueIsFilled(StartUpdates) Then
		GanttChart.SetWholeInterval(StartUpdates, UpdateEnd);
	EndIf;
	
	If HasData Then
		ResultDocument.Put(ChartArea);
	EndIf;
	
EndProcedure

Function TotalDuration(DurationOfUpdateSteps)
	
	Duration = 0;
	For Each UpdateStep In DurationOfUpdateSteps Do
		Begin = UpdateStep.Value.Begin; // Date
		End  = UpdateStep.Value.End; // Date
		If Not ValueIsFilled(Begin) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(End) Then
			Continue;
		EndIf;
		
		If End - Begin = 0 Then
			Continue;
		EndIf;
		
		Duration = Duration + (End - Begin);
	EndDo;
	
	Return Duration;
	
EndFunction

Function NextColor(Colors, HandlerName, Generator, Precise)
	
	Handler = Colors[Precise];
	
	If Handler = Undefined Then
		Handler = New Map;
		Colors[Precise] = Handler;
	EndIf;
	
	Color = Handler[HandlerName];
	
	If Color = Undefined Then
		If Precise Then
			Red = Generator.RandomNumber(32, 192);
			Green = Generator.RandomNumber(32, 192);
			B = Generator.RandomNumber(32, 192);
			Color = New Color(Red, Green, B); //@skip-check new-color - Intended for making the Gantt chart more visually informative.
		Else
			Gray = Generator.RandomNumber(32, 192);
			Color = New Color(Gray, Gray, Gray); //@skip-check new-color - Intended for making the Gantt chart more visually informative.
		EndIf;
		
		Handler[HandlerName] = Color;
	EndIf;
	
	Return Color;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf