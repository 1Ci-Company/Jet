///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Function TagNameCondition() Export
	Return NStr("en = 'v8 Condition';");
EndFunction

#EndRegion

#Region Private

Function PrintFormsCollectionFieldsNames() Export
	
	Fields = New Array;
	Fields.Add("TemplateName");
	Fields.Add("UpperCaseName");
	Fields.Add("TemplateSynonym");
	Fields.Add("SpreadsheetDocument");
	Fields.Add("Copies2");
	Fields.Add("Picture");
	Fields.Add("FullTemplatePath");
	Fields.Add("PrintFormFileName");
	Fields.Add("OfficeDocuments");
	Fields.Add("OutputInOtherLanguagesAvailable");
	Fields.Add("GenerationErrorText");
	Fields.Add("Protection");
	
	Return Fields;
	
EndFunction

// See PrintManagement.PrintToFile.
Function SettingsForSaving() Export
	
	SettingsForSaving = New Structure;
	SettingsForSaving.Insert("SaveFormats", New Array);
	SettingsForSaving.Insert("PackToArchive", False);
	SettingsForSaving.Insert("TransliterateFilesNames", False);
	SettingsForSaving.Insert("SignatureAndSeal", False);
	
	Return SettingsForSaving;
	
EndFunction

Function AreaID(Area) Export
	
	CoordinatesOfArea = New Array;
	CoordinatesOfArea.Add(Format(Area.Top, "NG=0"));
	CoordinatesOfArea.Add(Format(Area.Left, "NG=0"));
	CoordinatesOfArea.Add(Format(Area.Bottom, "NG=0"));
	CoordinatesOfArea.Add(Format(Area.Right, "NG=0"));
	
	AreaID = StrConcat(CoordinatesOfArea, ":");
	
	Return AreaID;
	
EndFunction

#EndRegion
