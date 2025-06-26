
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
	
	SeqBoundCurrent = DataProcessors.InventoryCostRecalculation.GetSeqBoundCurrent();
	SeqBoundCurrentStr = String(SeqBoundCurrent);
	
	SeqBoundEnd = DataProcessors.InventoryCostRecalculation.SequenceEnd();
	If SeqBoundEnd = Undefined Then
		SeqBoundEnd = SeqBoundCurrent;
		SeqBoundEndStr = NStr("en = 'There are no expense documents'");
	Else
		SeqBoundEndStr = String(SeqBoundEnd);
	EndIf;
	
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

#EndRegion
