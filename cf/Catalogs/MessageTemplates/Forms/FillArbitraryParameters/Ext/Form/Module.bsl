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
	
	If Not ValueIsFilled(Parameters.Template) Then
		Cancel = True;
		Return;
	EndIf;
	
	SubjectOf = Parameters.SubjectOf;
	AddTemplateParametersFormItems(Parameters.Template);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	Result = New Map;
	
	For Each AttributeName In AttributesList Do
		Result.Insert(AttributeName.Value, ThisObject[AttributeName.Value])
	EndDo;
	
	Close(Result);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddTemplateParametersFormItems(Template)
	
	AttributesToBeAdded = New Array;
	
	InformationRecords = Common.ObjectAttributesValues(Template, "TemplateByExternalDataProcessor, ExternalDataProcessor");
	If InformationRecords.TemplateByExternalDataProcessor <> True Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	MessageTemplatesParameters.Ref,
		|	MessageTemplatesParameters.ParameterName AS Name,
		|	MessageTemplatesParameters.ParameterType AS Type,
		|	MessageTemplatesParameters.ParameterPresentation AS Presentation
		|FROM
		|	Catalog.MessageTemplates.Parameters AS MessageTemplatesParameters
		|WHERE
		|	MessageTemplatesParameters.Ref = &Ref";
		
		Query.SetParameter("Ref", Template);
		
		TemplateParametersTable = Query.Execute().Unload();
		
		For Each Attribute In TemplateParametersTable Do
			
			DescriptionOfTheParameterType = Common.StringTypeDetails(250);
			If TypeOf(Attribute.Type) = Type("ValueStorage") Then
				TheTypeOfTheParameterValue = Attribute.Type.Get();
				If TypeOf(TheTypeOfTheParameterValue) = Type("TypeDescription") Then
					DescriptionOfTheParameterType = TheTypeOfTheParameterValue;
				EndIf;
			EndIf;
			
			AttributesToBeAdded.Add(New FormAttribute(Attribute.Name, DescriptionOfTheParameterType,, Attribute.Presentation));
			
		EndDo;
	ElsIf Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") 
			And InformationRecords.ExternalDataProcessor <> Undefined Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(InformationRecords.ExternalDataProcessor);
			TemplateParameters = ExternalObject.TemplateParameters();
			
			TemplateParametersTable = New ValueTable;
			TemplateParametersTable.Columns.Add("Name"                , New TypeDescription("String", , New StringQualifiers(50, AllowedLength.Variable)));
			TemplateParametersTable.Columns.Add("Type"                , New TypeDescription("TypeDescription"));
			TemplateParametersTable.Columns.Add("Presentation"      , New TypeDescription("String", , New StringQualifiers(150, AllowedLength.Variable)));
			
			For Each TemplateParameter In TemplateParameters Do
				TypeDetails = TemplateParameter.TypeDetails.Types();
				If TypeDetails.Count() > 0 Then
					If TypeDetails[0] <> TypeOf(SubjectOf) Then
						NewParameter1 = TemplateParametersTable.Add();
						NewParameter1.Name = TemplateParameter.ParameterName;
						NewParameter1.Presentation = TemplateParameter.ParameterPresentation;
						NewParameter1.Type = TemplateParameter.TypeDetails;
						AttributesToBeAdded.Add(New FormAttribute(TemplateParameter.ParameterName, TemplateParameter.TypeDetails,, TemplateParameter.ParameterPresentation));
					EndIf;
					
				EndIf;
			EndDo;
	EndIf;
	
	ChangeAttributes(AttributesToBeAdded);
	
	For Each TemplateParameter In TemplateParametersTable Do
		Item = Items.Add(TemplateParameter.Name, Type("FormField"), Items.TemplateParameters);
		Item.Type                        = FormFieldType.InputField;
		Item.TitleLocation         = FormItemTitleLocation.Left;
		Item.Title                  = TemplateParameter.Presentation;
		Item.DataPath                = TemplateParameter.Name;
		Item.HorizontalStretch   = False;
		Item.Width = 50;
		AttributesList.Add(TemplateParameter.Name);
	EndDo;
	
	Height = 3 + TemplateParametersTable.Count() * 2;
	
EndProcedure

#EndRegion

