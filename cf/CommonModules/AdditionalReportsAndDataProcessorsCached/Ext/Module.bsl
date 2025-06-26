///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Returns additional report or data processor publication kinds, which are available in the application.
Function AvaliablePublicationKinds() Export
	
	Result = New Array();
	
	Values = Metadata.Enums.AdditionalReportsAndDataProcessorsPublicationOptions.EnumValues;
	PublicationKindsToExcept = AdditionalReportsAndDataProcessors.NotAvailablePublicationKinds();
	
	For Each Value In Values Do
		If PublicationKindsToExcept.Find(Value.Name) = Undefined Then
			Result.Add(Enums.AdditionalReportsAndDataProcessorsPublicationOptions[Value.Name]);
		EndIf;
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Settings of the form of the object being assigned.
Function AssignedObjectFormParameters(FullFormName, FormType = Undefined) Export
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return "";
	EndIf;
	
	Result = New Structure("IsObjectForm, FormType, ParentRef");
	
	MetadataForm = Metadata.FindByFullName(FullFormName);
	If MetadataForm = Undefined Then
		PointPosition = StrLen(FullFormName);
		While Mid(FullFormName, PointPosition, 1) <> "." Do
			PointPosition = PointPosition - 1;
		EndDo;
		FullParentName = Left(FullFormName, PointPosition - 1);
		MetadataParent = Metadata.FindByFullName(FullParentName);
	Else
		MetadataParent = MetadataForm.Parent();
	EndIf;
	If MetadataParent = Undefined Or TypeOf(MetadataParent) = Type("ConfigurationMetadataObject") Then
		Return "";
	EndIf;
	Result.ParentRef = Common.MetadataObjectID(MetadataParent);
	
	If FormType <> Undefined Then
		If Upper(FormType) = Upper(AdditionalReportsAndDataProcessorsClientServer.ObjectFormType()) Then
			Result.IsObjectForm = True;
		ElsIf Upper(FormType) = Upper(AdditionalReportsAndDataProcessorsClientServer.ListFormType()) Then
			Result.IsObjectForm = False;
		Else
			Result.IsObjectForm = (MetadataParent.DefaultObjectForm = MetadataForm);
		EndIf;
	Else
		Collection = New Structure("DefaultObjectForm");
		FillPropertyValues(Collection, MetadataParent);
		Result.IsObjectForm = (Collection.DefaultObjectForm = MetadataForm);
	EndIf;
	
	If Result.IsObjectForm Then // Object form.
		Result.FormType = AdditionalReportsAndDataProcessorsClientServer.ObjectFormType();
	Else // List form
		Result.FormType = AdditionalReportsAndDataProcessorsClientServer.ListFormType();
	EndIf;
	
	Return New FixedStructure(Result);
EndFunction

#EndRegion
