///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Updates a full-text search index.
Procedure FullTextSearchIndexUpdate() Export
	
	UpdateIndex(NStr("en = 'Update full-text search index';"), False, True);
	
EndProcedure

// Merges full-text search indexes.
Procedure FullTextSearchMergeIndex() Export
	
	UpdateIndex(NStr("en = 'Merge full-text search index';"), True);
	
EndProcedure

// Returns a flag showing whether full-text search index is up-to-date.
//   The UseFullTextSearch functional option is checked in the calling code.
//
// Returns: 
//   Boolean - True - full-text search contains relevant data.
//
Function SearchIndexIsRelevant() Export
	
	State = FullTextSearchStatus();
	Return State = "SearchAllowed";
	
EndFunction

// Check box state for the full-text search setup form.
//
// Returns: 
//   Number - 0 - disabled, 1 - enabled, 2 - settings error; settings are not synchronized.
//
// Example:
//	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
//		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
//		UseFullTextSearch = ModuleFullTextSearchServer.UseSearchFlagValue();
//	Else 
//		Items.FullTextSearchManagementGroup.Visibility = False;
//	EndIf;
//
Function UseSearchFlagValue() Export
	
	State = FullTextSearchStatus();
	If State = "SearchProhibited" Then
		Result = 0;
	ElsIf State = "SearchSettingsError" Then
		Result = 2;
	Else
		Result = 1;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Internal

// Returns the current full text search status depending on settings and relevance.
// Does not throw exceptions.
//
// Returns:
//  String - Valid values are:
//    "SearchAllowed"
//    "SearchProhibited"
//    "UpdatingIndex"
//    "IndexMergeInProgress"
//    "IndexUpdateRequired"
//    "SearchSettingsError"
//
Function FullTextSearchStatus() Export
	
	If GetFunctionalOption("UseFullTextSearch") Then 
		
		If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then 
			
			If CurrentDate() < (FullTextSearch.UpdateDate() + 300) Then 
				Return "SearchAllowed";
			Else
				If FullTextSearchIndexIsUpToDate() Then 
					Return "SearchAllowed";
				ElsIf IndexUpdateBackgroundJobInProgress() Then 
					Return "IndexUpdateInProgress";
				ElsIf MergeIndexBackgroundJobInProgress() Then 
					Return "IndexMergeInProgress";
				Else
					Return "IndexUpdateRequired";
				EndIf;
			EndIf;
			
		Else 
			// Desyncing of the "UseFullTextSearch" constant
			// and the full-text search mode set in the infobase.
			Return "SearchSettingsError";
		EndIf;
		
	Else
		If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then
			// Desyncing of the "UseFullTextSearch" constant
			// and the full-text search mode set in the infobase.
			Return "SearchSettingsError";
		Else 
			Return "SearchProhibited";
		EndIf;
	EndIf;
	
EndFunction

// Metadata object with functional option of full text search usage.
//
// Returns:
//   MetadataObjectFunctionalOption - a functional option metadata 
//
Function UseFullTextSearchFunctionalOption() Export
	
	Return Metadata.FunctionalOptions.UseFullTextSearch;
	
EndFunction

// Returns the state of functional option of full text search usage.
//
// Returns:
//   Boolean - — if True, full-text search is used.
//
Function UseFullTextSearch() Export
	
	Return GetFunctionalOption("UseFullTextSearch");
	
EndFunction


#Region ConfigurationSubsystemsEventHandlers

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not GetFunctionalOption("UseFullTextSearch")
		Or Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled("FullTextSearchInData") Then
		Return;
	EndIf;
	
	State = FullTextSearchStatus();
	If State = "SearchProhibited" Then 
		Return;
	EndIf;
	
	Section = Metadata.Subsystems.Find("Administration");
	If Section = Undefined Then
		Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.FullTextSearchInData.FullName());
		If Sections.Count() = 0 Then 
			Return;
		Else 
			Section = Sections[0];
		EndIf;
	EndIf;
	
	// Search setup error.
	
	ToDoItem = ToDoList.Add();
	ToDoItem.Id = "FullTextSearchInDataSearchSettingsError";
	ToDoItem.HasToDoItems = (State = "SearchSettingsError");
	ToDoItem.Presentation = NStr("en = 'Full-text search not set up';");
	ToDoItem.Form = "DataProcessor.FullTextSearchInData.Form.FullTextSearchAndTextExtractionControl";
	ToDoItem.ToolTip = 
		NStr("en = 'Try toggling the full-text search off and on.';");
	ToDoItem.Owner = Section;
	
	// Index update is required.
	
	If State = "IndexUpdateRequired" Then 
		IndexUpdateDate = FullTextSearch.UpdateDate();
		CurrentDate = CurrentDate(); // ACC:143 - CurrentDate() must be used.
		
		If IndexUpdateDate > CurrentDate Then
			Interval = NStr("en = 'less than one day ago';");
		Else
			Interval = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ago';"),
				Common.TimeIntervalString(IndexUpdateDate, CurrentDate));
		EndIf;
		
		DaysFromLastUpdate = Int((CurrentDate - IndexUpdateDate) / 60 / 60 / 24);
		HasToDoItems = (DaysFromLastUpdate >= 1);
	Else 
		Interval = NStr("en = 'never';");
		HasToDoItems = False;
	EndIf;
	
	ToDoItem = ToDoList.Add();
	ToDoItem.Id = "FullTextSearchInDataIndexUpdateRequired";
	ToDoItem.HasToDoItems = HasToDoItems;
	ToDoItem.Presentation = NStr("en = 'Full-text search index is outdated';");
	ToDoItem.Form = "DataProcessor.FullTextSearchInData.Form.FullTextSearchAndTextExtractionControl";
	ToDoItem.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Last update: %1.';"),
		Interval);
	ToDoItem.Owner = Section;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "FullTextSearchServer.InitializeFullTextSearchFunctionalOption";
	Handler.Version = "1.0.0.1";
	Handler.SharedData = True;
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings.
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FullTextSearchIndexUpdate;
	Dependence.FunctionalOption = UseFullTextSearchFunctionalOption();
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FullTextSearchMergeIndex;
	Dependence.FunctionalOption = UseFullTextSearchFunctionalOption();
	
EndProcedure

#EndRegion

// Sets a value to the UseFullTextSearch constant.
// Used to synchronize a value
// of the "UseFullTextSearch" functional option
// with the value of the "FullTextSearch.GetFullTextSearchMode" function.
//
Procedure InitializeFullTextSearchFunctionalOption() Export
	
	OperationsAllowed = (FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable);
	Constants.UseFullTextSearch.Set(OperationsAllowed);
	
EndProcedure

#EndRegion

#Region Private

#Region ScheduledJobsHandlers

// Handler of the FullTextSearchIndexUpdate scheduled job.
Procedure FullTextSearchUpdateIndexOnSchedule() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FullTextSearchIndexUpdate);
	
	If MergeIndexBackgroundJobInProgress() Then
		Return;
	EndIf;
	
	FullTextSearchIndexUpdate();
	
EndProcedure

// Handler of the FullTextSearchMergeIndex scheduled job.
Procedure FullTextSearchMergeIndexOnSchedule() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FullTextSearchMergeIndex);
	
	If IndexUpdateBackgroundJobInProgress() Then
		Return;
	EndIf;
	
	FullTextSearchMergeIndex();
	
EndProcedure

#EndRegion

#Region SearchBusinessLogic

#Region SearchState

Function IndexUpdateBackgroundJobInProgress()
	
	ScheduledJob = Metadata.ScheduledJobs.FullTextSearchIndexUpdate;
	
	Filter = New Structure;
	Filter.Insert("MethodName", ScheduledJob.MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CurrentBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return CurrentBackgroundJobs.Count() > 0;
	
EndFunction

Function MergeIndexBackgroundJobInProgress()
	
	ScheduledJob = Metadata.ScheduledJobs.FullTextSearchMergeIndex;
	
	Filter = New Structure;
	Filter.Insert("MethodName", ScheduledJob.MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CurrentBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return CurrentBackgroundJobs.Count() > 0;
	
EndFunction

Function FullTextSearchIndexIsUpToDate()
	
	UpToDate = False;
	
	Try
		UpToDate = FullTextSearch.IndexTrue();
	Except
		LogRecord(
			EventLogLevel.Warning, 
			NStr("en = 'Failed to check full-text search index status';"),
			ErrorInfo());
	EndTry;
	
	Return UpToDate;
	
EndFunction

#EndRegion

#Region Searching

Function SearchParameters() Export 
	
	Parameters = New Structure;
	Parameters.Insert("SearchString", "");
	Parameters.Insert("SearchDirection", "FirstPart");
	Parameters.Insert("CurrentPosition", 0);
	Parameters.Insert("SearchInSections", False);
	Parameters.Insert("SearchAreas", New Array);
	
	Return Parameters;
	
EndFunction

Function ExecuteFullTextSearch(SearchParameters) Export 
	
	SearchString = SearchParameters.SearchString;
	Direction = SearchParameters.SearchDirection;
	CurrentPosition = SearchParameters.CurrentPosition;
	SearchInSections = SearchParameters.SearchInSections;
	SearchAreas = SearchParameters.SearchAreas;
	
	PortionSize = 10;
	ErrorDescription = "";
	ErrorCode = "";
	
	SearchResultsList = FullTextSearch.CreateList(SearchString, PortionSize);
	
	If SearchInSections And SearchAreas.Count() > 0 Then
		SearchResultsList.MetadataUse = FullTextSearchMetadataUse.DontUse;
		
		For Each Area In SearchAreas Do
			MetadataObject = Common.MetadataObjectByID(Area.Value, False);
			If TypeOf(MetadataObject) = Type("MetadataObject") Then 
				SearchResultsList.SearchArea.Add(MetadataObject);
			EndIf;
		EndDo;
	EndIf;
	
	Try
		If Direction = "FirstPart" Then
			SearchResultsList.FirstPart();
		ElsIf Direction = "PreviousPart" Then
			SearchResultsList.PreviousPart(CurrentPosition);
		ElsIf Direction = "NextPart" Then
			SearchResultsList.NextPart(CurrentPosition);
		Else 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value in parameter ""%1"". Expected value is ""%2"", ""%3"", or ""%4"".';"),
				"SearchDirection", "FirstPart", "PreviousPart", "NextPart");
		EndIf;
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		ErrorCode = "SearchError";
	EndTry;
	
	If SearchResultsList.TooManyResults() Then 
		ErrorDescription = NStr("en = 'Too many results. Please narrow your search.';");
		ErrorCode = "TooManyResults";
	EndIf;
	
	TotalCount = SearchResultsList.TotalCount();
	
	If TotalCount = 0 Then
		ErrorDescription = NStr("en = 'No results found';");
		ErrorCode = "FoundNothing";
	EndIf;
	
	If IsBlankString(ErrorCode) Then 
		SearchResults = FullTextSearchResults(SearchResultsList);
	Else 
		SearchResults = New Array;
	EndIf;
	
	Result = New Structure;
	Result.Insert("CurrentPosition", SearchResultsList.StartPosition());
	Result.Insert("Count", SearchResultsList.Count());
	Result.Insert("TotalCount", TotalCount);
	Result.Insert("ErrorCode", ErrorCode);
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("SearchResults", SearchResults);
	
	Return Result;
	
EndFunction

Function FullTextSearchResults(SearchResultsList)
	
	Result = New Array;

	HTMLSearchStrings = HTMLSearchResultStrings(SearchResultsList);
	For IndexOf = 0 To SearchResultsList.Count() - 1 Do
		
		HTMLDetails  = HTMLSearchStrings.HTMLDetails1.Get(IndexOf);
		Presentation = HTMLSearchStrings.Presentations.Get(IndexOf);
		SearchListString = SearchResultsList.Get(IndexOf);
		
		ObjectMetadata = SearchListString.Metadata;
		Value = SearchListString.Value;
		
		SSLSubsystemsIntegration.OnGetFullTextSearchResults(ObjectMetadata, Value, Presentation);
		
		Ref = "";
		Try
			Ref = GetURL(Value);
		Except
			Ref = "#"; // Unintended to be opened.
		EndTry;
		
		ResultString1 = New Structure;
		ResultString1.Insert("Ref",        Ref);
		ResultString1.Insert("HTMLDetails",  HTMLDetails);
		ResultString1.Insert("Presentation", Presentation);
		
		Result.Add(ResultString1);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function HTMLSearchResultStrings(SearchResultsList)
	
	HTMLListDisplay = SearchResultsList.GetRepresentation(FullTextSearchRepresentationType.HTMLText);
	
	// Get the DOM to display the list. NOTE: DOM getter cannot be implemented as a dedicated function:
	// 1C:Enterprise throws an error in the call stack of the DOM read stream.
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLListDisplay);
	DOMBuilder = New DOMBuilder;
	DOMListDisplay = DOMBuilder.Read(HTMLReader);
	HTMLReader.Close();
	
	DivDOMItemsList = DOMListDisplay.GetElementByTagName("div");
	HTMLDetailsStrings = HTMLDetailsStrings(DivDOMItemsList);
	
	AnchorDOMItemsList = DOMListDisplay.GetElementByTagName("a");
	PresentationStrings = PresentationStrings(AnchorDOMItemsList);
	
	Result = New Structure;
	Result.Insert("HTMLDetails1", HTMLDetailsStrings);
	Result.Insert("Presentations", PresentationStrings);
	
	Return Result;
	
EndFunction

Function HTMLDetailsStrings(DivDOMItemsList)
	
	HTMLDetailsStrings = New Array;
	For Each DOMElement In DivDOMItemsList Do 
		
		If DOMElement.ClassName = "textPortion" Then 
			
			DOMWriter = New DOMWriter;
			HTMLWriter = New HTMLWriter;
			HTMLWriter.SetString();
			DOMWriter.Write(DOMElement, HTMLWriter);
			
			HTMLResultStringDetails = HTMLWriter.Close();
			
			HTMLDetailsStrings.Add(HTMLResultStringDetails);
			
		EndIf;
	EndDo;
	
	Return HTMLDetailsStrings;
	
EndFunction

Function PresentationStrings(AnchorDOMItemsList)
	
	PresentationStrings = New Array;
	For Each DOMElement In AnchorDOMItemsList Do
		
		Presentation = DOMElement.TextContent;
		PresentationStrings.Add(Presentation);
		
	EndDo;
	
	Return PresentationStrings;
	
EndFunction

#EndRegion

#Region SearchIndexUpdate

// Common procedure for updating and merging a full-text search index.
Procedure UpdateIndex(ProcedurePresentation, EnableJoining = False, InPortions = False)
	
	If (FullTextSearch.GetFullTextSearchMode() <> FullTextSearchMode.Enable) Then
		Return;
	EndIf;
	
	Common.OnStartExecuteScheduledJob();
	
	LogRecord(
		Undefined, 
		NStr("en = 'Starting %1.';"),,
		ProcedurePresentation);
	
	Try
		FullTextSearch.UpdateIndex(EnableJoining, InPortions);
		LogRecord(
			Undefined, 
			NStr("en = '%1 is successfully completed.';"),, 
			ProcedurePresentation);
	Except
		LogRecord(
			EventLogLevel.Warning, 
			NStr("en = 'Failed to execute %1:';"),
			ErrorInfo(), 
			ProcedurePresentation);
	EndTry;
	
EndProcedure

// Parameters:
//   LogLevel - EventLogLevel - message importance for the administrator.
//   CommentWithParameters - String - a comment that can contain parameters %1.
//   ErrorInfo - ErrorInfo
//                      - String - error information placed after the comment.
//   Parameter - String - replaces %1 in CommentWithParameters.
//
Procedure LogRecord(LogLevel, CommentWithParameters, ErrorInfo = Undefined,
	Parameter = Undefined) Export
	
	If TypeOf(LogLevel) <> Type("EventLogLevel") Then
		If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
			LogLevel = EventLogLevel.Error;
		ElsIf TypeOf(ErrorInfo) = Type("String") Then
			LogLevel = EventLogLevel.Warning;
		Else
			LogLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	TextForLog = CommentWithParameters;
	If Parameter <> Undefined Then
		TextForLog = StringFunctionsClientServer.SubstituteParametersToString(TextForLog, Parameter);
	EndIf;
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		TextForLog = TextForLog + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo);
	ElsIf TypeOf(ErrorInfo) = Type("String") Then
		TextForLog = TextForLog + Chars.LF + ErrorInfo;
	EndIf;
	TextForLog = TrimAll(TextForLog);
	
	WriteLogEvent(NStr("en = 'Full-text indexing';", Common.DefaultLanguageCode()), 
		LogLevel, , , TextForLog);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion
