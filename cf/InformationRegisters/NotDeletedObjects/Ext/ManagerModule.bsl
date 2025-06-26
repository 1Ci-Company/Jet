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

// Generates a table with a number of attempts for the specified objects.
// If the object has not been deleted before, the information on the number of attempts will not be displayed.
// 
// Parameters:
//   Objects - Array of AnyRef
// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef
//   * AttemptsNumber - Number
//
Function ObjectsAttemptsCount(Objects) Export
	Query = New Query;
	
	Query.Text =
		"SELECT
		|	NotDeletedObjects.Object AS ItemToDeleteRef,
		|	NotDeletedObjects.AttemptsNumber AS AttemptsNumber
		|FROM
		|	InformationRegister.NotDeletedObjects AS NotDeletedObjects
		|WHERE
		|	NotDeletedObjects.Object IN (&ListOfObjects)
		|	AND NotDeletedObjects.AttemptsNumber > 0";
	
	Query.SetParameter("ListOfObjects", Objects);
	
	QueryResult = Query.Execute();
	ObjectsAttemptsCount = QueryResult.Unload();
	ObjectsAttemptsCount.Indexes.Add("ItemToDeleteRef");
	
	Return ObjectsAttemptsCount;
EndFunction

// Adds an entry to the register.
// 
// Parameters:
//   NotDeletedRef - AnyRef
//
Procedure Add(NotDeletedRef) Export
	Record = InformationRegisters.NotDeletedObjects.CreateRecordManager();
	Record.Object = NotDeletedRef;
	If ValueIsFilled(Record.Object) Then
		Record.Write();
	EndIf;
EndProcedure

#EndRegion

#EndIf