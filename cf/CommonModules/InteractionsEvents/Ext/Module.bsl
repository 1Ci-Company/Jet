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

Procedure OnWriteEmailAccount(Source, Cancel) Export

	If Source.DataExchange.Load Then
	
		Return;
	
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EmailMessageFolders.Ref
	               |FROM
	               |	Catalog.EmailMessageFolders AS EmailMessageFolders
	               |WHERE
	               |	EmailMessageFolders.PredefinedFolder
	               |	AND EmailMessageFolders.Owner = &Account";
	
	Query.SetParameter("Account",Source.Ref);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		EmailManagement.CreatePredefinedEmailsFoldersForAccount(Source.Ref);
	EndIf;

EndProcedure

Procedure ChoiceDataGetProcessing(DocumentName, ChoiceData, Parameters, StandardProcessing) Export
	
	StandardProcessing = False;
	
	QueryText = "SELECT TOP 50 ALLOWED DISTINCT
	|	InteractionsDocument.Ref AS Ref
	|FROM
	|	#DocumentName AS InteractionsDocument
	|WHERE
	|	InteractionsDocument.Subject LIKE &SearchString ESCAPE ""~""
	|	OR InteractionsDocument.Number LIKE &SearchString ESCAPE ""~""";
	
	QueryText = StrReplace(QueryText, "#DocumentName", "Document" + "." + DocumentName);
	Query = New Query(QueryText);
	Query.SetParameter("SearchString", Common.GenerateSearchQueryString(Parameters.SearchString) + "%");
	
	ChoiceData = New ValueList;
	ChoiceData.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

Procedure FillAccessValuesSets(Object, Table) Export
	
	InteractionsOverridable.OnFillingAccessValuesSets(Object, Table);
	
	If Table.Count() = 0 Then
		Interactions.FillDefaultAccessValuesSets(Object, Table);
	EndIf;
	
EndProcedure

#EndRegion
