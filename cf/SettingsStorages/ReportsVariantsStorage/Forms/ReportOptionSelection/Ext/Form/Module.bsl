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
	
	DefineBehaviorInMobileClient();
	
	VariantKey = Parameters.CurrentSettingsKey;
	CurrentUser = Users.AuthorizedUser();
	
	ReportInformation = ReportsOptions.ReportInformation(Parameters.ObjectKey);
	If Not IsBlankString(ReportInformation.ErrorText) Then
		Raise ReportInformation.ErrorText;
	EndIf;
	ReportInformation.Delete("ReportMetadata");
	ReportInformation.Delete("ErrorText");
	ReportInformation.Insert("ReportFullName", Parameters.ObjectKey);
	ReportInformation = New FixedStructure(ReportInformation);
	
	FullRightsToOptions = ReportsOptions.FullRightsToOptions();
	
	If Not FullRightsToOptions Then
		Items.ShowPersonalReportsOptionsByOtherAuthors.Visible = False;
		Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Visible = False;
		ShowPersonalReportsOptionsByOtherAuthors = False;
	EndIf;
	
	FillOptionsList();
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	Show = Settings.Get("ShowPersonalReportsOptionsByOtherAuthors");
	If Show <> ShowPersonalReportsOptionsByOtherAuthors Then
		ShowPersonalReportsOptionsByOtherAuthors = Show;
		Items.ShowPersonalReportsOptionsByOtherAuthors.Check = Show;
		Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Check = Show;
		FillOptionsList();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsOptionsClient.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Or EventName = "Write_ReportsOptions" Then
		FillOptionsList();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterAuthorOnChange(Item)
	FilterEnabled = ValueIsFilled(FilterAuthor);
	
	GroupsOrOptions = ReportOptionsTree.GetItems();
	For Each GroupOrOption In GroupsOrOptions Do
		HasEnabledItems = Undefined;
		NestedOptions = GroupOrOption.GetItems();
		For Each Variant In NestedOptions Do
			Variant.HiddenByFilter = FilterEnabled And Variant.Author <> FilterAuthor;
			If Not Variant.HiddenByFilter Then
				HasEnabledItems = True;
			ElsIf HasEnabledItems = Undefined Then
				HasEnabledItems = False;
			EndIf;
		EndDo;
		If HasEnabledItems = Undefined Then // Group is an option.
			GroupOrOption.HiddenByFilter = FilterEnabled And GroupOrOption.Author <> FilterAuthor;
		Else // This is a group.
			GroupOrOption.HiddenByFilter = HasEnabledItems;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReportOptionsTree

&AtClient
Procedure ReportOptionsTreeOnActivateRow(Item)
	Variant = Items.ReportOptionsTree.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.VariantKey) Then
		OptionDetails = "";
	Else
		OptionDetails = Variant.LongDesc;
	EndIf;
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenOptionForChange();
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	
	Variant = Items.ReportOptionsTree.CurrentData;
	If Variant = Undefined Or Not ValueIsFilled(Variant.VariantKey) Then
		Return;
	EndIf;
	
	If Variant.PictureIndex = 4 Then
		QueryText = NStr("en = 'Do you want to remove the deletion mark from ""%1""?';");
	Else
		QueryText = NStr("en = 'Do you want to mark ""%1"" for deletion?';");
	EndIf;
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, Variant.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Variant);
	Handler = New NotifyDescription("ReportOptionsTreeBeforeDeleteRowCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ReportOptionsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

&AtClient
Procedure ReportOptionsTreeValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ShowPersonalReportsOptionsByOtherAuthors(Command)
	ShowPersonalReportsOptionsByOtherAuthors = Not ShowPersonalReportsOptionsByOtherAuthors;
	Items.ShowPersonalReportsOptionsByOtherAuthors.Check = ShowPersonalReportsOptionsByOtherAuthors;
	Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Check = ShowPersonalReportsOptionsByOtherAuthors;
	
	FillOptionsList();
	
	For Each TreeGroup In ReportOptionsTree.GetItems() Do
		If TreeGroup.HiddenByFilter = False Then
			Items.ReportOptionsTree.Expand(TreeGroup.GetID(), True);
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillOptionsList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTree.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreeAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptionsTree.HiddenByFilter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreeAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptionsTree.CurrentUserIsAuthor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	MyReportsOptionsColor1 = Metadata.StyleItems.MyReportsOptionsColor;
	Item.Appearance.SetParameterValue("TextColor", MyReportsOptionsColor1.Value);

EndProcedure

&AtServer
Procedure DefineBehaviorInMobileClient()
	
	If Not Common.IsMobileClient() Then 
		Return;
	EndIf;
	
	Items.QuickFilters.Visible = False;
	Items.MainCommandBar.Visible = False;
	Items.OptionDetails.Visible = False;
	Items.ReportOptionsTreeAuthorPicture.Visible = False;
	Items.ReportOptionsTreeAuthor.Visible = False;
	
EndProcedure

&AtClient
Procedure SelectAndClose()
	Variant = Items.ReportOptionsTree.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.VariantKey) Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("VariantKey", Variant.VariantKey);
	If Variant.PictureIndex = 4 Then
		QueryText = NStr("en = 'Selected report option is marked for deletion.
		|Do you want to select this report option?';");
		Handler = New NotifyDescription("SelectAndCloseCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60);
	Else
		SelectAndCloseCompletion(DialogReturnCode.Yes, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectAndCloseCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Close(New SettingsChoice(AdditionalParameters.VariantKey));
	EndIf;
EndProcedure

&AtClient
Procedure OpenOptionForChange()
	Variant = Items.ReportOptionsTree.CurrentData;
	If Variant = Undefined Or Not ValueIsFilled(Variant.Ref) Then
		Return;
	EndIf;
	If Not OptionChangeRight(Variant, FullRightsToOptions) Then
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Insufficient rights to modify option ""%1"".';"), 
			Variant.Description);
		Raise(WarningText, ErrorCategory.AccessViolation);
	EndIf;
	ReportsOptionsClient.ShowReportSettings(Variant.Ref);
EndProcedure

// Question notification handler.
//
// Parameters:
//   Response - DialogReturnCode
//   AdditionalParameters - Structure:
//     * Variant - FormDataTreeItem:
//         ** Ref - CatalogRef.ReportsOptions
//         ** PictureIndex - Number
//
&AtClient
Procedure ReportOptionsTreeBeforeDeleteRowCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		DeleteOptionAtServer(AdditionalParameters.Variant.Ref, AdditionalParameters.Variant.PictureIndex);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function OptionChangeRight(Variant, FullRightsToOptions)
	Return FullRightsToOptions Or Variant.CurrentUserIsAuthor;
EndFunction

&AtServer
Procedure FillOptionsList()
	
	CurrentOptionKey = VariantKey;
	If ValueIsFilled(Items.ReportOptionsTree.CurrentRow) Then
		CurrentTreeRow = ReportOptionsTree.FindByID(Items.ReportOptionsTree.CurrentRow);
		If ValueIsFilled(CurrentTreeRow.VariantKey) Then
			CurrentOptionKey = CurrentTreeRow.VariantKey;
		EndIf;
	EndIf;
	
	FilterReports = New Array;
	FilterReports.Add(ReportInformation.Report);
	SearchParameters = New Structure("Reports,DeletionMark,OnlyPersonal", 
		FilterReports, False, Not ShowPersonalReportsOptionsByOtherAuthors);
	VariantsTable = ReportsOptions.ReportOptionTable(SearchParameters);
	
	// Populate autocalculated columns.
	VariantsTable.Columns.Add("CurrentUserIsAuthor", New TypeDescription("Boolean"));	
	VariantsTable.Columns.Add("PictureIndex", New TypeDescription("Number", New NumberQualifiers(1, 0, AllowedSign.Any)));	
	VariantsTable.Columns.Add("Order", New TypeDescription("Number", New NumberQualifiers(1, 0, AllowedSign.Any)));	
	For Each Variant In VariantsTable Do
		Variant.CurrentUserIsAuthor = (Variant.Author = CurrentUser);
		Variant.PictureIndex = ?(Variant.DeletionMark, 4, ?(Variant.Custom, 3, 5));
		Variant.Order = ?(Variant.DeletionMark, 3, 1);
	EndDo;

	If ReportInformation.ReportType = Enums.ReportsTypes.External 
		And Not SettingsStorages.ReportsVariantsStorage.AddExternalReportOptions(
			VariantsTable, ReportInformation.ReportFullName, ReportInformation.ReportShortName) Then
		Return;
	EndIf;
	
	VariantsTable.Sort("Order ASC, Description ASC");
	ReportOptionsTree.GetItems().Clear();
	TreeGroups = New Map;
	TreeGroups.Insert(1, ReportOptionsTree.GetItems());
	
	For Each OptionInfo In VariantsTable Do
		If Not ValueIsFilled(OptionInfo.VariantKey) Then
			Continue;
		EndIf;
		TreeRowsSet = TreeGroups.Get(OptionInfo.Order);
		If TreeRowsSet = Undefined Then
			TreeGroup = ReportOptionsTree.GetItems().Add();
			TreeGroup.NumberOfGroup = OptionInfo.Order;
			If OptionInfo.Order = 3 Then
				TreeGroup.Description = NStr("en = 'Marked for deletion';");
				TreeGroup.PictureIndex = 1;
				TreeGroup.AuthorPicture = -1;
			EndIf;
			TreeRowsSet = TreeGroup.GetItems();
			TreeGroups.Insert(OptionInfo.Order, TreeRowsSet);
		EndIf;
		
		Variant = TreeRowsSet.Add();
		FillPropertyValues(Variant, OptionInfo);
		Variant.NumberOfGroup = OptionInfo.Order;
		If Variant.VariantKey = CurrentOptionKey Then
			Items.ReportOptionsTree.CurrentRow = Variant.GetID();
		EndIf;
		Variant.AuthorPicture = ?(Variant.AuthorOnly, -1, 0);
		If OptionInfo.Purpose = Enums.ReportOptionPurposes.ForSmartphones Then
			Variant.PicturePurpose = 0;
		ElsIf OptionInfo.Purpose = Enums.ReportOptionPurposes.ForComputersAndTablets Then
			Variant.PicturePurpose = 1;
		ElsIf OptionInfo.Purpose = Enums.ReportOptionPurposes.ForAnyDevice Then
			Variant.PicturePurpose = 2;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure DeleteOptionAtServer(ReportOptionsRef, PictureIndex)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.ReportsOptions");
		LockItem.SetValue("Ref", ReportOptionsRef);
		Block.Lock();
		
		OptionObject = ReportOptionsRef.GetObject();
		DeletionMark = Not OptionObject.DeletionMark;
		Custom = OptionObject.Custom;
		OptionObject.SetDeletionMark(DeletionMark);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	PictureIndex = ?(DeletionMark, 4, ?(Custom, 3, 5));
	
EndProcedure

#EndRegion
