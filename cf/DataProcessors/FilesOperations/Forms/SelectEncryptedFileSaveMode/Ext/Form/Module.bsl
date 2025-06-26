///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SaveDecrypted = 1;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		
		EncryptedFilesExtension =
			ModuleDigitalSignature.PersonalSettings().EncryptedFilesExtension;
	Else
		EncryptedFilesExtension = "p7m";
	EndIf;
	
	If Common.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "SaveDecrypted", "RadioButtonType", RadioButtonType.RadioButton);
		CommonClientServer.SetFormItemProperty(Items, "FormSaveFile", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "FormCancel", "Visible", False);
		
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveFile(Command)
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("SaveDecrypted", SaveDecrypted);
	ReturnStructure.Insert("EncryptedFilesExtension", EncryptedFilesExtension);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion
