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

#Region EventHandlers

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
//
// Parameters:
//   Form - ClientApplicationForm - Report form.
//   Cancel - Boolean - passed from the OnCreateAtServer standard handler parameters "as it is".
//   StandardProcessing - Boolean - passed from the OnCreateAtServer standard handler parameters "as it is".
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	// Adding commands to the command bar.
	If Users.IsFullUser() Then
		
		ModuleReportsServer = Common.CommonModule("ReportsServer");
		
		Command = Form.Commands.Add("ProgressDelayUpdateDependencies");
		Command.Action  = "Attachable_Command";
		Command.Title = NStr("en = 'Handler dependences';");
		Command.ToolTip = NStr("en = 'View dependencies for selected handler';");
		Command.Picture  = PictureLib.GrayedAll;
		ModuleReportsServer.OutputCommand(Form, Command, "Settings");
		
		Command = Form.Commands.Add("ProgressDeferredUpdateErrors");
		Command.Action  = "Attachable_Command";
		Command.Title = NStr("en = 'View errors';");
		Command.ToolTip = NStr("en = 'View errors in Event log';");
		Command.Picture  = PictureLib.EventLog;
		ModuleReportsServer.OutputCommand(Form, Command, "Settings");
	EndIf;
	
EndProcedure

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	DCSettings = SettingsComposer.GetSettings();
	
	ProgressProcessing = DCSettings.DataParameters.Items.Find("ProgressProcessing");
	Period = Undefined;
	If ProgressProcessing.Use Then
		Period = ProgressProcessing.Value;
	EndIf;
	Cache = DCSettings.DataParameters.Items.Find("Cache");
	
	CurrentCacheValue = DCSettings.DataParameters.Items.Find("Cache").Value;
	ResultTable2 = Undefined;
	If ValueIsFilled(CurrentCacheValue) Then
		ResultTable2 = GetFromTempStorage(CurrentCacheValue);
	EndIf;
	Cache_Result = DCSettings.DataParameters.Items.Find("Cache_Result").Value
		And DCSettings.DataParameters.Items.Find("Cache_Result").Use;
	
	If Not Cache_Result Or ResultTable2 = Undefined Then
		ResultTable2 = RegisteredObjects(Period);
	EndIf;
	
	PutToTempStorage(ResultTable2, Cache.Value);
	
	ExternalDataSets = New Structure("ResultTable2", ResultTable2);
	
	DCTemplateComposer = New DataCompositionTemplateComposer;
	DCTemplate = DCTemplateComposer.Execute(DataCompositionSchema, DCSettings, DetailsData);
	
	DCProcessor = New DataCompositionProcessor;
	DCProcessor.Initialize(DCTemplate, ExternalDataSets, DetailsData, True);
	
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	DCResultOutputProcessor.SetDocument(ResultDocument);
	DCResultOutputProcessor.Output(DCProcessor);
	
	ResultDocument.ShowRowGroupLevel(2);
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ResultTable2.Count() = 0);
	
EndProcedure

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
	
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.OnLoadVariantAtServer = True;
	Settings.Events.OnLoadUserSettingsAtServer = True;
	Settings.Events.OnDefineSelectionParameters = True;
	
EndProcedure

Procedure OnLoadVariantAtServer(Form, NewDCSettings) Export
	DCParameter = Form.Report.SettingsComposer.Settings.DataParameters.Items.Find("Cache");
	DCParameter.Value = PutToTempStorage(Undefined, Form.UUID);
	
	DCParameter = Form.Report.SettingsComposer.Settings.DataParameters.Items.Find("CachePriorities");
	DCParameter.Value = PutToTempStorage(Undefined, Form.UUID);
EndProcedure

// Parameters:
//   Form - ClientApplicationForm
//   NewDCUserSettings - DataCompositionUserSettings
//
Procedure OnLoadUserSettingsAtServer(Form, NewDCUserSettings) Export

	If Form.Report.SettingsComposer.UserSettings.AdditionalProperties.Property("FiltersValuesCache") Then
		Form.Report.SettingsComposer.UserSettings.AdditionalProperties.FiltersValuesCache.Clear();
	EndIf;
	
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
	If SettingProperties.DCField = New DataCompositionField("DataParameters.ProgressProcessing") Then
		SettingProperties.ValuesForSelection.Add(Format(BegOfDay(CurrentSessionDate()), "DLF=D") + " " + "00:00:00", NStr("en = 'Over whole period';"));
		AvailablePeriods(SettingProperties.ValuesForSelection);
	ElsIf SettingProperties.DCField = New DataCompositionField("DataParameters.Cache_Result") Then
		SettingProperties.OutputFlagOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function AvailablePeriods(AvailablePeriods)
	
	Query = New Query;
	Query.Text =
		"SELECT DISTINCT
		|	UpdateProgress.IntervalHour AS IntervalHour
		|FROM
		|	InformationRegister.UpdateProgress AS UpdateProgress";
	Result = Query.Execute().Unload();
	
	For Each String In Result Do
		If Day(String.IntervalHour) = Day(CurrentSessionDate()) Then
			FormatString = "DLF=T";
		Else
			FormatString = "DLF=DT";
		EndIf;
		
		IntervalPresentation = "From1 %1";
		IntervalPresentation = StrTemplate(IntervalPresentation, Format(String.IntervalHour, FormatString));
		
		AvailablePeriods.Add(String(String.IntervalHour), IntervalPresentation);
	EndDo;
	
	Return AvailablePeriods;
	
EndFunction

Function RegisteredObjects(SelectedIntervals)
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	InfobaseUpdate.Ref AS Ref
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	InfobaseUpdate.Temporary = FALSE";
	Result = Query.Execute().Unload();
	NodesArray = Result.UnloadColumn("Ref");
	NodesList = New ValueList;
	NodesList.LoadValues(NodesArray);
	
	ResultTable2 = New ValueTable;
	ResultTable2.Columns.Add("ConfigurationSynonym");
	ResultTable2.Columns.Add("FullName");
	ResultTable2.Columns.Add("ObjectType");
	ResultTable2.Columns.Add("Presentation");
	ResultTable2.Columns.Add("MetadataType");
	ResultTable2.Columns.Add("ObjectCount");
	ResultTable2.Columns.Add("Queue");
	ResultTable2.Columns.Add("HandlerUpdates");
	ResultTable2.Columns.Add("Status");
	ResultTable2.Columns.Add("ProcessedForInterval", New TypeDescription("Number"));
	ResultTable2.Columns.Add("TotalObjectCount", New TypeDescription("Number"));
	ResultTable2.Columns.Add("HasErrors", New TypeDescription("Boolean"));
	ResultTable2.Columns.Add("ProblemInData", New TypeDescription("Boolean"));
	
	ExchangePlanContent = Metadata.ExchangePlans.InfobaseUpdate.Content;
	PresentationMap = New Map;
	
	ConfigurationSynonym = Metadata.Synonym;
	QueryText = "";
	Query       = New Query;
	Query.SetParameter("NodesList", NodesList);
	Restriction  = 0;
	For Each ExchangePlanItem In ExchangePlanContent Do
		MetadataObject = ExchangePlanItem.Metadata;
		If Not AccessRight("Read", MetadataObject) Then
			Continue;
		EndIf;
		Presentation    = MetadataObject.Presentation();
		FullName        = MetadataObject.FullName();
		FullNameParts = StrSplit(FullName, ".");
		
		// Convert "CalculationRegister.BaseEarnings.Recalculation.BasicAccrualsRecalculation.Changes"
		// into "CalculationRegister.BaseEarnings.BasicAccrualsRecalculation.Changes".
		If FullNameParts[0] = "CalculationRegister" And FullNameParts.Count() = 4 And FullNameParts[2] = "Recalculation" Then
			FullNameParts.Delete(2); // Remove the extra Recalculation.
			FullName = StrConcat(FullNameParts, ".");
		EndIf;
		// Contextual translation.
		QueryText = QueryText + ?(QueryText = "", "", "UNION ALL") + "
			|SELECT
			|	""&MetadataTypePresentation"" AS MetadataType,
			|	""&ObjectType"" AS ObjectType,
			|	""&FullName"" AS FullName,
			|	Node.Queue AS Queue,
			|	COUNT(*) AS ObjectCount
			|FROM
			|	&ChangesTable
			|WHERE
			|	Node IN (&NodesList)
			|GROUP BY
			|	Node
			|";
		QueryText = StrReplace(QueryText, "&MetadataTypePresentation", MetadataTypePresentation(FullNameParts[0]));
		QueryText = StrReplace(QueryText, "&ObjectType", FullNameParts[1]);
		QueryText = StrReplace(QueryText, "&FullName", FullName);
		QueryText = StrReplace(QueryText, "&ChangesTable", FullName + ".Changes");
		
		Restriction = Restriction + 1;
		PresentationMap.Insert(FullNameParts[1], Presentation);
		If Restriction = 200 Then
			Query.Text = QueryText;
			Selection = Query.Execute().Select(); // @skip-check query-in-loop - Batch selection (to avoid heavy queries).
			While Selection.Next() Do
				String = ResultTable2.Add();
				FillPropertyValues(String, Selection);
				String.ConfigurationSynonym = ConfigurationSynonym;
				String.Presentation = PresentationMap[String.ObjectType];
			EndDo;
			Restriction  = 0;
			QueryText = "";
			PresentationMap = New Map;
		EndIf;
		
	EndDo;
	
	If QueryText <> "" Then
		Query.Text = QueryText;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			String = ResultTable2.Add();
			FillPropertyValues(String, Selection);
			String.ConfigurationSynonym = ConfigurationSynonym;
			String.Presentation = PresentationMap[String.ObjectType];
		EndDo;
	EndIf;
	
	DataProcessingProgress         = DataProcessingProgress(SelectedIntervals);
	ErrorsWhenExecutingHandlers = ErrorsWhenExecutingHandlers();
	ProblemswithDatainHandlers   = ProblemswithDatainHandlers();
	
	Handlers = InfobaseUpdateInternal.HandlersForDeferredDataRegistration();
	For Each Handler In Handlers Do
		HandlerData1 = Handler.DataToProcess.Get();
		HandlerName = Handler.HandlerName;
		ProcessorStatus = Handler.Status;
		
		If DataProcessingProgress = Undefined Then
			ObjectsProcessed = 0;
		Else
			FilterParameters = New Structure;
			FilterParameters.Insert("HandlerName", HandlerName);
			Rows = DataProcessingProgress.FindRows(FilterParameters);
			ObjectsProcessed = 0;
			For Each String In Rows Do
				ObjectsProcessed = ObjectsProcessed + String.ObjectsProcessed;
			EndDo;
		EndIf;
		
		For Each ObjectData2 In HandlerData1.HandlerData Do
			FullObjectName = ObjectData2.Key;
			Queue    = ObjectData2.Value.Queue;
			Count = ObjectData2.Value.Count;
			
			FilterParameters = New Structure;
			FilterParameters.Insert("FullName", FullObjectName);
			FilterParameters.Insert("Queue", Queue);
			Rows = ResultTable2.FindRows(FilterParameters);
			For Each String In Rows Do
				If Not ValueIsFilled(String.HandlerUpdates) Then
					String.HandlerUpdates = HandlerName;
				Else
					String.HandlerUpdates = String.HandlerUpdates + "," + Chars.LF + HandlerName;
				EndIf;
				String.TotalObjectCount = String.TotalObjectCount + Count;
				If ObjectsProcessed > String.TotalObjectCount Then
					ObjectsProcessed = String.TotalObjectCount;
				EndIf;
				String.ProcessedForInterval = ObjectsProcessed;
				String.Status = ProcessorStatus;
				If ErrorsWhenExecutingHandlers[HandlerName] = True Then
					String.HasErrors = True;
				EndIf;
				If ProblemswithDatainHandlers[HandlerName] = True Then
					String.ProblemInData = True;
				EndIf;
			EndDo;
			
			// Whole object is processed.
			If Rows.Count() = 0 Then
				String = ResultTable2.Add();
				FullNameParts = StrSplit(FullObjectName, ".");
				
				String.ConfigurationSynonym = ConfigurationSynonym;
				String.FullName     = FullObjectName;
				String.ObjectType    = FullNameParts[1];
				String.Presentation = Common.MetadataObjectByFullName(FullObjectName).Presentation();
				String.MetadataType = MetadataTypePresentation(FullNameParts[0]);
				String.Queue       = Queue;
				String.HandlerUpdates = HandlerName;
				String.TotalObjectCount = String.TotalObjectCount + Count;
				String.ObjectCount = 0;
				If ObjectsProcessed > String.TotalObjectCount Then
					ObjectsProcessed = String.TotalObjectCount;
				EndIf;
				String.ProcessedForInterval = ObjectsProcessed;
				String.Status = ProcessorStatus;
				If ErrorsWhenExecutingHandlers[HandlerName] = True Then
					String.HasErrors = True;
				EndIf;
				If ProblemswithDatainHandlers[HandlerName] = True Then
					String.ProblemInData = True;
				EndIf;
			EndIf;
			
		EndDo;
	EndDo;
	
	Filter = New Structure;
	Filter.Insert("HandlerUpdates", Undefined);
	SearchResult = ResultTable2.FindRows(Filter);
	
	For Each String In SearchResult Do
		ResultTable2.Delete(String);
	EndDo;
	
	Return ResultTable2;
	
EndFunction

Function DataProcessingProgress(SelectedInterval)
	
	If SelectedInterval = Undefined Then
		Return Undefined;
	EndIf;
	
	DateDetails = New TypeDescription("Date");
	GivenDateValue = DateDetails.AdjustValue(SelectedInterval);
	If Not ValueIsFilled(GivenDateValue) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("IntervalHour", GivenDateValue);
	Query.Text =
	"SELECT
	|	UpdateProgress.HandlerName AS HandlerName,
	|	SUM(UpdateProgress.ObjectsProcessed) AS ObjectsProcessed
	|FROM
	|	InformationRegister.UpdateProgress AS UpdateProgress
	|WHERE
	|	UpdateProgress.IntervalHour >= &IntervalHour
	|
	|GROUP BY
	|	UpdateProgress.HandlerName";
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

Function ErrorsWhenExecutingHandlers()
	HandlersWithProblems = New Map;
	
	Query = New Query;
	Query.SetParameter("DeferredHandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Parallel);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.ExecutionStatistics AS ExecutionStatistics
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.DeferredHandlerExecutionMode = &DeferredHandlerExecutionMode";
	Result = Query.Execute().Unload();
	For Each RowHandler In Result Do
		ExecutionStatistics = RowHandler.ExecutionStatistics.Get();
		If ExecutionStatistics = Undefined Then
			Continue;
		EndIf;
		
		If ExecutionStatistics["HasErrors"] <> Undefined
			And ExecutionStatistics["HasErrors"] Then
			HandlersWithProblems.Insert(RowHandler.HandlerName, True);
		EndIf;
	EndDo;
	
	Return HandlersWithProblems;
EndFunction

Function ProblemswithDatainHandlers()
	
	ProblemsByHandler = New Map;
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAudit = Common.CommonModule("AccountingAudit");
		ErrorsByTypesofChecks = ModuleAccountingAudit.DetailedInformationOnChecksKinds("IBVersionUpdate", False);
		For Each Error In ErrorsByTypesofChecks Do
			CheckKind = Error.CheckKind;
			HandlerName = Common.ObjectAttributeValue(CheckKind, "Property2");
			ProblemsByHandler.Insert(HandlerName, True);
		EndDo;
	EndIf;
	
	Return ProblemsByHandler;
	
EndFunction

Function MetadataTypePresentation(MetadataType)
	
	Map = New Map;
	Map.Insert("Constant", NStr("en = 'Constants';"));
	Map.Insert("Catalog", NStr("en = 'Catalogs';"));
	Map.Insert("Document", NStr("en = 'Documents';"));
	Map.Insert("ChartOfCharacteristicTypes", NStr("en = 'Charts of characteristic types';"));
	Map.Insert("ChartOfAccounts", NStr("en = 'Charts of accounts';"));
	Map.Insert("ChartOfCalculationTypes", NStr("en = 'Charts of calculation types';"));
	Map.Insert("InformationRegister", NStr("en = 'Information registers';"));
	Map.Insert("AccumulationRegister", NStr("en = 'Accumulation registers';"));
	Map.Insert("AccountingRegister", NStr("en = 'Accounting registers';"));
	Map.Insert("CalculationRegister", NStr("en = 'Calculation registers';"));
	Map.Insert("BusinessProcess", NStr("en = 'Business processes';"));
	Map.Insert("Task", NStr("en = 'Tasks';"));
	
	Return Map[MetadataType];
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf