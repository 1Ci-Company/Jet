///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Backward compatibility.
// Creates details of the message template parameter table.
//
// Returns:
//   ValueTable:
//    * ParameterName                - String - a parameter name.
//    * TypeDetails                - TypeDescription - parameter type details.
//    * IsPredefinedParameter - Boolean - indicates whether the parameter is predefined.
//    * ParameterPresentation      - String - a parameter presentation.
//
Function ParametersTable() Export
	
	TemplateParameters = New ValueTable;
	
	TemplateParameters.Columns.Add("ParameterName"                , New TypeDescription("String",, New StringQualifiers(50, AllowedLength.Variable)));
	TemplateParameters.Columns.Add("TypeDetails"                , New TypeDescription("TypeDescription"));
	TemplateParameters.Columns.Add("IsPredefinedParameter" , New TypeDescription("Boolean"));
	TemplateParameters.Columns.Add("ParameterPresentation"      , New TypeDescription("String",, New StringQualifiers(150, AllowedLength.Variable)));
	
	Return TemplateParameters;
	
EndFunction

#EndRegion
