///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Adding fields on whose basis a business process presentation will be generated.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Fields                 - Array - fields used to generate a business process presentation.
//  StandardProcessing - Boolean - If False, the standard filling processing is
//                                  skipped.
//
Procedure BusinessProcessPresentationFieldsGetProcessing(ObjectManager, Fields, StandardProcessing) Export
	
	Fields.Add("Description");
	Fields.Add("Date");
	StandardProcessing = False;

EndProcedure

// CAC:547-off is called in the GetBusinessProcessPresentation event subscription.

// Processing for getting a business process presentation based on data fields.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Data               - Structure - fields used to generate a business process presentation: 
//  Presentation        - String - a business process presentation.
//  StandardProcessing - Boolean - If False, the standard filling processing is
//                                  skipped.
//
Procedure BusinessProcessPresentationGetProcessing(ObjectManager, Data, Presentation, StandardProcessing) Export
	
#If Server Or ThickClientOrdinaryApplication Or ThickClientManagedApplication Or ExternalConnection Then
	Date = Format(Data.Date, ?(GetFunctionalOption("UseDateAndTimeInTaskDeadlines"), "DLF=DT", "DLF=D"));
	Presentation = Metadata.FindByType(TypeOf(ObjectManager)).Presentation();
#Else	
	Date = Format(Data.Date, "DLF=D");
	Presentation = NStr("en = 'Business process';");
#EndIf
	
	BusinessProcessRepresentation(ObjectManager, Data, Date, Presentation, StandardProcessing);
	
EndProcedure

// CAC:547-on is called in the GetBusinessProcessPresentation event subscription.

#EndRegion

#Region Private

// Data processor of receiving a business process presentation based on data fields.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Data               - Structure - the fields used to generate a business process presentation, where:
//   * Description      - String - a business process description.
//  Date                 - Date   - a business process creation date.
//  Presentation        - String - a business process presentation.
//  StandardProcessing - Boolean - If False, the standard filling processing is
//                                  skipped.
//
Procedure BusinessProcessRepresentation(ObjectManager, Data, Date, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	TemplateOfPresentation  = NStr("en = '%1, started on %2 (%3)';");
	Description         = ?(IsBlankString(Data.Description), NStr("en = 'No details';"), Data.Description);
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfPresentation, Description, Date, Presentation);
	
EndProcedure

#EndRegion