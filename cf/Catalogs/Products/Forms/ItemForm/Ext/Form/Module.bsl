
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LockUnitChanges(Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	LockUnitChanges(CurrentObject.Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure LockUnitChanges(ObjectRef)
	
	Items.Unit.ReadOnly = Not ObjectRef.IsEmpty();
	
EndProcedure

#EndRegion