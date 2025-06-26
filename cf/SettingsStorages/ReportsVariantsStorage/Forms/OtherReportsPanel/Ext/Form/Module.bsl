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
	
	FillPropertyValues(ThisObject, Parameters,
		"OptionRef, ReportRef, SubsystemRef, ReportDescription, VisibleOptions");
	
	If VisibleOptions = Undefined Then
		VisibleOptions = New FixedArray(New Array);
	EndIf;
	
	Items.OtherReportOptionsGroup.Title = ReportDescription
		+ " (" + NStr("en = 'report options';") + "):";
	
	ReadThisFormSettings();
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	FillReportPanel();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CloseThisWindowAfterMoveToReportOnChange(Item)
	SaveThisFormSettings();
EndProcedure

// Hyperlink click handler.
//
// Parameters:
//   Item - FormDecoration
//
&AtClient
Procedure Attachable_OptionClick(Item)
	FoundItems = PanelOptions.FindRows(New Structure("LabelName", Item.Name));
	If FoundItems.Count() <> 1 Then
		Return;
	EndIf;
	Variant = FoundItems[0];
	
	If ValueIsFilled(SubsystemRef) Then
		FormParameters = New Structure("Subsystem", SubsystemRef);
	Else
		FormParameters = Undefined;
	EndIf;
	ReportsOptionsClient.OpenReportForm(FormOwner, Variant, FormParameters);
	
	If CloseAfterChoice Then
		Close();
	EndIf;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call, Server.

&AtServer
Procedure SaveThisFormSettings()
	FormSettings = DefaultSettings();
	FillPropertyValues(FormSettings, ThisObject);
	Common.FormDataSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		"OtherReportsPanel", 
		FormSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure ReadThisFormSettings()
	DefaultSettings = DefaultSettings();
	Items.CloseAfterChoice.Visible = DefaultSettings.ShowCheckBox;
	FormSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"OtherReportsPanel",
		DefaultSettings);
	FillPropertyValues(ThisObject, FormSettings);
EndProcedure

&AtServer
Function DefaultSettings()
	Return ReportsOptions.GlobalSettings().OtherReports;
EndFunction

&AtServer
Procedure FillReportPanel()
	OtherReportsAvailable = False;
	
	OutputTable = FormAttributeToValue("PanelOptions");
	OutputTable.Columns.Add("ItemMustBeAdded", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("KeepThisItem", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("Group");
	
	CommonSettings = ReportsOptions.CommonPanelSettings();
	ShowTooltips = CommonSettings.ShowTooltips = 1;
	
	VariantsTable = AvailableReportsOptions();
	For Each TableRow In VariantsTable Do
		// Other options only.
		If TableRow.Ref = OptionRef Then
			Continue;
		EndIf;
		OtherReportsAvailable = True;
		OutputHyperlinkToPanel(OutputTable, TableRow, Items.OtherReportOptionsGroup, ShowTooltips);
	EndDo;
	Items.OtherReportOptionsGroup.Visible = (VariantsTable.Count() > 0);
	
	If ValueIsFilled(SubsystemRef) Then
		Subsystems = SectionSubsystems(SubsystemRef);
		
		SearchParameters = New Structure;
		SearchParameters.Insert("Subsystems", Subsystems);
		SearchParameters.Insert("OnlyItemsVisibleInReportPanel", True);
		VariantsTable = ReportsOptions.ReportOptionTable(SearchParameters);
		
		FoundColumn = VariantsTable.Columns.Find("OptionDescription");
		FoundColumn.Name = "Description";
		
		VariantsTable.Sort("Description");
		
		// Deleting rows that correspond to the current (currently open) option.
		FoundItems = VariantsTable.FindRows(New Structure("Ref", OptionRef));
		For Each TableRow In FoundItems Do
			VariantsTable.Delete(TableRow);
		EndDo;
		
		AllSubsystems = ReportsOptionsCached.CurrentUserSubsystems().Tree;
		AllSections = AllSubsystems.Rows[0].Rows;
		
		// Subsystem iteration and found options output.
		For Each CurrentSubsystem In Subsystems Do
			FoundItems = VariantsTable.FindRows(New Structure("Subsystem", CurrentSubsystem));
			If FoundItems.Count() = 0 Then
				Continue;
			EndIf;
			FoundRows = AllSections.FindRows(New Structure("Ref", CurrentSubsystem));
			If FoundRows.Count() = 0 Then
				SubsystemDescription = FoundItems[0].SubsystemDescription;
			ElsIf CurrentSubsystem = SubsystemRef Then
				SubsystemDescription = FoundRows[0].FullPresentation;
			Else
				SubsystemDescription = FoundRows[0].Presentation;
			EndIf;
			Var_Group = DetermineOutputGroup(SubsystemDescription);
			For Each TableRow In FoundItems Do
				OtherReportsAvailable = True;
				OutputHyperlinkToPanel(OutputTable, TableRow, Var_Group, ShowTooltips);
			EndDo;
		EndDo;
	EndIf;
	
	// PanelOptionsItemNumber
	ItemsFoundForRemoving = OutputTable.FindRows(New Structure("KeepThisItem", False));
	For Each TableRow In ItemsFoundForRemoving Do
		OptionItem = Items.Find(TableRow.LabelName);
		If OptionItem <> Undefined Then
			Items.Delete(OptionItem);
		EndIf;
		OutputTable.Delete(TableRow);
	EndDo;
	
	OutputTable.Columns.Delete("KeepThisItem");
	OutputTable.Columns.Delete("Group");
	ValueToFormAttribute(OutputTable, "PanelOptions");
	
	Items.GroupNoOtherReports.Visible = Not OtherReportsAvailable;
	Items.CloseAfterChoice.Visible = OtherReportsAvailable;
	If Not OtherReportsAvailable Then
		Width = 25;
	EndIf;
	
EndProcedure

// Returns:
//  ValueTable:
//    * Ref - CatalogRef.ReportsOptions
//    * Report - CatalogRef.MetadataObjectIDs
//            - CatalogRef.ExtensionObjectIDs
//            - CatalogRef.AdditionalReportsAndDataProcessors
//            - String
//    * VariantKey - String
//    * Description - String
//    * LongDesc - String
//    * Author - CatalogRef.ExternalUsers
//            - CatalogRef.Users
//    * Custom - Boolean
//    * ReportType - EnumRef.ReportsTypes
//    * ReportName - String
//
&AtServer
Function AvailableReportsOptions()
	
	Query = New Query(
	"SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ReportsOptions.Report AS Report,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	ReportsOptions.Description AS Description,
	|	CASE
	|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
	|			THEN CAST(ReportsOptions.PredefinedOption.LongDesc AS STRING(1000))
	|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
	|	END AS LongDesc,
	|	ReportsOptions.Author AS Author,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.ReportType AS ReportType,
	|	&ReportName AS ReportName
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	(ReportsOptions.Ref IN (&VisibleOptions)
	|			OR ReportsOptions.Report = &Report
	|				AND NOT ReportsOptions.DeletionMark
	|				AND (NOT ReportsOptions.AuthorOnly
	|					OR ReportsOptions.Author = &CurrentUser)
	|				AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
	|				AND ReportsOptions.VariantKey <> """"
	|				AND ReportsOptions.Context = """")
	|
	|ORDER BY
	|	Description");
	
	ReportName = "CASE
	|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
	|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
	|		ELSE CAST(ReportsOptions.Report AS STRING(150))
	|	END";
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then 
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportTableName = ModuleAdditionalReportsAndDataProcessors.AdditionalReportTableName();
		
		ReportName = StringFunctionsClientServer.SubstituteParametersToString("CASE
		|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
		|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
		|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
		|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
		|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(%1)
		|			THEN CAST(ReportsOptions.Report AS %1).ObjectName
		|		ELSE CAST(ReportsOptions.Report AS STRING(150))
		|	END", AdditionalReportTableName);
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ReportName", ReportName);
	
	Query.SetParameter("VisibleOptions", VisibleOptions);
	Query.SetParameter("Report", ReportRef);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	
	Return Query.Execute().Unload();
	
EndFunction

// Creates form items referring to the report option.
// 
// Parameters:
//   OutputTable - ValueTable:
//     * ItemMustBeAdded - Boolean
//     * KeepThisItem - Boolean
//     * Group - FormGroup
//   Variant - ValueTableRow:
//     * Ref - CatalogRef.ReportsOptions
//     * ReportType - EnumRef.ReportsTypes
//     * LongDesc - String
//     * Author - CatalogRef.ExternalUsers
//             - CatalogRef.Users
//   Var_Group - FormGroup
//          - Undefined
//          - FormField
//          - FormTable
//          - FormButton
//          - FormDecoration
//   ShowTooltips - Boolean
//
&AtServer
Procedure OutputHyperlinkToPanel(OutputTable, Variant, Var_Group, ShowTooltips)
	
	FoundItems = OutputTable.FindRows(New Structure("Ref, Group", Variant.Ref, Var_Group.Name));
	If FoundItems.Count() > 0 Then
		OutputRow = FoundItems[0];
		OutputRow.KeepThisItem = True;
		Return;
	EndIf;
	
	OutputRow = OutputTable.Add();
	FillPropertyValues(OutputRow, Variant);
	PanelOptionsItemNumber = PanelOptionsItemNumber + 1;
	OutputRow.LabelName = "Variant" + Format(PanelOptionsItemNumber, "NG=");
	OutputRow.Additional = (Variant.ReportType = Enums.ReportsTypes.Additional);
	OutputRow.GroupName = Var_Group.Name;
	OutputRow.KeepThisItem = True;
	OutputRow.Group = Var_Group;
	
	StyleItems = Metadata.StyleItems;
	
	// Add a report option hyperlink title.
	Label = Items.Insert(OutputRow.LabelName, Type("FormDecoration"), OutputRow.Group); // FormDecoration, FormDecorationExtensionForALabel
	Label.Type = FormDecorationType.Label;
	Label.Hyperlink = True;
	Label.HorizontalStretch = True;
	Label.VerticalStretch = False;
	Label.Height = 1;
	Label.TextColor = StyleItems.HyperlinkColor.Value;
	Label.Title = TrimAll(String(Variant.Ref));
	Label.AutoMaxWidth = False;
	
	If ValueIsFilled(Variant.LongDesc) Then
		Label.ToolTip = TrimAll(Variant.LongDesc);
	EndIf;
	If ValueIsFilled(Variant.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("en = 'Author:';") + " " + TrimAll(String(Variant.Author));
	EndIf;
	If ShowTooltips Then
		Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
		Label.ExtendedTooltip.HorizontalStretch = True;
		Label.ExtendedTooltip.TextColor = StyleItems.NoteText.Value;
	EndIf;
	Label.SetAction("Click", "Attachable_OptionClick");
	
EndProcedure

&AtServerNoContext
Function SectionSubsystems(RootSection)
	Result = New Array;
	Result.Add(RootSection);
	
	SubsystemsTree = ReportsOptionsCached.CurrentUserSubsystems().Tree;
	FoundItems = SubsystemsTree.Rows.FindRows(New Structure("Ref", RootSection), True);
	IndexOf = 0;
	While IndexOf < FoundItems.Count() Do
		RowsCollection = FoundItems[IndexOf].Rows;
		IndexOf = IndexOf + 1;
		For Each TreeRow In RowsCollection Do
			Result.Add(TreeRow.Ref);
			FoundItems.Add(TreeRow);
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function DetermineOutputGroup(SubsystemPresentation)
	ListItem = SubsystemsGroups.FindByValue(SubsystemPresentation);
	If ListItem <> Undefined Then
		Return Items.Find(ListItem.Presentation);
	EndIf;
	
	NumberOfGroup = SubsystemsGroups.Count() + 1;
	DecorationName = "IndentSubsystems" + NumberOfGroup;
	GroupName = "SubsystemsGroup1_" + NumberOfGroup;
	
	If OtherReportsAvailable Then
		Decoration = Items.Add(DecorationName, Type("FormDecoration"), Items.OtherReportsPage);
		Decoration.Type = FormDecorationType.Label;
		Decoration.Title = " ";
	EndIf;
	
	Var_Group = Items.Add(GroupName, Type("FormGroup"), Items.OtherReportsPage);
	Var_Group.Type = FormGroupType.UsualGroup;
	Var_Group.Group = ChildFormItemsGroup.Vertical;
	Var_Group.Title = SubsystemPresentation;
	Var_Group.ShowTitle = True;
	Var_Group.Representation = UsualGroupRepresentation.NormalSeparation;
	Var_Group.HorizontalStretch = True;
	
	SubsystemsGroups.Add(SubsystemPresentation, GroupName);
	
	Return Var_Group;
EndFunction

#EndRegion
