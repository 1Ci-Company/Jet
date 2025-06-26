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
	
	AdditionalProperties.Insert("RecordStructure", RecordStructure()); // Used by the consumers.
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Interactions.CalculateReviewedItems(AdditionalProperties) Then
		Return;
	EndIf;
	
	OldRecord     = AdditionalProperties.RecordStructure;
	NewRecord      = RecordStructure();
	DataForCalculation = New Structure("NewRecord, OldRecord", NewRecord, OldRecord);
	
	If NewRecord.Reviewed <> OldRecord.Reviewed Then
		
		Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Folder"));
		Interactions.CalculateReviewedBySubjects(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "SubjectOf"));
		
		Return;

	EndIf;
	
	If NewRecord.Folder <> OldRecord.Folder Then
		
		Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Folder"));
		
		Return;
		
	EndIf;
	
	If NewRecord.SubjectOf <> OldRecord.SubjectOf Then
		
		Interactions.CalculateReviewedBySubjects(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "SubjectOf"));
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function RecordStructure()

	ReturnStructure = New Structure;
	ReturnStructure.Insert("SubjectOf", Undefined);
	ReturnStructure.Insert("Folder", Catalogs.EmailMessageFolders.EmptyRef());
	ReturnStructure.Insert("Reviewed", Undefined);
	
	If Filter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	InteractionsFolderSubjects.SubjectOf,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder,
	|	InteractionsFolderSubjects.Reviewed
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|WHERE
	|	InteractionsFolderSubjects.Interaction = &Interaction";
	
	Query.SetParameter("Interaction", Filter.Interaction.Value);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return ReturnStructure;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	FillPropertyValues(ReturnStructure, Selection);
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf