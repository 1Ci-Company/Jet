///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

////////////////////////////////////////////////////////////////////////////////
// "HeaderFooterManagement": Header & footer setup and output mechanism.
//
////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Gets header and footer settings received earlier. If settings are missing,
// a lank setting form is returned.
//
// Returns:
//   Structure - Values of header and footer settings.
//
Function HeaderOrFooterSettings() Export
	Var Settings;
	
	Store = Constants.HeaderOrFooterSettings.Get();
	If TypeOf(Store) = Type("ValueStorage") Then
		Settings = Store.Get();
		If TypeOf(Settings) = Type("Structure") Then
			If Not Settings.Property("Header") 
				Or Not Settings.Property("Footer") Then
				Settings = Undefined;
			Else
				AddHeaderOrFooterSettings(Settings.Header);
				AddHeaderOrFooterSettings(Settings.Footer);
			EndIf;
		EndIf;
	EndIf;
	
	If Settings = Undefined Then
		Settings = BlankHeaderOrFooterSettings();
	EndIf;
	
	Return Settings;
EndFunction

#EndRegion

#Region Private

// Saves settings of headers and footers passed in the parameter to use them later.
//
// Parameters:
//  Settings - Structure - Values of headers and footers settings to be saved.
//
Procedure SaveHeadersAndFootersSettings(Settings) Export
	Constants.HeaderOrFooterSettings.Set(New ValueStorage(Settings));
EndProcedure

// Sets the ReportDescription and User parameter values in template row.
//
// Parameters:
//   Template - String - Header/footer setting whose parameter values are not set yet.
//   ReportTitle - String - Parameter value that will be inserted to the template.
//   User - CatalogRef.Users - Parameter value that will be inserted to the template.
//
// Returns:
//   String - Settings of a header or footer with the template values.
//
Function PropertyValueFromTemplate(Template, ReportTitle, User)
	Result = StrReplace(Template, "[&ReportTitle]", TrimAll(ReportTitle));
	Result = StrReplace(Result, "[&User]"  , TrimAll(User));
	
	Return Result;
EndFunction

// Sets headers and footers in a spreadsheet document.
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - Document that requires setting headers and footers.
//  ReportTitle - String - Parameter value that will be inserted to the template.
//  User - CatalogRef.Users - Parameter value that will be inserted to the template.
//  HeaderOrFooterSettings - Structure - Individual settings of headers and footers.
//
Procedure SetHeadersAndFooters(SpreadsheetDocument, ReportTitle = "", User = Undefined, HeaderOrFooterSettings = Undefined) Export
	If User = Undefined Then
		User = Users.AuthorizedUser();
	EndIf;
	
	If HeaderOrFooterSettings = Undefined Then 
		HeaderOrFooterSettings = HeaderOrFooterSettings();
	EndIf;
	
	If Not HeaderOrFooterSet(SpreadsheetDocument.Header) Then 
		HeaderOrFooterProperties = HeaderOrFooterProperties(HeaderOrFooterSettings.Header, ReportTitle, User);
		FillPropertyValues(SpreadsheetDocument.Header, HeaderOrFooterProperties);
	EndIf;
	
	If Not HeaderOrFooterSet(SpreadsheetDocument.Footer) Then 
		HeaderOrFooterProperties = HeaderOrFooterProperties(HeaderOrFooterSettings.Footer, ReportTitle, User);
		FillPropertyValues(SpreadsheetDocument.Footer, HeaderOrFooterProperties);
	EndIf;
EndProcedure

// Returns the flag of setting up header and footer.
//
// Parameters:
//  HeaderOrFooter - SpreadsheetDocumentHeaderFooter - Spreadsheet header or footer.
//
// Returns:
//   Boolean - Flag indicating whether a header and footer is set.
//
Function HeaderOrFooterSet(HeaderOrFooter)
	Return ValueIsFilled(HeaderOrFooter.LeftText)
		Or ValueIsFilled(HeaderOrFooter.CenterText)
		Or ValueIsFilled(HeaderOrFooter.RightText);
EndFunction

// Returns property values of a header or a footer.
//
// Parameters:
//  HeaderOrFooterSettings1 - See BlankHeaderOrFooterSettings
//  ReportTitle - String - Parameter value that will be inserted to the [&ReportDescription] template.
//  User - CatalogRef.Users - Value to be inserted to the [&User] template.
//
// Returns:
//   Structure - Values of header and footer settings.
//
Function HeaderOrFooterProperties(HeaderOrFooterSettings1, ReportTitle, User)
	HeaderOrFooterProperties = New Structure;
	If ValueIsFilled(HeaderOrFooterSettings1.LeftText)
		Or ValueIsFilled(HeaderOrFooterSettings1.CenterText)
		Or ValueIsFilled(HeaderOrFooterSettings1.RightText) Then
		
		HeaderOrFooterProperties.Insert("Enabled", True);
		HeaderOrFooterProperties.Insert("HomePage", HeaderOrFooterSettings1.HomePage);
		HeaderOrFooterProperties.Insert("VerticalAlign", HeaderOrFooterSettings1.VerticalAlign);
		HeaderOrFooterProperties.Insert("LeftText", PropertyValueFromTemplate(
			HeaderOrFooterSettings1.LeftText, ReportTitle, User));
		HeaderOrFooterProperties.Insert("CenterText", PropertyValueFromTemplate(
			HeaderOrFooterSettings1.CenterText, ReportTitle, User));
		HeaderOrFooterProperties.Insert("RightText", PropertyValueFromTemplate(
			HeaderOrFooterSettings1.RightText, ReportTitle, User));
		
		If HeaderOrFooterSettings1.Property("Font") And HeaderOrFooterSettings1.Font <> Undefined Then
			HeaderOrFooterProperties.Insert("Font", HeaderOrFooterSettings1.Font);
		Else
			HeaderOrFooterProperties.Insert("Font", New Font);
		EndIf;
	Else
		HeaderOrFooterProperties.Insert("Enabled", False);
	EndIf;
	
	Return HeaderOrFooterProperties;
EndFunction

// Headers and footers settings wizard.
//
// Returns:
//   Structure - Settings of headers and footers with the default values.
//
Function BlankHeaderOrFooterSettings()
	Header = New Structure;
	Header.Insert("LeftText", "");
	Header.Insert("CenterText", "");
	Header.Insert("RightText", "");
	Header.Insert("Font", New Font);
	Header.Insert("VerticalAlign", VerticalAlign.Bottom);
	Header.Insert("HomePage", 0);
	
	Footer = New Structure;
	Footer.Insert("LeftText", "");
	Footer.Insert("CenterText", "");
	Footer.Insert("RightText", "");
	Footer.Insert("Font", New Font);
	Footer.Insert("VerticalAlign", VerticalAlign.Top);
	Footer.Insert("HomePage", 0);
	
	Return New Structure("Header, Footer", Header, Footer);
EndFunction

Procedure AddHeaderOrFooterSettings(HeaderOrFooterSettings1)
	If Not HeaderOrFooterSettings1.Property("LeftText")
		Or TypeOf(HeaderOrFooterSettings1.LeftText) <> Type("String") Then
		HeaderOrFooterSettings1.Insert("LeftText", "");
	EndIf;
	If Not HeaderOrFooterSettings1.Property("CenterText")
		Or TypeOf(HeaderOrFooterSettings1.CenterText) <> Type("String") Then
		HeaderOrFooterSettings1.Insert("CenterText", "");
	EndIf;
	If Not HeaderOrFooterSettings1.Property("RightText")
		Or TypeOf(HeaderOrFooterSettings1.RightText) <> Type("String") Then
		HeaderOrFooterSettings1.Insert("RightText", "");
	EndIf;
	If Not HeaderOrFooterSettings1.Property("Font")
		Or TypeOf(HeaderOrFooterSettings1.Font) <> Type("Font") Then
		HeaderOrFooterSettings1.Insert("Font", New Font);
	EndIf;
	If Not HeaderOrFooterSettings1.Property("VerticalAlign")
		Or TypeOf(HeaderOrFooterSettings1.VerticalAlign) <> Type("VerticalAlign") Then
		HeaderOrFooterSettings1.Insert("VerticalAlign", VerticalAlign.Center);
	EndIf;
	If Not HeaderOrFooterSettings1.Property("HomePage")
		Or TypeOf(HeaderOrFooterSettings1.HomePage) <> Type("Number")
		Or HeaderOrFooterSettings1.HomePage < 0 Then
		HeaderOrFooterSettings1.Insert("HomePage", 0);
	EndIf;
EndProcedure

// Defines if settings are standard or blank.
//
// Parameters:
//  Settings - See HeaderOrFooterSettings
//
// Returns:
//   Structure - Information on the header or footer setting status:
//     * Standard1 - Boolean - True if passed settings correspond to standard (common)
//                     settings that are stored in the HeaderOrFooterSettings constant.
//     * Empty1 - Boolean - True if passed settings correspond to blank settings
//                returned by the BlankHeaderOrFooterSettings() function.
//
Function HeadersAndFootersSettingsStatus(Settings) Export 
	SettingsStatus = New Structure("Standard1, Empty1");
	SettingsStatus.Standard1 = Common.DataMatch(Settings, HeaderOrFooterSettings());
	SettingsStatus.Empty1 = Common.DataMatch(Settings, BlankHeaderOrFooterSettings());
	
	Return SettingsStatus;
EndFunction

#EndRegion