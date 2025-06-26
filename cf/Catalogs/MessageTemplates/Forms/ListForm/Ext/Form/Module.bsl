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
	
	InitializeFilters();
	
	AvailableOptions = MessageTemplatesInternal.MessageTemplatesAvailableSendOutOptions();
	
	// buttons are in the group; if there is one button, the group is not required
	Items.FormCreateSMSMessageTemplate.Visible       = AvailableOptions.SMS;
	Items.FormCreateEmailTemplate.Visible = AvailableOptions.Mail;
	Items.FormShowContextTemplates.Visible = Users.IsFullUser();
	
	If Not AvailableOptions.SMS Then
		Items.FormCreateGroup.Type = FormGroupType.ButtonGroup;
		Items.FormCreateSMSMessageTemplate.Visible       = False;
		Items.FormCreateEmailTemplate.Title = NStr("en = 'Create';");
	EndIf;
	
	If Not AvailableOptions.Mail Then
		Items.FormCreateGroup.Type = FormGroupType.ButtonGroup;
		Items.FormCreateEmailTemplate.Visible = False;
		Items.FormCreateSMSMessageTemplate.Title       = NStr("en = 'Create';");
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.GroupDescriptionAndFiles.Group = ColumnsGroup.InCell;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_MessageTemplates" Then
		InitializeFilters();
		SetAssignmentFilter(Purpose);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AssignmentFilterOnChange(Item)
	SetAssignmentFilter(Purpose);
EndProcedure

&AtClient
Procedure TemplateForFilterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetSelectionInTheListOfTemplates(List, ValueSelected);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtServerNoContext
Procedure ListOnGetDataAtServer(TagName, Settings, Rows)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MessageTemplatesPrintedFormsAndAttachments.Ref AS Ref
		|FROM
		|	Catalog.MessageTemplates.PrintFormsAndAttachments AS MessageTemplatesPrintedFormsAndAttachments
		|WHERE
		|	MessageTemplatesPrintedFormsAndAttachments.Ref IN(&MessageTemplates)
		|
		|GROUP BY
		|	MessageTemplatesPrintedFormsAndAttachments.Ref";
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		
		Query.Text = Query.Text + "
		|UNION ALL
		|
		|SELECT
		|	MessageTemplatesAttachedFiles.FileOwner AS Ref
		|FROM
		|	Catalog.MessageTemplatesAttachedFiles AS MessageTemplatesAttachedFiles
		|WHERE
		|	MessageTemplatesAttachedFiles.FileOwner IN(&MessageTemplates)
		|
		|GROUP BY
		|	MessageTemplatesAttachedFiles.FileOwner";
		
	EndIf;
	
	Query.SetParameter("MessageTemplates", Rows.GetKeys());
	
	TemplatesWithAttachments = Query.Execute().Unload();
	TemplatesWithAttachments.GroupBy("Ref");
	For Each MessagesTemplate In TemplatesWithAttachments Do
		ListLine = Rows[MessagesTemplate.Ref];
		ListLine.Data["HasFiles"] = 1;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateEmailTemplate(Command)
	CreateTemplate("MailMessage");
EndProcedure

&AtClient
Procedure CreateSMSMessageTemplate(Command)
	CreateTemplate("SMSMessage");
EndProcedure

&AtClient
Procedure ShowContextTemplates(Command)
	Items.FormShowContextTemplates.Check = Not Items.FormShowContextTemplates.Check;
	List.Parameters.SetParameterValue("ShowContextTemplates", Items.FormShowContextTemplates.Check);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CreateTemplate(MessageType)
	FormParameters = New Structure();
	FormParameters.Insert("MessageKind",           MessageType);
	FormParameters.Insert("FullBasisTypeName", Purpose);
	FormParameters.Insert("CanChangeAssignment",  True);
	OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClientAtServerNoContext
Procedure SetSelectionInTheListOfTemplates(List, Val FilterValue)
	
	If FilterValue = MessageTemplatesClientServer.SMSTemplateName() Then
		CommonClientServer.SetFilterItem(List.Filter, "ForSMSMessages", True, DataCompositionComparisonType.Equal);
		CommonClientServer.SetFilterItem(List.Filter, "ForEmails", False, DataCompositionComparisonType.Equal);
	ElsIf FilterValue = MessageTemplatesClientServer.EmailTemplateName() Then
		CommonClientServer.SetFilterItem(List.Filter, "ForSMSMessages", False, DataCompositionComparisonType.Equal);
		CommonClientServer.SetFilterItem(List.Filter, "ForEmails", True, DataCompositionComparisonType.Equal);
	Else
		CommonClientServer.DeleteFilterItems(List.Filter, "ForSMSMessages");
		CommonClientServer.DeleteFilterItems(List.Filter, "ForEmails");
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAssignmentFilter(Val ValueSelected)
	
	If IsBlankString(ValueSelected) Then
		CommonClientServer.DeleteFilterItems(List.Filter, "Purpose");
	Else
		CommonClientServer.SetFilterItem(List.Filter, "Purpose", ValueSelected, DataCompositionComparisonType.Equal);
	EndIf;

EndProcedure

&AtServer
Procedure InitializeFilters()
	
	ShowContextTemplates = Items.FormShowContextTemplates.Check;
	
	Items.AssignmentFilter.ChoiceList.Clear();
	Items.TemplateForFilter.ChoiceList.Clear();
	
	List.Parameters.SetParameterValue("Purpose", "");
	
	TemplatesKinds = MessageTemplatesInternal.TemplatesKinds();
	TemplatesKinds.Insert(0,
		NStr("en = 'All messages';"),
		NStr("en = 'All messages';"));
	
	AvailableOptions = MessageTemplatesInternal.MessageTemplatesAvailableSendOutOptions();
	If AvailableOptions.SMS Then
		List.Parameters.SetParameterValue("SMSMessage", TemplatesKinds.FindByValue("SMS").Presentation);
	EndIf;
	If AvailableOptions.Mail Then
		List.Parameters.SetParameterValue("Email", TemplatesKinds.FindByValue("Email").Presentation);
	EndIf;
	List.Parameters.SetParameterValue("ShowContextTemplates", ShowContextTemplates);
	List.Parameters.SetParameterValue("Arbitrary", NStr("en = 'Arbitrary message';"));
	
	For Each TemplateKind In TemplatesKinds Do
		Items.TemplateForFilter.ChoiceList.Add(TemplateKind.Value, TemplateKind.Presentation);
	EndDo;
	
	Items.AssignmentFilter.ChoiceList.Add("", NStr("en = 'All';"));
	
	List.Parameters.SetParameterValue(MessageTemplatesClientServer.CommonID(),
		MessageTemplatesClientServer.CommonID());
	Items.AssignmentFilter.ChoiceList.Add(MessageTemplatesClientServer.CommonID(), 
		MessageTemplatesClientServer.SharedPresentation());
		
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	MessageTemplates.Purpose AS Purpose,
		|	MessageTemplates.InputOnBasisParameterTypeFullName AS InputOnBasisParameterTypeFullName
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.Purpose <> """" AND MessageTemplates.Purpose <> ""IsInternal""
		|	AND MessageTemplates.Purpose <> &Shared
		|
		|GROUP BY
		|	MessageTemplates.Purpose, MessageTemplates.InputOnBasisParameterTypeFullName
		|
		|ORDER BY
		|	Purpose";
	
	Query.SetParameter("Shared", MessageTemplatesClientServer.CommonID());
	QueryResult = Query.Execute().Select();
	
	OnDefineSettings =  MessageTemplatesInternalCached.OnDefineSettings();
	TemplatesSubjects = OnDefineSettings.TemplatesSubjects;
	While QueryResult.Next() Do
		FoundRow = TemplatesSubjects.Find(QueryResult.InputOnBasisParameterTypeFullName, "Name");
		Presentation = ?( FoundRow <> Undefined, FoundRow.Presentation, QueryResult.Purpose);
		
		Items.AssignmentFilter.ChoiceList.Add(QueryResult.InputOnBasisParameterTypeFullName, Presentation);
	EndDo;
	
	Purpose = "";
	TemplateFor = NStr("en = 'All messages';");
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Ref.TemplateOwner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Purpose.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Purpose");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = MessageTemplatesClientServer.CommonID();
	
	Item.Appearance.SetParameterValue("Text", MessageTemplatesClientServer.SharedPresentation());
	
	//
	OnDefineSettings =  MessageTemplatesInternalCached.OnDefineSettings();
	TemplatesSubjects = OnDefineSettings.TemplatesSubjects;
	
	For Each TemplateSubject In TemplatesSubjects Do
	
		Item = List.ConditionalAppearance.Items.Add();
		
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(Items.Purpose.Name);
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("Purpose");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = TemplateSubject.Name;
		
		Item.Appearance.SetParameterValue("Text", TemplateSubject.Presentation);
	
	EndDo;
	
EndProcedure

#EndRegion
