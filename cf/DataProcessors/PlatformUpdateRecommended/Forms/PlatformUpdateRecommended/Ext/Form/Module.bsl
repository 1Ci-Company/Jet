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
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	SkipExit = Parameters.SkipExit;
	
	Items.MessageText.Title = Parameters.MessageText;
	SystemInfo = New SystemInfo;
	Current       = SystemInfo.AppVersion;
	Min   = Parameters.MinPlatformVersion;
	Recommended = Parameters.RecommendedPlatformVersion;
	
	Items.MessageText.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.MessageText.Title, Min);
	
	VersionNumber   = Recommended;
	CannotContinue = False;
	TextCondition = "";
	If CommonClientServer.CompareVersions(Current, Min) < 0 Then
		TextCondition = NStr("en = 'The app requires 1C:Enterprise version %1 or later.
			|Current version is %2.';");
		CannotContinue = True;
		VersionNumber = Min;
	Else
		TextCondition = NStr("en = 'The app requires 1C:Enterprise version %1 or later.
			|Current version is %2.';");
	EndIf;
	
	Items.Version.Title = StringFunctionsClientServer.SubstituteParametersToString(
		TextCondition,
		VersionNumber,
		SystemInfo.AppVersion);
	
	If CannotContinue Then
		Items.QueryText.Visible = False;
		Items.FormNo.Visible     = False;
		Title = NStr("en = '1C:Enterprise update required';");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not ActionDefined Then
		ActionDefined = True;
		
		If Not SkipExit Then
			Terminate();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HyperlinkAnchorTextClick(Item)
	
	OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateOrder",,ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ContinueWork(Command)
	
	ActionDefined = True;
	Close("Continue");
	
EndProcedure

&AtClient
Procedure ExitApplication(Command)
	
	ActionDefined = True;
	If Not SkipExit Then
		Terminate();
	EndIf;
	Close();
	
EndProcedure

#EndRegion
