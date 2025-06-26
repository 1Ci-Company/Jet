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
	Title = Parameters.Title;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetErrorText();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ErrorTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "OpenSettings" Then
		StandardProcessing = False;
		FilesOperationsClient.OpenScanSettingForm();
	ElsIf FormattedStringURL = "TechnicalInformation" Then
		StandardProcessing = False;
		GetTechnicalInformation();
	ElsIf FormattedStringURL = "Run32BitClient" Then
		StandardProcessing = False;
		Run32BitClient();
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RedoScanning(Command)
	Close("RedoScanning");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetErrorText()
	Recommendations = New Array;
	Recommendations.Add(NStr("en = 'Check scanner connection and try again.';"));
	Recommendations.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Specify an available scanner in the <a href = ""%1"">scanning settings</a>.';"),
		"OpenSettings"));

	If Not Parameters.ShowScannerDialog And Not CommonClient.IsLinuxClient() Then
		Recommendations.Add(NStr("en = 'Switch to the <b>advanced settings</b>.';"));
	EndIf;
	
	If Parameters.ShowScannerDialog 
		Or Parameters.Resolution = PredefinedValue("Enum.ScannedImageResolutions.dpi1200") Then
		Recommendations.Add(NStr("en = 'Reduce the scanner resolution to <b>600 dpi</b>.';"));
	EndIf;

	SystemInfo = New SystemInfo();
	If SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		Recommendations.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Install the <a href = ""%1"">1C:Enterprise thin client for Windows x86</a>.
				|It supports more scanners and settings.';"), 
				"Run32BitClient"));
	EndIf;

	If Parameters.AssistanceRequiredMode Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Scanning is performed by %1.';"), 
			Parameters.ScannerName);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Scanner ""%1"" is not found or disconnected.';"), 
			Parameters.ScannerName);
	EndIf;		

	ErrorText = ErrorText + Chars.LF + Chars.LF 
		+ NStr("en = 'Try the following solutions:';") + Chars.LF
		+ " • " + StrConcat(Recommendations, Chars.LF + " • ");
	ErrorText = ErrorText + Chars.LF + Chars.LF 
		+ StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'If the issue persists, contact 1C technical support
				|and provide <a href = ""%1"">technical information</a> about the issue.';"), 
		"TechnicalInformation");
	
	Items.ErrorText.Title = StringFunctionsClient.FormattedString(ErrorText);
EndProcedure

&AtClient
Procedure GetTechnicalInformation()
	FilesOperationsInternalClient.GetTechnicalInformation(Parameters.DetailErrorDescription);
EndProcedure

&AtClient
Procedure Run32BitClient()
#If Not WebClient Then
	BinDir32 = StrReplace(BinDir(), "\Program Files\", "\Program Files (x86)\");
	ApplicationName = BinDir32 + "1cv8.exe";
	AppFile = New File(ApplicationName);
	If AppFile.Exists() Then 
		FileSystemClient.StartApplication(ApplicationName);
	Else
		SystemInfo = New SystemInfo();
		FileSystemClient.OpenURL("https://releases.1c.ru/version_files?nick=Platform83&ver=" + SystemInfo.AppVersion);
	EndIf;
#EndIf
EndProcedure

#EndRegion
