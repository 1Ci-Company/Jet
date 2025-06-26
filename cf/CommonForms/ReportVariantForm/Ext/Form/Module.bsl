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
	DefineBehaviorInMobileClient();
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then 
		
		// Calculating a number of form creation, a standard separator is a period (".").
		Comment = String(GetClientConnectionSpeed());
		
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation("CommonForm.ReportVariantForm", 1, Comment);
		
	EndIf;
	
	ParametersForm = ReportsOptions.StoredReportFormParameters(Parameters);
	
	If ValueIsFilled(Parameters.VariantPresentation) Then
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Modify ""%1"" report option';"), Parameters.VariantPresentation);
	EndIf;
	
	If Parameters.ReportSettings <> Undefined Then
		ReportSettings = Parameters.ReportSettings;
		If ReportSettings.SchemaModified Then
			Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Parameters.VariantPresentation) Then
		Parameters.VariantPresentation = Parameters.DescriptionOption;
	EndIf;
	
	DCSettings = CommonClientServer.StructureProperty(Parameters, "Variant");
	If DCSettings = Undefined Then
		DCSettings = Report.SettingsComposer.Settings;
	EndIf;
	
	Parameters.Property("SettingsStructureItemID", SettingsStructureItemID);
	
	PathToSettingsStructureItem = CommonClientServer.StructureProperty(
		Parameters, "PathToSettingsStructureItem", "");
	
	StructureItem = ReportsServer.SettingsItemByFullPath(DCSettings, PathToSettingsStructureItem);
	If StructureItem <> Undefined Then
		SettingsStructureItemID = DCSettings.GetIDByObject(StructureItem);
	EndIf;
	
	VariantModified = Parameters.VariantModified;
	UserSettingsModified = Parameters.UserSettingsModified;
	
	SetCurrentPage();
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(NewDCSettings)
	If TypeOf(ParametersForm.Filter) = Type("Structure") Then
		ReportsServer.SetFixedFilters(ParametersForm.Filter, NewDCSettings, ReportSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(Settings)
	NewSettings1 = Report.SettingsComposer.GetSettings();
	Report.SettingsComposer.LoadFixedSettings(New DataCompositionSettings);
	ReportsClientServer.LoadSettings(Report.SettingsComposer, NewSettings1);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If TypeOf(SettingsStructureItemID) = Type("DataCompositionID") Then
		AttachIdleHandler("SetCurrentRow", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOutputParameters

&AtClient
Procedure SettingsComposerSettingsOutputParametersOnChange(Item)
	
	String = Item.CurrentData;
	ParameterId = "Title";
	
	If String <> Undefined
		And String.Property("Parameter")
		And String.Parameter = ParameterId Then 
		
		Report.SettingsComposer.Settings.AdditionalProperties.Insert(
			"TitleSetInteractively", ValueIsFilled(String.Value));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateAndClose(Command)
	If ModalMode Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(True);
		Return;
	EndIf;

	SelectionResult = ReportsClientServer.ReportFormUpdateParameters(
		ReportsOptionsInternalClientServer.NameEventFormSettings());
	SelectionResult.DCSettingsComposer = Report.SettingsComposer;
	SelectionResult.VariantModified = VariantModified;
	SelectionResult.UserSettingsModified = VariantModified Or UserSettingsModified;
	SelectionResult.Regenerate = True;
	
	If SelectionResult.UserSettingsModified Then
		SelectionResult.ResetCustomSettings = True;
	EndIf;
	
	NotifyChoice(SelectionResult);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DefineBehaviorInMobileClient()
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then 
		Return;
	EndIf;
	
	CommandBarLocation = FormCommandBarLabelLocation.Auto;
EndProcedure

&AtServer
Procedure SetCurrentPage()
	If Not ValueIsFilled(Parameters.PageName) Then
		Return;
	EndIf;
	
	PageLinks = New Map;
	PageLinks.Insert("FiltersPage", "FilterPage");
	PageLinks.Insert("SelectedFieldsAndSortingsPage", "SelectionFieldsPage");
	PageLinks.Insert("AppearancePage", "ConditionalAppearancePage");
	
	PageName = PageLinks[Parameters.PageName];
	PageFound = Items.Find(PageName);
	
	If PageFound = Undefined Then
		PageFound = Items.Find(Parameters.PageName);
	EndIf;
	
	If PageFound <> Undefined Then 
		Items.SettingsPages.CurrentPage = PageFound;
	EndIf;
EndProcedure

&AtClient
Procedure SetCurrentRow()
	Items.SettingSettingsComposer.CurrentRow = SettingsStructureItemID;
EndProcedure

&AtClient
Procedure GroupFieldsUnavailable()
	
	Items.GroupFieldsPages.CurrentPage = Items.UnavailableGroupFieldsSettings;
	
EndProcedure

&AtClient
Procedure SelectedFieldsAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemSelection(StructureItem) Then
		
		LocalSelectedFields = True;
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
		
	Else
		
		LocalSelectedFields = False;
		Items.SelectionFieldsPages.CurrentPage = Items.DisabledSelectedFieldsSettings;
		
	EndIf;
	
	Items.LocalSelectedFields.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure SelectedFieldsUnavailable()
	
	LocalSelectedFields = False;
	Items.LocalSelectedFields.ReadOnly = True;
	Items.SelectionFieldsPages.CurrentPage = Items.UnavailableSelectedFieldsSettings;
	
EndProcedure

&AtClient
Procedure FilterAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemFilter(StructureItem) Then
		
		LocalFilter = True;
		Items.FilterPages.CurrentPage = Items.Filter_Settings;
		
	Else
		
		LocalFilter = False;
		Items.FilterPages.CurrentPage = Items.DisabledFilterSettings;
		
	EndIf;
	
	Items.LocalFilter.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure FilterDisabled()
	
	LocalFilter = False;
	Items.LocalFilter.ReadOnly = True;
	Items.FilterPages.CurrentPage = Items.UnavailableFilterSettings;
	
EndProcedure

&AtClient
Procedure OrderAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOrder(StructureItem) Then
		
		LocalOrder = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
		
	Else
		
		LocalOrder = False;
		Items.OrderPages.CurrentPage = Items.DisabledOrderSettings;
		
	EndIf;
	
	Items.LocalOrder.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure OrderUnavailable()
	
	LocalOrder = False;
	Items.LocalOrder.ReadOnly = True;
	Items.OrderPages.CurrentPage = Items.UnavailableOrderSettings;
	
EndProcedure

&AtClient
Procedure ConditionalAppearanceAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemConditionalAppearance(StructureItem) Then
		
		LocalConditionalAppearance = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
		
	Else
		
		LocalConditionalAppearance = False;
		Items.ConditionalAppearancePages.CurrentPage = Items.DisabledConditionalAppearanceSettings;
		
	EndIf;
	
	Items.LocalConditionalAppearance.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure ConditionalAppearanceUnavailable()
	
	LocalConditionalAppearance = False;
	Items.LocalConditionalAppearance.ReadOnly = True;
	Items.ConditionalAppearancePages.CurrentPage = Items.UnavailableConditionalAppearanceSettings;
	
EndProcedure

&AtClient
Procedure OutputParametersAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOutputParameters(StructureItem) Then
		
		LocalOutputParameters = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
		
	Else
		
		LocalOutputParameters = False;
		Items.OutputParametersPages.CurrentPage = Items.DisabledOutputParametersSettings;
		
	EndIf;
	
	Items.LocalOutputParameters.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure OutputParametersUnavailable()
	
	LocalOutputParameters = False;
	Items.LocalOutputParameters.ReadOnly = True;
	Items.OutputParametersPages.CurrentPage = Items.UnavailableOutputParametersSettings;
	
EndProcedure

&AtClient
Procedure SettingSettingsComposerOnActivateField(Item)
	
	Var SelectedPage;
	
	If Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsChoiceAvailable" Then
		
		SelectedPage = Items.SelectionFieldsPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsFilterAvailable" Then
		
		SelectedPage = Items.FilterPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsOrderAvailable" Then
		
		SelectedPage = Items.OrderPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsConditionalAppearanceAvailable" Then
		
		SelectedPage = Items.ConditionalAppearancePage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsOutputParametersAvailable" Then
		
		SelectedPage = Items.OutputParametersPage;
		
	EndIf;
	
	If SelectedPage <> Undefined Then
		
		Items.SettingsPages.CurrentPage = SelectedPage;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingSettingsComposerOnActivateRow(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
	ElementType = TypeOf(StructureItem); 
	
	If ElementType = Undefined
		Or ElementType = Type("DataCompositionChartStructureItemCollection")
		Or ElementType = Type("DataCompositionTableStructureItemCollection") Then
		
		GroupFieldsUnavailable();
		SelectedFieldsUnavailable();
		FilterDisabled();
		OrderUnavailable();
		ConditionalAppearanceUnavailable();
		OutputParametersUnavailable();
		
	ElsIf ElementType = Type("DataCompositionSettings")
		Or ElementType = Type("DataCompositionNestedObjectSettings") Then
		
		GroupFieldsUnavailable();
		
		LocalSelectedFields = True;
		Items.LocalSelectedFields.ReadOnly = True;
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
		
		LocalFilter = True;
		Items.LocalFilter.ReadOnly = True;
		Items.FilterPages.CurrentPage = Items.Filter_Settings;
		
		LocalOrder = True;
		Items.LocalOrder.ReadOnly = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
		
		LocalConditionalAppearance = True;
		Items.LocalConditionalAppearance.ReadOnly = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
		
		LocalOutputParameters = True;
		Items.LocalOutputParameters.ReadOnly = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
		
	ElsIf ElementType = Type("DataCompositionGroup")
		Or ElementType = Type("DataCompositionTableGroup")
		Or ElementType = Type("DataCompositionChartGroup") Then
		
		Items.GroupFieldsPages.CurrentPage = Items.GroupFieldsSettings;
		
		SelectedFieldsAvailable(StructureItem);
		FilterAvailable(StructureItem);
		OrderAvailable(StructureItem);
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	ElsIf ElementType = Type("DataCompositionTable")
		Or ElementType = Type("DataCompositionChart") Then
		
		GroupFieldsUnavailable();
		SelectedFieldsAvailable(StructureItem);
		FilterDisabled();
		OrderUnavailable();
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToReport(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
	ItemSettings =  Report.SettingsComposer.Settings.ItemSettings(StructureItem);
	Items.SettingSettingsComposer.CurrentRow = Report.SettingsComposer.Settings.GetIDByObject(ItemSettings);
	
EndProcedure

&AtClient
Procedure LocalSelectedFieldsOnChange(Item)
	
	If LocalSelectedFields Then
		
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
		
	Else
		
		Items.SelectionFieldsPages.CurrentPage = Items.DisabledSelectedFieldsSettings;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemSelection(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalFilterOnChange(Item)
	
	If LocalFilter Then
		
		Items.FilterPages.CurrentPage = Items.Filter_Settings;
		
	Else
		
		Items.FilterPages.CurrentPage = Items.DisabledFilterSettings;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemFilter(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalOrderOnChange(Item)
	
	If LocalOrder Then
		
		Items.OrderPages.CurrentPage = Items.OrderSettings;
		
	Else
		
		Items.OrderPages.CurrentPage = Items.DisabledOrderSettings;
		
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOrder(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalConditionalAppearanceOnChange(Item)

	If LocalConditionalAppearance Then
		
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
		
	Else
		
		Items.ConditionalAppearancePages.CurrentPage = Items.DisabledConditionalAppearanceSettings;
		
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemConditionalAppearance(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalOutputParametersOnChange(Item)
	
	If LocalOutputParameters Then
		
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
		
	Else
		
		Items.OutputParametersPages.CurrentPage = Items.DisabledOutputParametersSettings;
		
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOutputParameters(StructureItem);
		
	EndIf;
	
EndProcedure

#EndRegion
