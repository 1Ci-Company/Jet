///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Collects catalog data by metadata object references and updates register data.
//
Procedure UpdateDataByMetadataObjectsRefs(MetadataObjectsRefs) Export
	Query = NewRegisterDataUpdateRequest(MetadataObjectsRefs);
	
	ReferencesSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While ReferencesSelection.Next() Do
		RecordsSelection = ReferencesSelection.Select();
		While RecordsSelection.Next() Do
			RecordManager = CreateRecordManager();
			FillPropertyValues(RecordManager, RecordsSelection);
			RecordManager.Write(True);
		EndDo;
		
		// Registering the references being used for further deletion of the unused ones from the register.
		MetadataObjectsRefs.Delete(MetadataObjectsRefs.Find(ReferencesSelection.RelatedObject));
	EndDo;
	
	// Clearing the register from unused references.
	For Each RelatedObject In MetadataObjectsRefs Do
		RecordSet = CreateRecordSet();
		RecordSet.Filter.RelatedObject.Set(RelatedObject);
		RecordSet.Write(True);
	EndDo;
EndProcedure

// Returns the text of the register data update request.
//
Function NewRegisterDataUpdateRequest(MetadataObjectsRefs)
	
	Query = New Query;
	
	QueryText =
	"SELECT DISTINCT
	|	AdditionalReportsAndDataProcessorsAssignment.RelatedObject AS RelatedObject,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &KindObjectFilling
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseObjectFilling,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &KindOfReport
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseReports,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &KindCreateRelatedObjects
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseRelatedObjectCreation,
	|	AdditionalReportsAndDataProcessorsAssignment.Ref.UseForObjectForm,
	|	AdditionalReportsAndDataProcessorsAssignment.Ref.UseForListForm
	|INTO ttPrimaryData
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AdditionalReportsAndDataProcessorsAssignment
	|WHERE
	|	AdditionalReportsAndDataProcessorsAssignment.RelatedObject IN(&MetadataObjectsRefs)
	|	AND AdditionalReportsAndDataProcessorsAssignment.Ref.Publication <> &PublicationNotEqual
	|	AND AdditionalReportsAndDataProcessorsAssignment.Ref.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectForms.RelatedObject,
	|	FALSE AS UseObjectFilling,
	|	ObjectForms.UseReports,
	|	ObjectForms.UseRelatedObjectCreation,
	|	&ObjectFormType AS FormType
	|INTO ttResult
	|FROM
	|	ttPrimaryData AS ObjectForms
	|WHERE
	|	ObjectForms.UseForObjectForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledObjectForms.RelatedObject,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&ObjectFormType
	|FROM
	|	ttPrimaryData AS DisabledObjectForms
	|WHERE
	|	DisabledObjectForms.UseForObjectForm = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	ListForms.RelatedObject,
	|	ListForms.UseObjectFilling,
	|	ListForms.UseReports,
	|	ListForms.UseRelatedObjectCreation,
	|	&ListFormType
	|FROM
	|	ttPrimaryData AS ListForms
	|WHERE
	|	ListForms.UseForListForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledListForms.RelatedObject,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&ListFormType
	|FROM
	|	ttPrimaryData AS DisabledListForms
	|WHERE
	|	DisabledListForms.UseForListForm = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tabResult.RelatedObject AS RelatedObject,
	|	tabResult.FormType,
	|	MAX(tabResult.UseObjectFilling) AS UseObjectFilling,
	|	MAX(tabResult.UseReports) AS UseReports,
	|	MAX(tabResult.UseRelatedObjectCreation) AS UseRelatedObjectCreation
	|FROM
	|	ttResult AS tabResult
	|
	|GROUP BY
	|	tabResult.RelatedObject,
	|	tabResult.FormType
	|TOTALS BY
	|	RelatedObject";
	
	If MetadataObjectsRefs = Undefined Then
		QueryText = StrReplace(
			QueryText,
			"AdditionalReportsAndDataProcessorsAssignment.RelatedObject IN(&MetadataObjectsRefs)
			|	AND ",
			"");
	Else
		Query.SetParameter("MetadataObjectsRefs", MetadataObjectsRefs);
	EndIf;
	
	Query.SetParameter("PublicationNotEqual", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled);
	Query.SetParameter("KindObjectFilling",         Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling);
	Query.SetParameter("KindOfReport",                     Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindPrintForm",             Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm);
	Query.SetParameter("KindCreateRelatedObjects", Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation);
	Query.SetParameter("ListFormType",  AdditionalReportsAndDataProcessorsClientServer.ListFormType());
	Query.SetParameter("ObjectFormType", AdditionalReportsAndDataProcessorsClientServer.ObjectFormType());
	Query.Text = QueryText;
	
	Return Query;
EndFunction

#EndRegion

#EndIf