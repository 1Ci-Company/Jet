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
	
	TemplateName = ?(Common.FileInfobase() Or Parameters.IsInstructionForFileInfobase,
		"UpdateProcedureForTheFileBase", "ClientServerInfobaseUpdateOrder");
	
	If Parameters.IsApplicationUninstallation Then
		Title = NStr("en = 'Version deletion procedure';");
		TemplateName = "ProcedureForDeletingPlatform";
	EndIf;
	
	TemplatesCollection = Metadata.DataProcessors.PlatformUpdateRecommended.Templates;
	
	LocalizedTemplateName = TemplateName + "_" + CurrentLanguage().LanguageCode;
	Template                   = TemplatesCollection.Find(LocalizedTemplateName);
	
	If Template = Undefined Then
		LocalizedTemplateName = TemplateName + "_" + Common.DefaultLanguageCode();
		Template                   = TemplatesCollection.Find(LocalizedTemplateName);
	EndIf;
	
	If Template = Undefined Then
		LocalizedTemplateName = TemplateName;
	EndIf;
	
	UpdateOrderTemplate = DataProcessors.PlatformUpdateRecommended.GetTemplate(LocalizedTemplateName);
	
	PlatformUpdateOrder = UpdateOrderTemplate.GetText();
	
	If Parameters.IsApplicationUninstallation Then
		PlatformUpdateOrder = StrReplace(PlatformUpdateOrder, "%1", "(" + Parameters.PlatformVersion + ")");
	EndIf;
	
	If IsBlankString(PlatformUpdateOrder) Then
		UpdateOrderTemplate.TemplateLanguageCode = Common.DefaultLanguageCode();
		PlatformUpdateOrder = UpdateOrderTemplate.GetText();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ApplicationUpdateOrderOnClick(Item, EventData, StandardProcessing)
	If EventData.Href <> Undefined Then
		StandardProcessing = False;
		FileSystemClient.OpenURL(EventData.Href);
	EndIf;
EndProcedure

&AtClient
Procedure PrintGuide(Command)
	Items.PlatformUpdateOrder.Document.execCommand("Print");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ApplicationUpdateOrderDocumentGenerated(Item)
	// Print command visibility.
	If Not Item.Document.queryCommandSupported("Print") Then
		Items.PrintGuide.Visible = False;
	EndIf;
EndProcedure

#EndRegion