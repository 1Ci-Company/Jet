
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetSeqBounds();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Recalculate(Command)
	
	If RecalculateAtServer() Then
		CommonClient.MessageToUser(NStr("en = 'Inventory costs are recalculated.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	SetSeqBounds();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetSeqBounds()
	
	SeqBound = Sequences.InventoryCostRecalculation.GetBound();
	SeqBoundCurrent = CreatePointInTime(SeqBound.Date, SeqBound.Ref);
	SeqBoundCurrentStr = String(SeqBoundCurrent);
	
	SeqBoundEnd = SequenceEnd();
	SeqBoundEnd = ?(SeqBoundEnd = Undefined, SeqBoundCurrent, SeqBoundEnd);
	SeqBoundEndStr = String(SeqBoundEnd);
	
	If SeqBoundEnd.Compare(SeqBoundCurrent) = 0 Then
		Items.DecorNotNeedRecalculated.Visible = True;
		Items.DecorToRecalculate.Visible = False;
	Else
		Items.DecorNotNeedRecalculated.Visible = False;
		Items.DecorToRecalculate.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Function RecalculateAtServer()
	
	IsRecalculated = False;
	
	SetSeqBounds();
	
	If SeqBoundEnd.Compare(SeqBoundCurrent) = 1 Then
		Sequences.InventoryCostRecalculation.Restore();
		SetSeqBounds();
		IsRecalculated = True;
	EndIf;
	
	Return IsRecalculated;
	
EndFunction

&AtServer
Function SequenceEnd()
	
	Result = Undefined;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	InventoryCostRecalculation.Period AS Period,
	|	InventoryCostRecalculation.Recorder AS Recorder,
	|	InventoryCostRecalculation.PointInTime AS PointInTime
	|FROM
	|	Sequence.InventoryCostRecalculation AS InventoryCostRecalculation
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

&AtServer
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

#EndRegion
