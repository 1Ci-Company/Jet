///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Procedure AllowObjectAttributeEditAfterWarning(ContinuationHandler) Export
	
	If ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(ContinuationHandler, False);
	EndIf;
	
EndProcedure

Procedure AllowEditingObjectAttributesAfterFormClosed(Result, Parameters) Export
	
	UnlockedAttributes = Undefined;
	
	If Result = True Then
		UnlockedAttributes = Parameters.LockedAttributes;
	ElsIf TypeOf(Result) = Type("Array") Then
		UnlockedAttributes = Result;
	Else
		UnlockedAttributes = Undefined;
	EndIf;
	
	If UnlockedAttributes <> Undefined Then
		ObjectAttributesLockClient.SetAttributeEditEnabling(
			Parameters.Form, UnlockedAttributes);
		
		ObjectAttributesLockClient.SetFormItemEnabled(Parameters.Form);
	EndIf;
	
	Parameters.Form = Undefined;
	
	If Parameters.ContinuationHandler <> Undefined Then
		ContinuationHandler = Parameters.ContinuationHandler;
		Parameters.ContinuationHandler = Undefined;
		ExecuteNotifyProcessing(ContinuationHandler, Result);
	EndIf;
	
EndProcedure

Procedure CheckObjectReferenceAfterValidationConfirm(Response, Parameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
		Return;
	EndIf;
		
	If Parameters.ReferencesArrray.Count() = 0 Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
		Return;
	EndIf;
	
	If CommonServerCall.RefsToObjectFound(Parameters.ReferencesArrray) Then
		
		If Parameters.ReferencesArrray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 is used elsewhere in the app.
				           |Editing this object might lead to data inconsistency.';"),
				Parameters.ReferencesArrray[0]);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 selected items are used elsewhere in the app.
				           |Editing these items might lead to data inconsistency.';"),
				Parameters.ReferencesArrray.Count());
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Allow editing';"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel';"));
		ShowQueryBox(
			New NotifyDescription(
				"CheckObjectRefsAfterEditConfirmation", ThisObject, Parameters),
			MessageText, Buttons, , DialogReturnCode.No, Parameters.DialogTitle);
	Else
		If Parameters.ReferencesArrray.Count() = 1 Then
			ShowUserNotification(NStr("en = 'Attribute editing allowed';"),
				GetURL(Parameters.ReferencesArrray[0]), Parameters.ReferencesArrray[0]);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Allowed to edit attributes of %1 objects';"),
				Parameters.ReferencesArrray.Count());
			
			ShowUserNotification(NStr("en = 'Attribute editing allowed';"),,
				MessageText);
		EndIf;
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
	EndIf;
	
EndProcedure

Procedure CheckObjectRefsAfterEditConfirmation(Response, Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, Response = DialogReturnCode.Yes);
	
EndProcedure

#EndRegion
