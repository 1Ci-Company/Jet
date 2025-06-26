///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RefreshSearchHistory(Items.SearchString);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExecuteSearch(Command)
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("en = 'Please enter text to search for.';"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PassedSearchString", SearchString);
	
	OpenForm("CommonForm.SearchForm", FormParameters,, True);
	
	RefreshSearchHistory(Items.SearchString);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure RefreshSearchHistory(Item)
	
	SearchHistory = SavedSearchHistory();
	If TypeOf(SearchHistory) = Type("Array") Then
		Item.ChoiceList.LoadValues(SearchHistory);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SavedSearchHistory()
	
	Return Common.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings", "");
	
EndFunction

#EndRegion
