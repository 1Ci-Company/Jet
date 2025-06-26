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
	
	Resolution = Parameters.Resolution;
	Chromaticity = Parameters.Chromaticity;
	Rotation = Parameters.Rotation;
	PaperSize = Parameters.PaperSize;
	DuplexScanning = Parameters.DuplexScanning;
	UseImageMagickToConvertToPDF = Parameters.UseImageMagickToConvertToPDF;
	ShowScannerDialog = Parameters.ShowScannerDialog;
	ScannedImageFormat = Parameters.ScannedImageFormat;
	JPGQuality = Parameters.JPGQuality;
	TIFFDeflation = Parameters.TIFFDeflation;
	ShouldSaveAsPDF = Parameters.ShouldSaveAsPDF;
	MultipageStorageFormat = Parameters.MultipageStorageFormat;
	
	Items.Rotation.Enabled = Parameters.RotationAvailable;
	Items.PaperSize.Enabled = Parameters.PaperSizeAvailable;
	Items.DuplexScanning.Enabled = Parameters.DuplexScanningAvailable;
	
	JPGFormat = Enums.ScannedImageFormats.JPG;
	TIFFormat = Enums.ScannedImageFormats.TIF;
	
	Items.GroupJPGQuantity.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	
	Items.JPGQuality.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Quality (%1)';"), JPGQuality);
	InstallHints();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If CommonClient.IsLinuxClient() Then
		AdaptForLinux();
		ShowScannerDialog = False;
	EndIf;
	
	ProcessScanDialogUsage();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ScannedImageFormatOnChange(Item)
	
	Items.GroupJPGQuantity.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	InstallHints();
	
EndProcedure

&AtClient
Procedure JPGQualityOnChange(Item)
	Items.JPGQuality.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Quality (%1)';"), JPGQuality);
EndProcedure

&AtClient
Procedure ShowScannerDialogOnChange(Item)
	ProcessScanDialogUsage();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then 
		Return;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("ShowScannerDialog",  ShowScannerDialog);
	SelectionResult.Insert("Resolution",               Resolution);
	SelectionResult.Insert("Chromaticity",                Chromaticity);
	SelectionResult.Insert("Rotation",                  Rotation);
	SelectionResult.Insert("PaperSize",             PaperSize);
	SelectionResult.Insert("DuplexScanning", DuplexScanning);
	
	SelectionResult.Insert("UseImageMagickToConvertToPDF",
		UseImageMagickToConvertToPDF);
	
	SelectionResult.Insert("ScannedImageFormat", ScannedImageFormat);
	SelectionResult.Insert("JPGQuality",                     JPGQuality);
	SelectionResult.Insert("TIFFDeflation",                      TIFFDeflation);
	SelectionResult.Insert("ShouldSaveAsPDF",                   ShouldSaveAsPDF);
	SelectionResult.Insert("MultipageStorageFormat",   MultipageStorageFormat);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InstallHints()
	
	FormatTooltip = "";
	ExtendedTooltip = String(Items.ConvertToPDF.ExtendedTooltip.Title); 
	Hints = StrSplit(ExtendedTooltip, Chars.LF);
	CurFormat = String(ScannedImageFormat);
	For Each ToolTip In Hints Do
		If StrStartsWith(ToolTip, CurFormat) Then
			 FormatTooltip = ToolTip;
		EndIf;
	EndDo;
	
	Items.SinglePageDocumentFormatDetails.Title = FormatTooltip;
	
EndProcedure

&AtClient
Procedure ProcessScanDialogUsage()
	
	Items.Resolution.Enabled = Not ShowScannerDialog;
	Items.Chromaticity.Enabled = Not ShowScannerDialog;
	Items.Rotation.Enabled = Not ShowScannerDialog;
	Items.PaperSize.Enabled = Not ShowScannerDialog;
	Items.DuplexScanning.Enabled = Not ShowScannerDialog;
	Items.ScannedImageFormat.Enabled = Not ShowScannerDialog;
	Items.JPGQuality.Enabled = Not ShowScannerDialog;
	Items.TIFFDeflation.Enabled = Not ShowScannerDialog;

EndProcedure

&AtServer
Procedure AdaptForLinux()
	Items.ShowScannerDialog.Visible = False;
	Items.Rotation.Visible = False;
	AvailableFormats = New Array;
	AvailableFormats.Add(Enums.ScannedImageFormats.PNG);
	AvailableFormats.Add(Enums.ScannedImageFormats.JPG);
	Items.ScannedImageFormat.ChoiceList.LoadValues(AvailableFormats);
	Items.ScannedImageFormat.ListChoiceMode = True;
	If AvailableFormats.Find(ScannedImageFormat) = Undefined Then
		ScannedImageFormat = Enums.ScannedImageFormats.PNG;
		Modified = True;
	EndIf;
EndProcedure

#EndRegion
