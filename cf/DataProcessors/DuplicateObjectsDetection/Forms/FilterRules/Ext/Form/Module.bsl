///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// Expected parameters:
//
//     MasterFormID - UUID - ID of the form whose storage is used for exchange.
//                                                                 CompositionSchemaAddress - String - Address in the temp storage of the DCS whose settings are being edited.
//     FilterComposerSettingsAddress - String - Address of the composer settings in the temp storage.
//                                                FilterAreaPresentation - String - Presentation used to create the title.
//     Return value (as a selection result):
//     Undefined - Editing is canceled.
//
// String - Address of the new composer settings in the temp storage.
//
//     
//     
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MasterFormID = Parameters.MasterFormID;
	
	PrefilterComposer = New DataCompositionSettingsComposer;
	PrefilterComposer.Initialize( 
		New DataCompositionAvailableSettingsSource(Parameters.CompositionSchemaAddress) );
		
	FilterComposerSettingsAddress = Parameters.FilterComposerSettingsAddress;
	PrefilterComposer.LoadSettings(GetFromTempStorage(FilterComposerSettingsAddress));
	DeleteFromTempStorage(FilterComposerSettingsAddress);
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Filter rule: %1';"), 
		Parameters.FilterAreaPresentation);
	
	IsMobileClient = Common.IsMobileClient();
	If IsMobileClient Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		Items.HiddenAtMobileClientGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Modified And IsMobileClient Then
		NotifyChoice(FilterComposerSettingsAddress());
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	If Modified Then
		NotifyChoice(FilterComposerSettingsAddress());
	Else
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function FilterComposerSettingsAddress()
	Return PutToTempStorage(PrefilterComposer.Settings, MasterFormID)
EndFunction


#EndRegion

