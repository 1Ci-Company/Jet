///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables
&AtClient
Var SearchDirectionValue;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Users.IsExternalUserSession() Then
		Return;
	EndIf;
		
	SearchState = FullTextSearchServer.FullTextSearchStatus();
	LoadSettingsAndSearchHistory();
	
	If Not IsBlankString(Parameters.PassedSearchString) Then
		SearchString = Parameters.PassedSearchString;
		OnExecuteSearchAtServer(SearchString);
	Else	
		UpdateForm(New Array);
	EndIf;
	
	UpdateSearchAreaPresentation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClient.IsExternalUserSession() Then 
		Cancel = True;
		Raise(NStr("en = 'Insufficient rights to search.';"), ErrorCategory.AccessViolation);
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
#If WebClient Then
	If Items.SearchString.ChoiceList.Count() = 1 Then
		ValueSelected = Item.EditText;
	EndIf;
#EndIf
	
	SearchString = ValueSelected;
	OnExecuteSearch("FirstPart");
	
EndProcedure

&AtClient
Procedure SearchAreasPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("SearchAreas",   SearchAreas);
	OpeningParameters.Insert("SearchInSections", SearchInSections);
	
	Notification = New NotifyDescription("AfterGetSearchAreaSettings", ThisObject);
	
	OpenForm("DataProcessor.FullTextSearchInData.Form.SearchAreaChoice",
		OpeningParameters,,,,, Notification);
	
EndProcedure

&AtClient
Procedure HTMLTextOnClick(Item, EventData, StandardProcessing)
	
	StandardProcessing = False;
	
	HTMLRef = EventData.Anchor;
	
	If HTMLRef = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("AfterOpenURL", ThisObject);
	FileSystemClient.OpenURL(HTMLRef.href, Notification);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExecuteSearch(Command)
	
	OnExecuteSearch("FirstPart");
	
EndProcedure

&AtClient
Procedure PreviousPages(Command)
	
	OnExecuteSearch("PreviousPart");
	
EndProcedure

&AtClient
Procedure NextPages(Command)
	
	OnExecuteSearch("NextPart");
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtClient
Procedure AfterGetSearchAreaSettings(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		OnSetSearchArea(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSetSearchArea(SearchAreaSettings)
	
	SaveSearchSettings(SearchAreaSettings.SearchInSections, SearchAreaSettings.SearchAreas);
	SearchAreas = SearchAreaSettings.SearchAreas;
	SearchInSections = SearchAreaSettings.SearchInSections;
	UpdateSearchAreaPresentation();
	
EndProcedure

&AtClient
Procedure OnExecuteSearch(Val Var_SearchDirection)
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("en = 'Please enter text to search for.';"));
		Return;
	EndIf;
	
	If CommonInternalClient.IsURL(SearchString) Then
		FileSystemClient.OpenURL(SearchString);
		SearchString = "";
		Return;
	EndIf;
	
	SearchDirectionValue = Var_SearchDirection;
	AttachIdleHandler("OnExecuteSearchCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnExecuteSearchCompletion()
	
	OnExecuteSearchAtServer(SearchString, SearchDirectionValue);
	
EndProcedure

&AtServer
Procedure OnExecuteSearchAtServer(Val SearchString, Val Var_SearchDirection = "FirstPart")
	
	SaveSearchStringToHistory(SearchString);
	
	SearchParameters = FullTextSearchServer.SearchParameters();
	SearchParameters.CurrentPosition = CurrentPosition;
	SearchParameters.SearchInSections = SearchInSections;
	SearchParameters.SearchAreas = SearchAreas;
	SearchParameters.SearchString = SearchString;
	SearchParameters.SearchDirection = Var_SearchDirection;
	
	SearchResult = FullTextSearchServer.ExecuteFullTextSearch(SearchParameters);
	CurrentPosition = SearchResult.CurrentPosition;
	Count = SearchResult.Count;
	TotalCount = SearchResult.TotalCount;
	ErrorCode = SearchResult.ErrorCode;
	ErrorDescription = SearchResult.ErrorDescription;
	
	SearchState = FullTextSearchServer.FullTextSearchStatus();
	UpdateForm(SearchResult.SearchResults);

EndProcedure

&AtClient
Procedure AfterOpenURL(ApplicationStarted, Context) Export
	
	If Not ApplicationStarted Then 
		ShowMessageBox(, NStr("en = 'Cannot open objects of this type';"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Presentations

&AtServer
Procedure UpdateForm(SearchResults)
	
	If Count = 0 Then
		Items.NextPages.Enabled  = False;
		Items.PreviousPages.Enabled = False;
	Else
		Items.NextPages.Enabled  = (TotalCount - CurrentPosition) > Count;
		Items.PreviousPages.Enabled = (CurrentPosition > 0);
	EndIf;
	
	If Count <> 0 Then
		FoundItemsInformationPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Results %1–%2 out of %3';"),
			Format(CurrentPosition + 1, "NZ=0; NG="),
			Format(CurrentPosition + Count, "NZ=0; NG="),
			Format(TotalCount, "NZ=0; NG="));
	Else		
		FoundItemsInformationPresentation = "";
	EndIf;
	
	If IsBlankString(ErrorCode) Then 
		SearchResultsPresentation = NewHTMLResultPage(SearchResults);
	Else 
		SearchResultsPresentation = NewHTMLErrorPage();
	EndIf;
	
	If SearchState = "SearchAllowed" Then 
		SearchStatePresentation = "";
	ElsIf SearchState = "IndexUpdateInProgress"
		Or SearchState = "IndexMergeInProgress"
		Or SearchState = "IndexUpdateRequired" Then 
		
		SearchStatePresentation = NStr("en = 'Search results might be inaccurate. Try the search later.';");
	ElsIf SearchState = "SearchSettingsError" Then 
		
		// For non-administrators.
		SearchStatePresentation = NStr("en = 'Full-text search is not set up. Contact your administrator.';");
		
	ElsIf SearchState = "SearchProhibited" Then 
		SearchStatePresentation = NStr("en = 'Full-text search is disabled.';");
	EndIf;
	
	Items.SearchState.Visible = (SearchState <> "SearchAllowed");

EndProcedure

&AtServer
Procedure UpdateSearchAreaPresentation()
	
	SearchAreasSpecified = SearchAreas.Count() > 0;
	
	If Not SearchInSections Or Not SearchAreasSpecified Then
		SearchAreasPresentation = NStr("en = 'Everywhere';");
		Return;
	EndIf;
	
	If SearchAreas.Count() < 5 Then
		SearchAreasPresentation = "";
		For Each Area In SearchAreas Do
			MetadataObject = Common.MetadataObjectByID(Area.Value);
			SearchAreasPresentation = SearchAreasPresentation + Common.ListPresentation(MetadataObject) + ", ";
		EndDo;
		SearchAreasPresentation = Left(SearchAreasPresentation, StrLen(SearchAreasPresentation) - 2);
	Else	
		SearchAreasPresentation = NStr("en = 'In selected sections';");
	EndIf;
	
EndProcedure

// Parameters:
//  SearchResults - Array of Structure:
//    * Ref - String
//    * HTMLDetails - String
//    * Presentation - String
//
// Returns:
//  String
//
&AtServer
Function NewHTMLResultPage(SearchResults)
	
	LayoutTemplate = 
		"<html>
		|<head>
		|  <meta http-equiv=""Content-Type"" content=""text/html; charset=UTF-8"">
		|  <style type=""text/css"">
		|    html {
		|      overflow: auto;
		|    }
		|    body {
		|      margin: 10px;
		|      font-family: Arial, sans-serif;
		|      font-size: 10pt;
		|      overflow: auto;
		|      position: absolute;
		|      top: 0;
		|      left: 0;
		|      bottom: 0;
		|      right: 0;
		|    }
		|    div.main {
		|      overflow: auto;
		|      height: 100%;
		|    }
		|    div.presentation {
		|      font-size: 11pt;
		|    }
		|    div.textPortion {
		|      padding-bottom: 16px;
		|    }
		|    span.bold {
		|      font-weight: bold;
		|    }
		|    ol li {
		|      color: #B3B3B3;
		|    }
		|    ol li div {
		|      color: #333333;
		|    }
		|    a {
		|      text-decoration: none;
		|      color: #0066CC;
		|    }
		|    a:hover {
		|      text-decoration: underline;
		|    }
		|    .gray {
		|      color: #B3B3B3;
		|    }
		|  </style>
		|</head>
		|<body>
		|  <div class=""main"">
		|    <ol start=""%CurrentPosition%"">
		|%Rows%
		|    </ol>
		|  </div>
		|</body>
		|</html>";
	
	StringPattern = 
		"      <li>
		|        <div class=""presentation""><a href=""%Ref%"">%Presentation%</a></div>
		|        %HTMLDetails%
		|      </li>";
	
	InactiveStringPattern = 
		"      <li>
		|        <div class=""presentation""><a href=""#"" class=""gray"">%Presentation%</a></div>
		|        %HTMLDetails%
		|      </li>";
	
	Rows = "";
	
	For Each SearchResultString In SearchResults Do 
		
		Ref        = SearchResultString.Ref;
		Presentation = SearchResultString.Presentation;
		HTMLDetails  = SearchResultString.HTMLDetails;
		
		If Ref = "#" Then 
			String = InactiveStringPattern;
		Else 
			String = StrReplace(StringPattern, "%Ref%", Ref);
		EndIf;
		
		String = StrReplace(String, "%Presentation%", Presentation);
		String = StrReplace(String, "%HTMLDetails%",  HTMLDetails);
		
		Rows = Rows + String;
		
	EndDo;
	
	HTMLPage = StrReplace(LayoutTemplate, "%Rows%", Rows);
	HTMLPage = StrReplace(HTMLPage  , "%CurrentPosition%", CurrentPosition + 1);
	
	Return HTMLPage;
	
EndFunction

&AtServer
Function NewHTMLErrorPage()
	
	LayoutTemplate = 
		"<html>
		|<head>
		|  <meta http-equiv=""Content-Type"" content=""text/html; charset=UTF-8"">
		|  <style type=""text/css"">
		|    html { 
		|      overflow:auto;
		|    }
		|    body {
		|      margin: 10px;
		|      font-family: Arial, sans-serif;
		|      font-size: 10pt;
		|      overflow: auto;
		|      position: absolute;
		|      top: 0;
		|      left: 0;
		|      bottom: 0;
		|      right: 0;
		|    }
		|    div.main {
		|      overflow: auto;
		|      height: 100%;
		|    }
		|    div.error {
		|      font-size: 12pt;
		|    }
		|    div.presentation {
		|      font-size: 11pt;
		|    }
		|    h3 {
		|      color: #009646
		|    }
		|    li {
		|      padding-bottom: 16px;
		|    }
		|    a {
		|      text-decoration: none;
		|      color: #0066CC;
		|    }
		|    a:hover {
		|      text-decoration: underline;
		|    }
		|  </style>
		|</head>
		|<body>
		|  <div class=""main"">
		|    <div class=""error"">%1</div>
		|    <p>%2</p>
		|  </div>
		|</body>
		|</html>";
	
	HTMLRecommendations = 
		NStr("en = '<h3>Recommended:</h3>
			|<ul>
			|  %1
			|  %2
			|  <li>
			|    <b>Search by beginning of a word.</b><br>
			|    Use asterisk (*) as a wildcat symbol.<br>
			|    For example, a search for cons* will find all documents containing words that start with the same letters:
			|    Construction and Repair, Construction Works Ltd, and so on.
			|  </li>
			|  <li>
			|    <b>Fuzzy search.</b><br>
			|    For fuzzy search, use the number sign (#).<br>
			|    For example, a search for Child#3 will find all documents containing words that differ from the word 
			|    Child by one, two, or three letters.
			|   </li>
			|</ul>
			|<div class ""presentation""><a href=""%3"">Searching with regular expressions</a></div>';");
	
	SearchAreasSpecified = SearchAreas.Count() > 0;
	
	SearchAreaRecommendationHTML = "";
	QueryTextRecommendationHTML = "";
	
	If ErrorCode = "FoundNothing" Then 
		
		If SearchInSections And SearchAreasSpecified Then 
		
			SearchAreaRecommendationHTML = 
				NStr("en = '<li><b>Refine the search.</b><br>
					|Try to select other locations.</li>';");
		EndIf;
		
		QueryTextRecommendationHTML =
			NStr("en = '<li><b>Try searching for fewer words.</b></li>';");
		
	ElsIf ErrorCode = "TooManyResults" Then
		
		If Not SearchInSections Or Not SearchAreasSpecified Then 
			
			SearchAreaRecommendationHTML = 
			NStr("en = '<li><b>Refine the search.</b><br>
				|Try to select a location or list.</li>';");
		EndIf;
		
	EndIf;
	
	HTMLRecommendations = StringFunctionsClientServer.SubstituteParametersToString(HTMLRecommendations, 
		SearchAreaRecommendationHTML, QueryTextRecommendationHTML,
		"v8help://1cv8/QueryLanguageFullTextSearchInData");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(LayoutTemplate, ErrorDescription, HTMLRecommendations);
	
EndFunction

#EndRegion

#Region SearchSetupHistory

&AtServer
Procedure LoadSettingsAndSearchHistory()
	
	SearchHistory = Common.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings", "", New Array);
	Items.SearchString.ChoiceList.LoadValues(SearchHistory);
	
	SavedSearchSettings = Common.CommonSettingsStorageLoad("FullTextSearchSettings", "", SearchSettings1());
	SearchInSections = SavedSearchSettings.SearchInSections;
	SearchAreas   = SavedSearchSettings.SearchAreas;
	
EndProcedure

&AtServer
Procedure SaveSearchStringToHistory(SearchString)
	
	SearchHistory = Common.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings", "", New Array);
	SavedString = SearchHistory.Find(SearchString);
	If SavedString <> Undefined Then
		SearchHistory.Delete(SavedString);
	EndIf;
	
	SearchHistory.Insert(0, SearchString);
	RowsCount = SearchHistory.Count();
	If RowsCount > 20 Then
		SearchHistory.Delete(RowsCount - 1);
	EndIf;
	
	Common.CommonSettingsStorageSave("FullTextSearchFullTextSearchStrings", "", SearchHistory);
	Items.SearchString.ChoiceList.LoadValues(SearchHistory);
	
EndProcedure

&AtServerNoContext
Procedure SaveSearchSettings(SearchInSections, SearchAreas)
	
	Settings = SearchSettings1();
	Settings.SearchInSections = SearchInSections;
	Settings.SearchAreas = SearchAreas;
	
	Common.CommonSettingsStorageSave("FullTextSearchSettings", "", Settings);
	
EndProcedure

&AtServerNoContext
Function SearchSettings1()
	
	Settings = New Structure;
	Settings.Insert("SearchInSections", False);
	Settings.Insert("SearchAreas",   New ValueList);
	Return Settings;
	
EndFunction

#EndRegion

#EndRegion
