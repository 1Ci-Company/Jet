///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var FormClosingConfirmation;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Scenario = "RefsSearch" Or Parameters.Scenario = "PastingFromClipboard" Then
		ImportType = "PastingFromClipboard";
	ElsIf ValueIsFilled(Parameters.FullTabularSectionName) Then
		ImportType = "TabularSection";
	ElsIf Not Users.IsFullUser() Then
		Raise(NStr("en = 'Insufficient rights to import data from spreadsheets';"),
			ErrorCategory.AccessViolation);
	EndIf;	
	
	CreateIfUnmapped = 1;
	UpdateExistingItems = 0;
	AdditionalParameters = Parameters.AdditionalParameters;
	
	SetDataAppearance();
	SetFormItemsVisibility();
	
	If ImportType = "PastingFromClipboard" Then
		InsertFromClipboardInitialization();
	ElsIf ImportType = "TabularSection" Then
		
		MappingObjectName = DataProcessors.ImportDataFromFile.FullTabularSectionObjectName(Parameters.FullTabularSectionName);
		InfoOnImportDataColumns = FormAttributeToValue("ColumnsInformation");

		SavedColumnWiseInfo  = Common.CommonSettingsStorageLoad("ImportDataFromFile", MappingObjectName,, UserName()); // ValueTable
		
		If TypeOf(SavedColumnWiseInfo) = Type("ValueTable") Then
			CommonClientServer.SupplementTable(SavedColumnWiseInfo, InfoOnImportDataColumns);
		EndIf;
		
		DataImportParameters = ImportParameters();
		DataImportParameters.ImportType = ImportType;
		DataImportParameters.FullObjectName = MappingObjectName;
		DataImportParameters.Template = ?(ValueIsFilled(Parameters.DataStructureTemplateName), Parameters.DataStructureTemplateName, "LoadingFromFile");
		DataImportParameters.AdditionalParameters = AdditionalParameters;
		
		If Parameters.TemplateColumns <> Undefined Then
			DefineDynamicTemplate(InfoOnImportDataColumns, Parameters.TemplateColumns);
			Items.ChooseAnotherTemplate.Visible = False;
			Items.ChangeTemplateFillTable.Visible = False;
			ImportDataFromFile.AddStatisticalInformation("RunMode.ImportToTabularSection.DynamicTemplate",, Parameters.FullTabularSectionName);
		Else
			DataProcessors.ImportDataFromFile.DetermineColumnsInformation(DataImportParameters, InfoOnImportDataColumns);
			ChangeTemplateByColumnsInformation();
			ImportDataFromFile.AddStatisticalInformation("RunMode.ImportToTabularSection.StaticTemplate",, Parameters.FullTabularSectionName);
			If Cancel Then
				Return;
			EndIf;
		EndIf;
		ValueToFormAttribute(InfoOnImportDataColumns, "ColumnsInformation");
		
		ShowInfoBarAboutRequiredColumns();
		ChangeTemplateByColumnsInformation();
		
	Else
		FillDataImportTypeList();
	EndIf;
	
EndProcedure

// Returns:
//  Structure:
//   * ImportType - String
//   * FullObjectName - String
//   * Template - String
//   * AdditionalParameters - Structure
//
&AtServer
Function ImportParameters() 
	
	ImportParameters = New Structure;
	ImportParameters.Insert("ImportType", "");
	ImportParameters.Insert("FullObjectName", "");
	ImportParameters.Insert("Template", "LoadingFromFile");
	ImportParameters.Insert("AdditionalParameters", New Structure);
	
	Return ImportParameters;
	
EndFunction

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If FormClosingConfirmation = Undefined Then
		Return;
	EndIf;
	
	Cancel = Cancel Or (FormClosingConfirmation <> True);
	If Exit Then
		WarningText = NStr("en = 'The data that you entered will be lost.';");
		Return;
	EndIf;
		
	If Cancel Then
		Notification = New NotifyDescription("FormClosingCompletion1", ThisObject);
		QueryText = NStr("en = 'Changes are not saved. Close the form?';");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
	Else
		If OpenCatalogAfterCloseWizard Then 
			OpenForm(ListForm(MappingObjectName));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterReportOnChange(Item)

	ReportAtClientBackgroundJob(False);
	
	If FilterReport = "Skipped2" Then
		Items.ChangeAttributes.Enabled=False;
	Else
		Items.ChangeAttributes.Enabled=True;
	EndIf;
EndProcedure

&AtClient
Procedure MappingTableFilterOnChange(Item)
	SetMappingTableFiltering();
EndProcedure

&AtClient
Procedure SetMappingTableFiltering()
	
	Filter = MappingTableFilter;
	
	If Filter = "Mapped1" Then
		Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", 
			ImportDataFromFileClientServer.StatusMapped());
	ElsIf Filter = "Unmapped" Then 
		Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", 
			ImportDataFromFileClientServer.UnmappedRowsPrefix());
	ElsIf Filter = "Ambiguous" Then 
		Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", 
			ImportDataFromFileClientServer.StatusAmbiguity());
	Else
		Items.DataMappingTable.RowFilter = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure MappingColumnsListStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If MapByColumn.Count() = 0 Then
		For Each ColumnInfo In ColumnsInformation Do
			If (TypeOf(ColumnInfo.ColumnType) = Type("String")
				 And ColumnInfo.ColumnType.StringQualifiers.Length = 0)
				 Or StrStartsWith(ColumnInfo.ColumnName, "Property_") Then
					Continue;
			EndIf;
			ColumnPresentation = ?(IsBlankString(ColumnInfo.Synonym), ColumnInfo.ColumnPresentation, ColumnInfo.Synonym);
			MapByColumn.Add(ColumnInfo.ColumnName, ColumnPresentation);
		EndDo;
	EndIf;
	
	FormParameters      = New Structure("ColumnsList", MapByColumn);
	NotifyDescription  = New NotifyDescription("AfterColumnsChoiceForMapping", ThisObject);
	OpenForm("DataProcessor.ImportDataFromFile.Form.SelectColumns", FormParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AfterColumnsChoiceForMapping(Result, Parameter) Export
	
	If Result = Undefined Then 
		Return;
	EndIf;
		 
	MapByColumn = Result;
	ColumnsToString = "";
	Separator = "";
	SelectedColumnsCount = 0;
	For Each Item In MapByColumn Do 
		If Item.Check Then 
			ColumnsToString = ColumnsToString + Separator + Item.Presentation;
			Separator = ", ";
			SelectedColumnsCount = SelectedColumnsCount + 1;
		EndIf;
	EndDo;
	
	MappingColumnsList = ColumnsToString;
	RunMapping();
EndProcedure

&AtClient
Procedure ImportOptionOnChange(Item)
	
	If ImportOption = 0 Then
		Items.FillWithDataPages.CurrentPage = Items.FillTableOptionPage;
	Else
		Items.FillWithDataPages.CurrentPage = Items.ImportFromFileOptionPage;
	EndIf;
	
	ShowInfoBarAboutRequiredColumns();
	
EndProcedure

&AtClient
Procedure DataImportKindValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	ProceedToNextStepOfDataImport();
EndProcedure

&AtClient
Procedure DataImportKindBeforeRowChange(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure TableReportOnActivate(Item)
	If TableReport.CurrentArea.Bottom = 1 And TableReport.CurrentArea.Top = 1 Then
		Items.ChangeAttributes.Enabled = False;
	Else
		Items.ChangeAttributes.Enabled = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersTemplateWithData

&AtClient
Procedure TemplateWithDataOnActivate(Item)
	Item.Protection = ?(Item.CurrentArea.Top > TemplateWithDataHeaderHeight, False, True);
EndProcedure

&AtClient
Procedure TemplateWithDataSelection(Item, Area, StandardProcessing)
	If Area.Top <= TemplateWithDataHeaderHeight Then
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDataMappingTable

&AtClient
Procedure DataMappingTableOnEditEnd(Item, NewRow, CancelEdit)
	
	If ImportType <> "TabularSection" Then
		If ValueIsFilled(Item.CurrentData.MappingObject) Then 
			Item.CurrentData.RowMappingResult = ImportDataFromFileClientServer.StatusMapped();
		Else
			Item.CurrentData.RowMappingResult = ImportDataFromFileClientServer.StatusUnmapped();
		EndIf;
	Else
		Filter = New Structure("IsRequiredInfo", True);
		RequiredColumns = ColumnsInformation.FindRows(Filter);
		RowMappingResult    = ImportDataFromFileClientServer.StatusMapped();
		TablePartPrefix           = ImportDataFromFileClientServer.TablePartPrefix() + "_";
		
		For Each TableColumn2 In RequiredColumns Do
			If Not ValueIsFilled(Item.CurrentData[TablePartPrefix + TableColumn2.Parent]) Then
				RowMappingResult = ?(ValueIsFilled(Item.CurrentData.ErrorDescription), 
					ImportDataFromFileClientServer.StatusAmbiguity(), ImportDataFromFileClientServer.StatusUnmapped());
				Break;
			EndIf;
		EndDo;
		
		Item.CurrentData.RowMappingResult = RowMappingResult;
	EndIf;
	
	AttachIdleHandler("ShowMappingStatisticsImportFromFile", 0.2, True);
	
EndProcedure

&AtClient
Procedure DataMappingTableOnActivateCell(Item)
	Items.ResolveConflict.Enabled = False;
	Items.DataMappingTableContextMenuResolveConflict.Enabled = False;
	
	If Item.CurrentData <> Undefined And ValueIsFilled(Item.CurrentData.RowMappingResult) Then 
		If ImportType = "TabularSection" Then
			TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix() + "_"; 
			If StrLen(Item.CurrentItem.Name) > 3 And StrStartsWith(Item.CurrentItem.Name, TablePartPrefix) Then
				ColumnName = Mid(Item.CurrentItem.Name, 4);
				If StrFind(Item.CurrentData.ErrorDescription, ColumnName) > 0 Then 
					Items.ResolveConflict.Enabled = True;
					Items.DataMappingTableContextMenuResolveConflict.Enabled = True;
				EndIf;
			EndIf;
		ElsIf Item.CurrentData.RowMappingResult = ImportDataFromFileClientServer.StatusAmbiguity() Then 
			Items.ResolveConflict.Enabled = True;
			Items.DataMappingTableContextMenuResolveConflict.Enabled = True;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure DataMappingTableSelection(Item, RowSelected, Field, StandardProcessing)
	OpenResolveConflictForm(RowSelected, Field.Name, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CancelMapping(Command)
	Notification = New NotifyDescription("AfterCancelMappingPrompt", ThisObject);
	ShowQueryBox(Notification, NStr("en = 'Do you want to clear the mapping?';"), QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure ChooseAnotherTemplate(Command)
	OpenChangeTemplateForm();
EndProcedure

&AtClient
Procedure ResolveConflict(Command)
	OpenResolveConflictForm(Items.DataMappingTable.CurrentRow,Items.DataMappingTable.CurrentItem.Name, True);
EndProcedure

&AtClient
Procedure AddToList(Command)
	CloseFormAndReturnRefArray();
EndProcedure

&AtClient
Procedure Next(Command)
	ProceedToNextStepOfDataImport();
EndProcedure

&AtClient
Procedure AfterAddToTabularSectionPrompt(Result, AdditionalParameters) Export 
	If Result = DialogReturnCode.Yes Then 
		ImportedDataAddress = MappingTableAddressInStorage();
		Close(ImportedDataAddress);
	EndIf;
EndProcedure

&AtClient
Procedure CloseFormAndReturnRefArray()
	FormClosingConfirmation = True;
	ReferencesArrray = New Array;
	For Each TableRow In DataMappingTable Do
		If ValueIsFilled(TableRow.MappingObject) Then
			ReferencesArrray.Add(TableRow.MappingObject);
		EndIf;
	EndDo;
	
	Close(ReferencesArrray);
EndProcedure

&AtClient
Procedure Back(Command)
	
	StepBack();
	
EndProcedure

&AtClient
Procedure StepBack()
	
	If Items.WizardPages.CurrentPage = Items.FillTableWithData Then
		
		Items.WizardPages.CurrentPage = Items.SelectCatalogToImport;
		Items.Back.Visible = False;
		Title = NStr("en = 'Import data to catalog';");
		ClearTable();
		
	ElsIf Items.WizardPages.CurrentPage = Items.DataToImportMapping
		Or Items.WizardPages.CurrentPage = Items.NotFound4
		Or Items.WizardPages.CurrentPage = Items.MappingResults
		Or Items.WizardPages.CurrentPage = Items.TimeConsumingOperations Then
		
		Items.WizardPages.CurrentPage = Items.FillTableWithData;
		Items.AddToList.Visible = False;
		Items.Next.DefaultButton = True;
		Items.Next.Visible = True;
		Items.Next.Enabled = True;
		Items.Next.Title = ?(ImportType = "PastingFromClipboard",
				NStr("en = 'Add to list';"), NStr("en = 'Next >';"));
		
		If ImportType = "TabularSection" Or ImportType = "PastingFromClipboard" Then
			Items.Back.Visible = False;
		Else
			Items.Back.Enabled = True;
		EndIf;
		
	ElsIf Items.WizardPages.CurrentPage = Items.DataImportReport Then
		
		Items.OpenCatalogAfterCloseWizard.Visible = False;
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
		
	EndIf;

EndProcedure

&AtClient
Procedure ExportTemplateToFile(Command)
	
	Notification = New NotifyDescription("ExportTemplateToFileCompletion", ThisObject);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure ImportTemplateFromFile(Command)
	
	FileName = GenerateFileNameForMetadataObject(MappingObjectName);
	
	Notification = New NotifyDescription("ImportDataFromFileToTemplate", ThisObject);
	ImportDataFromFileClient.FileImportDialog(Notification, FileName);
	
EndProcedure

&AtClient
Procedure BatchEditAttributes(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		If TableReport.CurrentArea.Top = 1 Then
			UpperPosition = 2;
		Else
			UpperPosition = TableReport.CurrentArea.Top;
		EndIf;
		ReferencesArrray = BatchAttributesModificationAtServer(UpperPosition, TableReport.CurrentArea.Bottom);
		If ReferencesArrray.Count() > 0 Then
			FormParameters = New Structure("ObjectsArray", ReferencesArrray);
			ObjectName = "DataProcessor.";
			OpenForm(ObjectName + "BatchEditAttributes.Form", FormParameters);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

//CLIENT ///////////////////////////////////////////

// Ending the form closing dialog.
&AtClient
Procedure FormClosingCompletion1(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult = DialogReturnCode.Yes Then
		FormClosingConfirmation = True;
		Close();
	Else 
		FormClosingConfirmation = False;
	EndIf;
EndProcedure

&AtClient
Procedure ProceedToNextStepOfDataImport()
	
	If Items.WizardPages.CurrentPage = Items.SelectCatalogToImport Then
		If Items.DataImportKind.CurrentData = Undefined Then
			Return;
		EndIf;
		
		SelectionRowDetails = Items.DataImportKind.CurrentData.Value;
		ExecuteStepFillTableWithDataAtServer(SelectionRowDetails);
		ExecuteStepFillTableWithDataAtClient();
	
	ElsIf Items.WizardPages.CurrentPage = Items.FillTableWithData Then
		MapDataToImport();
	ElsIf Items.WizardPages.CurrentPage = Items.MappingResults Then
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
		Items.AddToList.Visible = False;
		Items.Next.Title = NStr("en = 'Add to list';");
		Items.Next.DefaultButton = True;
		Items.Back.Title = NStr("en = '< To Beginning';");
	ElsIf Items.WizardPages.CurrentPage = Items.DataToImportMapping Then
		Items.AddToList.Visible = False;
		FormClosingConfirmation = True;
		If ImportType = "TabularSection" Then
			Filter = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusUnmapped());
			Rows = DataMappingTable.FindRows(Filter);
			If Rows.Count() > 0 Then
				Notification = New NotifyDescription("AfterAddToTabularSectionPrompt", ThisObject);
				ShowQueryBox(Notification, NStr("en = 'Rows that contain empty required cells will be skipped.';")
					+ Chars.LF + NStr("en = 'Do you want to continue?';"), QuestionDialogMode.YesNo);
				Return;
			EndIf;
			
			ImportedDataAddress = MappingTableAddressInStorage();
			Close(ImportedDataAddress);
		ElsIf ImportType = "PastingFromClipboard" Then
			Items.Back.Title = NStr("en = '< To Beginning';");
			CloseFormAndReturnRefArray();
		Else
			Items.WizardPages.CurrentPage = Items.TimeConsumingOperations;
			WriteDataToImportClient();
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//  Result - Arbitrary
//  Parameter - See ConflictsMapParametersDetails
// 
&AtClient
Procedure AfterMappingConflicts(Result, Parameter) Export
	
	If ImportType  = "TabularSection" Then
		If Result <> Undefined Then
			TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix() + "_";
			
			String = DataMappingTable.FindByID(Parameter.Id);
			String[TablePartPrefix + Parameter.Name] = Result;
			String.ErrorDescription = StrReplace(String.ErrorDescription, Parameter.Name + ";", "");
			String.RowMappingResult = ?(StrLen(String.ErrorDescription) = 0, 
				ImportDataFromFileClientServer.StatusMapped(), ImportDataFromFileClientServer.StatusUnmapped());
		EndIf;
	Else
		String = DataMappingTable.FindByID(Parameter.Id);
		String.MappingObject = Result;
		If Result <> Undefined Then
			String.RowMappingResult = ImportDataFromFileClientServer.StatusMapped();
			String.ConflictsList = Undefined;
		Else 
			If String.RowMappingResult <> ImportDataFromFileClientServer.StatusAmbiguity() Then 
				String.RowMappingResult = ImportDataFromFileClientServer.StatusUnmapped();
				String.ConflictsList = Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	ShowMappingStatisticsImportFromFile();
	
EndProcedure

&AtClient
Procedure RunMapping()
	ItemsMappedByColumnsCount = 0;
	ColumnsList = "";
	ExecuteMappingBySelectedAttribute(ItemsMappedByColumnsCount, ColumnsList);
	ShowUserNotification(NStr("en = 'Mapping completed';"),, NStr("en = 'Items mapped:';") + " " + String(ItemsMappedByColumnsCount));
	ShowMappingStatisticsImportFromFile();
EndProcedure

&AtClient
Function AllDataMapped()
	Filter = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusMapped());
	Result = DataMappingTable.FindRows(Filter);
	MappedItemsCount = Result.Count();
	
	If DataMappingTable.Count() = MappedItemsCount Then 
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Function MappingStatistics()
	
	Filter                    = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusMapped());
	Result                = DataMappingTable.FindRows(Filter);
	MappedItemsCount = Result.Count();
	
	If ImportType = "PastingFromClipboard" Then
		Filter                   = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusUnmapped());
		Result               = DataMappingTable.FindRows(Filter);
		ConflictingItemsCount = DataMappingTable.Count() - MappedItemsCount - Result.Count();
	Else
		Filter                   = New Structure("ErrorDescription", "");
		Result               = DataMappingTable.FindRows(Filter);
		ConflictingItemsCount = DataMappingTable.Count() - Result.Count();
	EndIf;
	UnmappedItemsCount  = DataMappingTable.Count() - MappedItemsCount;
	
	Result = New Structure;
	Result.Insert("Total",            DataMappingTable.Count());
	Result.Insert("Mapped2",   MappedItemsCount);
	Result.Insert("Ambiguous1",    ConflictingItemsCount);
	Result.Insert("Incomparable", UnmappedItemsCount);
	Result.Insert("NotFound4",        UnmappedItemsCount - ConflictingItemsCount);
	
	Return Result;
	
EndFunction

&AtClient
Procedure ShowMappingStatisticsImportFromFile()
	
	Statistics = MappingStatistics();
	
	AllText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All (%1)';"), Statistics.Total);
	
	Items.CreateIfUnmapped.Title = NStr("en = 'Unmapped items (';") + Statistics.Incomparable + ")";
	Items.UpdateExistingItems.Title       = NStr("en = 'Mapped items (';") + String(Statistics.Mapped2) + ")";
	
	ChoiceList = Items.MappingTableFilter.ChoiceList;
	ChoiceList.Clear();
	ChoiceList.Add("All", AllText, True);
	ChoiceList.Add("Unmapped", StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Unmapped items (%1 out of %2)';"),
		Statistics.Incomparable, Statistics.Total));
	ChoiceList.Add("Mapped1", StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Mapped items (%1 out of %2)';"),
		Statistics.Mapped2, Statistics.Total));
	ChoiceList.Add("Ambiguous", StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Ambiguous items (%1 out of %2)';"),
		Statistics.Ambiguous1, Statistics.Total));
	
	If Statistics.Ambiguous1 > 0 Then
		Items.ConflictDetails.Visible = True;
		Items.ConflictDetails.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '(conflicts: %1)';"),
			Statistics.Ambiguous1);
	Else
		Items.ConflictDetails.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(MappingTableFilter) Then 
		MappingTableFilter = "Unmapped";
	EndIf;
	
	SetMappingTableFiltering();
	
EndProcedure

&AtClient
Procedure ExportTemplateToFileCompletion(Attached, AdditionalParameters) Export
	
	If Attached Then
		Notification = New NotifyDescription("AfterFileChoiceForSaving", ThisObject);
		FileName = GenerateFileNameForMetadataObject(MappingObjectName);
		FileDialog = New FileDialog(FileDialogMode.Save);
		FileDialog.Filter                      = NStr("en = 'Excel Workbook 97 (*.xls)|*.xls|Excel Workbook 2007 (*.xlsx)|*.xlsx|OpenDocument Spreadsheet (*.ods)|*.ods|Comma-separated values file (*.csv)|*.csv|Spreadsheet document (*.mxl)|*.mxl';");
		FileDialog.DefaultExt                  = "xls";
		FileDialog.Multiselect = False;
		FileDialog.FilterIndex               = 0;
		FileDialog.FullFileName = FileName;
		FileSystemClient.ShowSelectionDialog(Notification, FileDialog);
	Else
		Notification = New NotifyDescription("AfterFileExtensionChoice", ThisObject);
		OpenForm("DataProcessor.ImportDataFromFile.Form.FileExtention",, ThisObject, True,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyFormsAboutChange(ReferencesArrray)
	StandardSubsystemsClient.NotifyFormsAboutChange(ReferencesArrray);
EndProcedure

//SERVER ///////////////////////////////////////////

&AtServer
Procedure InsertFromClipboardInitialization()
	MappingTableFilter = "Unmapped";
	
	If ValueIsFilled("FieldPresentation") Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Paste (%1)';"), Parameters.FieldPresentation);
	Else
		Title = NStr("en = 'Paste';");
	EndIf;
	
	ImportDataFromFile.AddStatisticalInformation("RunMode.PastingFromClipboard");
	
	DataProcessors.ImportDataFromFile.SetInsertModeFromClipboard(TemplateWithData, ColumnsInformation, Parameters.TypeDescription);
	CreateMappingTableByColumnsInformationAuto(Parameters.TypeDescription);
	
	If ColumnsInformation.Count() = 1 Then
		Items.FillWithDataPages.CurrentPage = Items.SingleColumnPage;
		Items.ImportOption.Visible = False;
		Items.AddToList.Visible = False;
		Items.Next.Title = NStr("en = 'Add to list';");
	Else
		Items.FillWithDataPages.CurrentPage = Items.FillTableOptionPage;
	EndIf;

EndProcedure

&AtServer
Procedure SetFormItemsVisibility()
	
	Title = ?(IsBlankString(Parameters.Title), NStr("en = 'Import data to catalog';"), Parameters.Title);
	
	If Common.IsWebClient() Then
		Items.FillTableOptionPage.Visible = False;
		Items.ImportOption.Visible                  = False;
		Items.FillWithDataPages.CurrentPage = Items.ImportFromFileOptionPage;
		Items.SelectCatalogToImportNote.Title = NStr("en = 'Select a catalog you want to import data from a spreadsheet file to.
		|';");
	EndIf;
	
	If ImportType = "PastingFromClipboard" Then
		Items.WizardPages.CurrentPage = Items.FillTableWithData;
		Items.MappingSettingsGroup.Visible = False;
		Items.MappingColumnsList.Visible   = False;
		Items.Close.Title = NStr("en = 'Cancel';");
	ElsIf ImportType = "TabularSection" Then
		Items.WizardPages.CurrentPage = Items.FillTableWithData;
		Items.MappingSettingsGroup.Visible = False;
		Items.MappingColumnsList.Visible   = False;
		Items.UnmappedItemsTotalGroup.Visible  = False;
	Else
		Items.WizardPages.CurrentPage = Items.SelectCatalogToImport;
	EndIf;
	
EndProcedure

#Region SelectImportOptionStep

&AtServer
Procedure FillDataImportTypeList()
	DataProcessors.ImportDataFromFile.CreateCatalogsListForImport(ImportOptionsList);
EndProcedure 

#EndRegion

#Region FillTableWithDataStep

&AtClient
Procedure ExecuteStepFillTableWithDataAtClient()
	
	Items.WizardPages.CurrentPage = Items.FillTableWithData;
	Items.Back.Visible = True;
	TemplateWithDataHeaderHeight = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation), 2, 1);
	
EndProcedure

&AtClient
Function EmptyDataTable()
	
	If TemplateWithData.TableHeight <= TemplateWithDataHeaderHeight Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure OpenChangeTemplateForm()
	
	Var Notification, FormParameters;
	
	FormParameters = New Structure();
	FormParameters.Insert("ColumnsInformation", ColumnsInformation);
	FormParameters.Insert("MappingObjectName", MappingObjectName);
	FormParameters.Insert("ImportParameters", ImportParameters);
	
	Notification = New NotifyDescription("AfterCallFormChangeTemplate", ThisObject);
	OpenForm("DataProcessor.ImportDataFromFile.Form.EditTemplate1", FormParameters, ThisObject,,,, Notification, FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtServerNoContext
Function GetFullMetadataObjectName(Name)
	MetadataObject = Metadata.Catalogs.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	MetadataObject = Metadata.Documents.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	MetadataObject = Metadata.ChartsOfCharacteristicTypes.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	
	Return Undefined;
EndFunction

// Parameters:
//  SelectionRowDetails - See DataProcessors.ImportDataFromFile.NewInfoOnImportType
//
&AtServer
Procedure ExecuteStepFillTableWithDataAtServer(SelectionRowDetails)
	
	If StrFind(SelectionRowDetails.FullMetadataObjectName, ".") > 0 Then
		MappingObjectName = SelectionRowDetails.FullMetadataObjectName; 
	Else
		MappingObjectName = GetFullMetadataObjectName(SelectionRowDetails.FullMetadataObjectName);
	EndIf;
	
	ImportType = SelectionRowDetails.Type;
	If ImportType = "ExternalImport" Then
		ExternalDataProcessorRef = SelectionRowDetails.Ref;
		CommandID = SelectionRowDetails.Id;
	EndIf;
	ImportDataFromFile.AddStatisticalInformation("RunMode.ImportToCatalog." + MappingObjectName,, ImportType);
	
	GenerateTemplateByImportType();
	CreateMappingTableByColumnsInformation();
	ShowInfoBarAboutRequiredColumns();
	
	If TypeOf(SelectionRowDetails) = Type("Structure") Then
		WindowTitle = SelectionRowDetails.Presentation;
	Else
		WindowTitle = LoadingParametersOnTheForm().Title;
	EndIf;
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Import data to catalog ""%1""';"), WindowTitle);
	
EndProcedure

// Returns import parameters stored in the form attribute.
// 
// Returns:
//   See ImportDataFromFile.ImportFromFileParameters
//
&AtServer
Function LoadingParametersOnTheForm()
	Return ImportParameters;
EndFunction

&AtServer
Procedure GenerateTemplateByImportType()
	
	DefaultImportParameters = ImportDataFromFile.ImportFromFileParameters(MappingObjectName);
	DefaultImportParameters.ImportType = ImportType;
	
	If ImportType = "UniversalImport" Then
		AutoTitle = False;
	ElsIf ImportType = "AppliedImport" Then
		AutoTitle = False;
		ObjectManager(MappingObjectName).DefineParametersForLoadingDataFromFile(DefaultImportParameters);
		Title = DefaultImportParameters.Title;
	ElsIf ImportType = "ExternalImport" Then
		DefaultImportParameters.Insert("DataStructureTemplateName", "ImportDataFromFile");
		DataProcessors.ImportDataFromFile.ParametersOfImportFromFileExternalDataProcessor(CommandID,
			ExternalDataProcessorRef, DefaultImportParameters);
	EndIf;
	
	ColumnsInformationTable = Common.CommonSettingsStorageLoad("ImportDataFromFile", MappingObjectName,, UserName());
	If ColumnsInformationTable = Undefined Then
		ColumnsInformationTable = FormAttributeToValue("ColumnsInformation");
	EndIf;
	DataProcessors.ImportDataFromFile.DetermineColumnsInformation(DefaultImportParameters, ColumnsInformationTable);
	ValueToFormAttribute(ColumnsInformationTable, "ColumnsInformation");
	
	ImportParameters = DefaultImportParameters;
	
	ChangeTemplateByColumnsInformation();
EndProcedure

&AtServer
Procedure SaveTableToCSVFile(FullFileName)
	DataProcessors.ImportDataFromFile.SaveTableToCSVFile(FullFileName, ColumnsInformation);
EndProcedure

#EndRegion

#Region ImportedDataMappingStep

&AtServer
Procedure CopySingleColumnToTemplateWithData()
	
	ClearTemplateWithData();
	
	RowsCount = StrLineCount(TemplateWithDataSingleColumn);
	RowNumberInTemplate = 2;
	For LineNumber = 1 To RowsCount Do 
		String = StrGetLine(TemplateWithDataSingleColumn, LineNumber);
		If ValueIsFilled(String) Then
			Cell = TemplateWithData.GetArea(RowNumberInTemplate, 1, RowNumberInTemplate, 1);
			Cell.CurrentArea.Text = String;
			TemplateWithData.Put(Cell);
			RowNumberInTemplate = RowNumberInTemplate + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure MapDataToImportAtServer()
	
	ImportDataFromFile.AddStatisticalInformation(?(ImportOption = 0,
		"ImportOption.FillTable", "ImportOption.FromExternalFile"));
	
	TableColumnsInformation = FormAttributeToValue("ColumnsInformation");
	If ImportType = "TabularSection" Then
		ImportedDataAddress   = "";
		TabularSectionCopyAddress = "";
		ConflictsList   =  ImportDataFromFile.ANewListOfAmbiguities();
		
		DataProcessors.ImportDataFromFile.SpreadsheetDocumentIntoValuesTable(TemplateWithData, TableColumnsInformation, ImportedDataAddress);
		
		CopyTabularSectionStructure(TabularSectionCopyAddress);
		
		ObjectManager = ObjectManager(MappingObjectName);
		ObjectManager.MapDataToImport(ImportedDataAddress, TabularSectionCopyAddress, ConflictsList, MappingObjectName, AdditionalParameters);
		
		If Not AttributesCreated Then
			CreateMappingTableByColumnsInformationForTS();
		EndIf;
		PutDataInMappingTable(ImportedDataAddress, TabularSectionCopyAddress, ConflictsList);
		
	ElsIf ImportType = "PastingFromClipboard" Then
		MappingTable = FormAttributeToValue("DataMappingTable");
		DataProcessors.ImportDataFromFile.FillMappingTableWithDataFromTemplate(TemplateWithData, MappingTable, ColumnsInformation);
		DataProcessors.ImportDataFromFile.MapAutoColumnValue(MappingTable, "References");
		ValueToFormAttribute(MappingTable, "DataMappingTable");
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataToImportMappingStepAfterMapAtServer(ResultAddress)
	
	MappingTable = GetFromTempStorage(ResultAddress);
	
	If ImportType = "AppliedImport" Then
		MapDataAppliedImport(MappingTable);
	ElsIf ImportType = "ExternalImport" Then
		MapDataExternalDataProcessor(MappingTable);
	EndIf;
	
	Filter                    = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusMapped());
	Result                = MappingTable.FindRows(Filter);
	
	If Result.Count() = MappingTable.Count() Then
		Explanation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data is mapped. If necessary, you can map the data manually by filling in the ""%1"" column.';"),
			ImportParameters.ObjectPresentation);
		MappingTableFilter = Items.MappingTableFilter.ChoiceList.FindByValue("");
	Else
		Explanation =  StringFunctionsClientServer.SubstituteParametersToString(
			Items.AppliedImportNote.Title, ImportParameters.ObjectPresentation);
	EndIf;
	
	Items.AppliedImportNote.Title = Explanation;
	
	ValueToFormAttribute(MappingTable, "DataMappingTable");
	
EndProcedure

&AtClient
Procedure MapDataToImport()
	
	If ImportType = "PastingFromClipboard" Then
		If IsBlankString(TemplateWithDataSingleColumn) Then
			ShowMessageBox(, (NStr("en = 'To add mapped data to the list, fill in the text field.';")));
			Return;
		EndIf;
		
		CopySingleColumnToTemplateWithData();
		
	Else
		
		ExecuteStepFillTableWithDataAtClient();
		
		If EmptyDataTable() Then
		
			If ImportOption = 0 Then
				ShowMessageBox(, (NStr("en = 'To map and import data, fill in the table.';")));
			Else
				ShowMessageBox(, (NStr("en = 'Cannot import data from the spreadsheet.
				|It appears that column titles in the file don''t match the column titles in the template.';")));
				Items.Back.Visible = False;
			EndIf;
			
			CommandBarButtonsAvailability(True); 
			
			Return;
			
		EndIf;
		
	EndIf;
	
	FormClosingConfirmation = False;
	UnfilledColumnsList = NotFilledRequiredColumns();
	If UnfilledColumnsList.Count() > 0 Then
		If UnfilledColumnsList.Count() = 1 Then
			TextAboutColumns = NStr("en = 'Required column ""';") + " " + UnfilledColumnsList[0]
				+ NStr("en = '"" contains blank cells. Rows with these cells will be skipped.';");
		Else
			TextAboutColumns = NStr("en = 'Required columns ""';") + " " + StrConcat(UnfilledColumnsList,", ")
				+ NStr("en = '"" contain blank cells. Rows with these cells will be skipped.';");
		EndIf;
		TextAboutColumns = TextAboutColumns + Chars.LF + NStr("en = 'Do you want to continue?';");
		
		Notification = New NotifyDescription("AfterQuestionAboutBlankStrings", ThisObject);
		ShowQueryBox(Notification, TextAboutColumns, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	Else
		ExecuteDataToImportMappingStepAfterCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterQuestionAboutBlankStrings(Result, Parameter) Export
	If Result = DialogReturnCode.Yes Then 
		ExecuteDataToImportMappingStepAfterCheck();
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteDataToImportMappingStepAfterCheck()
	
	CommandBarButtonsAvailability(False);
	
	If ImportType = "PastingFromClipboard" Or ImportType = "TabularSection" Then
		MapDataToImportAtServer();
		If AllDataMapped() And ImportType = "PastingFromClipboard" Then
			CloseFormAndReturnRefArray();
		Else
			ExecuteDataToImportMappingStepClient();
		EndIf;
	Else
		ExecutionProgressNotification = New NotifyDescription("ExecutionProgress", ThisObject);
		TimeConsumingOperation = MapDataToImportAtServerUniversalImport();
		If TimeConsumingOperation.Status = "Running" Then
			Items.WizardPages.CurrentPage = Items.TimeConsumingOperations;
		EndIf;
	
		WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		WaitSettings.OutputIdleWindow = False;
		WaitSettings.ExecutionProgressNotification = ExecutionProgressNotification;
		
		Handler = New NotifyDescription("AfterMapImportedData", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Handler, WaitSettings);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandBarButtonsAvailability(Var_Enabled)
	
	Items.Back.Enabled = Var_Enabled;
	Items.Next.Enabled = Var_Enabled;

EndProcedure

&AtClient
Procedure GoToPage(DisplayedPage)
	
	CommandBarButtonsAvailability(True);
	Items.WizardPages.CurrentPage = DisplayedPage;
EndProcedure

#Region TimeConsumingOperations

&AtClient
Procedure WriteDataToImportClient()
	
	CommandBarButtonsAvailability(False);
	
	ObjectPresentation = ImportParameters.ObjectPresentation;
	Items.OpenCatalogAfterCloseWizard.Title = 
		StringFunctionsClientServer.SubstituteParametersToString(Items.OpenCatalogAfterCloseWizard.Title,
			ObjectPresentation);
	Items.ImportReportNote.Title = 
		StringFunctionsClientServer.SubstituteParametersToString(Items.ImportReportNote.Title, ObjectPresentation);
	
	If ImportType <> "UniversalImport" Then
		RefsToNotificationObjects = New Array;
		
		ProcessDataToImport(RefsToNotificationObjects);
		NotifyFormsAboutChange(RefsToNotificationObjects);
		
		ReportAtClientBackgroundJob();
	Else
		BackgroundJobPercentage = 0;
		TimeConsumingOperation = RecordDataToImportReportUniversalImport();
		If TimeConsumingOperation.Status = "Running" Then
			Items.WizardPages.CurrentPage = Items.TimeConsumingOperations;
		EndIf;
		
		ExecutionProgressNotification = New NotifyDescription("ExecutionProgress", ThisObject);
		WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		WaitSettings.OutputIdleWindow = False;
		WaitSettings.ExecutionProgressNotification = ExecutionProgressNotification;
		
		Handler = New NotifyDescription("AfterSaveDataToImportReport", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Handler, WaitSettings);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportAtClientBackgroundJob(NotOutputIdleWindow = True)
	
	TimeConsumingOperation = GenerateReportOnImport(FilterReport, NotOutputIdleWindow);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = Not NotOutputIdleWindow;
	
	Handler = New NotifyDescription("AfterCreateReport", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Handler, WaitSettings);
	
EndProcedure

&AtClient
Procedure ShowReport(ResultAddress)
	
	Report = GetFromTempStorage(ResultAddress);
	
	If Items.WizardPages.CurrentPage <> Items.DataImportReport Then
		ExecuteDataImportReportStepClient();
	EndIf;
	
	CreatedItemsTotalReport = Report.CreatedOn;
	TotalItemsUpdatedReport = Report.Updated3;
	SkippedItemsTotalReport = Report.Skipped3;
	TotalInvalidItemsReport = Report.Invalid2;
	
	Items.FilterReport.ChoiceList.Clear();
	Items.FilterReport.ChoiceList.Add("AllItems", NStr("en = 'All (';") + Report.Total + ")");
	Items.FilterReport.ChoiceList.Add("New_Items", NStr("en = 'New items (';") + Report.CreatedOn+ ")");
	Items.FilterReport.ChoiceList.Add("Updated2", NStr("en = 'Updated items (';") + Report.Updated3+ ")");
	Items.FilterReport.ChoiceList.Add("Skipped2", NStr("en = 'Skipped items (';") + Report.Skipped3+ ")");
	FilterReport = Report.ReportType;

	TableReport = Report.TableReport;
	
EndProcedure

#EndRegion

&AtClient
Procedure ExecuteDataToImportMappingStepClient()
	
	If ImportType = "PastingFromClipboard" Then
		Statistics = MappingStatistics();
		
		If Statistics.Mapped2 > 0 Then
			TextFound = NStr("en = '%2 out of %1 entered lines will be added to the list.';");
			Items.MappingResultLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(TextFound,
				Statistics.Total, Statistics.Mapped2);
			
			If Statistics.Ambiguous1 > 0 And Statistics.NotFound4 > 0 Then 
				TextNotFound = NStr("en = 'Total rows skipped: %3. Details:
				| • No matches found: %1
				| • Multiple matches found: %2';");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersToString(TextNotFound, Statistics.NotFound4, Statistics.Ambiguous1, Statistics.Incomparable);
			ElsIf Statistics.Ambiguous1 > 0 Then
				TextNotFound = NStr("en = 'Rows that has multiple matches will be skipped: %1';");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersToString(TextNotFound, Statistics.Ambiguous1);
			ElsIf Statistics.NotFound4 > 0 Then
				TextNotFound = NStr("en = 'Rows that has no matches will be skipped: %1';");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersToString(TextNotFound, Statistics.NotFound4);
			EndIf;
			TextNotFound = TextNotFound + Chars.LF + NStr("en = 'To view skipped rows and map them manually, click ""Next"".';");
			Items.NotFoundAndConflictsDecoration.Title = TextNotFound;
			
			Items.WizardPages.CurrentPage = Items.MappingResults;
			Items.Back.Visible = True;
			Items.AddToList.Visible = True;
			Items.Next.Visible = True;
			Items.Back.Title = NStr("en = '< Back';");
			Items.Next.Title = NStr("en = 'Next >';");
			Items.Next.DefaultItem = False;
			Items.AddToList.DefaultItem = True;
			Items.AddToList.DefaultButton = True;
			
			ShowMappingStatisticsImportFromFile();
			SetAppearanceForMappingPage(False, Items.RefSearchNote, False, NStr("en = 'Next >';"));
		Else
			Items.WizardPages.CurrentPage = Items.NotFound4;
			Items.Close.Title = NStr("en = 'Close';");
			Items.Back.Visible = True;
			Items.AddToList.Visible = False;
			Items.Next.Visible = False;
		EndIf;
		
	Else 
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
		ShowMappingStatisticsImportFromFile();
		
		If ImportType = "UniversalImport" Then
			SetAppearanceForMappingPage(True, Items.DataMappingNote, True, NStr("en = 'Import data >';"));
		ElsIf ImportType = "TabularSection" Then
			FilterNotMapped = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusUnmapped());
			FilterConflict1 = New Structure("RowMappingResult", ImportDataFromFileClientServer.StatusAmbiguity());
			If DataMappingTable.FindRows(FilterNotMapped).Count() = 0
				And DataMappingTable.FindRows(FilterConflict1).Count() = 0 Then
				// All rows are mapped.
				ProceedToNextStepOfDataImport();
			EndIf;
			
			SetAppearanceForMappingPage(False, Items.TabularSectionNote, True, NStr("en = 'Import data';"));
			SetAppearanceForConflictFields(FilterConflict1);
		Else
			SetAppearanceForMappingPage(False, Items.AppliedImportNote, False, NStr("en = 'Import data >';"));
		EndIf;
	EndIf;
	
	CommandBarButtonsAvailability(True);

EndProcedure

&AtClient
Procedure SetAppearanceForMappingPage(MappingButtonVisibility, ExplanatoryTextItem, ButtonVisibilityResolveConflict, NextButtonText)
	
	Items.MappingColumnsList.Visible = MappingButtonVisibility;
	Items.Back.Visible = True;
	Items.AppliedImportNote.Visible = False;
	Items.TabularSectionNote.Visible = False;
	Items.RefSearchNote.Visible = False;
	If ExplanatoryTextItem = Items.TabularSectionNote Then
		Items.TabularSectionNote.Visible = True;
	ElsIf ExplanatoryTextItem = Items.RefSearchNote Then
		Items.RefSearchNote.Visible = True;
		Items.DataMappingNote.ShowTitle = False;
	ElsIf ExplanatoryTextItem = Items.AppliedImportNote Then
		Items.AppliedImportNote.Visible = True;
	EndIf;
	
	Items.ResolveConflict.Visible = ButtonVisibilityResolveConflict;
	Items.Next.Title = NextButtonText;
	
EndProcedure

&AtClient
Procedure OpenResolveConflictForm(RowSelected, NameField1, StandardProcessing)
	String = DataMappingTable.FindByID(RowSelected);
	
	If ImportType = "TabularSection" Then
		If String.RowMappingResult = ImportDataFromFileClientServer.StatusAmbiguity()
		   And StrLen(String.ErrorDescription) > 0 Then
			TabularSectionStartPrefix = StringFunctionsClientServer.SubstituteParametersToString("%1_%2_", 
				ImportDataFromFileClientServer.MappingTablePrefix(), 
				ImportDataFromFileClientServer.TablePartPrefix());
			If StrLen(NameField1) > 3 And StrStartsWith(NameField1, TabularSectionStartPrefix) Then
				Name = Mid(NameField1, StrLen(TabularSectionStartPrefix) + 1);
				If StrFind(String.ErrorDescription, Name) Then
					StandardProcessing = False;
					TableRow = New Array;
					ValuesOfColumnsToImport = New Structure();
					For Each Column In ColumnsInformation Do
						ColumnsArray1 = New Array();
						ColumnsArray1.Add(Column.ColumnName);
						ColumnsArray1.Add(Column.ColumnPresentation);
						ColumnsArray1.Add(String["PL_" + Column.ColumnName]);
						ColumnsArray1.Add(Column.ColumnType);
						TableRow.Add(ColumnsArray1);
						If Name = Column.Parent Then
							ValuesOfColumnsToImport.Insert(Column.ColumnName, String["PL_" + Column.ColumnName]);
						EndIf;
					EndDo;
					
					FormParameters = New Structure();
					FormParameters.Insert("ImportType", ImportType);
					FormParameters.Insert("Name", Name);
					FormParameters.Insert("TableRow", TableRow);
					FormParameters.Insert("ValuesOfColumnsToImport", ValuesOfColumnsToImport);
					FormParameters.Insert("ConflictsList", Undefined);
					FormParameters.Insert("FullTabularSectionName", MappingObjectName);
					FormParameters.Insert("AdditionalParameters", AdditionalParameters);
					
					Parameter = ConflictsMapParametersDetails(RowSelected, Name);
					
					Notification = New NotifyDescription("AfterMappingConflicts", ThisObject, Parameter);
					OpenForm("DataProcessor.ImportDataFromFile.Form.ResolveConflicts", FormParameters, ThisObject, True , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
				EndIf;
			EndIf;
		EndIf;
	Else
		If String.RowMappingResult = ImportDataFromFileClientServer.StatusAmbiguity() Then
			StandardProcessing = False;
			
			TableRow = New Array;
			For Each Column In ColumnsInformation Do 
				ColumnsArray1 = New Array();
				ColumnsArray1.Add(Column.ColumnName);
				ColumnsArray1.Add(Column.ColumnPresentation);
				ColumnsArray1.Add(String[Column.ColumnName]);
				ColumnsArray1.Add(Column.ColumnType);
				TableRow.Add(ColumnsArray1);
			EndDo;
			
			MappingColumns = New ValueList;
			For Each Item In MapByColumn Do 
				If Item.Check Then
					MappingColumns.Add(Item.Value);
				EndIf;
			EndDo;
			
			FormParameters = New Structure();
			FormParameters.Insert("TableRow", TableRow);
			FormParameters.Insert("ConflictsList", String.ConflictsList);
			FormParameters.Insert("MappingColumns", MappingColumns);
			FormParameters.Insert("ImportType", ImportType);
			
			Parameter = New Structure("Id", RowSelected);
			
			Notification = New NotifyDescription("AfterMappingConflicts", ThisObject, Parameter);
			OpenForm("DataProcessor.ImportDataFromFile.Form.ResolveConflicts", FormParameters, ThisObject, True , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		
	EndIf;
	
EndProcedure

// Returns:
//   Structure:
//    * Id - Number
//    * Name - String
//
&AtClient
Function ConflictsMapParametersDetails(Val RowSelected, Val Name)
	
	Parameter = New Structure();
	Parameter.Insert("Id", RowSelected);
	Parameter.Insert("Name", Name);
	
	Return Parameter;
	
EndFunction

&AtServer
Procedure MapDataAppliedImport(DataMappingTableServer)
	
	ManagerObject = ObjectManager(MappingObjectName);
	
	ManagerObject.MatchUploadedDataFromFile(DataMappingTableServer);
	For Each TableRow In DataMappingTableServer Do 
		If ValueIsFilled(TableRow.MappingObject) Then 
			TableRow.RowMappingResult = ImportDataFromFileClientServer.StatusMapped();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ImportReportStep

&AtServer
Procedure ProcessDataToImport(RefsToNotificationObjects)
	
	MappedData = FormAttributeToValue("DataMappingTable");
	
	If ImportType = "ExternalImport" Then
		WriteMappedDataExternalDataProcessor(MappedData);
		ValueToFormAttribute(MappedData, "DataMappingTable");
	Else
		WriteMappedDataAppliedImport(MappedData);
		ValueToFormAttribute(MappedData, "DataMappingTable");
	EndIf;
	
	PrepareListForNotification(MappedData, RefsToNotificationObjects);
	
EndProcedure

&AtServerNoContext
Procedure PrepareListForNotification(MappedData, RefsToNotificationObjects)
	
	ObjectsRefs = New Array;
	For Each MappedDataString In MappedData Do
		ObjectsRefs.Add(MappedDataString.MappingObject);
	EndDo;
	
	RefsToNotificationObjects = StandardSubsystemsServer.PrepareFormChangeNotification(ObjectsRefs);
	
EndProcedure

&AtClient
Procedure ExecuteDataImportReportStepClient()
	
	Items.WizardPages.CurrentPage = Items.DataImportReport;
	Items.OpenCatalogAfterCloseWizard.Visible = True;
	Items.Close.Title = NStr("en = 'Finish';");
	Items.Next.Visible = False;
	Items.Back.Visible = False;
	
EndProcedure

#EndRegion

// Parameters:
//   TableColumnsInformation - ValueTable
//   TemplateColumns - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
//
&AtServer
Procedure DefineDynamicTemplate(TableColumnsInformation, TemplateColumns)
	
	TableColumnsInformation = ColumnsInformation();
	TableColumnsInformation.Clear();
	
	For Each Column In TemplateColumns Do
		If Column.Position <> Undefined Then
			String = TableColumnsInformation.Add();
			String.ColumnName = Column.Name;
			String.Width = ?(ValueIsFilled(Column.Width), Column.Width, 20);
			String.Note = Column.ToolTip;
			FillPropertyValues(String, Column,, "Width");
			String.Visible = True;
			String.ColumnPresentation = Column.Title;
			String.ColumnType = Column.Type;
			EndIf;
	EndDo;

	AdjustingColumnPositions(TableColumnsInformation);
	
EndProcedure

&AtServer
Procedure AdjustingColumnPositions(TableColumnsInformation)

	TableColumnsInformation.Sort("Position");
	Position = 1;
	
	For Each ColumnInformation In TableColumnsInformation Do
		
		ColumnInformation.Position = Position;
		Position = Position + 1;
		
	EndDo;
	
EndProcedure

// Returns:
//  ValueTable:
//    * ColumnName - String
//    * ColumnPresentation - String
//    * ColumnType - Arbitrary
//    * IsRequiredInfo - Boolean
//    * Position - Number
//    * Group - String
//    * Parent - String
//    * Visible - Boolean
//    * Note - String
//    * Width - Number
//    * Synonym - String
//
&AtServer
Function ColumnsInformation()
	
	TableColumnsInformation = FormAttributeToValue("ColumnsInformation");
	Return TableColumnsInformation ;
	
EndFunction

&AtServer
Procedure ClearTable()
	
	DataMappingTableServer = FormAttributeToValue("DataMappingTable");
	DataMappingTableServer.Columns.Clear();
	ColumnsInformation.Clear();
	
	While Items.DataMappingTable.ChildItems.Count() > 0 Do
		Items.Delete(Items.DataMappingTable.ChildItems.Get(0));
	EndDo;
	TemplateWithData = New SpreadsheetDocument;
	
	MappingTableAttributes = GetAttributes("DataMappingTable");
	AttributePathsArray = New Array;
	For Each TableAttribute In MappingTableAttributes Do
		AttributePathsArray.Add("DataMappingTable." + TableAttribute.Name);
	EndDo;
	If AttributePathsArray.Count() > 0 Then
		ChangeAttributes(,AttributePathsArray);
	EndIf;
	
EndProcedure

&AtClient
Function SetAppearanceForConflictFields(Filter)
	
	Rows = DataMappingTable.FindRows(Filter);
	If Rows.Count() > 0 Then
		ColumnsList = New Array;
		For Each DataString1 In Rows Do
			If StrCompare(DataString1.RowMappingResult, 
				ImportDataFromFileClientServer.StatusAmbiguity()) = 0 Then
				ColumnsArray1 = StrSplit(DataString1.ErrorDescription, ";", False);
				For Each ColumnName In ColumnsArray1 Do
					ColumnsList.Add(ColumnName);
				EndDo;
			EndIf;
		EndDo;
	Else 
		Return False;
	EndIf;
	
	SetDataAppearance(ColumnsList);
	Return True;
EndFunction

&AtServer
Procedure SetDataAppearance(ColumnsList = Undefined)
	
	
	If ImportType = "PastingFromClipboard" Then 
		TextObjectNotFound = NStr("en = '<Not found>';");
		ColorObjectNotFound = StyleColors.InaccessibleCellTextColor;
		ColorConflict = StyleColors.ErrorNoteText;
	Else
		TextObjectNotFound = NStr("en = '<New>';");
		ColorObjectNotFound = StyleColors.SuccessResultColor;
		ColorConflict = StyleColors.ErrorNoteText;
	EndIf;
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("MappingObject");
	AppearanceField.Use = True;
	
	FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DataMappingTable.MappingObject"); 
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterElement.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", ColorObjectNotFound);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", TextObjectNotFound);
	
	MappingTablePrefix = ImportDataFromFileClientServer.MappingTablePrefix();
	
	If ValueIsFilled(ColumnsList) Then
		TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix();
		
		For Each ColumnName In ColumnsList Do
			ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
			AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
			AppearanceField.Field = New DataCompositionField(StringFunctionsClientServer.SubstituteParametersToString("%1_%2_%3",
				MappingTablePrefix, TablePartPrefix, ColumnName));
			AppearanceField.Use = True;
			FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterElement.LeftValue = New DataCompositionField("DataMappingTable.RowMappingResult");
			FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
			FilterElement.RightValue = ImportDataFromFileClientServer.StatusAmbiguity();
			FilterElement.Use = True;
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", ColorConflict);
			ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
			ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en = '<ambiguity>';"));
		EndDo;
	Else
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField(StringFunctionsClientServer.SubstituteParametersToString("%1_%2",
			MappingTablePrefix, "MappingObject"));
		AppearanceField.Use = True;
		FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue = New DataCompositionField("DataMappingTable.RowMappingResult");
		FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
		FilterElement.RightValue = ImportDataFromFileClientServer.StatusAmbiguity();
		FilterElement.Use = True;
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", ColorConflict);
		ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en = '<ambiguity>';"));
		
	EndIf;
	
EndProcedure

&AtServer
Function ColumnInformation(ColumnName)
	Filter = New Structure("ColumnName", ColumnName);
	Result = ColumnsInformation.FindRows(Filter);
	If Result.Count() > 0 Then
		Return Result[0];
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function MetadataObjectInfoByType(FullObjectType)
	ObjectDetails = New Structure("ObjectType, ObjectName");
	FullName = Metadata.FindByType(FullObjectType).FullName();
	Result = StrSplit(FullName, ".", False);
	If Result.Count()>1 Then
		ObjectDetails.ObjectType = Result[0];
		ObjectDetails.ObjectName = Result[1];
		
		Return ObjectDetails;
	Else
		Return Undefined;
	EndIf;
	
EndFunction 

&AtServer
Function ConditionsBySelectedColumns(CatalogName)
	
	ComparisonTypeSSL   = " = ";
	StringCondition  = "";
	TabularSection = "";
	FilterWhere       = New Array;
	ConditionStrings  = New Array;
	ContactInformationConditionTemplate = "CAST(MappingCatalog.Presentation AS STRING(500)) = CAST(MappingTable.%1 AS STRING(500))";
	AdditionalAttributeConditionTemplate = "MappingCatalog.Value =  MappingTable.%1";
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Catalogs[CatalogName].EmptyRef());
	EndIf;
	
	For Each Item In MapByColumn Do
		If Item.Check Then

			Column = ColumnInformation(Item.Value);
			If Column = Undefined Then
				Continue;
			EndIf;
				
			If StrStartsWith(Column.ColumnName, "ContactInformation_") Then
				
				CIKindName = StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(
					Mid(Column.ColumnName, StrLen("ContactInformation_") + 1));
				FoundKinds = ContactInformationKinds.Find(CIKindName, "Description");
				
				TabularSection = "ContactInformation";
				StringCondition = StringFunctionsClientServer.SubstituteParametersToString(ContactInformationConditionTemplate, Column.ColumnName);
				If FoundKinds <> Undefined Then
					
					KindDescription = Common.ObjectAttributeValue(FoundKinds.Ref, "Description");
					If KindDescription <> Undefined Then
						StringCondition = StringCondition + StringFunctionsClientServer.SubstituteParametersToString(
							" AND MappingCatalog.Kind.Description = ""%1""", KindDescription);
					EndIf;
					
				EndIf;
				ConditionStrings.Add(StringCondition);
				FilterWhere.Add("MappingCatalog.Presentation <> """"");
				Continue;
				
			ElsIf StrStartsWith(Column.ColumnName, "AdditionalAttribute_") Then
				CatalogColumnName = "Value";
				TabularSection = "AdditionalAttributes";
				ConditionStrings.Add(StringFunctionsClientServer.SubstituteParametersToString(AdditionalAttributeConditionTemplate, Column.ColumnName));
				
				ColumnType = Column.ColumnType.Types()[0];
				If TypeOf(ColumnType) = Type("String") And Column.ColumnType.StringQualifiers.Length = 0 Then
					Continue; // It is not allowed to compare lines of unlimited length.
				EndIf;
				
				ColumnTypeObjects = Metadata.FindByType(ColumnType);
				If ColumnTypeObjects <> Undefined Then      
					TemplateWhere = "MappingCatalog.Value <> VALUE(%1.EmptyRef)";
					FilterWhere.Add(StringFunctionsClientServer.SubstituteParametersToString(TemplateWhere, ColumnTypeObjects.FullName()));
				EndIf;
				Continue;
			EndIf;
			
			CatalogColumnName = "Ref." + Column.ColumnName;
			
			ColumnType = Column.ColumnType.Types()[0];
			If ColumnType = Type("String") Then 
				If Column.ColumnType.StringQualifiers.Length = 0 Then
					ConditionStrings.Add(StringFunctionsClientServer.SubstituteParametersToString(
						"CAST(MappingCatalog.%1 AS STRING(500)) = CAST(MappingTable.%2 AS  STRING(500))", 
						CatalogColumnName, Column.ColumnName));
				Else
					ConditionStrings.Add(StringFunctionsClientServer.SubstituteParametersToString(
						"MappingCatalog.%1 = MappingTable.%2", CatalogColumnName, Column.ColumnName));
				EndIf;
				TemplateWhere = "MappingCatalog.%1 <> """"";
				FilterWhere.Add(StringFunctionsClientServer.SubstituteParametersToString(TemplateWhere, CatalogColumnName));
			ElsIf ColumnType = Type("Number") Or ColumnType = Type("Date") Or ColumnType = Type("Boolean") Then
				ConditionStrings.Add(StringFunctionsClientServer.SubstituteParametersToString(
					"MappingCatalog.%1 =  MappingTable.%2", CatalogColumnName, Column.ColumnName));
			Else
				InfoObject = MetadataObjectInfoByType(ColumnType);
				If InfoObject.ObjectType = "Catalog" Then
					ConditionTextCatalog = New Array;
					Catalog = Metadata.Catalogs.Find(InfoObject.ObjectName); // MetadataObjectCatalog
					For Each InputString In Catalog.InputByString Do 
						If InputString.Name = "Code" And Not Catalog.Autonumbering Then 
							InputByStringConditionText = StringFunctionsClientServer.SubstituteParametersToString(
								"MappingCatalog.%1.Code %2 MappingTable.%3", // ACC:1297 - The query fragment is not localizable.
								CatalogColumnName, ComparisonTypeSSL, Column.ColumnName);
						Else
							InputByStringConditionText = StringFunctionsClientServer.SubstituteParametersToString(
								"MappingCatalog.%1.%2 %3 MappingTable.%4", // ACC:1297 - The query fragment is not localizable.
								CatalogColumnName, InputString.Name, ComparisonTypeSSL, Column.ColumnName);
						EndIf;
						ConditionTextCatalog.Add(InputByStringConditionText);
					EndDo;
					ConditionStrings.Add(" ( " + StrConcat(ConditionTextCatalog, " OR ") + " )");
				ElsIf InfoObject.ObjectType = "Enum" Then
					ConditionStrings.Add(StringFunctionsClientServer.SubstituteParametersToString(
						"MappingCatalog.%1 =  MappingTable.%2", CatalogColumnName, Column.ColumnName));	
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;
	
	Conditions = New Structure("JoinCondition , Where, TabularSection");
	Conditions.JoinCondition  = StrConcat(ConditionStrings, " And ");
	Conditions.Where = StrConcat(FilterWhere, " And ");
	Conditions.TabularSection = TabularSection;
	Return Conditions;
	
EndFunction

&AtServer
Procedure ExecuteMappingBySelectedAttribute(MappedItemsCount = 0, MappingColumnsList = "")
	
	ObjectStructure = DataProcessors.ImportDataFromFile.SplitFullObjectName(MappingObjectName);
	CatalogName   = ObjectStructure.NameOfObject;
	Conditions          = ConditionsBySelectedColumns(CatalogName);
	
	If Not ValueIsFilled(Conditions.JoinCondition) Then
		Return;
	EndIf;
	
	If ValueIsFilled(Conditions.TabularSection) Then
		CatalogName = CatalogName + "." + Conditions.TabularSection;
	EndIf;
	
	MappingTable = FormAttributeToValue("DataMappingTable");
	
	ColumnsList = "";
	Separator   = "";
	
	For Each Column In MappingTable.Columns Do
		If Column.Name <> "ConflictsList" And Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" Then
			ColumnsList = ColumnsList + Separator + Column.Name;
			Separator   = ", ";
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text = "SELECT
	|	&ColumnsList
	|INTO MappingTable
	|FROM
	|	&MappingTable AS MappingTable
	|;
	|
	|SELECT
	|	MappingCatalog.Ref,
	|	MappingTable.Id
	|FROM
	|	MappingTable AS MappingTable
	|		LEFT JOIN &MappingCatalog AS MappingCatalog
	|		ON &JoinCondition
	|WHERE
	|	MappingCatalog.Ref.DeletionMark = FALSE
	|	AND &Conditions
	|ORDER BY
	|	MappingTable.ID
	|TOTALS
	|BY
	|	MappingTable.ID";
	
	Query.Text = StrReplace(Query.Text, "&ColumnsList", ColumnsList);
	Query.Text = StrReplace(Query.Text, "&MappingCatalog", "Catalog." + CatalogName);
	Query.Text = StrReplace(Query.Text, "&JoinCondition", Conditions.JoinCondition);
	Query.Text = StrReplace(Query.Text, "&Conditions", ?(IsBlankString(Conditions.Where), "TRUE", Conditions.Where));
	Query.SetParameter("MappingTable", MappingTable);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionDetailRecords.Next() Do
		String = MappingTable.Find(SelectionDetailRecords.Id, "Id");
		
		If ValueIsFilled(String.MappingObject) Then
			Continue;
		EndIf;
		
		DetailedRecordsSelectionGroup = SelectionDetailRecords.Select();
		
		If DetailedRecordsSelectionGroup.Count() > 1 Then
			ConflictsList = New ValueList;
			While DetailedRecordsSelectionGroup.Next() Do
				ConflictsList.Add(DetailedRecordsSelectionGroup.Ref);
			EndDo;
			String.RowMappingResult = ImportDataFromFileClientServer.StatusAmbiguity();
			String.ErrorDescription = MappingColumnsList;
			String.ConflictsList = ConflictsList;
		Else
			DetailedRecordsSelectionGroup.Next();
			MappedItemsCount = MappedItemsCount + 1;
			String.RowMappingResult = ImportDataFromFileClientServer.StatusMapped();
			String.ErrorDescription = "";
			String.MappingObject = DetailedRecordsSelectionGroup.Ref;
		EndIf;
	EndDo;
	
	MappingColumnsList = "";
	Separator = "";
	For Each Column In MapByColumn Do
		If Column.Check Then
			MappingColumnsList = MappingColumnsList + Separator + Column.Presentation;
			Separator = ", ";
		EndIf;
	EndDo;
	ImportDataFromFile.AddStatisticalInformation("ColumnMapping", MappedItemsCount, MappingColumnsList);
	
	ValueToFormAttribute(MappingTable, "DataMappingTable");
	
EndProcedure

&AtServer
Procedure PutDataInMappingTable(ImportedDataAddress, TabularSectionCopyAddress, ConflictsList)
	
	TabularSection = GetFromTempStorage(TabularSectionCopyAddress); // See TabularSectionDetails 
	
	ThisIsTable = TypeOf(TabularSection) = Type("ValueTable");
	
	If Not ThisIsTable Or TabularSection.Count() = 0  Then
		Return;
	EndIf;
	
	Filter = New Structure("IsRequiredInfo", True);
	FilteredColumnsRequiredForTableFilling = ColumnsInformation.FindRows(Filter);
	RequiredColumns1 = New Map;
	For Each TableColumn2 In FilteredColumnsRequiredForTableFilling  Do
		RequiredColumns1.Insert(TableColumn2.Parent, True);
	EndDo;
	
	DataMappingTable.Clear();
	DataToImport = GetFromTempStorage(ImportedDataAddress); // See TabularSectionDetails 
	
	TabularSectionColumns = New Map();
	For Each Column In TabularSection.Columns Do
		TabularSectionColumns.Insert(Column.Name, True);
	EndDo;
	TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix() + "_";
	
	TemporarySpecification = FormAttributeToValue("DataMappingTable"); // See DataProcessor.ImportDataFromFile.Form.ImportDataFromFile.DataMappingTable
	For Each TableRow In TabularSection Do
		NewRow = TemporarySpecification.Add();
		NewRow.Id = TableRow.Id;
		AllRequiredColumnsFilled = True;
		For Each Column In TabularSection.Columns Do
			If Column.Name <> "Id" Then
				NewRow[TablePartPrefix + Column.Name] = TableRow[Column.Name];
			EndIf;
			
			If ValueIsFilled(RequiredColumns1.Get(Column.Name))
				And AllRequiredColumnsFilled
				And Not ValueIsFilled(TableRow[Column.Name]) Then
					AllRequiredColumnsFilled = False;
			EndIf;
		EndDo;
		
		NewRow["RowMappingResult"] = ?(AllRequiredColumnsFilled, 
			ImportDataFromFileClientServer.StatusMapped(), ImportDataFromFileClientServer.StatusUnmapped());
		
		Filter = New Structure("Id", TableRow.Id); 
		
		Conflicts2 = ConflictsList.FindRows(Filter);
		If Conflicts2.Count() > 0 Then 
			NewRow["RowMappingResult"] = ImportDataFromFileClientServer.StatusAmbiguity();
			For Each Conflict1 In Conflicts2 Do
				NewRow["ErrorDescription"] = NewRow["ErrorDescription"] + Conflict1.Column+ ";";
				ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
				AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
				AppearanceField.Field = New DataCompositionField(TablePartPrefix + Conflict1.Column);
				AppearanceField.Use = True;
				FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
				FilterElement.LeftValue = New DataCompositionField("DataMappingTable.ErrorDescription"); 
				FilterElement.ComparisonType = DataCompositionComparisonType.Contains; 
				FilterElement.RightValue = Conflict1.Column; 
				FilterElement.Use = True;
				ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.ErrorNoteText);
				ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
				ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en = '<ambiguity>';"));
			EndDo;
		EndIf;
	EndDo;
	
	TemporarySpecification.Indexes.Add("Id");
	For Each TableRow In DataToImport Do
		Filter = New Structure("Id", TableRow.Id);
		Rows = TemporarySpecification.FindRows(Filter);
		If Rows.Count() > 0 Then 
			NewRow = Rows[0];
			For Each Column In DataToImport.Columns Do
				If Column.Name <> "Id" And Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" Then
					NewRow["PL_" + Column.Name] = TableRow[Column.Name];
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	ValueToFormData(TemporarySpecification, DataMappingTable);
	
EndProcedure

&AtServer
Function MappingTableAddressInStorage()
	Table = FormAttributeToValue("DataMappingTable");
	
	TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix() + "_";
	TableForTS = New ValueTable;
	For Each Column In Table.Columns Do
		If StrStartsWith(Column.Name, TablePartPrefix) Then
			TableForTS.Columns.Add(Mid(Column.Name, StrLen(TablePartPrefix) + 1), Column.ValueType, Column.Title, Column.Width);
		ElsIf  Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Or Column.Name = "Id" Then 
			TableForTS.Columns.Add(Column.Name, Column.ValueType, Column.Title, Column.Width);
		EndIf;
	EndDo;
	
	For Each TableRow In Table Do
		NewRow = TableForTS.Add();
		For Each Column In TableForTS.Columns Do
			If Column.Name = "Id" Then 
				NewRow[Column.Name] = TableRow[Column.Name];
			ElsIf Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" Then
				NewRow[Column.Name] = TableRow[TablePartPrefix + Column.Name];
			EndIf;
		EndDo;
	EndDo;
	
	Return PutToTempStorage(TableForTS);
EndFunction

&AtServerNoContext
Function ObjectManager(MappingObjectName)
	
	ObjectArray = DataProcessors.ImportDataFromFile.SplitFullObjectName(MappingObjectName);
	If ObjectArray.ObjectType = "Document" Then
		ObjectManager = Documents[ObjectArray.NameOfObject];
	ElsIf ObjectArray.ObjectType = "Catalog" Then
		ObjectManager = Catalogs[ObjectArray.NameOfObject];
	ElsIf ObjectArray.ObjectType = "DataProcessor" Then
		ObjectManager = DataProcessors[ObjectArray.NameOfObject];
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Object ""%1"" is not found.';"), MappingObjectName);
	EndIf;
	
	Return ObjectManager;
	
EndFunction

&AtServerNoContext
Function ListForm(MappingObjectName)
	MetadataObject = Common.MetadataObjectByFullName(MappingObjectName);
	If MetadataObject.DefaultListForm <> Undefined Then
		Return MetadataObject.DefaultListForm.FullName();
	Else
		Return MetadataObject.FullName() + ".ListForm";
	EndIf;
EndFunction

&AtServer
Function TypeDetailsByMetadata(FullMetadataObjectName)
	Result = DataProcessors.ImportDataFromFile.SplitFullObjectName(FullMetadataObjectName);
	If Result.ObjectType = "Catalog" Then 
		Return New TypeDescription("CatalogRef." +  Result.NameOfObject);
	ElsIf Result.ObjectType = "Document" Then 
		Return New TypeDescription("DocumentRef." +  Result.NameOfObject);
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function NotFilledRequiredColumns()
	ColumnsNameWithoutData = New Array;
	
	Filter = New Structure("IsRequiredInfo", True);
	
	Header = TableTemplateHeaderArea(TemplateWithData);
	For ColumnNumber = 1 To Header.TableWidth Do 
		Cell = Header.GetArea(1, ColumnNumber, 1, ColumnNumber);
		ColumnName = TrimAll(Cell.CurrentArea.Text);
		
		ColumnInformation = Undefined;
		Filter = New Structure("ColumnPresentation", ColumnName);
		ColumnsFilter = ColumnsInformation.FindRows(Filter);
		
		If ColumnsFilter.Count() > 0 Then
			ColumnInformation = ColumnsFilter[0];
		Else
			Filter = New Structure("ColumnName", ColumnName);
			ColumnsFilter = ColumnsInformation.FindRows(Filter);
			
			If ColumnsFilter.Count() > 0 Then
				ColumnInformation = ColumnsFilter[0];
			EndIf;
		EndIf;
		If ColumnInformation <> Undefined Then
			If ColumnInformation.IsRequiredInfo Then
				For LineNumber = 2 To TemplateWithData.TableHeight Do
					Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
					If Not ValueIsFilled(Cell.CurrentArea.Text) Then
						ColumnsNameWithoutData.Add(ColumnInformation.ColumnPresentation);
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Return ColumnsNameWithoutData;
EndFunction

#Region ExternalImport

&AtServer
Procedure MapDataExternalDataProcessor(DataMappingTableServer )
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(ExternalDataProcessorRef);
		ExternalObject.MatchUploadedDataFromFile(CommandID, DataMappingTableServer);
		
		For Each TableRow In DataMappingTableServer Do
			If ValueIsFilled(TableRow.MappingObject) Then
				TableRow.RowMappingResult = ImportDataFromFileClientServer.StatusMapped();
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure WriteMappedDataExternalDataProcessor(MappedData) 
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(ExternalDataProcessorRef);
	EndIf;
	
	Cancel = False;
	
	ImportParameters= ImportDataFromFile.DataLoadingSettings();
	ImportParameters.CreateNewItems = CreateIfUnmapped;
	ImportParameters.UpdateExistingItems = UpdateExistingItems;
	
	ExternalObject.LoadFromFile(CommandID, MappedData, ImportParameters, Cancel); 
	
EndProcedure

#EndRegion

#Region LoadingFromFile

&AtServer
Procedure WriteMappedDataAppliedImport(MappedData)
	
	ObjectManager = ObjectManager(MappingObjectName);
	
	Cancel = False;
	
	ImportParameters= ImportDataFromFile.DataLoadingSettings();
	ImportParameters.CreateNewItems = CreateIfUnmapped;
	ImportParameters.UpdateExistingItems = UpdateExistingItems;
	
	ObjectManager.LoadFromFile(MappedData, ImportParameters, Cancel)
	
EndProcedure

#EndRegion

#Region ImportToTabularSection

&AtServer
Procedure CopyTabularSectionStructure(TabularSectionAddress)
	
	DataForTabularSection = TabularSectionDetails();
	
	If ValueIsFilled(MappingObjectName) Then
		TabularSection = Metadata.FindByFullName(MappingObjectName);
	
		For Each TabularSectionAttribute In TabularSection.Attributes Do
			DataForTabularSection.Columns.Add(TabularSectionAttribute.Name, TabularSectionAttribute.Type, TabularSectionAttribute.Presentation());
		EndDo;
	Else
		For Each Column In ColumnsInformation Do
			DataForTabularSection.Columns.Add(Column.ColumnName, Column.ColumnType, Column.ColumnPresentation);
		EndDo;
	EndIf;
	
	
	TabularSectionAddress = PutToTempStorage(DataForTabularSection);
	
EndProcedure

// Returns:
//   ValueTable:
//   * Id - Number
//
&AtServer
Function TabularSectionDetails() 
	
	DataForTabularSection = New ValueTable;
	DataForTabularSection.Columns.Add("Id", New TypeDescription("Number"), "Id");
	
	Return DataForTabularSection;
	
EndFunction

#EndRegion

&AtServer
Function TableTemplateHeaderArea(Template)
	MetadataTableHeaderArea = Template.Areas.Find("Header");
	
	If MetadataTableHeaderArea = Undefined Then 
		TableHeaderArea = Template.GetArea("R1");
	Else 
		TableHeaderArea = Template.GetArea("Header"); 
	EndIf;
	
	Return TableHeaderArea;
	
EndFunction

&AtServer
Procedure ShowInfoBarAboutRequiredColumns()
	
	If Items.FillWithDataPages.CurrentPage = Items.ImportFromFileOptionPage Then
		ToolTipText = NStr("en = 'Save the template to a file, open it in a spreadsheet editor, and enter the data.
		|Then import the spreadsheet to the application. The application supports the following formats:
		| • Microsoft Excel 97 Workbook (.xls) or Microsoft Excel 2007 Workbook (.xlsx)
		| • LibreOffice Calc Spreadsheet (.ods)
		| • Comma-separated values file (.csv)
		| • Spreadsheet document (.mxl)';") + Chars.LF;
	Else
		ToolTipText = NStr("en = 'To fill in the table, copy and paste data to the table from an external file.';") + Chars.LF;
	EndIf;
	
	Filter = New Structure("IsRequiredInfo", True);
	RequiredColumns2= ColumnsInformation.FindRows(Filter);
	
	If RequiredColumns2.Count() > 0 Then 
		ColumnsList = "";
		
		For Each Column In RequiredColumns2 Do 
			If ValueIsFilled(Column.Synonym) Then
				ColumnsList = ColumnsList + ", """ + Column.Synonym + """";
			Else
				ColumnsList = ColumnsList + ", """ + Column.ColumnPresentation + """";
			EndIf;
		EndDo;
		ColumnsList = Mid(ColumnsList, 3);
		
		If RequiredColumns2.Count() = 1 Then
			ToolTipText = ToolTipText + NStr("en = 'Required column:';") + " " + ColumnsList;
		Else
			ToolTipText = ToolTipText + NStr("en = 'Required columns:';") + " " + ColumnsList;
		EndIf;
		
	EndIf;
	
	Items.FillingHintLabel.Title = ToolTipText;
	Items.ImportFromFileOptionNote.Title = ToolTipText;
	
EndProcedure

&AtServer
Procedure AddStandardColumnsToMappingTable(TemporarySpecification, MappingObjectStructure, AddID,
		AddErrorDescription, AddRowMappingResult, AddConflictsList)
		
	If AddID Then 
		TemporarySpecification.Columns.Add("Id", New TypeDescription("Number"), NStr("en = '#';"));
	EndIf;
	
	If ValueIsFilled(MappingObjectStructure) Then 
		If Not ValueIsFilled(MappingObjectStructure.Synonym) Then
			ColumnTitle = "";
			If MappingObjectStructure.MappingObjectTypeDetails.Types().Count() > 1 Then 
				ColumnTitle = NStr("en = 'Objects';");
			Else
				ColumnTitle = String(MappingObjectStructure.MappingObjectTypeDetails.Types()[0]);
			EndIf;
			
		Else
			ColumnTitle = MappingObjectStructure.Synonym;
		EndIf;
		TemporarySpecification.Columns.Add("MappingObject", MappingObjectStructure.MappingObjectTypeDetails, ColumnTitle);
	EndIf;
	
	If AddRowMappingResult Then 
		TemporarySpecification.Columns.Add("RowMappingResult", New TypeDescription("String"), NStr("en = 'Status';"));
	EndIf;
	If AddErrorDescription Then
		TemporarySpecification.Columns.Add("ErrorDescription", New TypeDescription("String"), NStr("en = 'Reason';"));
	EndIf;

	If AddConflictsList Then 
		VLType = New TypeDescription("ValueList");
		TemporarySpecification.Columns.Add("ConflictsList", VLType, "ConflictsList");
	EndIf;
	
EndProcedure

&AtServer
Procedure AddStandardColumnsToAttributesArray(AttributesArray, MappingObjectTypeDetails , AddID, 
		AddErrorDescription, AddRowMappingResult, AddConflictsList)
		
		StringType = New TypeDescription("String");
		If AddID Then 
			NumberType = New TypeDescription("Number");
			AttributesArray.Add(New FormAttribute("Id", NumberType, "DataMappingTable", "Id"));
		EndIf;
		
		If ValueIsFilled(MappingObjectTypeDetails) Then 
			AttributesArray.Add(New FormAttribute("MappingObject", MappingObjectTypeDetails, "DataMappingTable", MappingObjectName));
		EndIf;
		
		If AddRowMappingResult Then
			AttributesArray.Add(New FormAttribute("RowMappingResult", StringType, "DataMappingTable", "Result"));
		EndIf;
		If AddErrorDescription Then 
			AttributesArray.Add(New FormAttribute("ErrorDescription", StringType, "DataMappingTable", "Cause"));
		EndIf;

	If AddConflictsList Then 
		VLType = New TypeDescription("ValueList");
		AttributesArray.Add(New FormAttribute("ConflictsList", VLType, "DataMappingTable", "ConflictsList"));
	EndIf;

EndProcedure

&AtServer
Procedure CreateMappingTableByColumnsInformationAuto(MappingObjectTypeDetails)
	
	AttributesArray = New Array;
	
	TemporarySpecification = FormAttributeToValue("DataMappingTable");
	TemporarySpecification.Columns.Clear();
	
	MappingObjectStructure = DescriptionOfTheMappingObject();
	MappingObjectStructure.MappingObjectTypeDetails = MappingObjectTypeDetails;
	
	AddStandardColumnsToMappingTable(TemporarySpecification, MappingObjectStructure, True, False, True, True);
	AddStandardColumnsToAttributesArray(AttributesArray, MappingObjectTypeDetails, True, False, True, True);
	
	For Each Column In ColumnsInformation Do
		TemporarySpecification.Columns.Add(Column.ColumnName, Column.ColumnType, Column.ColumnPresentation);
		AttributesArray.Add(New FormAttribute(Column.ColumnName, Column.ColumnType, "DataMappingTable", Column.ColumnPresentation));
	EndDo;
	
	ChangeAttributes(AttributesArray);
	
	ValueToFormAttribute(TemporarySpecification, "DataMappingTable");
	
	Picture = PictureLib.Change;
	For Each Column In TemporarySpecification.Columns Do
		NewItem = Items.Add(StringFunctionsClientServer.SubstituteParametersToString("%1_%2",
			ImportDataFromFileClientServer.MappingTablePrefix(), Column.Name),
			Type("FormField"), Items.DataMappingTable); // FormFieldExtensionForInputField
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable." + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ReadOnly = True;
		If NewItem.Type <> FormFieldType.LabelField Then
			IsRequiredInfo = ThisColumnRequired(Column.Name);
			NewItem.AutoMarkIncomplete  = IsRequiredInfo;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
			
		EndIf;
		If Column.Name = "MappingObject" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.BackColor = StyleColors.MasterFieldBackground;
			NewItem.HeaderPicture = Picture;
			NewItem.ReadOnly = False;
			
			NewItem.EditMode = ColumnEditMode.Directly;
			NewItem.CreateButton = False;
			NewItem.OpenButton = True;
			NewItem.ChoiceButton = True;
			NewItem.TextEdit = True;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		ElsIf Column.Name = "Id" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 4;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ConflictsList" Then
			NewItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

// Returns:
//  Structure:
//   * MappingObjectTypeDetails - String
//   * Synonym - String
//
&AtServerNoContext
Function DescriptionOfTheMappingObject()
	
	MappingObjectStructure = New Structure;
	MappingObjectStructure.Insert("MappingObjectTypeDetails", "");
	MappingObjectStructure.Insert("Synonym", "");
	
	Return MappingObjectStructure;
	
EndFunction

&AtServer
Procedure CreateMappingTableByColumnsInformation()
	
	AttributesArray = New Array;
	
	MetadataObject = Common.MetadataObjectByFullName(MappingObjectName);
	MappingObjectTypeDetails = TypeDetailsByMetadata(MappingObjectName);
	
	TemporarySpecification = FormAttributeToValue("DataMappingTable");
	TemporarySpecification.Columns.Clear();
	
	Synonym = ?(ValueIsFilled(ImportParameters.ObjectPresentation), 
		ImportParameters.ObjectPresentation, MetadataObject.Presentation());
	
	TemporarySpecification  = ImportDataFromFile.DescriptionOfTheUploadedDataForReferenceBooks(TemporarySpecification, MappingObjectTypeDetails, Synonym);
	AddStandardColumnsToAttributesArray(AttributesArray, MappingObjectTypeDetails, True, True, True, True);
	
	For Each Column In ColumnsInformation Do 
		If TemporarySpecification.Columns.Find(Column.ColumnName) = Undefined Then
			ColumnPresentation = Column.ColumnPresentation;
			TemporarySpecification.Columns.Add(Column.ColumnName, Column.ColumnType, ColumnPresentation);
			AttributesArray.Add(New FormAttribute(Column.ColumnName, Column.ColumnType, "DataMappingTable", ColumnPresentation));
		EndIf;
	EndDo;
	
	ChangeAttributes(AttributesArray);
	
	Picture = PictureLib.Change;
	For Each Column In TemporarySpecification.Columns Do
		NewItem = Items.Add(StringFunctionsClientServer.SubstituteParametersToString("%1_%2",
			ImportDataFromFileClientServer.MappingTablePrefix(), Column.Name),
			Type("FormField"), Items.DataMappingTable); // FormFieldExtensionForInputField
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable." + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ReadOnly = True;
		If NewItem.Type <> FormFieldType.LabelField Then 
			IsRequiredInfo = ThisColumnRequired(Column.Name);
			NewItem.AutoMarkIncomplete  = IsRequiredInfo;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		EndIf;
		If Column.Name = "MappingObject" Then 
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.BackColor = StyleColors.MasterFieldBackground;
			NewItem.HeaderPicture = Picture;
			NewItem.ReadOnly = False;
			NewItem.EditMode =  ColumnEditMode.Directly;
			NewItem.IncompleteChoiceMode = IncompleteChoiceMode.OnActivate;
		ElsIf Column.Name = "Id" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 4;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Or Column.Name = "ConflictsList" Then
			NewItem.Visible = False;
		EndIf;
		
		Filter = New Structure("ColumnName", Column.Name);
		Columns = ColumnsInformation.FindRows(Filter);
		If Columns.Count() > 0 Then 
			NewItem.Visible = Columns[0].Visible;
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(TemporarySpecification, "DataMappingTable");
EndProcedure

&AtServer
Procedure CreateMappingTableByColumnsInformationForTS() 
	
	AttributesArray = New Array;
	StringType = New TypeDescription("String");
	
	TemporarySpecification = FormAttributeToValue("DataMappingTable"); 
	TemporarySpecification.Columns.Clear();
	
	AddStandardColumnsToMappingTable(TemporarySpecification, Undefined, True, True, True, False);
	AddStandardColumnsToAttributesArray(AttributesArray, Undefined, True, True, True, False);
	
	RequiredColumns2 = New Array;
	ColumnsContainingChoiceParametersLinks = New Map;
	ObjectTSAttributes = Common.MetadataObjectByFullName(MappingObjectName); // MetadataObjectCatalog,  MetadataObjectDocument
	TSAttributes = ObjectTSAttributes.Attributes;
	TablePartPrefix = ImportDataFromFileClientServer.TablePartPrefix() + "_";
	
	For Each Column In TSAttributes Do
		
		If Column.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		If Column.FillChecking = FillChecking.ShowError Then
			RequiredColumns2.Add(TablePartPrefix + Column.Name);
		EndIf;
		
		If Column.ChoiceParameterLinks.Count() > 0 Then
			ColumnsContainingChoiceParametersLinks.Insert(Column.Name, Column.ChoiceParameterLinks);
		EndIf;
		
		AttributeType = ?(Column.Type.ContainsType(Type("UUID")), Common.StringTypeDetails(36), Column.Type);
		
		TemporarySpecification.Columns.Add(TablePartPrefix + Column.Name, AttributeType, Column.Presentation());
		AttributesArray.Add(New FormAttribute(TablePartPrefix + Column.Name, AttributeType, "DataMappingTable", Column.Presentation()));
		
	EndDo;
	
	For Each Column In ColumnsInformation Do
		TemporarySpecification.Columns.Add("PL_" + Column.ColumnName, StringType, Column.ColumnPresentation);
		AttributesArray.Add(New FormAttribute("PL_" + Column.ColumnName, StringType, "DataMappingTable", Column.ColumnPresentation));
	EndDo;
	
	ChangeAttributes(AttributesArray);
	AttributesCreated = True;
	
	DataToImportColumnsGroup = Items.Add("DataToImport", Type("FormGroup"), Items.DataMappingTable);
	DataToImportColumnsGroup.Group = ColumnsGroup.Horizontal;
	Picture = PictureLib.Change;
	
	For Each Column In TemporarySpecification.Columns Do
		
		If StrStartsWith(Column.Name, TablePartPrefix) Then
			TSDataToImportColumnsGroup = Items.Add("DataToImport_" + Column.Name , Type("FormGroup"), DataToImportColumnsGroup);
			TSDataToImportColumnsGroup.Group = ColumnsGroup.Vertical;
			Parent = TSDataToImportColumnsGroup;
		ElsIf StrStartsWith(Column.Name, "PL_") Then
			Continue;
		Else
			Parent = DataToImportColumnsGroup;
		EndIf;
		
		NewItem = Items.Add(StringFunctionsClientServer.SubstituteParametersToString("%1_%2",
			ImportDataFromFileClientServer.MappingTablePrefix(), Column.Name), Type("FormField"), Parent);
		
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable." + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		
		If StrLen(Column.Name) > 3 And StrStartsWith(Column.Name, TablePartPrefix) Then
			Filter = New Structure("ColumnName", Mid(Column.Name, 4));
			Columns = ColumnsInformation.FindRows(Filter);
			If Columns.Count() > 0 Then 
				NewItem.Visible = Columns[0].Visible;
			EndIf;
		EndIf;
		
		If Column.Name = "Id" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 1;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Then
			NewItem.Visible = False;
		EndIf;
		
		If RequiredColumns2.Find(Column.Name) <> Undefined Then 
			NewItem.AutoMarkIncomplete = True;
		EndIf;
		
		If StrStartsWith(Column.Name, TablePartPrefix) Then
			ColumnType = Metadata.FindByType(Column.ValueType.Types()[0]);
			If ColumnType <> Undefined And StrFind(ColumnType.FullName(), "Catalog") > 0 Then
				NewItem.HeaderPicture = Picture;
			EndIf;
			
			ColumnChoiceParametersLink = ColumnsContainingChoiceParametersLinks.Get(Mid(Column.Name, 4));
			If ColumnChoiceParametersLink <> Undefined Then 
				NewArray = New Array();
				For Each ChoiceParameterLink In ColumnChoiceParametersLink Do // ChoiceParameterLink
					Position = StrFind(ChoiceParameterLink.DataPath, ".", SearchDirection.FromEnd);
					If Position > 0 Then
						TagName = Mid(ChoiceParameterLink.DataPath, Position + 1);
						NewLink = New ChoiceParameterLink(ChoiceParameterLink.Name, "Items.DataMappingTable.CurrentData." 
							+ TablePartPrefix + TagName, ChoiceParameterLink.ValueChange);
						NewArray.Add(NewLink);
					EndIf;
				EndDo;
				NewLinks = New FixedArray(NewArray);
				NewItem.ChoiceParameterLinks = NewLinks;
			EndIf;
			
			Filter = New Structure("Parent", Mid(Column.Name, 4));
			GroupColumns = ColumnsInformation.FindRows(Filter);
			
			If GroupColumns.Count() = 1 Then
				
				ColumnLevel2 = TemporarySpecification.Columns.Find("PL_" + GroupColumns[0].ColumnName);
				If ColumnLevel2 <> Undefined Then 
					NewItem = Items.Add(ColumnLevel2.Name, Type("FormField"), Parent); // FormFieldExtensionForATextBox
					NewItem.Type = FormFieldType.InputField;
					NewItem.DataPath = "DataMappingTable." + ColumnLevel2.Name;
					ColumnType = Metadata.FindByType(ColumnLevel2.ValueType.Types()[0]);
					If ColumnType <> Undefined And StrFind(ColumnType.FullName(), "Catalog") > 0 Then
						NewItem.Title = NStr("en = 'File';");
					Else
						NewItem.Title = " ";
					EndIf;
					NewItem.ReadOnly = True;
					NewItem.TextColor = StyleColors.NoteText;
				EndIf;
				
			ElsIf GroupColumns.Count() > 1 Then
				TSDataToImportColumnsGroup = Items.Add("DataToImportIndividual" + Column.Name , Type("FormGroup"), Parent);
				TSDataToImportColumnsGroup.Group = ColumnsGroup.InCell;
				Parent = TSDataToImportColumnsGroup;
				
				Prefix = NStr("en = 'File:';");
				For Each GroupColumn In GroupColumns Do
					Column2 = TemporarySpecification.Columns.Find("PL_" + GroupColumn.ColumnName);
					If Column2 <> Undefined Then 
						NewItem = Items.Add(Column2.Name, Type("FormField"), Parent);  // FormFieldExtensionForATextBox
						NewItem.Type = FormFieldType.InputField;
						NewItem.DataPath = "DataMappingTable." + Column2.Name;
						NewItem.Title = Prefix + Column2.Title;
						NewItem.ReadOnly = True;
						NewItem.TextColor = StyleColors.NoteText;
						
						If StrLen(Column.Name) > 3 And StrStartsWith(Column.Name, "PL_") Then
						Filter = New Structure("ColumnName", Mid(Column.Name, 4));
						Columns = ColumnsInformation.FindRows(Filter);
							If Columns.Count() > 0 Then 
								NewItem.Visible = Columns[0].Visible;
							EndIf;
						EndIf;
						
					EndIf;
					Prefix = "";
				EndDo;
			Else
				NewItem.Visible = False;
			EndIf;
		EndIf;
	EndDo;
	
	ValueToFormAttribute(TemporarySpecification, "DataMappingTable");
EndProcedure

&AtServer
Function ThisColumnRequired(ColumnName)
	Filter = New Structure("ColumnName", ColumnName);
	Column =  ColumnsInformation.FindRows(Filter);
	If Column.Count()>0 Then 
		Return Column[0].IsRequiredInfo;
	EndIf;
	
	Return False;
EndFunction

&AtServer
Procedure ClearTemplateWithData()
	RowNumberWithTableHeader = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation), 2, 1);
	
	TitleArea = TemplateWithData.GetArea(1, 1, RowNumberWithTableHeader, TemplateWithData.TableWidth);
	TemplateWithData.Clear();
	TemplateWithData.Put(TitleArea);
EndProcedure

&AtServer
Function BatchAttributesModificationAtServer(UpperPosition, LowerPosition)
	ReferencesArrray = New Array;
	For Position = UpperPosition To LowerPosition Do 
		Cell = TableReport.GetArea(Position, 2, Position, 2);	
		If ValueIsFilled(Cell.CurrentArea.Details) Then 
			ReferencesArrray.Add(Cell.CurrentArea.Details);
		EndIf;
	EndDo;
	Return ReferencesArrray;
EndFunction

//File management //////////////////////

&AtClient
Procedure AfterFileChoiceForSaving(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		PathToFile = Result[0];
		SelectedFile = CommonClientServer.ParseFullFileName(PathToFile);
		FileExtention = CommonClientServer.ExtensionWithoutPoint(SelectedFile.Extension);
	
		If ValueIsFilled(SelectedFile.Name) Then
			If FileExtention = "csv" Then
				SaveTableToCSVFile(PathToFile);
			Else
				If FileExtention = "xlsx" Then
					FileType = SpreadsheetDocumentFileType.XLSX;
				ElsIf FileExtention = "mxl" Then
					FileType = SpreadsheetDocumentFileType.MXL;
				ElsIf FileExtention = "xls" Then
					FileType = SpreadsheetDocumentFileType.XLS;
				ElsIf FileExtention = "ods" Then
					FileType = SpreadsheetDocumentFileType.ODS;
				Else
					ShowMessageBox(, NStr("en = 'The file template is not saved.';"));
					Return;
				EndIf;
				Notification = New NotifyDescription("AfterSaveSpreadsheetDocumentToFile", ThisObject);
				TemplateWithData.BeginWriting(Notification, PathToFile, FileType);
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure AfterSaveSpreadsheetDocumentToFile(Result, AdditionalParameters) Export
	If Result = False Then
		ShowMessageBox(, NStr("en = 'The file template is not saved.';"));
	EndIf;
EndProcedure

&AtClient
Procedure ImportDataFromFileToTemplate(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		CommandBarButtonsAvailability(False);
		Items.WizardPages.CurrentPage = Items.TimeConsumingOperations;
		FileName                 = Result.Name;
		TempStorageAddress = Result.Location;
		Extension = CommonClientServer.ExtensionWithoutPoint(CommonClientServer.GetFileNameExtension(FileName));
	
		TimeConsumingOperation = ImportFileWithDataToSpreadsheetDocumentAtServer(TempStorageAddress, Extension);
		WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		WaitSettings.OutputIdleWindow = False;
		WaitSettings.ExecutionProgressNotification = New NotifyDescription("ExecutionProgress", ThisObject);
		Handler = New NotifyDescription("AfterImportDataFileToSpreadsheetDocument", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Handler, WaitSettings);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterFileExtensionChoice(Result, Parameter) Export
	If ValueIsFilled(Result) Then
		AddressInTempStorage = UUID;
		SaveTemplateToTempStorage(Result, AddressInTempStorage);
		FileSavingParameters = FileSystemClient.FileSavingParameters();
		FileSystemClient.SaveFile(Undefined, AddressInTempStorage,
			MappingObjectName + "." + Result, FileSavingParameters);
	EndIf;
EndProcedure

&AtServer
Procedure SaveTemplateToTempStorage(FileExtention, AddressInTempStorage)
	
	FileName = GetTempFileName(FileExtention);
	If FileExtention = "csv" Then 
		SaveTableToCSVFile(FileName);
	ElsIf FileExtention = "xlsx" Then
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.XLSX);
	ElsIf FileExtention = "xls" Then
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.XLS);
	ElsIf FileExtention = "ods" Then
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.ODS);
	Else 
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.MXL);
	EndIf;
	BinaryData = New BinaryData(FileName);
	
	AddressInTempStorage = PutToTempStorage(BinaryData, AddressInTempStorage);
	
	FileSystem.DeleteTempFile(FileName);
	
EndProcedure

&AtServerNoContext
Function GenerateFileNameForMetadataObject(MetadataObjectName)
	CatalogMetadata = Common.MetadataObjectByFullName(MetadataObjectName);
	
	If CatalogMetadata <> Undefined Then 
		FileName = TrimAll(CatalogMetadata.Synonym);
		If StrLen(FileName) = 0 Then 
			FileName = MetadataObjectName;	
		EndIf;
	Else
		FileName = MetadataObjectName;
	EndIf;
	
	FileName = StrReplace(FileName,":","");
	FileName = StrReplace(FileName,"*","");
	FileName = StrReplace(FileName,"\","");
	FileName = StrReplace(FileName,"/","");
	FileName = StrReplace(FileName,"&","");
	FileName = StrReplace(FileName,"<","");
	FileName = StrReplace(FileName,">","");
	FileName = StrReplace(FileName,"|","");
	FileName = StrReplace(FileName,"""","");
	
	Return FileName;
EndFunction 

&AtClient
Procedure AfterCancelMappingPrompt(Result, Parameter) Export
	
	If Result = DialogReturnCode.Yes Then
		For Each TableRow In DataMappingTable Do
			TableRow.MappingObject = Undefined;
			TableRow.RowMappingResult = ImportDataFromFileClientServer.StatusUnmapped();
			TableRow.ConflictsList = Undefined;
			TableRow.ErrorDescription = "";
		EndDo;
		ShowMappingStatisticsImportFromFile();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCallFormChangeTemplate(Result, Parameter) Export
	
	If Result <> Undefined Then
		If Result.Count() > 0 Then
			
			ColumnsInformation.Clear();
			For Each TableRow In Result Do
				NewRow = ColumnsInformation.Add();
				FillPropertyValues(NewRow, TableRow);
			EndDo;
			SaveSettings2 = True;
			
		Else
			ColumnsInformation.Clear();
			GenerateTemplateByImportType();
			SaveSettings2 = False;
		EndIf;
		ColumnsInformation.Sort("Position Asc");
		UpdateMappingTableColumnsDescriptions();
		ChangeTemplateByColumnsInformation(, SaveSettings2);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateMappingTableColumnsDescriptions()
	
	For Each TableRow In ColumnsInformation Do 
		Column = Items.DataMappingTable.ChildItems.Find(TableRow.ColumnName); // FormField
		If Column <> Undefined Then
			Column.Title = ?(Not IsBlankString(TableRow.Synonym), 
				TableRow.Synonym + " (" + TableRow.ColumnPresentation +")", 
				TableRow.ColumnPresentation);
		EndIf;
	EndDo;

EndProcedure

&AtServer
Procedure ChangeTemplateByColumnsInformation(Form = Undefined, ShouldSaveSettings = False)

	If Form = Undefined Then 
		Form = TemplateWithData;
	EndIf;
	
	ColumnsTable1 = FormAttributeToValue("ColumnsInformation");
	If ShouldSaveSettings Then
		Common.CommonSettingsStorageSave("ImportDataFromFile", MappingObjectName, ColumnsTable1,, UserName());
	EndIf;
	
	Form.Clear();
	Header = DataProcessors.ImportDataFromFile.HeaderOfTemplateForFillingColumnsInformation(ColumnsTable1);
	Form.Put(Header);
	ShowInfoBarAboutRequiredColumns();
	
EndProcedure

&AtClient
Procedure TemplateWithDataOnChange(Item)
	FormClosingConfirmation = False;
EndProcedure

#Region BackgroundJobs

// Background import of file with data

&AtServer
Function ImportFileWithDataToSpreadsheetDocumentAtServer(TempStorageAddress, Extension)
	
	SharedDirectoryOfTemporaryFiles = FileSystem.SharedDirectoryOfTemporaryFiles(); 
	
	TempFile = New File(GetTempFileName(Extension));
	TempFileName = FileSystem.UniqueFileName(SharedDirectoryOfTemporaryFiles + TempFile.Name);
	
	BinaryData = GetFromTempStorage(TempStorageAddress); // BinaryData
	BinaryData.Write(TempFileName);
	
	ClearTemplateWithData();
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("Extension", Extension);
	ProcedureParameters.Insert("TemplateWithData", TemplateWithData);
	ProcedureParameters.Insert("TempFileName", TempFileName);
	ProcedureParameters.Insert("ColumnsInformation", FormAttributeToValue("ColumnsInformation"));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 subsystem: import data from file using the server method';"), "ImportDataFromFile");
	ExecutionParameters.RefinementErrors =
		NStr("en = 'Could not import data due to:';");
	
	Return TimeConsumingOperations.ExecuteInBackground("DataProcessors.ImportDataFromFile.ImportFileToTable",
		ProcedureParameters, ExecutionParameters);
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterImportDataFileToSpreadsheetDocument(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		
		Items.WizardPages.CurrentPage = Items.FillTableWithData;
		CommandBarButtonsAvailability(True);
		Return;
	EndIf;
	
	TemplateWithData = GetFromTempStorage(Result.ResultAddress);
	MapDataToImport();
	
EndProcedure

// Background mapping of imported data

&AtServer
Function MapDataToImportAtServerUniversalImport()
	
	ImportDataFromFile.AddStatisticalInformation(?(ImportOption = 0,
		"ImportOption.FillTable", "ImportOption.FromExternalFile"));
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("TemplateWithData", TemplateWithData);
	ProcedureParameters.Insert("MappingTable", FormAttributeToValue("DataMappingTable"));
	ProcedureParameters.Insert("ColumnsInformation", FormAttributeToValue("ColumnsInformation"));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription =
		NStr("en = 'Populate mapping table with data imported from file.';");
	ExecutionParameters.RefinementErrors =
		NStr("en = 'Could not map data due to:';");
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.ImportDataFromFile.FillMappingTableWithDataFromTemplateBackground", 
		ProcedureParameters,
		ExecutionParameters);
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterMapImportedData(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	ExecuteDataToImportMappingStepAfterMapAtServer(Result.ResultAddress);
	ExecuteDataToImportMappingStepClient();
	
EndProcedure

// Background recording of imported data

&AtServer
Function RecordDataToImportReportUniversalImport()
	
	ImportParameters = New Structure();
	ImportParameters.Insert("CreateIfUnmapped", CreateIfUnmapped);
	ImportParameters.Insert("UpdateExistingItems", UpdateExistingItems);

	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("MappedData", FormAttributeToValue("DataMappingTable"));
	ProcedureParameters.Insert("ImportParameters", ImportParameters);
	ProcedureParameters.Insert("MappingObjectName", MappingObjectName);
	ProcedureParameters.Insert("ColumnsInformation", FormAttributeToValue("ColumnsInformation"));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Save data imported from file';");
	ExecutionParameters.RefinementErrors = NStr("en = 'Could not save data due to:';");
	
	Return TimeConsumingOperations.ExecuteInBackground("DataProcessors.ImportDataFromFile.WriteMappedData", 
		ProcedureParameters, ExecutionParameters);
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterSaveDataToImportReport(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	RefsToNotificationObjects = New Array;
	FillMappingTableFromTempStorage(Result.ResultAddress, RefsToNotificationObjects);
	NotifyFormsAboutChange(RefsToNotificationObjects);
	ReportAtClientBackgroundJob();
	
EndProcedure

&AtServer
Procedure FillMappingTableFromTempStorage(AddressInTempStorage, RefsToNotificationObjects)
	MappedData = GetFromTempStorage(AddressInTempStorage);
	ValueToFormAttribute(MappedData, "DataMappingTable");
	
	PrepareListForNotification(MappedData, RefsToNotificationObjects);
	
EndProcedure

// Background report generation.

&AtServer
Function GenerateReportOnImport(ReportType = "AllItems",  CalculateProgressPercent = False)
	
	MappedData        = FormAttributeToValue("DataMappingTable");
	TableColumnsInformation = FormAttributeToValue("ColumnsInformation");
	
	ProcedureParameters = New Structure();
	ProcedureParameters.Insert("TableReport", TableReport);
	ProcedureParameters.Insert("ReportType", ReportType);
	ProcedureParameters.Insert("MappedData", MappedData);
	ProcedureParameters.Insert("TemplateWithData", TemplateWithData);
	ProcedureParameters.Insert("MappingObjectName", MappingObjectName);
	ProcedureParameters.Insert("CalculateProgressPercent", CalculateProgressPercent);
	ProcedureParameters.Insert("ColumnsInformation", TableColumnsInformation);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Create report on data import from file';");
	
	Return TimeConsumingOperations.ExecuteInBackground("DataProcessors.ImportDataFromFile.GenerateReportOnBackgroundImport",
		ProcedureParameters, ExecutionParameters);
		
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterCreateReport(Result, AdditionalResults) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		GoToPage(Items.DataToImportMapping);
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	ShowReport(Result.ResultAddress);
	FormClosingConfirmation = True;
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.LongRunningOperationNewState
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ExecutionProgress(Result, AdditionalParameters) Export
	
	If Result.Status = "Running"
	   And Result.Progress <> Undefined Then
		
		BackgroundJobPercentage = Result.Progress.Percent;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
