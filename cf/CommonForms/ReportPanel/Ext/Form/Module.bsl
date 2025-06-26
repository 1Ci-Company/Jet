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
Var Measurement;
#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationTruth = NStr("en = 'All report options';");
	PresentationLies = NStr("en = 'Computers and tablets';");
	Items.DisplayAllReportOptions.EditFormat = "BF='" + PresentationLies + "'; BT='"
		+ PresentationTruth + "'";
	DefineBehaviorInMobileClient();
	
	If Not ValueIsFilled(Parameters.SubsystemPath) Then
		Parameters.SubsystemPath = ReportsOptionsClientServer.HomePageID();
	EndIf;
	
	ClientParameters = ReportsOptions.ClientParameters();
	ClientParameters.Insert("SubsystemPath", Parameters.SubsystemPath);
	
	QuickAccessPicture = PictureLib.QuickAccess;
	
	StyleItems = Metadata.StyleItems;
	
	HiddenOptionsColor = StyleItems.HiddenReportOptionColor.Value;
	ColorOfHiddenOptionsByAssignment = StyleItems.LockedAttributeColor.Value;
	VisibleOptionsColor = StyleItems.HyperlinkColor.Value;
	SearchResultsHighlightColor = StyleItems.SearchResultsBackground.Value;
	TooltipColor = StyleItems.NoteText.Value;
	ReportOptionsGroupColor = StyleItems.ReportsOptionsGroupColor.Value;
	
	ImportantGroupFont = StyleItems.ImportantReportsOptionsGroupFont.Value;
	NormalGroupFont = StyleItems.RegularReportsOptionsGroupFont.Value;
	SectionFont = StyleItems.ReportsOptionsSectionFont.Value;
	FontImportantLabel = StyleItems.ImportantLabelFont.Value;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.Customize.Visible = False;
		Items.ResetMySettings.Visible = False;
	EndIf;
	
	GlobalSettings = ReportsOptions.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;
	
	MobileApplicationDetails = CommonClientServer.StructureProperty(GlobalSettings, "MobileApplicationDetails");
	If MobileApplicationDetails = Undefined Then
		Items.MobileApplicationDetails.Visible = False;
	Else
		ClientParameters.Insert("MobileApplicationDetails", MobileApplicationDetails);
	EndIf;
	
	SectionColor = ReportOptionsGroupColor;
	
	Items.QuickAccessHeaderLabel.Font = ImportantGroupFont;
	Items.QuickAccessHeaderLabel.TextColor = ReportOptionsGroupColor;
	
	AttributesSet = GetAttributes();
	For Each Attribute In AttributesSet Do
		ConstantAttributes.Add(Attribute.Name);
	EndDo;
	
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	// Reading a user setting common to all report panels.
	ImportAllSettings();
	
	If ValueIsFilled(Parameters.SearchString) Then
		SearchString = Parameters.SearchString;
	EndIf;
	SearchInAllSections = Parameters.SearchInAllSections;
	
	DefineSubsystemsAndTitle(Parameters);
	TimeConsumingOperation = UpdateReportPanelAtServer();

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If TimeConsumingOperation <> Undefined Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		End = New NotifyDescription("UpdateReportPanelCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, End, IdleParameters);
	EndIf;	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure UpdateReportPanelCompletion(Result, AdditionalParameters) Export
	
	TimeConsumingOperation = Undefined;
	If Result = Undefined Then
		Return;
	EndIf;
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	If Result.Status = "Completed2" Then
		FillReportPanel(Result.ResultAddress);
		If ClientParameters.RunMeasurements Then
			EndMeasurement(Measurement);
		EndIf;
	EndIf;
	
EndProcedure 

&AtClient
Procedure OnReopen()
	If SetupMode Or ValueIsFilled(SearchString) Then
		SetupMode = False;
		SearchString = "";
		UpdateReportPanelAtClient("OnReopen");
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Changes, Source)
	If Source = ThisObject Then
		Return;
	EndIf;
	If ClientParameters.Property("ShouldUpdate") Then
		DetachIdleHandler("UpdateReportPanelByTimer");
	Else
		ClientParameters.Insert("ShouldUpdate", False)
	EndIf;
	If EventName = ReportsOptionsClient.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Or EventName = "Write_ReportsOptions" Then
		ClientParameters.ShouldUpdate = True;
	ElsIf EventName = ReportsOptionsClient.EventNameChangingCommonSettings() Then
		If Changes.ShowTooltips <> ShowTooltips
			Or Changes.DisplayAllReportOptions <> DisplayAllReportOptions
			Or Changes.SearchInAllSections <> SearchInAllSections Then
			ClientParameters.ShouldUpdate = True;
		EndIf;
		FillPropertyValues(ThisObject, Changes, "ShowTooltips,SearchInAllSections,DisplayAllReportOptions");
	EndIf;
	If ClientParameters.ShouldUpdate Then
		AttachIdleHandler("UpdateReportPanelByTimer", 1, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Parameters:
//  Item - FormDecoration
//
&AtClient
Procedure Attachable_OptionClick(Item)
	Variant = FindOptionByItemName(Item.Name);
	If Variant = Undefined Then
		Return;
	EndIf;
	ReportFormParameters = New Structure;
	Subsystem = FindSubsystemByRef(ThisObject, Variant.Subsystem);
	If Subsystem.VisibleOptionsCount > 1 Then
		ReportFormParameters.Insert("Subsystem", Variant.Subsystem);
	EndIf;
	ReportsOptionsClient.OpenReportForm(ThisObject, Variant, ReportFormParameters);
EndProcedure

// Parameters:
//  Item - FormField
//
&AtClient
Procedure Attachable_OptionVisibilityOnChange(Item)
	CheckBox = Item;
	Show = ThisObject[CheckBox.Name];
	
	LabelName = Mid(CheckBox.Name, StrLen("CheckBox_")+1);
	Variant = FindOptionByItemName(LabelName);
	Item = Items.Find(LabelName);
	If Variant = Undefined Or Item = Undefined Then
		Return;
	EndIf;
	
	ShowHideOption(Variant, Item, Show);
EndProcedure

&AtClient
Procedure SearchStringTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	If Not IsBlankString(Text) And SearchStringIsTooShort(Text) Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Function SearchStringIsTooShort(Text)
	Text = TrimAll(Text);
	If StrLen(Text) < 2 Then
		ShowMessageBox(, NStr("en = 'Search text is too short.';"));
		Return True;
	EndIf;
	
	HasNormalWord = False;
	WordArray = ReportsOptionsClientServer.ParseSearchStringIntoWordArray(Text);
	For Each Word In WordArray Do
		If StrLen(Word) >= 2 Then
			HasNormalWord = True;
			Break;
		EndIf;
	EndDo;
	If Not HasNormalWord Then
		ShowMessageBox(, NStr("en = 'Search words are too short.';"));
		Return True;
	EndIf;
	
	Return False;
EndFunction

&AtClient
Procedure SearchStringOnChange(Item)
	If Not IsBlankString(SearchString) And SearchStringIsTooShort(SearchString) Then
		SearchString = "";
		CurrentItem = Items.SearchString;
		Return;
	EndIf;
	
	UpdateReportPanelAtClient("SearchStringOnChange");
	
	If ValueIsFilled(SearchString) Then
		CurrentItem = Items.SearchString;
	EndIf;
EndProcedure

// Parameters:
//  Item - FormDecoration
// 
&AtClient
Procedure Attachable_SectionTitleClick(Item)
	SectionGroupName = Item.Parent.Name;
	Substrings = StrSplit(SectionGroupName, "_");
	SectionPriority = Substrings[1];
	FoundItems = ApplicationSubsystems.FindRows(New Structure("Priority", SectionPriority));
	If FoundItems.Count() = 0 Then
		Return;
	EndIf;
	Section = FoundItems[0];
	
	SubsystemPath = StrReplace(Section.FullName, "Subsystem.", "");

	SubsystemPath = ?(IsBlankString(SubsystemPath), "NonIncludedToSections", SubsystemPath);
	
	ParametersForm = New Structure;
	ParametersForm.Insert("SubsystemPath",      SubsystemPath);
	ParametersForm.Insert("SearchString",         SearchString);
	ParametersForm.Insert("SearchInAllSections", True);
	
	OwnerForm     = ThisObject;
	FormUniqueness = True;
	
	If ClientParameters.RunMeasurements Then
		Comment = New Map;
		Comment.Insert("SubsystemPath", SubsystemPath);
		Measurement = StartMeasurement("ReportPanel.Opening", Comment);
	EndIf;
	
	OpenForm("CommonForm.ReportPanel", ParametersForm, OwnerForm, FormUniqueness);
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Measurement);
	EndIf;
EndProcedure

&AtClient
Procedure ShowTooltipsOnChange(Item)
	UpdateReportPanelAtClient("ShowTooltipsOnChange");
	
	CommonSettings = New Structure;
	CommonSettings.Insert("ShowTooltips", ShowTooltips);
	CommonSettings.Insert("SearchInAllSections", SearchInAllSections);
	CommonSettings.Insert("DisplayAllReportOptions", DisplayAllReportOptions);
	Notify(ReportsOptionsClient.EventNameChangingCommonSettings(), CommonSettings, ThisObject);
EndProcedure

&AtClient
Procedure DisplayAllReportOptionsOnChange(Item)
	UpdateReportPanelAtClient("DisplayAllReportOptionsOnChange");
	
	CommonSettings = New Structure;
	CommonSettings.Insert("ShowTooltips", ShowTooltips);
	CommonSettings.Insert("SearchInAllSections", SearchInAllSections);
	CommonSettings.Insert("DisplayAllReportOptions", DisplayAllReportOptions);
	Notify(ReportsOptionsClient.EventNameChangingCommonSettings(), CommonSettings, ThisObject);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Customize(Command)
	SetupMode = Not SetupMode;
	UpdateReportPanelAtClient(?(SetupMode, "EnableSetupMode", "DisableSetupMode"));
EndProcedure

&AtClient
Procedure MoveToQuickAccess(Command)
	
#If WebClient Then
	Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
#Else
	Item = CurrentItem;
#EndIf

	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Variant = FindOptionByItemName(Item.Name);
	If Variant = Undefined Then
		Return;
	EndIf;
	
	AddRemoveOptionFromQuickAccess(Variant, Item, True);
EndProcedure

&AtClient
Procedure RemoveFromQuickAccess(Command)
	
#If WebClient Then
	Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
#Else
	Item = CurrentItem;
#EndIf

	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Variant = FindOptionByItemName(Item.Name);
	If Variant = Undefined Then
		Return;
	EndIf;
	
	AddRemoveOptionFromQuickAccess(Variant, Item, False);
EndProcedure

&AtClient
Procedure Change(Command)
	
#If WebClient Then
	Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
#Else
	Item = CurrentItem;
#EndIf

	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Variant = FindOptionByItemName(Item.Name);
	If Variant = Undefined Then
		Return;
	EndIf;
	
	ReportsOptionsClient.ShowReportSettings(Variant.Ref);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	QueryText = NStr("en = 'Do you want to reset report assignment settings?';");
	Handler = New NotifyDescription("ResetSettingsCompletion", ThisObject);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure AllReports(Command)
	ParametersForm = New Structure;
	If ValueIsFilled(SearchString) Then
		ParametersForm.Insert("SearchString", SearchString);
	EndIf;
	If ValueIsFilled(SearchString) And Not SetupMode And SearchInAllSections = 1 Then
		// Set the position to the tree root.
		SectionReference = PredefinedValue("Catalog.MetadataObjectIDs.EmptyRef");
	Else
		SectionReference = CurrentSectionRef;
	EndIf;
	ParametersForm.Insert("SectionReference", SectionReference);
	
	If ClientParameters.RunMeasurements Then
		Measurement = StartMeasurement("ReportsList.Opening");
	EndIf;
	
	OpenForm("Catalog.ReportsOptions.ListForm", ParametersForm, , "ReportsOptions.AllReports");
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Measurement);
	EndIf;
EndProcedure

&AtClient
Procedure Refresh(Command)
	UpdateReportPanelAtClient("Refresh");
EndProcedure

&AtClient
Procedure ExecuteSearch(Command)
	UpdateReportPanelAtClient("ExecuteSearch");
EndProcedure

&AtClient
Procedure ReportsSnapshots(Command)
	
	OpenForm("InformationRegister.ReportsSnapshots.ListForm",
				New Structure("User",
							UsersClient.CurrentUser()));
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure ShowHideOption(Variant, Item, Show)
	Variant.Visible = Show;
	Item.TextColor = ?(Show, ?(Variant.VisibilityByAssignment, VisibleOptionsColor,
		ColorOfHiddenOptionsByAssignment), HiddenOptionsColor);
	ThisObject["CheckBox_"+ Variant.LabelName] = Show;
	If Variant.Important Then
		If Show Then
			Item.Font = FontImportantLabel;
		Else
			Item.Font = New Font;
		EndIf;
	EndIf;
	Subsystem = FindSubsystemByRef(ThisObject, Variant.Subsystem);
	Subsystem.VisibleOptionsCount = Subsystem.VisibleOptionsCount + ?(Show, 1, -1);
	While Subsystem.Ref <> Subsystem.SectionReference Do
		Subsystem = FindSubsystemByRef(ThisObject, Subsystem.SectionReference);
		Subsystem.VisibleOptionsCount = Subsystem.VisibleOptionsCount + ?(Show, 1, -1);
	EndDo;
	SaveUserSettingsSSL(Variant.Ref, Variant.Subsystem, Variant.Visible, Variant.QuickAccess);
	Notify("ChangeReportOptionVisibilityInReportPanel", "Report." + Variant.ReportName);
EndProcedure

&AtClient
Procedure AddRemoveOptionFromQuickAccess(Variant, Item, QuickAccess)
	If Variant.QuickAccess = QuickAccess Then
		Return;
	EndIf;
	
	// Register the result for writing.
	Variant.QuickAccess = QuickAccess;
	
	// Related action: If the option to be added to the quick access list is hidden, show this option.
	If QuickAccess And Not Variant.Visible Then
		ShowHideOption(Variant, Item, True);
	EndIf;
	
	// Visual result.
	MoveQuickAccessOption(Variant.GetID(), QuickAccess);
EndProcedure

&AtClient
Procedure ResetSettingsCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		SetupMode = False;
		UpdateReportPanelAtClient("ResetSettings");
	EndIf;
EndProcedure

&AtClient
Procedure UpdateReportPanelByTimer()
	If ClientParameters.ShouldUpdate Then
		ClientParameters.ShouldUpdate = False;
		UpdateReportPanelAtClient("");
	EndIf;
EndProcedure

&AtClient
Function UpdateReportPanelAtClient(Event = "")
	If ClientParameters.RunMeasurements Then
		Measurement = StartMeasurement(Event);
	EndIf;
	
	Items.Pages.CurrentPage = Items.Waiting;
	If TimeConsumingOperation <> Undefined And TimeConsumingOperation.Status = "Running" Then
		Return False;	
	EndIf;
	
	TimeConsumingOperation = UpdateReportPanelAtServer(Event);
	If TimeConsumingOperation <> Undefined Then
		End = New NotifyDescription("UpdateReportPanelCompletion", ThisObject);
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, End);
		Return True;
	EndIf;
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Measurement);
	EndIf;
	
	Return TimeConsumingOperation <> Undefined;

EndFunction

&AtClient
Function StartMeasurement(Event, Comment = Undefined)
	If Comment = Undefined Then
		Comment = New Map;
	EndIf;
	
	Measurement = New Structure("Name, Id, ModulePerformanceMonitorClient");
	If Event = "ReportsList.Opening" Or Event = "ReportPanel.Opening" Then
		Measurement.Name = Event;
		Comment.Insert("FromReportPanel", ClientParameters.SubsystemPath);
	Else
		If SetupMode Or Event = "DisableSetupMode" Then
			Measurement.Name = "ReportPanel.SetupMode";
		ElsIf ValueIsFilled(SearchString) Then
			Measurement.Name = "ReportPanel.Search"; // 
		EndIf;
		Comment.Insert("SubsystemPath", ClientParameters.SubsystemPath);
		Comment.Insert("ShowTooltips", ShowTooltips);
	EndIf;
	
	If Measurement.Name = Undefined Then
		Return Undefined;
	EndIf;
	
	If ValueIsFilled(SearchString) Then
		Comment.Insert("Search", True);
		Comment.Insert("SearchString", String(SearchString));
		Comment.Insert("SearchInAllSections", SearchInAllSections);
	Else
		Comment.Insert("Search", False);
	EndIf;
	
	If Event = "DisableSetupMode" Then
		Comment.Insert("DisableSetupMode", True);
	EndIf;
	Measurement.ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
	Measurement.Id = Measurement.ModulePerformanceMonitorClient.TimeMeasurement(Measurement.Name);
	Measurement.ModulePerformanceMonitorClient.SetMeasurementComment(Measurement.Id, Comment);
	Return Measurement;
EndFunction

&AtClient
Procedure EndMeasurement(Measurement)
	If Measurement <> Undefined Then
		Measurement.ModulePerformanceMonitorClient.StopTimeMeasurement(Measurement.Id);
	EndIf;
EndProcedure

&AtClient
Function FindOptionByItemName(LabelName)
	Id = ReportOptionByItemName[LabelName];
	If Id <> Undefined Then
		Return AddedOptions.FindByID(Id);
	Else
		FoundItems = AddedOptions.FindRows(New Structure("LabelName", LabelName));
		If FoundItems.Count() = 1 Then
			Return FoundItems[0];
		EndIf;
	EndIf;
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtClientAtServerNoContext
Function FindSubsystemByRef(Form, Ref)
	Id = Form.SubsystemByReference[Ref];
	If Id <> Undefined Then
		Return Form.ApplicationSubsystems.FindByID(Id);
	EndIf;
	
	FoundItems = Form.ApplicationSubsystems.FindRows(New Structure("Ref", Ref));
	If FoundItems.Count() = 1 Then
		Return FoundItems[0];
	EndIf;
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Procedure MoveQuickAccessOption(Val OptionID, Val QuickAccess)
	Variant = AddedOptions.FindByID(OptionID);
	Item = Items.Find(Variant.LabelName);
	
	If QuickAccess Then
		Item.Font = New Font;
		GroupToTransfer = SubgroupWithMinimalItemsCount(Items.QuickAccess);
	ElsIf Variant.SeeAlso Then
		Item.Font = New Font;
		GroupToTransfer = SubgroupWithMinimalItemsCount(Items.SeeAlso);
	ElsIf Variant.NoGroup Then
		Item.Font = ?(Variant.Important, FontImportantLabel, New Font);
		GroupToTransfer = SubgroupWithMinimalItemsCount(Items.NoGroup);
	Else
		Item.Font = ?(Variant.Important, FontImportantLabel, New Font);
		Subsystem = FindSubsystemByRef(ThisObject, Variant.Subsystem);
		
		GroupToTransfer = Items.Find(Subsystem.TagName + "_1");
		If GroupToTransfer = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	BeforeWhichItem = Undefined;
	If GroupToTransfer.ChildItems.Count() > 0 Then
		BeforeWhichItem = GroupToTransfer.ChildItems.Get(0);
	EndIf;
	
	Items.Move(Item.Parent, GroupToTransfer, BeforeWhichItem);
	
	If QuickAccess Then
		Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
	Else
		QuickAccessOptions = AddedOptions.FindRows(New Structure("QuickAccess", True));
		If QuickAccessOptions.Count() = 0 Then
			Items.QuickAccessTooltipWhenNotConfigured.Visible = True;
		Else
			Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
		EndIf;
	EndIf;
	
	CheckBoxName1 = "CheckBox_" + Variant.LabelName;
	CheckBox = Items.Find(CheckBoxName1);
	CheckBoxIsDisplayed = (CheckBox.Visible = True);
	If CheckBoxIsDisplayed = QuickAccess Then
		CheckBox.Visible = Not QuickAccess;
	EndIf;
	
	LabelContextMenu = Item.ContextMenu;
	If LabelContextMenu <> Undefined Then
		ButtonRemove = Items.Find("RemoveFromQuickAccess_" + Variant.LabelName);
		ButtonRemove.Visible = QuickAccess;
		ButtonMove = Items.Find("MoveToQuickAccess_" + Variant.LabelName);
		ButtonMove.Visible = Not QuickAccess;
	EndIf;
	
	SaveUserSettingsSSL(Variant.Ref, Variant.Subsystem, Variant.Visible, Variant.QuickAccess);
EndProcedure

&AtServer
Function UpdateReportPanelAtServer(Val Event = "")
	
	If Event = "ResetSettings" Then
		InformationRegisters.ReportOptionsSettings.ResetUsesrSettingsInSection(CurrentSectionRef);
	EndIf;
	
	If Event = "" Or Event = "SearchStringOnChange" Or Event = "ResetSettings" Then
		If ValueIsFilled(SearchString) Then
			ChoiceList = Items.SearchString.ChoiceList;
			ListItem = ChoiceList.FindByValue(SearchString);
			If ListItem = Undefined Then
				ChoiceList.Insert(0, SearchString);
				If ChoiceList.Count() > 10 Then
					ChoiceList.Delete(10);
				EndIf;
			Else
				IndexOf = ChoiceList.IndexOf(ListItem);
				If IndexOf <> 0 Then
					ChoiceList.Move(IndexOf, -IndexOf);
				EndIf;
			EndIf;
			If Event = "SearchStringOnChange" Then
				SaveSettingsOfThisReportPanel();
			EndIf;
		EndIf;
	ElsIf Event = "ShowTooltipsOnChange"
		Or Event = "DisplayAllReportOptionsOnChange"
		Or Event = "SearchInAllSectionsOnChange" Then
		
		CommonSettings = New Structure;
		CommonSettings.Insert("ShowTooltips", ShowTooltips);
		CommonSettings.Insert("SearchInAllSections", SearchInAllSections);
		CommonSettings.Insert("DisplayAllReportOptions", DisplayAllReportOptions);
		ReportsOptions.SaveCommonPanelSettings(CommonSettings);
	EndIf;
	
	Items.ShowTooltips.Visible = SetupMode;
	Items.DisplayAllReportOptions.Visible = SetupMode;
	Items.QuickAccessHeaderLabel.ToolTipRepresentation = ?(SetupMode, ToolTipRepresentation.Button, ToolTipRepresentation.None);
	Items.OtherSectionsSearchResultsGroup.Visible = (SearchInAllSections = 1);
	Items.Customize.Check = SetupMode;
	Items.GroupReportsSnapshots.Visible = AccessRight("Edit", Metadata.InformationRegisters.ReportsSnapshots);
	
	// Title.
	SetupModeSuffix = " (" + NStr("en = 'setting';") + ")";
	SuffixIsDisplayed = (Right(Title, StrLen(SetupModeSuffix)) = SetupModeSuffix);
	If SuffixIsDisplayed <> SetupMode Then
		If SetupMode Then
			Title = Title + SetupModeSuffix;
		Else
			Title = StrReplace(Title, SetupModeSuffix, "");
		EndIf;
	EndIf;
	
	// Remove elements.
	ClearFormFromAddedItems();
	
	// Remove commands.
	If Common.IsWebClient() Then
		CommandsToRemove = New Array;
		For Each Command In Commands Do
			If ConstantCommands.FindByValue(Command.Name) = Undefined Then
				CommandsToRemove.Add(Command);
			EndIf;
		EndDo;
		For Each Command In CommandsToRemove Do
			Commands.Delete(Command);
		EndDo;
	EndIf;
	
	// Reset the number of the last added item.
	For Each TableRow In ApplicationSubsystems Do
		TableRow.ItemNumber = 0;
		TableRow.VisibleOptionsCount = 0;
	EndDo;
	
	Return FillReportPanelInBackground();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure DefineBehaviorInMobileClient()
	If Not Common.IsMobileClient() Then 
		Return;
	EndIf;
	
	Items.SearchString.TitleLocation = FormItemTitleLocation.None;
	Items.SearchString.DropListButton = False;
	Items.ExecuteSearch.Representation = ButtonRepresentation.Picture;
	Items.Move(Items.ShowTooltips, Items.TopBarMobileClient);
	Items.CommandBarRightGroup.Visible = False;
	Items.MobileApplicationDetails.Visible = False;
	
	SearchSubstring = NStr("en = 'right-click the report and';");
	ReplaceSubstring = NStr("en = 'in the context menu';");
	
	Items.QuickAccessTooltipWhenNotConfigured.Title =
		StrReplace(Items.QuickAccessTooltipWhenNotConfigured.Title, SearchSubstring, ReplaceSubstring);
	
	Items.QuickAccessHeaderLabel.ExtendedTooltip.Title =
		StrReplace(Items.QuickAccessHeaderLabel.ExtendedTooltip.Title, SearchSubstring, ReplaceSubstring);
	
	Items.Move(Items.DisplayAllReportOptions, Items.TopBarMobileClient,
		Items.ShowTooltips);
	Items.DisplayAllReportOptions.Title = NStr("en = 'Show reports for computers and tablets';");
	Items.DisplayAllReportOptions.TitleLocation = FormItemTitleLocation.Right;
	
EndProcedure

&AtServer
Procedure ClearFormFromAddedItems()
	ItemsToRemove = New Array;
	For Each Level3Item In Items.QuickAccess.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.NoGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.WithGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.SeeAlso.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level4Item In Items.OtherSectionsSearchResults.ChildItems Do
		ItemsToRemove.Add(Level4Item);
	EndDo;
	For Each ItemToRemove In ItemsToRemove Do
		Items.Delete(ItemToRemove);
	EndDo;
EndProcedure

&AtServerNoContext
Procedure SaveUserSettingsSSL(Variant, Subsystem, Visible, QuickAccess)
	SettingsPackage = New ValueTable;
	SettingsPackage.Add();
	Dimensions = New Structure;
	Dimensions.Insert("User", Users.AuthorizedUser());
	Dimensions.Insert("Variant", Variant);
	Dimensions.Insert("Subsystem", Subsystem);
	Resources = New Structure;
	Resources.Insert("Visible", Visible);
	Resources.Insert("QuickAccess", QuickAccess);
	InformationRegisters.ReportOptionsSettings.WriteSettingsPackage(SettingsPackage, Dimensions, Resources, True);
EndProcedure

&AtServer
Function SubgroupWithMinimalItemsCount(Var_Group)
	SubgroupMin = Undefined;
	NestedItemsMin = 0;
	For Each Subgroup In Var_Group.ChildItems Do
		NestedItems1 = Subgroup.ChildItems.Count();
		If NestedItems1 < NestedItemsMin Or SubgroupMin = Undefined Then
			SubgroupMin          = Subgroup;
			NestedItemsMin = NestedItems1;
		EndIf;
	EndDo;
	Return SubgroupMin;
EndFunction

&AtServer
Procedure DefineSubsystemsAndTitle(Var_Parameters)
	
	TitleIsSet = Not IsBlankString(Var_Parameters.Title);
	PanelTitle = ?(TitleIsSet, Var_Parameters.Title, NStr("en = 'Reports';"));
	
	If Var_Parameters.SubsystemPath = ReportsOptionsClientServer.HomePageID() Then
		CurrentSectionFullName = Var_Parameters.SubsystemPath;
	Else
		CurrentSectionFullName = "Subsystem." + StrReplace(Var_Parameters.SubsystemPath, ".", ".Subsystem.");
	EndIf;
	
	ApplicationSubsystems.Clear();
	AllSubsystems = ReportsOptionsCached.CurrentUserSubsystems().Tree;
	AllSections = AllSubsystems.Rows[0].Rows;
	SubsystemsByRef = New Map;
	For Each RowSection In AllSections Do
		TableRow = ApplicationSubsystems.Add();
		FillPropertyValues(TableRow, RowSection);
		TableRow.TagName    = StrReplace(RowSection.FullName, ".", "_");
		TableRow.ItemNumber  = 0;
		TableRow.SectionReference   = RowSection.Ref;
		
		SubsystemsByRef[TableRow.Ref] = TableRow.GetID();
		
		If RowSection.FullName = CurrentSectionFullName Then
			CurrentSectionRef = RowSection.Ref;
			If TitleIsSet Then
				RowSection.FullPresentation = Var_Parameters.Title;
			Else
				PanelTitle = RowSection.FullPresentation;
			EndIf;
		EndIf;
		
		FoundItems = RowSection.Rows.FindRows(New Structure("SectionReference", RowSection.Ref), True);
		For Each TreeRow In FoundItems Do
			TableRow = ApplicationSubsystems.Add();
			FillPropertyValues(TableRow, TreeRow);
			TableRow.TagName    = StrReplace(TableRow.FullName, ".", "_");
			TableRow.ItemNumber  = 0;
			TableRow.ParentReference = TreeRow.Parent.Ref;
			TableRow.SectionReference   = RowSection.Ref;
			
			SubsystemsByRef[TableRow.Ref] = TableRow.GetID();
			If TreeRow.FullName = CurrentSectionFullName Then
				CurrentSectionRef = TreeRow.Ref;
				If TitleIsSet Then
					TreeRow.FullPresentation = Var_Parameters.Title;
				Else
					PanelTitle = TreeRow.FullPresentation;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	TableRow = ApplicationSubsystems.Add();
	TableRow.TagName    = "NonIncludedToSections";
	TableRow.Name            = "NonIncludedToSections";
	TableRow.Presentation  = NStr("en = 'Not included in sections';");
	TableRow.ItemNumber  = 0;
	TableRow.SectionReference   = Catalogs.MetadataObjectIDs.EmptyRef();
	TableRow.ParentReference = Catalogs.MetadataObjectIDs.EmptyRef();
	TableRow.Ref   = Catalogs.MetadataObjectIDs.EmptyRef(); 
	TableRow.Priority = "999";
	SubsystemsByRef.Insert(Catalogs.MetadataObjectIDs.EmptyRef(), TableRow.GetID());
	
	If Var_Parameters.SubsystemPath = "NonIncludedToSections" Then
		CurrentSectionRef = Catalogs.MetadataObjectIDs.EmptyRef();
		PanelTitle = NStr("en = 'Reports not included in sections';");
	EndIf;
	
	If CurrentSectionRef = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Non-existent section ""%1"" specified in report panel. See %2.';"),
			Var_Parameters.SubsystemPath, "ReportsOptionsOverridable.DefineSectionsWithReportOptions");
	EndIf;
	
	PurposeUseKey = "Section_" + String(CurrentSectionRef.UUID());
	Title = PanelTitle;
	SubsystemByReference = New FixedMap(SubsystemsByRef);
	
EndProcedure

&AtServer
Procedure ImportAllSettings()
	CommonSettings = ReportsOptions.CommonPanelSettings();
	FillPropertyValues(ThisObject, CommonSettings, "ShowTooltips,SearchInAllSections,DisplayAllReportOptions");
	
	LocalSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		PurposeUseKey);
	If LocalSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(LocalSettings.SearchStringSelectionList);
	EndIf;
EndProcedure

&AtServer
Procedure SaveSettingsOfThisReportPanel()
	LocalSettings = New Structure;
	LocalSettings.Insert("SearchStringSelectionList", Items.SearchString.ChoiceList.UnloadValues());
	
	Common.CommonSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		PurposeUseKey,
		LocalSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server / filling in a report panel.

&AtServer
Function FillReportPanelInBackground()
	
	ClearInformationAboutChangesInUserSettings();
	
	SearchParameters = New Structure;
	SearchParameters.Insert("SetupMode", SetupMode);
	SearchParameters.Insert("SearchString", SearchString);
	SearchParameters.Insert("SearchInAllSections", SearchInAllSections);
	SearchParameters.Insert("CurrentSectionRef", CurrentSectionRef);
	
	ReportOptionPurposes = New Array;
	ReportOptionPurposes.Add(Enums.ReportOptionPurposes.ForAnyDevice);
	ReportOptionPurposes.Add(?(Common.IsMobileClient(),
									Enums.ReportOptionPurposes.ForSmartphones,
									Enums.ReportOptionPurposes.ForComputersAndTablets));
	SearchParameters.Insert("ReportOptionPurposes", ReportOptionPurposes);
	SearchParameters.Insert("DisplayAllReportOptions", DisplayAllReportOptions);
	
	CurrentSectionOnly = SetupMode Or Not ValueIsFilled(SearchString) Or SearchInAllSections = 0;
	If CurrentSectionOnly Then
		SubsystemsTable = ApplicationSubsystems.Unload(New Structure("SectionReference", CurrentSectionRef));
	Else
		SubsystemsTable = ApplicationSubsystems.Unload();
	EndIf;
	SearchParameters.Insert("ApplicationSubsystems", SubsystemsTable);
	
	If ReportsOptions.PresentationsFilled() = "Filled1" Then
		ResultAddress = PutToTempStorage(Undefined, UUID);
		ReportsOptions.FindReportOptionsForOutput(SearchParameters, ResultAddress);
	Else
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		Result = TimeConsumingOperations.ExecuteInBackground("ReportsOptions.FindReportOptionsForOutput", SearchParameters, ExecutionParameters);
		If Result.Status <> "Completed2" Then
			Return Result;
		EndIf;
		ResultAddress = Result.ResultAddress;
	EndIf;
	
	FillReportPanel(ResultAddress);
	Return Undefined;
	
EndFunction

&AtServer
Procedure ClearInformationAboutChangesInUserSettings()
	AddedOptions.Clear();
EndProcedure

&AtServer
Procedure FillReportPanel(ResultAddress)
	
	FillParameters = GetFromTempStorage(ResultAddress); // See ReportsOptions.ReportOptionsToShow
	DeleteFromTempStorage(ResultAddress);
	
	InitializeFillingParameters(FillParameters);
	If SetupMode Then
		FillParameters.ContextMenu.RemoveFromQuickAccess.Visible = True;
		FillParameters.ContextMenu.MoveToQuickAccess.Visible = False;
	EndIf;
	
	OutputSectionOptions(FillParameters, CurrentSectionRef);
	
	If FillParameters.CurrentSectionOnly Then
		Items.OtherSectionsSearchResultsGroup.Visible = False;
	Else
		Items.OtherSectionsSearchResultsGroup.Visible = True;
		If FillParameters.OtherSections.Count() = 0 Then
			Label = Items.Insert("InOtherSections", Type("FormDecoration"), Items.OtherSectionsSearchResults);
			Label.Title = NStr("en = 'Reports not found in other sections.';") + Chars.LF;
			Label.Height = 2;
		EndIf;
		For Each SectionReference In FillParameters.OtherSections Do
			OutputSectionOptions(FillParameters, SectionReference);
		EndDo;
		If FillParameters.NotDisplayed > 0 Then // Show the note.
			LabelTitle = NStr("en = 'Limited to first %1 reports. Please narrow your search.';");
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(LabelTitle, FillParameters.OutputLimit);
			Label = Items.Insert("OutputLimitExceeded", Type("FormDecoration"), Items.OtherSectionsSearchResults);
			Label.Title = LabelTitle;
			Label.Font = FontImportantLabel;
			Label.Height = 2;
		EndIf;
	EndIf;
	
	If FillParameters.AttributesToBeAdded.Count() > 0 Then
		// Registering old attributes for deleting.
		AttributesToBeDeleted = New Array;
		AttributesSet = GetAttributes(); // Array of FormAttribute
		For Each Attribute In AttributesSet Do
			If ConstantAttributes.FindByValue(Attribute.Name) = Undefined Then
				AttributesToBeDeleted.Add(Attribute.Name);
			EndIf;
		EndDo;
		// Delete old and add new attributes.
		ChangeAttributes(FillParameters.AttributesToBeAdded, AttributesToBeDeleted);
		// Link new attributes to data.
		For Each Attribute In FillParameters.AttributesToBeAdded Do
			CheckBox = Items.Find(Attribute.Name);
			CheckBox.DataPath = Attribute.Name;
			LabelName = Mid(Attribute.Name, StrLen("CheckBox_")+1);
			FoundItems = AddedOptions.FindRows(New Structure("LabelName", LabelName));
			If FoundItems.Count() > 0 Then
				Variant = FoundItems[0];
				ThisObject[Attribute.Name] = Variant.Visible;
			EndIf;
		EndDo;
	EndIf;
	
	ReportOptionByItemName = New FixedMap(FillParameters.SearchForOptions);
	Items.Pages.CurrentPage = Items.IsMain;
	
EndProcedure

&AtServer
Procedure InitializeFillingParameters(FillParameters)
	FillParameters.Insert("GroupName", "");
	FillParameters.Insert("AttributesToBeAdded", New Array);
	FillParameters.Insert("EmptyDecorationsAdded", 0);
	FillParameters.Insert("OutputLimit", 20);
	FillParameters.Insert("RemainsToOutput", FillParameters.OutputLimit);
	FillParameters.Insert("NotDisplayed", 0);
	FillParameters.Insert("OptionItemsDisplayed", 0);
	FillParameters.Insert("SearchForOptions", New Map);
	
	OptionGroupTemplate = New Structure(
		"Type, HorizontalStretch,
		|Representation, Group, 
		|ShowTitle");
	OptionGroupTemplate.Type = FormGroupType.UsualGroup;
	OptionGroupTemplate.HorizontalStretch = True;
	OptionGroupTemplate.Representation = UsualGroupRepresentation.None;
	OptionGroupTemplate.Group = ChildFormItemsGroup.AlwaysHorizontal;
	OptionGroupTemplate.ShowTitle = False;
	
	QuickAccessPictureTemplate = New Structure(
		"Type, Width, Height, Picture,
		|HorizontalStretch, VerticalStretch");
	QuickAccessPictureTemplate.Type = FormDecorationType.Picture;
	QuickAccessPictureTemplate.Width = 2;
	QuickAccessPictureTemplate.Height = 1;
	QuickAccessPictureTemplate.Picture = QuickAccessPicture;
	QuickAccessPictureTemplate.HorizontalStretch = False;
	QuickAccessPictureTemplate.VerticalStretch = False;
	
	IndentPictureTemplate = New Structure(
		"Type, Width, Height,
		|HorizontalStretch, VerticalStretch");
	IndentPictureTemplate.Type = FormDecorationType.Picture;
	IndentPictureTemplate.Width = 1;
	IndentPictureTemplate.Height = 1;
	IndentPictureTemplate.HorizontalStretch = False;
	IndentPictureTemplate.VerticalStretch = False;
	
	// Templates for filling in control items to be created.
	OptionLabelTemplate = New Structure(
		"Type, Hyperlink, TextColor,
		|VerticalStretch, Height,
		|HorizontalStretch, AutoMaxWidth, MaxWidth");
	OptionLabelTemplate.Type = FormDecorationType.Label;
	OptionLabelTemplate.Hyperlink = True;
	OptionLabelTemplate.TextColor = VisibleOptionsColor;
	OptionLabelTemplate.VerticalStretch = False;
	OptionLabelTemplate.Height = 1;
	OptionLabelTemplate.HorizontalStretch = True;
	OptionLabelTemplate.AutoMaxWidth = False;
	OptionLabelTemplate.MaxWidth = 0;
	
	FillParameters.Insert("Templates", New Structure);
	FillParameters.Templates.Insert("VariantGroup", OptionGroupTemplate);
	FillParameters.Templates.Insert("QuickAccessPicture", QuickAccessPictureTemplate);
	FillParameters.Templates.Insert("IndentPicture1", IndentPictureTemplate);
	FillParameters.Templates.Insert("OptionLabel", OptionLabelTemplate);
	
	If SetupMode Then
		FillParameters.Insert("ContextMenu", New Structure("RemoveFromQuickAccess, MoveToQuickAccess, Change"));
		FillParameters.ContextMenu.RemoveFromQuickAccess   = New Structure("Visible", False);
		FillParameters.ContextMenu.MoveToQuickAccess = New Structure("Visible", False);
		FillParameters.ContextMenu.Change                  = New Structure("Visible", True);
	EndIf;
	
	FillParameters.Insert("ImportanceGroups", New Array);
	FillParameters.ImportanceGroups.Add("QuickAccess");
	FillParameters.ImportanceGroups.Add("NoGroup");
	FillParameters.ImportanceGroups.Add("WithGroup");
	FillParameters.ImportanceGroups.Add("SeeAlso");
	
	For Each GroupName In FillParameters.ImportanceGroups Do
		FillParameters.Insert(GroupName, New Structure("Filter, Variants, Count"));
	EndDo;
	
	FillParameters.QuickAccess.Filter = New Structure("QuickAccess", True);
	FillParameters.NoGroup.Filter     = New Structure("QuickAccess, NoGroup", False, True);
	FillParameters.WithGroup.Filter      = New Structure("QuickAccess, NoGroup, SeeAlso", False, False, False);
	FillParameters.SeeAlso.Filter       = New Structure("QuickAccess, NoGroup, SeeAlso", False, False, True);
	
EndProcedure

// Parameters:
//  FillParameters -  See ReportsOptions.ReportOptionsToShow
//  SectionReference - CatalogRef.MetadataObjectIDs
//               - CatalogRef.ExtensionObjectIDs
//
&AtServer
Procedure OutputSectionOptions(FillParameters, SectionReference)
	FilterBySection = New Structure("SectionReference", SectionReference);
	SectionOptions = FillParameters.Variants.Copy(FilterBySection);
	FillParameters.Insert("CurrentSectionOptionsDisplayed", SectionReference = CurrentSectionRef);
	FillParameters.Insert("SectionOptions",    SectionOptions);
	FillParameters.Insert("OptionsNumber", SectionOptions.Count());
	If FillParameters.OptionsNumber = 0 Then
		// Display a message explaining why there are no options. Applicable only for the current section.
		If FillParameters.CurrentSectionOptionsDisplayed Then
			Label = Items.Insert("ReportListEmpty", Type("FormDecoration"), Items.NoGroupColumn1);
			If ValueIsFilled(SearchString) Then
				If FillParameters.CurrentSectionOnly Then
					Label.Title = NStr("en = 'Reports not found.';");
				Else
					Label.Title = NStr("en = 'Reports not found in current section.';");
					Label.Height = 2;
				EndIf;
			Else
				Label.Title = NStr("en = 'No reports in this section.';");
			EndIf;
			Items["QuickAccessHeader"].Visible  = False;
			Items["QuickAccessFooter"].Visible = False;
			Items["NoGroupFooter"].Visible     = False;
			Items["WithGroupFooter"].Visible      = False;
			Items["SeeAlsoHeader"].Visible    = False;
			Items["SeeAlsoFooter"].Visible       = False;
			Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
		EndIf;
		Return;
	EndIf;
	
	If FillParameters.CurrentSectionOnly Then
		SectionSubsystems = FillParameters.SubsystemsTable; // ValueTable
	Else
		SectionSubsystems = FillParameters.SubsystemsTable.Copy(FilterBySection);
	EndIf;
	SectionSubsystems.Sort("Priority ASC"); // 
	
	FillParameters.Insert("SectionReference",      SectionReference);
	FillParameters.Insert("SectionSubsystems", SectionSubsystems);
	
	DefineGroupsAndDecorationsForOptionsOutput(FillParameters);
	
	If Not FillParameters.CurrentSectionOptionsDisplayed
		And FillParameters.RemainsToOutput = 0 Then
		FillParameters.NotDisplayed = FillParameters.NotDisplayed + FillParameters.OptionsNumber;
		Return;
	EndIf;
	
	For Each GroupName In FillParameters.ImportanceGroups Do
		GroupParameters = FillParameters[GroupName]; // See ReportsOptions.ReportOptionsToShow
		If FillParameters.RemainsToOutput <= 0 Then
			GroupParameters.Variants   = New Array;
			GroupParameters.Count = 0;
		Else
			GroupParameters.Variants   = FillParameters.SectionOptions.Copy(GroupParameters.Filter);
			GroupParameters.Count = GroupParameters.Variants.Count();
		EndIf;
		
		If GroupParameters.Count = 0 And Not (SetupMode And GroupName = "WithGroup") Then
			Continue;
		EndIf;
		
		If Not FillParameters.CurrentSectionOptionsDisplayed Then
			// Restrict options output.
			FillParameters.RemainsToOutput = FillParameters.RemainsToOutput - GroupParameters.Count;
			If FillParameters.RemainsToOutput < 0 Then
				// Remove rows that exceed the limit.
				ExcessiveOptions = -FillParameters.RemainsToOutput;
				For Number = 1 To ExcessiveOptions Do
					GroupParameters.Variants.Delete(GroupParameters.Count - Number);
				EndDo;
				FillParameters.NotDisplayed = FillParameters.NotDisplayed + ExcessiveOptions;
				FillParameters.RemainsToOutput = 0;
			EndIf;
		EndIf;
		
		If SetupMode Then
			FillParameters.ContextMenu.RemoveFromQuickAccess.Visible   = (GroupName = "QuickAccess");
			FillParameters.ContextMenu.MoveToQuickAccess.Visible = (GroupName <> "QuickAccess");
		EndIf;
		
		FillParameters.GroupName = GroupName;
		OutputOptionsWithGroup(FillParameters);
	EndDo;
	
	HasQuickAccess     = (FillParameters.QuickAccess.Count > 0);
	HasOptionsWithoutGroups = (FillParameters.NoGroup.Count > 0);
	HasOptionsWithGroups  = (FillParameters.WithGroup.Count > 0);
	HasOptionsSeeAlso   = (FillParameters.SeeAlso.Count > 0);
	
	Items[FillParameters.Prefix + "QuickAccessHeader"].Visible  = SetupMode Or HasQuickAccess;
	Items[FillParameters.Prefix + "QuickAccessFooter"].Visible = (
		SetupMode
		Or (
			HasQuickAccess
			And (
				HasOptionsWithoutGroups
				Or HasOptionsWithGroups
				Or HasOptionsSeeAlso)));
	Items[FillParameters.Prefix + "NoGroupFooter"].Visible  = HasOptionsWithoutGroups;
	Items[FillParameters.Prefix + "WithGroupFooter"].Visible   = HasOptionsWithGroups;
	Items[FillParameters.Prefix + "SeeAlsoHeader"].Visible = HasOptionsSeeAlso;
	Items[FillParameters.Prefix + "SeeAlsoFooter"].Visible    = HasOptionsSeeAlso;
	
	If FillParameters.CurrentSectionOptionsDisplayed Then
		Items.QuickAccessTooltipWhenNotConfigured.Visible = SetupMode And Not HasQuickAccess;
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineGroupsAndDecorationsForOptionsOutput(FillParameters)
	// This procedure defines substitutions of standard groups and items.
	FillParameters.Insert("Prefix", "");
	If FillParameters.CurrentSectionOptionsDisplayed Then
		Return;
	EndIf;
	
	InformationOnSection = FillParameters.SubsystemsTable.Find(FillParameters.SectionReference, "Ref");
	FillParameters.Prefix = "Section_" + InformationOnSection.Priority + "_";
	
	SectionGroupName = FillParameters.Prefix + InformationOnSection.Name;
	SectionGroup = Items.Insert(SectionGroupName, Type("FormGroup"), Items.OtherSectionsSearchResults);
	SectionGroup.Type         = FormGroupType.UsualGroup;
	SectionGroup.Representation = UsualGroupRepresentation.None;
	SectionGroup.ShowTitle      = False;
	SectionGroup.ToolTipRepresentation     = ToolTipRepresentation.ShowTop;
	SectionGroup.HorizontalStretch = True;
	
	SectionSuffix = " (" + Format(FillParameters.OptionsNumber, "NZ=0; NG=") + ")" + Chars.LF;
	If FillParameters.UseHighlighting Then
		HighlightParameters = FillParameters.SearchResult.SubsystemsHighlight.Get(FillParameters.SectionReference);
		If HighlightParameters = Undefined Then
			PresentationHighlighting = New Structure("Value, FoundWordsCount, WordHighlighting", InformationOnSection.Presentation, 0, New ValueList);
			For Each Word In FillParameters.WordArray Do
				ReportsOptions.MarkWord(PresentationHighlighting, Word);
			EndDo;
		Else
			PresentationHighlighting = HighlightParameters.SubsystemDescription;
		EndIf;
		PresentationHighlighting.Value = PresentationHighlighting.Value + SectionSuffix;
		If PresentationHighlighting.FoundWordsCount > 0 Then
			TitleOfSection = GenerateRowWithHighlighting(PresentationHighlighting);
		Else
			TitleOfSection = PresentationHighlighting.Value;
		EndIf;
	Else
		TitleOfSection = InformationOnSection.Presentation + SectionSuffix;
	EndIf;
	
	SectionTitle = SectionGroup.ExtendedTooltip; // FormDecoration, FormDecorationExtensionForALabel
	SectionTitle.Title   = TitleOfSection;
	SectionTitle.Font       = SectionFont;
	SectionTitle.TextColor  = SectionColor;
	SectionTitle.Height      = 2;
	SectionTitle.Hyperlink = True;
	SectionTitle.VerticalAlign = ItemVerticalAlign.Top;
	SectionTitle.HorizontalStretch = True;
	SectionTitle.SetAction("Click", "Attachable_SectionTitleClick");
	
	SectionGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	IndentDecorationName = FillParameters.Prefix + "IndentDecoration1";
	IndentDecoration1 = Items.Insert(IndentDecorationName, Type("FormDecoration"), SectionGroup);
	IndentDecoration1.Type = FormDecorationType.Label;
	IndentDecoration1.Title = " ";
	
	// Previously, an output limit was reached in other groups, so there is no need to generate subordinate items.
	If FillParameters.RemainsToOutput = 0 Then
		SectionTitle.Height = 1; // 
		Return;
	EndIf;
	
	CopyItem(FillParameters.Prefix, SectionGroup, "Columns", 2);
	
	Items.Delete(Items[FillParameters.Prefix + "QuickAccessTooltipWhenNotConfigured"]);
	
	FoundGroup = Items[FillParameters.Prefix + "QuickAccessHeader"]; // FormGroup
	FoundGroup.ExtendedTooltip.Title = "";
EndProcedure

&AtServer
Function CopyItem(NewItemPrefix, NewItemGroup, NameOfItemToCopy, NestingLevel)
	ItemToCopy = Items.Find(NameOfItemToCopy);
	NewItemName = NewItemPrefix + NameOfItemToCopy;
	NewItem = Items.Find(NewItemName);
	ElementType = TypeOf(ItemToCopy);
	IsFolder = (ElementType = Type("FormGroup"));
	If NewItem = Undefined Then
		NewItem = Items.Insert(NewItemName, ElementType, NewItemGroup);
	EndIf;
	If IsFolder Then
		PropertiesNotToFill = "Name, Parent, Visible, Shortcut, ChildItems, TitleDataPath";
	Else
		PropertiesNotToFill = "Name, Parent, Visible, Shortcut, ExtendedTooltip";
	EndIf;
	FillPropertyValues(NewItem, ItemToCopy, , PropertiesNotToFill);
	If IsFolder And NestingLevel > 0 Then
		For Each SubordinateItem In ItemToCopy.ChildItems Do
			CopyItem(NewItemPrefix, NewItem, SubordinateItem.Name, NestingLevel - 1);
		EndDo;
	EndIf;
	Return NewItem;
EndFunction

// Parameters:
//  FillParameters - See ReportsOptions.ReportOptionsToShow
//
&AtServer
Procedure OutputOptionsWithGroup(FillParameters)
	GroupParameters = FillParameters[FillParameters.GroupName]; // See ReportsOptions.ReportOptionsToShow
	Variants = GroupParameters.Variants;
	OptionsCount = GroupParameters.Count;
	If OptionsCount = 0 And Not (SetupMode And FillParameters.GroupName = "WithGroup") Then
		Return;
	EndIf;
	
	// Basic properties of the second-level group.
	Level2GroupName = FillParameters.GroupName;
	Level2Group = Items.Find(FillParameters.Prefix + Level2GroupName);
	
	OutputWithoutGroups = (Level2GroupName = "QuickAccess" Or Level2GroupName = "SeeAlso");
	
	// Sorting options (there are groups and important objects).
	Variants.Sort("SubsystemPriority ASC, Important DESC, Description ASC");
	ParentsFound = Variants.FindRows(New Structure("TopLevel", True));
	For Each ParentOption In ParentsFound Do
		SubordinateItemsFound = Variants.FindRows(New Structure("Parent, Subsystem", ParentOption.Ref, ParentOption.Subsystem));
		CurrentIndex = Variants.IndexOf(ParentOption);
		For Each SubordinateOption In SubordinateItemsFound Do
			ParentOption.SubordinateCount = ParentOption.SubordinateCount + 1;
			SubordinateOption.OutputWithMainReport = True;
			SubordinateOptionIndex = Variants.IndexOf(SubordinateOption);
			If SubordinateOptionIndex < CurrentIndex Then
				Variants.Move(SubordinateOptionIndex, CurrentIndex - SubordinateOptionIndex);
			ElsIf SubordinateOptionIndex = CurrentIndex Then
				CurrentIndex = CurrentIndex + 1;
			Else
				Variants.Move(SubordinateOptionIndex, CurrentIndex - SubordinateOptionIndex + 1);
				CurrentIndex = CurrentIndex + 1;
			EndIf;
		EndDo;
	EndDo;
	
	DistributionTree = DistributionTree();
	
	MaxNestingLevel = 0;
	
	For Each Subsystem In FillParameters.SectionSubsystems Do
		
		ParentLevelRow = DistributionTree.Rows.Find(Subsystem.ParentReference, "SubsystemRef", True);
		If ParentLevelRow = Undefined Then
			TreeRow = DistributionTree.Rows.Add();
		Else
			TreeRow = ParentLevelRow.Rows.Add();
		EndIf;
		
		TreeRow.Subsystem = Subsystem;
		TreeRow.SubsystemRef = Subsystem.Ref;
		
		If OutputWithoutGroups Then
			If Subsystem.Ref = FillParameters.SectionReference Then
				For Each Variant In Variants Do
					TreeRow.Variants.Add(Variant);
				EndDo;
			EndIf;
		Else
			TreeRow.Variants = Variants.FindRows(New Structure("Subsystem", Subsystem.Ref));
		EndIf;
		TreeRow.OptionsCount = TreeRow.Variants.Count();
		
		HasOptions = TreeRow.OptionsCount > 0;
		If Not HasOptions Then
			TreeRow.BlankRowsCount = -1;
		EndIf;
		
		// Calculating a nesting level. Calculating the count in the hierarchy (if there are options).
		If ParentLevelRow <> Undefined Then
			While ParentLevelRow <> Undefined Do
				If HasOptions Then
					ParentLevelRow.TotalNestedOptions = ParentLevelRow.TotalNestedOptions + TreeRow.OptionsCount;
					ParentLevelRow.TotalNestedSubsystems = ParentLevelRow.TotalNestedSubsystems + 1;
					ParentLevelRow.TotalNestedBlankRows = ParentLevelRow.TotalNestedBlankRows + 1;
				EndIf;
				ParentLevelRow = ParentLevelRow.Parent;
				TreeRow.NestingLevel = TreeRow.NestingLevel + 1;
			EndDo;
		EndIf;
		
		MaxNestingLevel = Max(MaxNestingLevel, TreeRow.NestingLevel);
		
	EndDo;
	
	// Calculating the location column and determining for each subsystem if it is to be moved based on count data.
	FillParameters.Insert("MaxNestingLevel", MaxNestingLevel);
	DistributionTree.Columns.Add("FormGroup");
	DistributionTree.Columns.Add("OutputStarted", New TypeDescription("Boolean"));
	RootRow = DistributionTree.Rows[0];
	RowsCount = RootRow.OptionsCount + RootRow.TotalNestedOptions + RootRow.TotalNestedSubsystems + Max(RootRow.TotalNestedBlankRows - 2, 0);
	
	// Variables to support dynamics of third-level groups.
	ColumnsCount = Level2Group.ChildItems.Count();
	If RootRow.OptionsCount = 0 Then
		If ColumnsCount > 1 And RootRow.TotalNestedOptions <= 5 Then
			ColumnsCount = 1;
		ElsIf ColumnsCount > 2 And RootRow.TotalNestedOptions <= 10 Then
			ColumnsCount = 2;
		EndIf;
	EndIf;
	// Number of options to output per column.
	Level3GroupCutoff = Max(Int(RowsCount / ColumnsCount), 2);
	
	OutputOrder = OutputOrder();
	
	Recursion = New Structure;
	Recursion.Insert("TotaItemsLeftToOutput", RowsCount);
	Recursion.Insert("FreeColumns", ColumnsCount - 1);
	Recursion.Insert("ColumnsCount", ColumnsCount);
	Recursion.Insert("Level3GroupCutoff", Level3GroupCutoff);
	Recursion.Insert("CurrentColumnNumber", 1);
	Recursion.Insert("IsLastColumn", Recursion.CurrentColumnNumber = Recursion.ColumnsCount Or RowsCount <= 6);
	Recursion.Insert("FreeRows", Level3GroupCutoff);
	Recursion.Insert("OutputInCurrentColumnIsStarted", False);
	
	FillOutputOrder(OutputOrder, Undefined, RootRow, Recursion, FillParameters);
	
	// Output to the form.
	CurrentColumnNumber = 0;
	For Each OutputOrderRow In OutputOrder Do
		
		If CurrentColumnNumber <> OutputOrderRow.ColumnNumber Then
			CurrentColumnNumber = OutputOrderRow.ColumnNumber;
			CurrentNestingLevel = 0;
			CurrentGroup = Level2Group.ChildItems.Get(CurrentColumnNumber - 1);
			CurrentGroupsByNestingLevels = New Map;
			CurrentGroupsByNestingLevels.Insert(0, CurrentGroup);
		EndIf;
		
		If OutputOrderRow.IsSubsystem Then
			
			If OutputOrderRow.SubsystemRef = FillParameters.SectionReference Then
				CurrentNestingLevel = 0;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(0);
			Else
				CurrentNestingLevel = OutputOrderRow.NestingLevel;
				ToGroup = CurrentGroupsByNestingLevels.Get(OutputOrderRow.NestingLevel - 1);
				CurrentGroup = AddSubsystemsGroup(FillParameters, OutputOrderRow, ToGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf OutputOrderRow.IsOption Then
			
			If CurrentNestingLevel <> OutputOrderRow.NestingLevel Then
				CurrentNestingLevel = OutputOrderRow.NestingLevel;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(CurrentNestingLevel);
			EndIf;
			
			AddReportOptionItems(FillParameters, OutputOrderRow.Variant, CurrentGroup, OutputOrderRow.NestingLevel);
			
			If OutputOrderRow.Variant.SubordinateCount > 0 Then
				CurrentNestingLevel = CurrentNestingLevel + 1;
				CurrentGroup = AddGroupWithIndent(FillParameters, OutputOrderRow, CurrentGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf OutputOrderRow.IsBlankRow Then
			
			ToGroup = CurrentGroupsByNestingLevels.Get(OutputOrderRow.NestingLevel - 1);
			AddBlankDecoration(FillParameters, ToGroup);
			
		EndIf;
		
	EndDo;
	
	For ColumnNumber = 3 To Level2Group.ChildItems.Count() Do
		FoundItems = OutputOrder.FindRows(New Structure("ColumnNumber, IsSubsystem", ColumnNumber, False));
		If FoundItems.Count() = 0 Then
			Level3Group = Level2Group.ChildItems.Get(ColumnNumber - 1);
			AddBlankDecoration(FillParameters, Level3Group);
		EndIf;
	EndDo;
	
EndProcedure

// The constructor of the collection for modeling distribution of report options considering subsystems nesting.
//
// Returns:
//   ValueTree - Collection for simulating the distribution of report options considering subsystem nesting, where:
//       * Subsystem - ValueTableRow - Subsystem details.
//       * SubsystemRef - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//       * Variants - Array of ValueTableRow:
//           ** Ref - CatalogRef.ReportsOptions
//           ** Subsystem - CatalogRef.MetadataObjectIDs
//                         - CatalogRef.ExtensionObjectIDs
//           ** SubsystemPresentation - String
//           ** SubsystemPriority - String
//           ** SectionReference - CatalogRef.MetadataObjectIDs
//                           - CatalogRef.ExtensionObjectIDs
//           ** NoGroup - Boolean
//           ** Important - Boolean
//           ** SeeAlso - Boolean
//           ** Additional - Boolean
//           ** Visible - Boolean
//           ** QuickAccess - Boolean
//           ** ReportName - String
//           ** Description - String
//           ** LongDesc - String
//           ** Author - CatalogRef.Users
//                    - CatalogRef.ExternalUsers
//           ** Report - CatalogRef.MetadataObjectIDs
//                    - CatalogRef.ExtensionObjectIDs
//                    - CatalogRef.AdditionalReportsAndDataProcessors
//                    - String
//           ** ReportType - EnumRef.ReportsTypes
//           ** VariantKey - String
//           ** Parent - CatalogRef.ReportsOptions
//           ** TopLevel - Boolean
//           ** MeasurementsKey - String
//       * OptionsCount- Number - Report option counter.
//       * BlankRowsCount - Number - Additional counter.
//       * TotalNestedOptions- Number - Subordinate report option counter.
//       * TotalNestedSubsystems- Number - Subordinate subsystem counter.
//       * TotalNestedBlankRows- Number - Additional counter.
//       * NestingLevel- Number - Hierarchical number.
//       * TopLevel- Boolean - Flag indicating that this is a top-level record.
//
&AtServer
Function DistributionTree()
	
	FlagDetails = New TypeDescription("Boolean");
	NumberDetails = New TypeDescription("Number");
	ArrayDetails = New TypeDescription("Array");
	
	IDDetails = New TypeDescription(
		"CatalogRef.MetadataObjectIDs, CatalogRef.ExtensionObjectIDs");
	
	DistributionTree = New ValueTree;
	
	DistributionTree.Columns.Add("Subsystem");
	DistributionTree.Columns.Add("SubsystemRef", IDDetails);
	DistributionTree.Columns.Add("Variants", ArrayDetails);
	DistributionTree.Columns.Add("OptionsCount", NumberDetails);
	DistributionTree.Columns.Add("BlankRowsCount", NumberDetails);
	DistributionTree.Columns.Add("TotalNestedOptions", NumberDetails);
	DistributionTree.Columns.Add("TotalNestedSubsystems", NumberDetails);
	DistributionTree.Columns.Add("TotalNestedBlankRows", NumberDetails);
	DistributionTree.Columns.Add("NestingLevel", NumberDetails);
	DistributionTree.Columns.Add("TopLevel", FlagDetails);
	
	Return DistributionTree;
	
EndFunction

// The constructor of the collection that stores information about the order in which reports are displayed on the panel.
//
// Returns:
//   ValueTable:
//       * ColumnNumber- Number
//       * IsSubsystem - Boolean
//       * IsFollowUp - Boolean
//       * IsOption - Boolean
//       * IsBlankRow - Boolean
//       * TreeRow - ValueTreeRow - See …
//       * Subsystem - ValueTableRow:
//           ** Ref - CatalogRef.MetadataObjectIDs
//                     - CatalogRef.ExtensionObjectIDs
//           ** Presentation - String
//           ** Name - String
//           ** FullName - String
//           ** Priority - String
//           ** ItemNumber - Number
//           ** TagName - String
//           ** ParentReference - CatalogRef.MetadataObjectIDs
//                             - CatalogRef.ExtensionObjectIDs
//           ** SectionReference - CatalogRef.MetadataObjectIDs
//                           - CatalogRef.ExtensionObjectIDs
//           ** VisibleOptionsCount - Number
//       * SubsystemRef - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//       * SubsystemPriority - Number
//       * Variant - ValueTableRow:
//             ** SubordinateCount - Number - Counter of subordinate items.
//       * OptionRef - CatalogRef.ReportsOptions
//       * NestingLevel - Number
//
&AtServer
Function OutputOrder()
	
	FlagDetails = New TypeDescription("Boolean");
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	
	IDDetails = New TypeDescription(
		"CatalogRef.MetadataObjectIDs, CatalogRef.ExtensionObjectIDs");
	
	OutputOrder = New ValueTable;
	
	OutputOrder.Columns.Add("ColumnNumber", NumberDetails);
	OutputOrder.Columns.Add("IsSubsystem", FlagDetails);
	OutputOrder.Columns.Add("IsFollowUp", FlagDetails);
	OutputOrder.Columns.Add("IsOption", FlagDetails);
	OutputOrder.Columns.Add("IsBlankRow", FlagDetails);
	OutputOrder.Columns.Add("TreeRow");
	OutputOrder.Columns.Add("Subsystem");
	OutputOrder.Columns.Add("SubsystemRef", IDDetails);
	OutputOrder.Columns.Add("SubsystemPriority", RowDescription);
	OutputOrder.Columns.Add("Variant");
	OutputOrder.Columns.Add("OptionRef");
	OutputOrder.Columns.Add("NestingLevel", NumberDetails);
	
	Return OutputOrder;
	
EndFunction

// Parameters:
//  OutputOrder - See OutputOrder
//  ParentLevelRow - See DistributionTree
//  TreeRow - See DistributionTree
//  Recursion - Structure:
//    * TotaItemsLeftToOutput - Number
//    * FreeColumns - Number
//    * ColumnsCount - Number
//    * Level3GroupCutoff - Number
//    * CurrentColumnNumber - Number
//    * IsLastColumn - Boolean
//    * FreeRows - Number
//    * OutputInCurrentColumnIsStarted - Boolean
//  FillParameters - See ReportsOptions.ReportOptionsToShow
//
&AtServer
Procedure FillOutputOrder(OutputOrder, ParentLevelRow, TreeRow, Recursion, FillParameters)
	
	If Not Recursion.IsLastColumn And Recursion.FreeRows <= 0 Then // Reached the end of the column.
		// Move to the next one.
		Recursion.TotaItemsLeftToOutput = Recursion.TotaItemsLeftToOutput - 1; // Empty group that shouldn't be output.
		Recursion.CurrentColumnNumber = Recursion.CurrentColumnNumber + 1;
		Recursion.IsLastColumn = (Recursion.CurrentColumnNumber = Recursion.ColumnsCount);
		FreeColumns = Recursion.ColumnsCount - Recursion.CurrentColumnNumber + 1;
		// Number of options to output per column.
		Recursion.Level3GroupCutoff = Max(Int(Recursion.TotaItemsLeftToOutput / FreeColumns), 2);
		Recursion.FreeRows = Recursion.Level3GroupCutoff; // Number of options to output per column.
		
		// Output/Repeat the hierarchy with the " (continued)" postfix
		// if some of the parent's rows are output in the previous column.
		CurrentParent = ParentLevelRow;
		While CurrentParent <> Undefined And CurrentParent.SubsystemRef <> FillParameters.SectionReference Do
			
			// Recursion.TotalObjectsToOutput will not decrease as continuation output increases the number of rows.
			OutputSubsystem = OutputOrder.Add();
			OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
			OutputSubsystem.IsSubsystem       = True;
			OutputSubsystem.IsFollowUp      = ParentLevelRow.OutputStarted;
			OutputSubsystem.TreeRow        = TreeRow;
			OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(OutputSubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
			
			CurrentParent = CurrentParent.Parent;
		EndDo;
		
		Recursion.OutputInCurrentColumnIsStarted = False;
		
	EndIf;
	
	If (TreeRow.OptionsCount > 0 Or TreeRow.TotalNestedOptions > 0) And Recursion.OutputInCurrentColumnIsStarted And ParentLevelRow.OutputStarted Then
		// Output a blank row.
		Recursion.TotaItemsLeftToOutput = Recursion.TotaItemsLeftToOutput - 1;
		OutputBlankRow = OutputOrder.Add();
		OutputBlankRow.ColumnNumber        = Recursion.CurrentColumnNumber;
		OutputBlankRow.IsBlankRow     = True;
		OutputBlankRow.TreeRow        = TreeRow;
		OutputBlankRow.SubsystemPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(OutputBlankRow, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
		
		// Counting rows occupied by a blank row.
		Recursion.FreeRows = Recursion.FreeRows - 1;
	EndIf;
	
	// Output a group.
	If ParentLevelRow <> Undefined Then
		OutputSubsystem = OutputOrder.Add();
		OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
		OutputSubsystem.IsSubsystem       = True;
		OutputSubsystem.TreeRow        = TreeRow;
		OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(OutputSubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
	EndIf;
	
	If TreeRow.OptionsCount > 0 Then
		
		// Counting a row occupied by a group.
		Recursion.TotaItemsLeftToOutput = Recursion.TotaItemsLeftToOutput - 1;
		Recursion.FreeRows = Recursion.FreeRows - 1;
		
		TreeRow.OutputStarted = True;
		Recursion.OutputInCurrentColumnIsStarted = True;
		
		If Recursion.IsLastColumn
			Or ParentLevelRow <> Undefined
			And (TreeRow.OptionsCount <= 5
			Or TreeRow.OptionsCount - 2 <= Recursion.FreeRows + 2) Then
			
			// Output all in the current column.
			CanContinue = False;
			CountToCurrentColumn = TreeRow.OptionsCount;
			
		Else
			
			// Partial output to the current column and proceeding in the next column.
			CanContinue = True;
			CountToCurrentColumn = Max(Recursion.FreeRows + 2, 3);
			
		EndIf;
		
		// Register options in the current column / Proceeding to output options in a new column.
		OutputOptionsCount = 0;
		VisibleOptionsCount = 0;
		For Each Variant In TreeRow.Variants Do
			// TreeRow.Variants - Search result.
			// The code logic assumes that the search result sort is a row sort.
			// If that's not the case, copy the source table
			// with the applied filter by subsystem and sort it by name.
			
			If CanContinue
				And Not Recursion.IsLastColumn
				And Not Variant.OutputWithMainReport
				And OutputOptionsCount >= CountToCurrentColumn Then
				// Navigate to the new column.
				Recursion.CurrentColumnNumber = Recursion.CurrentColumnNumber + 1;
				Recursion.IsLastColumn = (Recursion.CurrentColumnNumber = Recursion.ColumnsCount);
				FreeColumns = Recursion.ColumnsCount - Recursion.CurrentColumnNumber + 1;
				// Number of options to output per column.
				Recursion.Level3GroupCutoff = Max(Int(Recursion.TotaItemsLeftToOutput / FreeColumns), 2);
				Recursion.FreeRows = Recursion.Level3GroupCutoff; // Number of options to output per column.
				
				If Recursion.IsLastColumn Then
					CountToCurrentColumn = -1;
				Else
					CountToCurrentColumn = Max(Min(Recursion.FreeRows, TreeRow.OptionsCount - OutputOptionsCount), 3);
				EndIf;
				OutputOptionsCount = 0;
				
				// Copy the hierarchy with the "(continue)" postfix.
				CurrentParent = ParentLevelRow;
				While CurrentParent <> Undefined And CurrentParent.SubsystemRef <> FillParameters.SectionReference Do
					
					// Recursion.TotalObjectsToOutput will not decrease as continuation output increases the number of rows.
					OutputSubsystem = OutputOrder.Add();
					OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
					OutputSubsystem.IsSubsystem       = True;
					OutputSubsystem.IsFollowUp      = True;
					OutputSubsystem.TreeRow        = TreeRow;
					OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
					FillPropertyValues(OutputSubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
					
					CurrentParent = CurrentParent.Parent;
				EndDo;
				
				// Output a group with the " (continued)" postfix.
				// "Recursion.TotalObjectsToOutput" will not decrease as continuation output increases the number of rows.
				OutputSubsystem = OutputOrder.Add();
				OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
				OutputSubsystem.IsSubsystem       = True;
				OutputSubsystem.IsFollowUp      = True;
				OutputSubsystem.TreeRow        = TreeRow;
				OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
				FillPropertyValues(OutputSubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
				
				// Counting a row occupied by a group.
				Recursion.FreeRows = Recursion.FreeRows - 1;
			EndIf;
			
			Recursion.TotaItemsLeftToOutput = Recursion.TotaItemsLeftToOutput - 1;
			OutputOption = OutputOrder.Add();
			OutputOption.ColumnNumber        = Recursion.CurrentColumnNumber;
			OutputOption.IsOption          = True;
			OutputOption.TreeRow        = TreeRow;
			OutputOption.Variant             = Variant;
			OutputOption.OptionRef       = Variant.Ref;
			OutputOption.SubsystemPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(OutputOption, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
			If Variant.OutputWithMainReport Then
				OutputOption.NestingLevel = OutputOption.NestingLevel + 1;
			EndIf;
			
			OutputOptionsCount = OutputOptionsCount + 1;
			If Variant.Visible Then
				VisibleOptionsCount = VisibleOptionsCount + 1;
			EndIf;
			
			// Count rows containing options.
			Recursion.FreeRows = Recursion.FreeRows - 1;
		EndDo;
		
		If VisibleOptionsCount > 0 Then
			SubsystemForms = FindSubsystemByRef(ThisObject, TreeRow.SubsystemRef);
			If SubsystemForms <> Undefined Then
			SubsystemForms.VisibleOptionsCount = SubsystemForms.VisibleOptionsCount + VisibleOptionsCount;
			While SubsystemForms.Ref <> SubsystemForms.SectionReference Do
				SubsystemForms = FindSubsystemByRef(ThisObject, SubsystemForms.SectionReference);
				SubsystemForms.VisibleOptionsCount = SubsystemForms.VisibleOptionsCount + VisibleOptionsCount;
			EndDo;
			EndIf;
		EndIf;
		
	EndIf;
	
	// Register nested rows.
	For Each SubordinateObjectRow In TreeRow.Rows Do
		FillOutputOrder(OutputOrder, TreeRow, SubordinateObjectRow, Recursion, FillParameters);
		// Forward OutputStarted from the lower level.
		If SubordinateObjectRow.OutputStarted Then
			TreeRow.OutputStarted = True;
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  FillParameters - See ReportsOptions.ReportOptionsToShow
//  OutputOrderRow - See OutputOrder
//  ToGroup - FormGroup
//
// Returns:
//  FormGroup, FormButton, FormTable, FormField, Arbitrary, FormDecoration
// 
&AtServer
Function AddSubsystemsGroup(FillParameters, OutputOrderRow, ToGroup)
	Subsystem = OutputOrderRow.Subsystem;
	TreeRow = OutputOrderRow.TreeRow;
	If TreeRow.OptionsCount = 0
		And TreeRow.TotalNestedOptions = 0
		And Not (SetupMode And FillParameters.GroupName = "WithGroup") Then
		Return ToGroup;
	EndIf;
	SubsystemPresentation = Subsystem.Presentation;
	
	Subsystem.ItemNumber = Subsystem.ItemNumber + 1;
	SubsystemsGroupName = Subsystem.TagName + "_" + Format(Subsystem.ItemNumber, "NG=0");
	
	While Items.Find(SubsystemsGroupName) <> Undefined Do
		Subsystem.ItemNumber = Subsystem.ItemNumber + 1;
		SubsystemsGroupName = Subsystem.TagName + "_" + Format(Subsystem.ItemNumber, "NG=0");
	EndDo;
	
	// Insert a left indent.
	If OutputOrderRow.NestingLevel > 1 Then
		// Group.
		IndentGroup1 = Items.Insert(SubsystemsGroupName + "_IndentGroup1", Type("FormGroup"), ToGroup);
		IndentGroup1.Type                      = FormGroupType.UsualGroup;
		IndentGroup1.Group              = ChildFormItemsGroup.AlwaysHorizontal;
		IndentGroup1.Representation              = UsualGroupRepresentation.None;
		IndentGroup1.ShowTitle      = False;
		IndentGroup1.HorizontalStretch = True;
		
		// Picture.
		IndentPicture1 = Items.Insert(SubsystemsGroupName + "_IndentPicture1", Type("FormDecoration"), IndentGroup1);
		FillPropertyValues(IndentPicture1, FillParameters.Templates.IndentPicture1);
		IndentPicture1.Width = OutputOrderRow.NestingLevel - 1;
		If OutputOrderRow.TreeRow.OptionsCount = 0 And OutputOrderRow.TreeRow.TotalNestedOptions = 0 Then
			IndentPicture1.Visible = False;
		EndIf;
		
		// Substitute a higher-level group.
		ToGroup = IndentGroup1;
		
		TitleFont = NormalGroupFont;
		SubsystemsGroupDisplay = UsualGroupRepresentation.None;
	Else
		TitleFont = ImportantGroupFont;
		SubsystemsGroupDisplay = UsualGroupRepresentation.NormalSeparation;
	EndIf;
	
	SubsystemsGroup1 = Items.Insert(SubsystemsGroupName, Type("FormGroup"), ToGroup);
	SubsystemsGroup1.Type = FormGroupType.UsualGroup;
	SubsystemsGroup1.HorizontalStretch = True;
	SubsystemsGroup1.Group = ChildFormItemsGroup.Vertical;
	SubsystemsGroup1.Representation = SubsystemsGroupDisplay;
	
	HighlightingIsRequired = False;
	If FillParameters.UseHighlighting Then
		HighlightParameters = FillParameters.SearchResult.SubsystemsHighlight.Get(Subsystem.Ref);
		If HighlightParameters <> Undefined Then
			PresentationHighlighting = HighlightParameters.SubsystemDescription;
			If PresentationHighlighting.FoundWordsCount > 0 Then
				HighlightingIsRequired = True;
			EndIf;
		EndIf;
	EndIf;
	
	If HighlightingIsRequired Then
		If OutputOrderRow.IsFollowUp Then
			Suffix = NStr("en = '(continued)';");
			If Not StrEndsWith(PresentationHighlighting.Value, Suffix) Then
				PresentationHighlighting.Value = PresentationHighlighting.Value + " " + Suffix;
			EndIf;
		EndIf;
		
		SubsystemsGroup1.ShowTitle = False;
		SubsystemsGroup1.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
		
		FormattedString = GenerateRowWithHighlighting(PresentationHighlighting);
		
		SubsystemTitle = Items.Insert(SubsystemsGroup1.Name + "_ExtendedTooltip", Type("FormDecoration"), SubsystemsGroup1);
		SubsystemTitle.Title = FormattedString;
		SubsystemTitle.TextColor = ReportOptionsGroupColor;
		SubsystemTitle.Font = TitleFont;
		SubsystemTitle.HorizontalStretch = True;
		SubsystemTitle.Height = 1;
		
	Else
		If OutputOrderRow.IsFollowUp Then
			SubsystemPresentation = SubsystemPresentation + " " + NStr("en = '(continued)';");
		EndIf;
		
		SubsystemsGroup1.ShowTitle = True;
		SubsystemsGroup1.Title = SubsystemPresentation;
	EndIf;
	
	TreeRow.FormGroup = SubsystemsGroup1;
	
	Return SubsystemsGroup1;
EndFunction

&AtServer
Function AddGroupWithIndent(FillParameters, OutputOrderRow, ToGroup)
	FillParameters.OptionItemsDisplayed = FillParameters.OptionItemsDisplayed + 1;
	
	IndentGroupName   = "IndentGroup1_" + Format(FillParameters.OptionItemsDisplayed, "NG=0");
	IndentPictureName = "IndentPicture1_" + Format(FillParameters.OptionItemsDisplayed, "NG=0");
	OutputGroupName    = "OutputGroup1_" + Format(FillParameters.OptionItemsDisplayed, "NG=0");
	
	// Indent.
	IndentGroup1 = Items.Insert(IndentGroupName, Type("FormGroup"), ToGroup);
	IndentGroup1.Type                      = FormGroupType.UsualGroup;
	IndentGroup1.Group              = ChildFormItemsGroup.AlwaysHorizontal;
	IndentGroup1.Representation              = UsualGroupRepresentation.None;
	IndentGroup1.ShowTitle      = False;
	IndentGroup1.HorizontalStretch = True;
	
	// Picture.
	IndentPicture1 = Items.Insert(IndentPictureName, Type("FormDecoration"), IndentGroup1);
	FillPropertyValues(IndentPicture1, FillParameters.Templates.IndentPicture1);
	IndentPicture1.Width = 1;
	
	// Output.
	OutputGroup1 = Items.Insert(OutputGroupName, Type("FormGroup"), IndentGroup1);
	OutputGroup1.Type                      = FormGroupType.UsualGroup;
	OutputGroup1.Group              = ChildFormItemsGroup.Vertical;
	OutputGroup1.Representation              = UsualGroupRepresentation.None;
	OutputGroup1.ShowTitle      = False;
	OutputGroup1.HorizontalStretch = True;
	
	Return OutputGroup1;
EndFunction

// Parameters:
//  FillParameters - See ReportsOptions.ReportOptionsToShow
//  Variant - ValueTableRow:
//    * Ref - CatalogRef.ReportsOptions
//    * Subsystem - CatalogRef.MetadataObjectIDs
//                 - CatalogRef.ExtensionObjectIDs
//    * SubsystemPresentation - String
//    * SubsystemPriority - String
//    * SectionReference - CatalogRef.MetadataObjectIDs
//                   - CatalogRef.ExtensionObjectIDs
//    * NoGroup - Boolean
//    * Important - Boolean
//    * SeeAlso - Boolean
//    * Additional - Boolean
//    * Visible - Boolean
//    * QuickAccess - Boolean
//    * ReportName - String
//    * Description - String
//    * LongDesc - String
//    * Author - CatalogRef.Users
//            - CatalogRef.ExternalUsers
//    * Report - CatalogRef.MetadataObjectIDs
//            - CatalogRef.ExtensionObjectIDs
//            - CatalogRef.AdditionalReportsAndDataProcessors
//            - String
//    * ReportType - EnumRef.ReportsTypes
//    * VariantKey - String
//    * Parent - CatalogRef.ReportsOptions
//    * TopLevel - Boolean
//    * MeasurementsKey - String
//  ToGroup - FormGroup
//          - FormButton
//          - FormTable
//          - FormField
//          - Arbitrary
//  NestingLevel - Number
//
// Returns:
//  FormGroup, FormButton, FormTable, FormField. FormDecoration
//
&AtServer
Function AddReportOptionItems(FillParameters, Variant, ToGroup, NestingLevel = 0)
	
	// Unique name of an item to be added.
	LabelName = "Variant_" + ReportsServer.CastIDToName(Variant.Ref.UUID());
	If ValueIsFilled(Variant.Subsystem) Then
		LabelName = LabelName
			+ "_Subsystem_"
			+ ReportsServer.CastIDToName(Variant.Subsystem.UUID());
	EndIf;
	If Not FillParameters.CurrentSectionOnly And Items.Find(LabelName) <> Undefined Then
		If ValueIsFilled(Variant.SectionReference) Then
			Number = 0;
			Suffix = "_Section_" + ReportsServer.CastIDToName(Variant.SectionReference.UUID());
		Else
			Number = 1;
			Suffix = "_1";
		EndIf;
		While Items.Find(LabelName + Suffix) <> Undefined Do
			Number = Number + 1;
			Suffix = "_" + XMLString(Number);
		EndDo;
		LabelName = LabelName + Suffix;
	EndIf;
	
	If SetupMode Then
		OptionGroupName = "Group_" + LabelName;
		VariantGroup = Items.Insert(OptionGroupName, Type("FormGroup"), ToGroup);
		FillPropertyValues(VariantGroup, FillParameters.Templates.VariantGroup);
	Else
		VariantGroup = ToGroup;
	EndIf;
	
	// Add a check box (not used for quick access).
	If SetupMode Then
		CheckBoxName1 = "CheckBox_" + LabelName;
		
		FormAttribute = New FormAttribute(CheckBoxName1, New TypeDescription("Boolean"), , , False);
		FillParameters.AttributesToBeAdded.Add(FormAttribute);
		
		CheckBox = Items.Insert(CheckBoxName1, Type("FormField"), VariantGroup);
		CheckBox.Type = FormFieldType.CheckBoxField;
		CheckBox.TitleLocation = FormItemTitleLocation.None;
		CheckBox.Visible = (FillParameters.GroupName <> "QuickAccess");
		CheckBox.SetAction("OnChange", "Attachable_OptionVisibilityOnChange");
	EndIf;
	
	// Add a report option hyperlink title.
	Label = Items.Insert(LabelName, Type("FormDecoration"), VariantGroup);
	FillPropertyValues(Label, FillParameters.Templates.OptionLabel);
	Label.Title = TrimAll(Variant.Description);
	If ValueIsFilled(Variant.LongDesc) Then
		Label.ToolTip = TrimAll(Variant.LongDesc);
	EndIf;
	If ValueIsFilled(Variant.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("en = 'Author:';") + " " + TrimAll(String(Variant.Author));
	EndIf;
	Label.SetAction("Click", "Attachable_OptionClick");
	If Not Variant.Visible Then
		Label.TextColor = HiddenOptionsColor;
	ElsIf Not Variant.VisibilityByAssignment Then
		Label.TextColor = ColorOfHiddenOptionsByAssignment;
	EndIf;
	If Variant.Important
		And FillParameters.GroupName <> "SeeAlso"
		And FillParameters.GroupName <> "QuickAccess" Then
		Label.Font = FontImportantLabel;
	EndIf;
	Label.AutoMaxWidth = False;
	
	TooltipContent = New Array;
	DefineOptionTooltipContent(FillParameters, Variant, TooltipContent, Label);
	OutputOptionTooltip(Label, TooltipContent);
	
	If SetupMode Then
		For Each KeyAndValue In FillParameters.ContextMenu Do
			NameOfCommand = KeyAndValue.Key;
			ButtonName = NameOfCommand + "_" + LabelName;
			Button = Items.Insert(ButtonName, Type("FormButton"), Label.ContextMenu);
			If Common.IsWebClient() Then
				Command = Commands.Add(ButtonName);
				FillPropertyValues(Command, Commands[NameOfCommand]);
				Button.CommandName = ButtonName;
			Else
				Button.CommandName = NameOfCommand;
			EndIf;
			FillPropertyValues(Button, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	// Register the added label.
	TableRow = AddedOptions.Add();
	FillPropertyValues(TableRow, Variant);
	TableRow.Level2GroupName     = FillParameters.GroupName;
	TableRow.LabelName           = LabelName;
	
	FillParameters.SearchForOptions[LabelName] = TableRow.GetID();
	
	Return Label;
	
EndFunction

// Parameters:
//  FillParameters - See ReportsOptions.ReportOptionsToShow
//  Variant - ValueTableRow:
//    * SubordinateCount - Number
//  TooltipContent - Array
//  Label - FormGroup
//          - FormButton
//          - FormTable
//          - FormField
//          - FormDecoration
//
&AtServer
Procedure DefineOptionTooltipContent(FillParameters, Variant, TooltipContent, Label)
	TooltipIsOutput = False;
	If FillParameters.UseHighlighting Then
		HighlightParameters = FillParameters.SearchResult.OptionsHighlight.Get(Variant.Ref); // Structure
		If HighlightParameters <> Undefined Then
			If HighlightParameters.OptionDescription.FoundWordsCount > 0 Then
				Label.Title = GenerateRowWithHighlighting(HighlightParameters.OptionDescription);
			EndIf;
			If HighlightParameters.LongDesc.FoundWordsCount > 0 Then
				GenerateRowWithHighlighting(HighlightParameters.LongDesc, TooltipContent);
				TooltipIsOutput = True;
			EndIf;
			If HighlightParameters.AuthorPresentation1.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("en = 'Author:';") + " ");
				GenerateRowWithHighlighting(HighlightParameters.AuthorPresentation1, TooltipContent);
				TooltipContent.Add(".");
				TooltipIsOutput = True;
			EndIf;
			If HighlightParameters.UserSettingsDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("en = 'Saved setting:';") + " ");
				GenerateRowWithHighlighting(HighlightParameters.UserSettingsDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipIsOutput = True;
			EndIf;
			If HighlightParameters.FieldDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("en = 'Fields:';") + " ");
				GenerateRowWithHighlighting(HighlightParameters.FieldDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipIsOutput = True;
			EndIf;
			If HighlightParameters.FilterParameterDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("en = 'Settings:';") + " ");
				GenerateRowWithHighlighting(HighlightParameters.FilterParameterDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipIsOutput = True;
			EndIf;
			If HighlightParameters.Keywords.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("en = 'Keywords:';") + " ");
				GenerateRowWithHighlighting(HighlightParameters.Keywords, TooltipContent);
				TooltipContent.Add(".");
				TooltipIsOutput = True;
			EndIf;
		EndIf;
	EndIf;
	If Not TooltipIsOutput And ShowTooltips Then
		TooltipContent.Add(TrimAll(Label.ToolTip));
	EndIf;
EndProcedure

&AtServer
Procedure OutputOptionTooltip(Label, TooltipContent)
	If TooltipContent.Count() = 0 Then
		Return;
	EndIf;
	
	Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	
	ToolTip = Label.ExtendedTooltip;
	ToolTip.Title                = New FormattedString(TooltipContent);
	ToolTip.TextColor               = TooltipColor;
	ToolTip.AutoMaxHeight   = False;
	ToolTip.MaxHeight       = 3;
	ToolTip.HorizontalStretch = True;
	ToolTip.AutoMaxWidth   = False;
	ToolTip.MaxWidth       = 0;
EndProcedure

&AtServer
Function GenerateRowWithHighlighting(SearchArea, Content = Undefined)
	ReturnFormattedRow = False;
	If Content = Undefined Then
		ReturnFormattedRow = True;
		Content = New Array;
	EndIf;
	
	SourceText = SearchArea.Value;
	TextIsShortened = False;
	TextLength = StrLen(SourceText);
	If TextLength > 150 Then
		TextIsShortened = ShortenText(SourceText, TextLength, 150);
	EndIf;
	
	SearchArea.WordHighlighting.SortByValue(SortDirection.Asc);
	CountOpen = 0;
	NormalTextStartPosition = 1;
	HighlightStartPosition = 0;
	For Each ListItem In SearchArea.WordHighlighting Do
		If TextIsShortened And ListItem.Value > TextLength Then
			ListItem.Value = TextLength; // If a text was shortened, adjusting highlighting.
		EndIf;
		Highlight = (ListItem.Presentation = "+");
		CountOpen = CountOpen + ?(Highlight, 1, -1);
		If Highlight And CountOpen = 1 Then
			HighlightStartPosition = ListItem.Value;
			NormalTextFragment = Mid(SourceText, NormalTextStartPosition, HighlightStartPosition - NormalTextStartPosition);
			Content.Add(NormalTextFragment);
		ElsIf Not Highlight And CountOpen = 0 Then
			NormalTextStartPosition = ListItem.Value;
			FragmentToHighlight = Mid(SourceText, HighlightStartPosition, NormalTextStartPosition - HighlightStartPosition);
			Content.Add(New FormattedString(FragmentToHighlight, , , SearchResultsHighlightColor));
		EndIf;
	EndDo;
	If NormalTextStartPosition <= TextLength Then
		NormalTextFragment = Mid(SourceText, NormalTextStartPosition);
		Content.Add(NormalTextFragment);
	EndIf;
	
	If ReturnFormattedRow Then
		Return New FormattedString(Content); // ACC:1356 Don't create a new string. Instead, process the existing string.
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function ShortenText(Text, CurrentLength, LengthLimit)
	ESPosition = StrFind(Text, Chars.LF, SearchDirection.FromEnd, LengthLimit);
	PointPosition = StrFind(Text, ".", SearchDirection.FromEnd, LengthLimit);
	CommaPosition = StrFind(Text, ",", SearchDirection.FromEnd, LengthLimit);
	SemicolonPosition = StrFind(Text, ",", SearchDirection.FromEnd, LengthLimit);
	Position = Max(ESPosition, PointPosition, CommaPosition, SemicolonPosition);
	If Position = 0 Then
		ESPosition = StrFind(Text, Chars.LF, SearchDirection.FromBegin, LengthLimit);
		PointPosition = StrFind(Text, ".", SearchDirection.FromBegin, LengthLimit);
		CommaPosition = StrFind(Text, ",", SearchDirection.FromBegin, LengthLimit);
		SemicolonPosition = StrFind(Text, ",", SearchDirection.FromBegin, LengthLimit);
		Position = Min(ESPosition, PointPosition, CommaPosition, SemicolonPosition);
	EndIf;
	If Position = 0 Or Position = CurrentLength Then
		Return False;
	EndIf;
	Text = Left(Text, Position) + " ...";
	CurrentLength = Position;
	Return True;
EndFunction

&AtServer
Function AddBlankDecoration(FillParameters, ToGroup)
	
	FillParameters.EmptyDecorationsAdded = FillParameters.EmptyDecorationsAdded + 1;
	DecorationName = "BlankDecoration_" + Format(FillParameters.EmptyDecorationsAdded, "NG=0");
	
	Decoration = Items.Insert(DecorationName, Type("FormDecoration"), ToGroup);
	Decoration.Type = FormDecorationType.Label;
	Decoration.Title = " ";
	Decoration.HorizontalStretch = True;
	
	Return Decoration;
	
EndFunction

&AtClient
Procedure MobileApplicationDetailsClick(Item)
	
	FormParameters = ClientParameters.MobileApplicationDetails;
	OpenForm(FormParameters.FormName, FormParameters.FormParameters, ThisObject); 
	
EndProcedure

#EndRegion
