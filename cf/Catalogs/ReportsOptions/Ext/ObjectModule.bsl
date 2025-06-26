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

#If Not MobileStandaloneServer Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)

	InitializeObject(FillingData);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	AttributesToExclude = New Array;

	If Not Custom Then
		AttributesToExclude.Add("Author");
	EndIf;

	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);

	If Description <> "" And ReportsOptions.DescriptionIsUsed(Report, Ref, Description) Then
		Cancel = True;
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" is taken. Enter another description.';"), 
				Description),, 
			"Description");
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel)

	If AdditionalProperties.Property("PredefinedObjectsFilling") Then
		CheckPredefinedReportOptionFilling(Cancel);
	EndIf;

	If DataExchange.Load Then
		Return;
	EndIf;

	InfobaseUpdate.CheckObjectProcessed(ThisObject);

	AdditionalProperties.Insert("IsNew", IsNew());

	UserChangedDeletionMark = (Not IsNew() And DeletionMark <> Common.ObjectAttributeValue(Ref, "DeletionMark")
		And Not AdditionalProperties.Property("PredefinedObjectsFilling"));

	If Not Custom And UserChangedDeletionMark Then
		If DeletionMark Then
			ErrorText = NStr("en = 'Predefined report options cannot be marked for deletion.';");
		Else
			ErrorText = NStr("en = 'Predefined report options cannot be unmarked for deletion.';");
		EndIf;
		Raise ErrorText;
	EndIf;

	If Not DeletionMark And UserChangedDeletionMark Then
		DescriptionIsUsed = ReportsOptions.DescriptionIsUsed(Report, Ref, Description);
		OptionKeyIsUsed  = ReportsOptions.OptionKeyIsUsed(Report, Ref, VariantKey);
		If DescriptionIsUsed Or OptionKeyIsUsed Then
			ErrorText = NStr("en = 'Cannot clear the deletion mark from the report option:';");
			If DescriptionIsUsed Then
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Name ""%1"" is taken by another option of this report.';"), 
					Description);
			Else
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Key ""%1"" is assigned to another option of this report.';"), 
					VariantKey);
			EndIf;
			ErrorText = ErrorText + NStr("en = 'Before you clear the deletion mark for the report option 
											 |mark the conflicting report option for deletion.';");
			Raise ErrorText;
		EndIf;
	EndIf;

	If UserChangedDeletionMark Then
		InteractiveDeletionMark = ?(Custom, DeletionMark, False);
	EndIf;

	CheckPutting();
	FillFieldsForSearch();

	If Not Custom And AuthorOnly Then
		AuthorOnly = False;
	EndIf;

EndProcedure

Procedure OnWrite(Cancel)

	If DataExchange.Load Then
		Return;
	EndIf;

	OptionUsers = CommonClientServer.StructureProperty(AdditionalProperties,
		"OptionUsers");
	IsNew = CommonClientServer.StructureProperty(AdditionalProperties, "IsNew", False);
	NotifyUsers = CommonClientServer.StructureProperty(AdditionalProperties,
		"NotifyUsers", False);

	InformationRegisters.ReportOptionsSettings.WriteReportOptionAvailabilitySettings(
		Ref, IsNew, OptionUsers, NotifyUsers);

EndProcedure

#EndRegion

#Region Private

Procedure InitializeObject(FillingData)

	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;

	FillPropertyValues(ThisObject, FillingData);
	ReportOptionSettings = CommonClientServer.StructureProperty(FillingData, "Settings");

	If TypeOf(ReportOptionSettings) = Type("DataCompositionSettings") Then

		Settings = New ValueStorage(ReportOptionSettings);

	EndIf;

#Region SetReportType

	If TypeOf(Report) = Type("CatalogRef.MetadataObjectIDs") Then

		ReportType = Enums.ReportsTypes.BuiltIn;

	ElsIf TypeOf(Report) = Type("CatalogRef.ExtensionObjectIDs") Then

		ReportType = Enums.ReportsTypes.Extension;

	ElsIf Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors")
		And TypeOf(Report) = Type("CatalogRef.AdditionalReportsAndDataProcessors") Then 

		ReportType = Enums.ReportsTypes.Additional;

	ElsIf TypeOf(Report) = Type("String") Then

		ReportType = Enums.ReportsTypes.External;

	EndIf;

#EndRegion

#Region SetDataDependingOnAuthorValue

	If ValueIsFilled(Author) Then

		Custom = ValueIsFilled(Author);

		OptionUsers = New ValueList;
		OptionUsers.Add(Author,, True);

		AdditionalProperties.Insert("OptionUsers", OptionUsers);

	EndIf;

#EndRegion

#Region SetParent1

	Basis = CommonClientServer.StructureProperty(FillingData, "Basis");

	If TypeOf(Basis) = TypeOf(Ref) Then

		BaseProperties = Common.ObjectAttributesValues(
			Basis, "Parent, Report, Custom, Location");

		If BaseProperties.Report = Report Then
			Parent = ?(BaseProperties.Custom, BaseProperties.Parent, Basis);
		EndIf;

		Location.Load(BaseProperties.Location.Unload());

	EndIf;

	If Not ValueIsFilled(Parent) Then
		FillInParent();
	EndIf;

	FillInThePlacementByParent();

#EndRegion

EndProcedure

Procedure OnReadPresentationsAtServer() Export

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(ThisObject);
	EndIf;

EndProcedure

Procedure CheckPutting()

	If ValueIsFilled(Context) Then

		Location.Clear();
		Return;

	EndIf;
	
	// Remove the subsystems marked for deletion from the table.
	LinesToDelete = New Array;
	Subsystems = Location.UnloadColumn("Subsystem");
	Subsystems = Common.ObjectsAttributeValue(Subsystems, "DeletionMark");
	For Each Subsystem In Subsystems Do
		If Subsystem.Value Then 
			AssignmentRow2 = Location.Find(Subsystem.Key, "Subsystem");
			If AssignmentRow2 <> Undefined Then
				LinesToDelete.Add(AssignmentRow2);
			EndIf;
		EndIf;
	EndDo;

	For Each AssignmentRow2 In LinesToDelete Do
		Location.Delete(AssignmentRow2);
	EndDo;

EndProcedure

// Populate the FieldDescriptions and FilterParameterDescriptions attributes.
Procedure FillFieldsForSearch()

	Additional = (ReportType = Enums.ReportsTypes.Additional);
	If Not Custom And Not Additional Then
		Return;
	EndIf;

	Try
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		ReportsOptions.FillFieldsForSearch(ThisObject);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot index the scheme of option ""%1"" of report ""%2"":';"), 
			VariantKey, String(Report));
		ErrorText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		ReportsOptions.WriteToLog(EventLogLevel.Error, ErrorText, Ref);
	EndTry;

EndProcedure

// This procedure populates the parent report option based on the report reference and predefined settings.
Procedure FillInParent() Export

	Query = New Query(
		"SELECT ALLOWED TOP 1
		|	PredefinedOptions.Ref,
		|	PredefinedOptions.Enabled
		|INTO PredefinedOptions
		|FROM
		|	Catalog.PredefinedReportsOptions AS PredefinedOptions
		|WHERE
		|	VALUETYPE(&Report) <> TYPE(Catalog.ExtensionObjectIDs)
		|	AND PredefinedOptions.Report = &Report
		|	AND NOT PredefinedOptions.DeletionMark
		|	AND PredefinedOptions.GroupByReport
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	PredefinedOptions.Ref,
		|	PredefinedOptions.Enabled
		|FROM
		|	Catalog.PredefinedExtensionsReportsOptions AS PredefinedOptions
		|	LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableOptions
		|		ON AvailableOptions.Variant = PredefinedOptions.Ref
		|WHERE
		|	VALUETYPE(&Report) = TYPE(Catalog.ExtensionObjectIDs)
		|	AND PredefinedOptions.Report = &Report
		|	AND PredefinedOptions.GroupByReport
		|	AND NOT AvailableOptions.Variant IS NULL
		|
		|ORDER BY
		|	PredefinedOptions.Enabled DESC
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	ReportsOptions.Ref
		|FROM
		|	PredefinedOptions AS PredefinedOptions
		|	INNER JOIN Catalog.ReportsOptions AS ReportsOptions
		|		ON PredefinedOptions.Ref = ReportsOptions.PredefinedOption
		|WHERE
		|	NOT ReportsOptions.DeletionMark");

	Query.SetParameter("Report", Report);

	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Parent = Selection.Ref;
	EndIf;

EndProcedure

Procedure FillInThePlacementByParent()

	If Location.Count() > 0 Or Not ValueIsFilled(Parent) Then
		Return;
	EndIf;

	ParentProperties = Common.ObjectAttributesValues(
		Parent, "PredefinedOption, Location");

	Location.Load(ParentProperties.Location.Unload());
	If Location.Count() > 0 Or Not ValueIsFilled(ParentProperties.PredefinedOption) Then
		Return;
	EndIf;

	PlacingAPredefinedOption = Common.ObjectAttributeValue(
		ParentProperties.PredefinedOption, "Location");

	Location.Load(PlacingAPredefinedOption.Unload());
	For Each TableRow In Location Do
		TableRow.Use = True;
	EndDo;

EndProcedure

// Basic validation of predefined report options.
Procedure CheckPredefinedReportOptionFilling(Cancel)

	If DeletionMark Or Not Predefined Then
		Return;
	EndIf;

	If Not ValueIsFilled(Report) Then
		Raise FieldIsRequired("Report");
	ElsIf Not ValueIsFilled(ReportType) Then
		Raise FieldIsRequired("ReportType");
	ElsIf ReportType <> ReportsOptions.ReportType(Report) Then
		ErrorText = NStr("en = 'Fields ""%1"" and ""%2"" contains inconsistent values.';");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, "ReportType", "Report");
	ElsIf Not ValueIsFilled(PredefinedOption) And (ReportType = Enums.ReportsTypes.BuiltIn
		Or ReportType = Enums.ReportsTypes.Extension) Then
		Raise FieldIsRequired("PredefinedOption");
	EndIf;

EndProcedure

Function FieldIsRequired(FieldName)

	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Field %1 is required.';"), FieldName);

EndFunction

#EndRegion

#EndIf

#Else
	Raise NStr("en = 'Invalid object call on the client.';");

#EndIf