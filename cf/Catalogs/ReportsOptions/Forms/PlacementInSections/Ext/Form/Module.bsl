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

	SetConditionalAppearance();

	MixedImportance = NStr("en = 'Mixed';");
	
	// The number of report options is checked before opening the form.
	OptionsToAssign.LoadValues(Parameters.Variants);
	OptionsCount = OptionsToAssign.Count();
	FillSections();

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ErrorsMessages <> Undefined Then
		Cancel = True;
		ClearMessages();
		StandardSubsystemsClient.ShowQuestionToUser(Undefined,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1
				|Details:
				|%2';"), 
			ErrorsMessages.Text, ErrorsMessages.More), QuestionDialogMode.OK);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeUseOnChange(Item)
	ReportsOptionsClient.SubsystemsTreeUseOnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure SubsystemsTreeImportanceOnChange(Item)
	ReportsOptionsClient.SubsystemsTreeImportanceOnChange(ThisObject, Item);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Place(Command)
	WriteAtServer();
	NotificationText1 = NStr("en = 'Settings changed for %1 report options.';");
	NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(NotificationText1, Format(
		OptionsToAssign.Count(), "NZ=0; NG=0"));
	ShowUserNotification(,, NotificationText1);
	ReportsOptionsClient.UpdateOpenForms();
	Close();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	ClearSectionsCheckBoxes();
	Items.SubsystemsTree.Expand(SubsystemsTree.GetItems()[0].GetID(), True);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SubsystemsTreeImportance.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SubsystemsTree.Importance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("MixedImportance");

	LockedAttributeColor1 = Metadata.StyleItems.LockedAttributeColor;
	Item.Appearance.SetParameterValue("TextColor", LockedAttributeColor1.Value);

	ReportsOptions.SetSubsystemsTreeConditionalAppearance(ThisObject);

EndProcedure

&AtServer
Procedure ClearSectionsCheckBoxes()

	DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	FoundItems = DestinationTree.Rows.FindRows(New Structure("Use", 1), True);
	For Each TreeRow In FoundItems Do
		TreeRow.Use = 0;
		TreeRow.Modified = True;
	EndDo;

	FoundItems = DestinationTree.Rows.FindRows(New Structure("Use", 2), True);
	For Each TreeRow In FoundItems Do
		TreeRow.Use = 0;
		TreeRow.Modified = True;
	EndDo;

	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
EndProcedure

&AtServer
Procedure FillSections()

	FillingData = SectionsFillingData();
	FilteredOptions = FillingData.FilteredOptions;

	ErrorsCount = FilteredOptions.Count();

	If ErrorsCount > 0 Then
		ErrorsMessages = New Structure("Text, More");
		CurrentReason = 0;
		ErrorsMessages.More = "";
		For Each TableRow In FilteredOptions Do
			If CurrentReason <> TableRow.Cause Then
				CurrentReason = TableRow.Cause;
				ErrorsMessages.More = ErrorsMessages.More + Chars.LF + Chars.LF;
				If CurrentReason = 1 Then
					ErrorsMessages.More = ErrorsMessages.More + NStr("en = 'Marked for deletion:';");
				ElsIf CurrentReason = 2 Then
					ErrorsMessages.More = ErrorsMessages.More + NStr("en = 'Insufficient rights to modify:';");
				ElsIf CurrentReason = 3 Then
					ErrorsMessages.More = ErrorsMessages.More + NStr("en = 'The report is disabled or cannot be accessed with the rights:';");
				ElsIf CurrentReason = 4 Then
					ErrorsMessages.More = ErrorsMessages.More + NStr("en = 'Report option is disabled using the functional option:';");
				EndIf;
			EndIf;

			ErrorsMessages.More = TrimL(ErrorsMessages.More) + Chars.LF + "    - " + String(
				TableRow.Ref);
			OptionsToAssign.Delete(OptionsToAssign.FindByValue(TableRow.Ref));
		EndDo;

		OptionsCount = OptionsToAssign.Count();

		If OptionsCount = 0 Then
			ErrorsMessages.Text = NStr("en = 'Insufficient rights to add selected report options to sections.';");
		Else
			ErrorsMessages.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient rights to add some report options (%1) to sections.';"),
				Format(ErrorsCount, "NG="));
		EndIf;

		ErrorsMessages = New FixedStructure(ErrorsMessages);
	EndIf;

	SubsystemsOccurrences = FillingData.SubsystemsOccurrences;

	SourceTree = ReportsOptionsCached.CurrentUserSubsystems().Tree;

	DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	DestinationTree.Rows.Clear();

	AddSubsystemsToTree(DestinationTree, SourceTree, SubsystemsOccurrences);

	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
EndProcedure

// Returns the data for populating the sections tree.
//
// Returns:
//  Structure:
//    * FilteredOptions - ValueTable:
//        ** Ref - CatalogRef.ReportsOptions
//        ** Cause - Number
//    * SubsystemsOccurrences - ValueTable:
//        ** Ref - CatalogRef.ReportsOptions
//        ** Count - Number
//        ** Importance - String
//
&AtServer
Function SectionsFillingData()

	Query = New Query(SectionsFillingQueryText());
	Query.SetParameter("FullRightsToOptions", ReportsOptions.FullRightsToOptions());
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("References", OptionsToAssign.UnloadValues());
	Query.SetParameter("UserReports", ReportsOptions.CurrentUserReports());
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	Query.SetParameter("ImportantPresentation", ReportsOptions.ImportantPresentation());
	Query.SetParameter("SeeAlsoPresentation", ReportsOptions.SeeAlsoPresentation());

	Package = Query.ExecuteBatch();
	Boundary = Package.UBound();

	FillingData = New Structure;
	FillingData.Insert("FilteredOptions", Package[Boundary - 1].Unload());
	FillingData.Insert("SubsystemsOccurrences", Package[Boundary].Unload());

	Return FillingData;

EndFunction

&AtServer
Function SectionsFillingQueryText()
	
	// ACC:70-off - The full join with "SeparatedSettings" just slightly slows down the query 
	// since the combined tables don't have many records.
	Return "SELECT ALLOWED
			|	ReportsOptions.Ref,
			|	ReportsOptions.PredefinedOption,
			|	CASE
			|		WHEN ReportsOptions.DeletionMark
			|			THEN 1
			|		WHEN &FullRightsToOptions = FALSE
			|				AND ReportsOptions.Author <> &CurrentUser
			|			THEN 2
			|		WHEN NOT ReportsOptions.Report IN (&UserReports)
			|			THEN 3
			|		WHEN ReportsOptions.Ref IN (&DIsabledApplicationOptions)
			|			THEN 4
			|		ELSE 0
			|	END AS Cause
			|INTO ReportsOptions
			|FROM
			|	Catalog.ReportsOptions AS ReportsOptions
			|WHERE
			|	ReportsOptions.Ref IN(&References)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ReportsOptions.Ref AS Ref,
			|	ConfigurationPlacement.Subsystem AS Subsystem,
			|	ConfigurationPlacement.Important AS Important,
			|	ConfigurationPlacement.SeeAlso AS SeeAlso
			|INTO CommonSettings
			|FROM
			|	ReportsOptions AS ReportsOptions
			|	INNER JOIN Catalog.PredefinedReportsOptions.Location AS ConfigurationPlacement
			|		ON ReportsOptions.Cause = 0
			|		AND ReportsOptions.PredefinedOption = ConfigurationPlacement.Ref
			|
			|UNION ALL
			|
			|SELECT
			|	ReportsOptions.Ref,
			|	ExtensionsPlacement.Subsystem,
			|	ExtensionsPlacement.Important,
			|	ExtensionsPlacement.SeeAlso
			|FROM
			|	ReportsOptions AS ReportsOptions
			|	INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS ExtensionsPlacement
			|		ON ReportsOptions.Cause = 0
			|		AND ReportsOptions.PredefinedOption = ExtensionsPlacement.Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ReportOptionsPlacement.Ref AS Ref,
			|	ReportOptionsPlacement.Use AS Use,
			|	ReportOptionsPlacement.Subsystem AS Subsystem,
			|	ReportOptionsPlacement.Important AS Important,
			|	ReportOptionsPlacement.SeeAlso AS SeeAlso
			|INTO SeparatedSettings
			|FROM
			|	ReportsOptions AS ReportsOptions
			|	INNER JOIN Catalog.ReportsOptions.Location AS ReportOptionsPlacement
			|		ON ReportsOptions.Cause = 0
			|		AND ReportsOptions.Ref = ReportOptionsPlacement.Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	ReportsOptions.Ref,
			|	ReportsOptions.Cause AS Cause
			|FROM
			|	ReportsOptions AS ReportsOptions
			|WHERE
			|	ReportsOptions.Cause <> 0
			|
			|ORDER BY
			|	Cause
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ISNULL(SeparatedSettings.Subsystem, CommonSettings.Subsystem) AS Ref,
			|	COUNT(1) AS Count,
			|	CASE
			|		WHEN ISNULL(SeparatedSettings.Important, CommonSettings.Important) = TRUE
			|			THEN &ImportantPresentation
			|		WHEN ISNULL(SeparatedSettings.SeeAlso, CommonSettings.SeeAlso) = TRUE
			|			THEN &SeeAlsoPresentation
			|		ELSE """"
			|	END AS Importance
			|FROM
			|	CommonSettings AS CommonSettings
			|	FULL JOIN SeparatedSettings AS SeparatedSettings
			|		ON CommonSettings.Ref = SeparatedSettings.Ref
			|		AND CommonSettings.Subsystem = SeparatedSettings.Subsystem
			|WHERE
			|	SeparatedSettings.Use = TRUE
			|		OR SeparatedSettings.Use IS NULL
			|
			|GROUP BY
			|	ISNULL(SeparatedSettings.Subsystem, CommonSettings.Subsystem),
			|	CASE
			|		WHEN ISNULL(SeparatedSettings.Important, CommonSettings.Important) = TRUE
			|			THEN &ImportantPresentation
			|		WHEN ISNULL(SeparatedSettings.SeeAlso, CommonSettings.SeeAlso) = TRUE
			|			THEN &SeeAlsoPresentation
			|		ELSE """"
			|	END";
	// ACC:70-on
EndFunction

&AtServer
Procedure WriteAtServer()

	DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	ChangedSections = DestinationTree.Rows.FindRows(New Structure("Modified", True), True);

	BeginTransaction();
	Try
		Block = New DataLock;
		For Each ReportVariant In OptionsToAssign Do
			LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", ReportVariant.Value);
		EndDo;
		Block.Lock();

		For Each ReportVariant In OptionsToAssign Do
			OptionObject = ReportVariant.Value.GetObject(); // CatalogObject.ReportsOptions
			ReportsOptions.SubsystemsTreeWrite(OptionObject, ChangedSections);
			OptionObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

// Adds a row to the sections tree recursively.
//
// Parameters:
//  DestinationParent - ValueTree:
//    * Ref - CatalogRef.ExtensionObjectIDs
//             - CatalogRef.MetadataObjectIDs
//    * Name - String
//    * FullName - String
//    * Presentation - String
//    * SectionReference - CatalogRef.ExtensionObjectIDs
//                   - CatalogRef.MetadataObjectIDs
//    * SectionFullName - String
//    * Priority - String
//    * FullPresentation - String
//    * Importance - String
//    * Modified - Boolean
//  SourceParent - ValueTreeRow
//                   - ValueTree:
//    * Ref - CatalogRef.ExtensionObjectIDs
//             - CatalogRef.MetadataObjectIDs
//    * Name - String
//    * FullName - String
//    * Presentation - String
//    * SectionReference - CatalogRef.ExtensionObjectIDs
//                   - CatalogRef.MetadataObjectIDs
//    * SectionFullName - String
//    * Priority - String
//    * FullPresentation - String
//    * Importance - String
//    * Modified - Boolean
//  SubsystemsOccurrences - ValueTable:
//    * Ref - CatalogRef.ReportsOptions
//    * Count - Number
//    * Importance - String
//
&AtServer
Procedure AddSubsystemsToTree(DestinationParent, SourceParent, SubsystemsOccurrences)
	For Each Source In SourceParent.Rows Do

		Receiver = DestinationParent.Rows.Add();
		FillPropertyValues(Receiver, Source);

		OccurrencesOfThisSubsystem = SubsystemsOccurrences.Copy(New Structure("Ref", Receiver.Ref));
		If OccurrencesOfThisSubsystem.Count() = 1 Then
			Receiver.Importance = OccurrencesOfThisSubsystem[0].Importance;
		ElsIf OccurrencesOfThisSubsystem.Count() = 0 Then
			Receiver.Importance = "";
		Else
			Receiver.Importance = MixedImportance; // Also used in conditional appearance.
		EndIf;

		OptionsOccurrences = OccurrencesOfThisSubsystem.Total("Count");
		If OptionsOccurrences = OptionsCount Then
			Receiver.Use = 1;
		ElsIf OptionsOccurrences = 0 Then
			Receiver.Use = 0;
		Else
			Receiver.Use = 2;
		EndIf;

		AddSubsystemsToTree(Receiver, Source, SubsystemsOccurrences);
	EndDo;
EndProcedure

#EndRegion