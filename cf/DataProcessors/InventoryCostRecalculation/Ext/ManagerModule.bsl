#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Gets the point in time which corresponds to the minimum
// boundary of the InventoryCostRecalculation sequence.
//
// Returns:
//  PointInTime
//
Function GetSeqBoundCurrent() Export
	
	SeqBound = Sequences.InventoryCostRecalculation.GetBound();
	
	Return CreatePointInTime(SeqBound.Date, SeqBound.Ref);
	
EndFunction

// Gets the end of InventoryCostRecalculation sequence
//
// Returns:
//  PointInTime
//
Function SequenceEnd() Export
	
	Result = Undefined;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	InventoryCost.Period AS Period,
	|	InventoryCost.Recorder AS Recorder,
	|	InventoryCost.PointInTime AS PointInTime
	|FROM
	|	AccumulationRegister.InventoryCost AS InventoryCost
	|WHERE
	|	InventoryCost.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND InventoryCost.Active
	|
	|ORDER BY
	|	PointInTime DESC";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		Result = CreatePointInTime(Selection.Period, Selection.Recorder);
	EndIf;
	
	Return Result;
	
EndFunction

// StandardSubsystems.ToDoList

// Integration with the StandardSubsystems.ToDoList subsystem.
// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - a value table with the following columns:
//    * Id - String - an internal to-do ID used by the To-do list algorithm.
//    * HasToDoItems      - Boolean - if True, the to-do item is displayed in the user's to-do list.
//    * Important        - Boolean - if True, the to-do item is highlighted in red.
//    * Presentation - String - To-do item presentation displayed to a user.
//    * Count    - Number  - a number related to a to-do item; it is displayed in a to-do item's title.
//    * Form         - String - Full path to the form that is displayed by clicking on the
//                               to-do item hyperlink in the "To-do list" panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner      - String, MetadataObject - String ID of the to-do item that is the owner of the current to-do item,
//                      or a subsystem metadata object.
//    * ToolTip     - String - Tooltip text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Use", Metadata.DataProcessors.InventoryCostRecalculation) Then
		Return;
	EndIf;
	
	IsNeedToRecalculate = IsNeedToRecalculate();
	RowID = "InventoryCostRecalculation";
	
	ToDoRow					= ToDoList.Add();
	ToDoRow.ID				= RowID;
	ToDoRow.HasToDoItems	= IsNeedToRecalculate;
	ToDoRow.Presentation	= NStr("en = 'Inventory cost recalculation'");
	ToDoRow.Owner			= Metadata.Subsystems.Warehouses;
	
	ToDoRow					= ToDoList.Add();
	ToDoRow.ID				= "MonthClosureNotCalculatedTotals";
	ToDoRow.HasToDoItems	= IsNeedToRecalculate;
	ToDoRow.Presentation	= NStr("en = 'It may be necessary to recalculate inventory costs'");
	ToDoRow.Form			= "DataProcessor.InventoryCostRecalculation.Form";
	ToDoRow.Owner			= RowID;
	ToDoRow.Important		= True;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#Region Private

Function CreatePointInTime(Period, Recorder)
	
	Result = Undefined;
	
	// Sometimes document ref in the sequence are “broken” or of unprocessed types.
	// If the moment of sequence violation falls on such a ref, it may interfere with
	// the normal recovery of the chronological sequence.
	// Therefore, if such a link is found, we determine the moment of sequence violation simply by the date,
	// and we will try to remove the reference itself from the sequence.
	
	If ValueIsFilled(Recorder) Then
		If Common.RefExists(Recorder) Then
			Result = New PointInTime(Period, Recorder);
		Else
			Try
				RecordSet = Sequences.InventoryCostRecalculation.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(Recorder);
				If ValueIsFilled(RecordSet.Filter.Recorder.Value) Then
					RecordSet.Write();
				EndIf;
			Except
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error deleting an invalid ref: %1'"),
					BriefErrorDescription(ErrorInfo()));
				WriteLogEvent(NStr("en = 'Work with sequences'", Common.DefaultLanguageCode()),
					EventLogLevel.Error,,
					Recorder,
					MessageText);
			EndTry;
		EndIf;
	EndIf;
	
	If Result = Undefined Then
		Result = New PointInTime(Period);
	EndIf;
	
	Return Result;
	
EndFunction

// StandardSubsystems.ToDoList

Function IsNeedToRecalculate()
	
	Result = False;
	
	SeqBoundCurrent = GetSeqBoundCurrent();
	SeqBoundEnd = SequenceEnd();
	SeqBoundEnd = ?(SeqBoundEnd = Undefined, SeqBoundCurrent, SeqBoundEnd);
	
	If SeqBoundEnd.Compare(SeqBoundCurrent) <> 0 Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

// End StandardSubsystems.ToDoList

#EndRegion

#EndIf