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

#Region Internal

// Returns references to nodes that have a smaller position in queue than the passed one.
//
// Parameters:
//  Queue	 - Number - the queue position of the data processor.
// 
// Returns:
//   Array of ExchangePlanRef.InfobaseUpdate 
//
Function EarlierQueueNodes(Queue) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InfobaseUpdate.Ref AS Ref
	|FROM
	|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
	|WHERE
	|	InfobaseUpdate.Queue < &Queue
	|	AND NOT InfobaseUpdate.ThisNode
	|	AND NOT InfobaseUpdate.Temporary
	|	AND InfobaseUpdate.Queue <> 0";
	
	Query.SetParameter("Queue", Queue);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Searches for the exchange plan node by its queue and returns a reference to it.
// If there is no node, it will be created.
//
// Parameters:
//  Queue - Number - the queue position of the data processor.
//  Temporary - Boolean - Flag indicating whether data is registered during a deferred handler restart.
// 
// Returns:
//  ExchangePlanRef.InfobaseUpdate
//
Function NodeInQueue(Queue, Temporary = False) Export
	
	If TypeOf(Queue) <> Type("Number") Or Queue = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get the node of exchange plan %1 because the position in queue is not provided.';"),
			"InfobaseUpdate");
	EndIf;
	
	Query = New Query(
		"SELECT
		|	InfobaseUpdate.Ref AS Ref
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	InfobaseUpdate.Queue = &Queue
		|	AND InfobaseUpdate.Temporary = &Temporary
		|	AND NOT InfobaseUpdate.ThisNode");
	Query.SetParameter("Queue", Queue);
	Query.SetParameter("Temporary", Temporary);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Node = Selection.Ref;
	Else
		BeginTransaction();
		
		Try
			Locks = New DataLock;
			Block = Locks.Add("ExchangePlan.InfobaseUpdate");
			Block.SetValue("Queue", Queue);
			Block.SetValue("Temporary", Temporary);
			Locks.Lock();
			
			Selection = Query.Execute().Select();
			
			If Selection.Next() Then
				Node = Selection.Ref;
			Else
				QueueString = String(Queue);
				ObjectNode = CreateNode();
				ObjectNode.Queue = Queue;
				ObjectNode.Temporary = Temporary;
				ObjectNode.SetNewCode(QueueString);
				ObjectNode.Description = QueueString + ?(Temporary, " " + NStr("en = 'New for restart';"), "");
				ObjectNode.Write();
				Node = ObjectNode.Ref;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	Return Node;
	
EndFunction

#EndRegion

#EndIf