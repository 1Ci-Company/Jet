///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		DataSeparationEnabled = Common.DataSeparationEnabled();
		Items.UseAdditionalReportsAndDataProcessors.Visible = Not DataSeparationEnabled;
		Items.OpenAdditionalReportsAndDataProcessors.Visible      = Not DataSeparationEnabled
			// In SaaS mode, if it is enabled by the service administrator.
			Or ConstantsSet.UseAdditionalReportsAndDataProcessors;
	Else
		Items.AdditionalReportsAndDataProcessorsGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		Items.OpenReportsBulkEmails.Visible = ModuleReportDistribution.InsertRight1(); 
		If Common.SubsystemExists("StandardSubsystems.Interactions") Then
			ToolTipText = NStr("en = 'Provides you with the information on the date when reports were sent, the recipients, and the result of sending. To limit the amount of stored data,
			|obsolete report distribution history is automatically deleted. Besides the report distribution history, sent emails are saved indefinitely.';");
			Items.GroupReportDistributionHistorySetup.ExtendedTooltip.Title = ToolTipText;
		EndIf;
		NumberFormat_ = NStr("en = '%Number% %OfMonths%';");
		NumberFormat_ = StrReplace(NumberFormat_, "%Number%", "Ch");
		NumberFormat_ = StrReplace(NumberFormat_, "%OfMonths%", NStr("en = 'months';"));
		Items.ReportDistributionHistoryRetentionPeriodInMonths.EditFormat =
			StringFunctionsClientServer.SubstituteParametersToString("BLACKSEAFLEET='%1'", NumberFormat_);	
		Items.ReportDistributionHistoryRetentionPeriodInMonths.Width = StrLen(NumberFormat_);
	Else
		Items.ReportsBulkEmailsGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		TextTranslationService = ConstantsSet["TextTranslationService"];
		Items.TextTranslationServiceSetting.Title = TitleOfTheTextTranslationServiceSettings(TextTranslationService);
	Else
		Items.AutomaticTranslationGroup.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.PrintFormsReportsAndDataProcessorsOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseAdditionalReportsAndDataProcessorsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseSourceDocumentsOriginalsAccountingOnChange(Item)

	Attachable_OnChangeAttribute(Item)

EndProcedure

&AtClient
Procedure UseTextTranslationServiceOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	If ConstantsSet["UseTextTranslationService"] And Not ValueIsFilled(ConstantsSet["TextTranslationService"]) Then
		GoToTheTranslatorSettings();
	EndIf;
	
EndProcedure

&AtClient
Procedure TextTranslationServiceSettingURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "GoToSettingUpTheTextTranslationService" Then
		StandardProcessing = False;
		GoToTheTranslatorSettings();
	EndIf;
	
EndProcedure

&AtClient
Procedure RetainReportDistributionHistoryOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);   
		
	If CommonClient.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistributionServerCall = CommonClient.CommonModule("ReportMailingServerCall");
		ModuleReportDistributionServerCall.OnChangeRetainReportDistributionHistory();
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportDistributionHistoryRetentionPeriodInMonthsOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AdditionalReportsAndDataProcessors(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsClient = CommonClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
		ModuleAdditionalReportsAndDataProcessorsClient.OpenAdditionalReportsAndDataProcessorsList();
	EndIf;
	
EndProcedure    

&AtClient
Procedure ClearReportDistributionHistory(Command)

	If CommonClient.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistributionClient = CommonClient.CommonModule("ReportMailingClient");
		ModuleReportDistributionClient.ClearReportDistributionHistory(ThisObject);
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GoToTheTranslatorSettings()
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		ModuleTranslationOfTextIntoOtherLanguagesClient = CommonClient.CommonModule("TextTranslationToolClient");
		NotifyDescription = New NotifyDescription("WhenYouFinishSettingUpTheTranslationService", ThisObject);
		ModuleTranslationOfTextIntoOtherLanguagesClient.GoToSettings(ThisObject, NotifyDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure WhenYouFinishSettingUpTheTranslationService(Val SelectedTranslator, AdditionalParameters) Export
	
	If SelectedTranslator = Undefined Then
		SelectedTranslator = CurrentTranslator();
	EndIf;
	
	Items.TextTranslationServiceSetting.Title = TitleOfTheTextTranslationServiceSettings(SelectedTranslator);
	If Not ValueIsFilled(SelectedTranslator) Then
		ConstantsSet["UseTextTranslationService"] = False;
		Attachable_OnChangeAttribute(Items.UseTextTranslationService);
	EndIf;
	
	ConstantsSet["TextTranslationService"] = SelectedTranslator;
	
EndProcedure

&AtClientAtServerNoContext
Function TitleOfTheTextTranslationServiceSettings(TextTranslationService)
	
	If ValueIsFilled(TextTranslationService) Then
		Template = NStr("en = 'Translate with <a href=""%1"">%2</a>';");
	Else
		Template = NStr("en = 'Online translation service';");
	EndIf;
	
#If Client Then
	Return StringFunctionsClient.FormattedString(Template, "GoToSettingUpTheTextTranslationService", TextTranslationService);
#Else
	Return StringFunctions.FormattedString(Template, "GoToSettingUpTheTextTranslationService", TextTranslationService);
#EndIf
	
EndFunction

&AtServerNoContext
Function CurrentTranslator()
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		ModuleTranslationOfTextIntoOtherLanguages = Common.CommonModule("TextTranslationTool");
		Return ModuleTranslationOfTextIntoOtherLanguages.TextTranslationService();
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	
	If ShouldRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	ConstantName = SaveAttributeValue(DataPathAttribute);
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		Return "";
	EndIf;
	
	ConstantName = NameParts[1];
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If DataPathAttribute = "ConstantsSet.UseAdditionalReportsAndDataProcessors" Or DataPathAttribute = ""
		And Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Items.OpenAdditionalReportsAndDataProcessors.Enabled = ConstantsSet.UseAdditionalReportsAndDataProcessors;
	EndIf;
	
	If DataPathAttribute = "ConstantsSet.UseSourceDocumentsOriginalsRecording" Or DataPathAttribute = ""
		And Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		Items.OpenSourceDocumentsOriginalsStates.Enabled = ConstantsSet.UseSourceDocumentsOriginalsRecording;
	EndIf;       
	
	If  DataPathAttribute = "ConstantsSet.RetainReportDistributionHistory" Or DataPathAttribute = ""
		And Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		Items.ReportDistributionHistoryRetentionPeriodInMonths.Enabled = ConstantsSet["RetainReportDistributionHistory"];
	EndIf;

EndProcedure

#EndRegion
