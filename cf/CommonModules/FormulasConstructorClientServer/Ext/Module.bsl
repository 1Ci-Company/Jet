///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Returns:
//  ValueTableRow of See FormulasConstructorInternal.DescriptionOfFieldLists
//
Function FieldListSettings(Form, NameOfTheFieldList) Export
	
	Filter = New Structure("NameOfTheFieldList", NameOfTheFieldList);
	For Each FieldList In Form.ConnectedFieldLists.FindRows(Filter) Do
		Return FieldList;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function FormulaEditingOptions() Export
	
	Parameters = New Structure;
	Parameters.Insert("Formula");
	Parameters.Insert("Operands");
	Parameters.Insert("Operators");
	Parameters.Insert("OperandsDCSCollectionName");
	Parameters.Insert("OperatorsDCSCollectionName");
	Parameters.Insert("Description");
	Parameters.Insert("ForQuery");
	Parameters.Insert("BracketsOperands", True);
	
	Return Parameters;
	
EndFunction

Function FindTextInALine(Val String, Val Text, Font, Color, SearchConsideringLevels) Export
	
	Result = New Structure("FormattedString, Weight, MatchesFilter", Undefined, 0, False);
	
	If StrFind(String.DataPath, ".Delete") > 0 Then
		Return Result;
	EndIf;
	
	PathPresentationStart = 0;
	
	If SearchConsideringLevels Then
		If TypeOf(String) = Type("FormDataTreeItem") Then
			Parent = String.GetParent();
		ElsIf TypeOf(String) = Type("ValueTreeRow") Then
			Parent = String.Parent;
		EndIf;
		
		If Parent <> Undefined Then
			PathPresentationStart = StrLen(Parent.RepresentationOfTheDataPath)+1;
			SearchString = Mid(String.RepresentationOfTheDataPath, PathPresentationStart+1);
		Else
			SearchString = String.RepresentationOfTheDataPath;
		EndIf;
	Else
		SearchString = String.RepresentationOfTheDataPath;
	EndIf;
	SearchPresentationString = String.RepresentationOfTheDataPath;
	SearchPresentationCurrentString = SearchPresentationString;
	CurrentSearchString = SearchString;
	SearchStringMaxLeng = 1024;
	MaxWordLeng = 150;
	CurrentSearchStrLeng = StrLen(SearchPresentationCurrentString);
	
	Weight = 0;
	FormattedStrings = New Array;
	SearchWords = StrSplit(Text, " ", False);
	
	If SearchWords.Count() > 0 Then
		WordWeight = 1/SearchWords.Count();
	EndIf;
	
	LevelWeight = 20;
	WeightPerfectMatch = 12;
	WeightOfEntireWord = 7;
	OccurrenceCountWeight = 4;
	WeightOfProximityToStringBeginning = 2;
	WeightOfProximityToWordBeginning = 1;
	
	WordSeparators = New Map;
	WordSeparators.Insert(" ", True);
	WordSeparators.Insert(".", True);
	
	PositionFromStringStart = 0;
	For Each Substring In SearchWords Do
		Position = StrFind(Lower(CurrentSearchString), Lower(Substring));
		If Position = 0 Then
			FormattedStrings = Undefined;
			Result.MatchesFilter = False;
			Break;
		EndIf;
		SearchSubstrLeng = StrLen(Substring);
		NumberOfOccurrences = StrOccurrenceCount(Lower(CurrentSearchString), Lower(Substring));
		
		If Lower(SearchString) = Lower(Substring) Then
			Weight = Weight + WordWeight * WeightPerfectMatch;
		EndIf;
		
		CurrentSearchString = Mid(CurrentSearchString, Position + SearchSubstrLeng);
		PositionFromStringStart = PositionFromStringStart + Position;
		Position = StrFind(Lower(SearchPresentationCurrentString), Lower(Substring),,PathPresentationStart + Position);
		PathPresentationStart = 0;
		
		SubstringBeforeOccurence = Left(SearchPresentationCurrentString, Position - 1);
		Weight = Weight + (5 - NumberOfOccurrences)/4 * WordWeight * OccurrenceCountWeight;
		
		For EntryNumber = 1 To NumberOfOccurrences Do
			Weight = Weight + (1 - (PositionFromStringStart-1)/SearchStringMaxLeng) * WordWeight * WeightOfProximityToStringBeginning / NumberOfOccurrences;
			If (PositionFromStringStart = 1 Or WordSeparators[Mid(SearchPresentationString, PositionFromStringStart - 1, 1)] = True)
				And (PositionFromStringStart + SearchSubstrLeng = CurrentSearchStrLeng +1
					Or WordSeparators[Mid(SearchPresentationString, PositionFromStringStart + SearchSubstrLeng, 1)] = True) Then
				Weight = Weight + WordWeight * WeightOfEntireWord / NumberOfOccurrences;
			EndIf;
			
			WordBeginningPosition = 0;
			For Each WordsSeparator In WordSeparators Do
				WordBeginningPosition = Max(WordBeginningPosition, 
					StrFind(SearchPresentationString, WordsSeparator.Key, SearchDirection.FromEnd, PositionFromStringStart));
			EndDo;
			Weight = Weight + (1 - WordBeginningPosition/MaxWordLeng) * WordWeight * WeightOfProximityToWordBeginning / NumberOfOccurrences;
		EndDo;
		
		OccurenceSubstring = Mid(SearchPresentationCurrentString, Position, StrLen(Substring));
		SearchPresentationCurrentString = Mid(SearchPresentationCurrentString, Position + SearchSubstrLeng);
		Result.MatchesFilter = True;
		FormattedStrings.Add(SubstringBeforeOccurence);
		FormattedStrings.Add(New FormattedString(OccurenceSubstring,
			Font, Color));
	EndDo;
	
	If Not Result.MatchesFilter Then
		Return Result;
	EndIf;
	Result.Weight = Weight + (10 - StrSplit(String.DataPath, ".").Count()) * LevelWeight;
	FormattedStrings.Add(CurrentSearchString);
	Result.FormattedString = New FormattedString(FormattedStrings); // ACC:1356 - A compound format string can be used as the string array consists of the passed text.
	
	Return Result;
	
EndFunction

Procedure DoSortByColumn(FieldTree, Column, Direction = Undefined) Export
	Sort = New ValueList;
	IndexByValues = New Map;
	
	TreeItems = FieldTree.GetItems();
	
	For Each Item In TreeItems Do
		Value = Item[Column];
		
		ValueStrings_ = IndexByValues[Value];
		If ValueStrings_ = Undefined Then
			ValueStrings_ = New Array;
			IndexByValues.Insert(Value, ValueStrings_);
			Sort.Add(Value);
		EndIf;
		ValueStrings_.Add(Item);
		DoSortByColumn(Item, Column);
	EndDo;
	
	Sort.SortByValue(?(Direction = Undefined, SortDirection.Desc, Direction));
	
	NewIndex = 0;
	For Each SortingElement In Sort Do
		
		ValueStrings_ = IndexByValues.Get(SortingElement.Value);
		For Each CurrentRow In ValueStrings_ Do
			
			CurrentIndex = TreeItems.IndexOf(CurrentRow);
			ShiftStep = NewIndex - CurrentIndex;
			If Not ShiftStep = 0 Then
				TreeItems.Move(CurrentIndex, ShiftStep);
			EndIf;
			
			NewIndex = NewIndex + 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function SearchResultsString(FieldTree, ShouldCreateString = True) Export
	SearchResultsString = Undefined;
	FieldsTreeElements = FieldTree.GetItems();
	For Each TableRow In FieldsTreeElements Do
		If TableRow.DataPath = "<SearchResultsString>" Then
			SearchResultsString = TableRow;
			Break;
		EndIf;
	EndDo;
	
	If SearchResultsString = Undefined And ShouldCreateString Then
		SearchResultsString = FieldsTreeElements.Add();
		SearchResultsString.DataPath = "<SearchResultsString>";
	EndIf;
	Return SearchResultsString;
EndFunction

#EndRegion