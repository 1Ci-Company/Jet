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
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CurrentRecordSet.Object AS Object,
		|	1 AS AttemptsNumber,
		|	&CurrentAttemptTime AS LastAttemptTime
		|INTO Current_Set
		|FROM
		|	&CurrentRecordSet AS CurrentRecordSet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.Object AS Object,
		|	SUM(Table.AttemptsNumber) AS AttemptsNumber,
		|	MAX(Table.LastAttemptTime) AS LastAttemptTime
		|FROM
		|	(SELECT
		|		NotDeletedObjects.Object AS Object,
		|		NotDeletedObjects.AttemptsNumber AS AttemptsNumber,
		|		NotDeletedObjects.LastAttemptTime AS LastAttemptTime
		|	FROM
		|		InformationRegister.NotDeletedObjects AS NotDeletedObjects
		|	WHERE
		|		NotDeletedObjects.Object IN
		|			(SELECT
		|				Tab.Object
		|			FROM
		|				Current_Set AS Tab)
		|
		|	UNION ALL
		|
		|	SELECT
		|		Current_Set.Object,
		|		Current_Set.AttemptsNumber,
		|		Current_Set.LastAttemptTime
		|	FROM
		|		Current_Set AS Current_Set) AS Table
		|GROUP BY
		|	Table.Object";
	
	Query.SetParameter("CurrentAttemptTime", Common.CurrentUserDate());
	Query.SetParameter("CurrentRecordSet", Unload());
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	Clear();
	While SelectionDetailRecords.Next() Do
		FillPropertyValues(Add(), SelectionDetailRecords);
	EndDo;
	
EndProcedure
#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf