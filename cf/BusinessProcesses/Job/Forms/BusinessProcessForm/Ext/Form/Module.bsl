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
Var PerformerChoiceFormOpened;  // Flag showing that the assignee is selected in a form (without using quick input).
&AtClient
Var SupervisorChoiceFormOpened; // Flag showing that the supervisor is selected in a form (without using quick input).
&AtClient
Var ChoiceContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// For new objects, run the form initializer in "OnCreateAtServer".
	// For existing objects, in "OnReadAtServer".
	If Object.Ref.IsEmpty() Then
		InitializeTheForm();
	EndIf;
	
	// StandardSubsystems.StoredFiles
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FilesHyperlink = ModuleFilesOperations.FilesHyperlink();
		FilesHyperlink.Location = "CommandBar";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, FilesHyperlink);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	RefreshStopCommandsAvailability();
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	InitializeTheForm();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)

	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectPerformerRole") Then

		If ChoiceContext = "PerformerOnChange" Then

			If TypeOf(ValueSelected) = Type("Structure") Then
				Object.Performer = ValueSelected.PerformerRole;
			EndIf;

			SetSupervisorAvailability(ThisObject);

		ElsIf ChoiceContext = "SupervisorOnChange" Then

			If TypeOf(ValueSelected) = Type("Structure") Then
				Object.Supervisor = ValueSelected.PerformerRole;
			EndIf;

		EndIf;

	EndIf;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName = "DeferredStartSettingsChanged" Then
		Defer = (Parameter.Defer 
			And Parameter.State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart"));
		DeferredStartDate = Parameter.DeferredStartDate;
		SetFormItemsProperties(ThisObject);
		If Items.StateGroup.Visible Then
			HelpTextTitle = StringFunctionsClient.FormattedString(JobStatusMessage(ThisObject));
			Items.HelpTextTitle.Height = ?(StrLen(HelpTextTitle) > 80, 2, 1);
		EndIf;
	EndIf;
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CheckDeferredProcessEndDate(CurrentObject, Cancel);
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)

	ChangeJobsBackdated = GetFunctionalOption("ChangeJobsBackdated");
	If InitialStartFlag And ChangeJobsBackdated Then
		SetPrivilegedMode(True);
		CurrentObject.ChangeUncompletedTasksAttributes();
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_Job", WriteParameters, Object.Ref);
	Notify("Write_PerformerTask", WriteParameters, Undefined);
	If WriteParameters.Property("Start") And WriteParameters.Start Then
		AttachIdleHandler("UpdateForm", 0.2, True);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateForm()
	SetFormItemsProperties(ThisObject);
	If Items.StateGroup.Visible Then
		HelpTextTitle = StringFunctionsClient.FormattedString(JobStatusMessage(ThisObject));
		Items.HelpTextTitle.Height = ?(StrLen(HelpTextTitle) > 80, 2, 1);
	EndIf;
	RefreshStopCommandsAvailability();
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnValidationOnChange(Item)

	SetSupervisorAvailability(ThisObject);

EndProcedure

&AtClient
Procedure SubjectOfClick(Item, StandardProcessing)

	StandardProcessing = False;
	ShowValue(, Object.SubjectOf);

EndProcedure

&AtClient
Procedure MainTaskClick(Item, StandardProcessing)

	StandardProcessing = False;
	ShowValue(, Object.MainTask);

EndProcedure

&AtClient
Procedure HelpTextTitleURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	OpenDeferredStartSetup();
EndProcedure

&AtClient
Procedure PerformerStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	BusinessProcessesAndTasksClient.SelectPerformer(Item, Object.Performer);

EndProcedure

&AtClient
Procedure PerformerOnChange(Item)

	If PerformerChoiceFormOpened = True Then
		Return;
	EndIf;

	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;

	If TypeOf(Object.Performer) = Type("CatalogRef.PerformerRoles") And ValueIsFilled(Object.Performer) Then

		If UsedByAddressingObjects(Object.Performer) Then

			ChoiceContext = "PerformerOnChange";

			FormParameters = BusinessProcessesAndTasksClient.PerformerRoleChoiceFormParameters(Object.Performer,
				MainAddressingObject, AdditionalAddressingObject);
	
			BusinessProcessesAndTasksClient.OpenPerformerRoleChoiceForm(FormParameters, ThisObject);

			Return;

		EndIf;

	EndIf;

	SetSupervisorAvailability(ThisObject);

EndProcedure

&AtClient
Procedure PerformerChoiceProcessing(Item, ValueSelected, StandardProcessing)

	PerformerChoiceFormOpened = TypeOf(ValueSelected) = Type("Structure");
	If PerformerChoiceFormOpened Then
		StandardProcessing = False;
		Object.Performer = ValueSelected.PerformerRole;
		Object.MainAddressingObject = ValueSelected.MainAddressingObject;
		Object.AdditionalAddressingObject = ValueSelected.AdditionalAddressingObject;
		Modified = True;
	EndIf;

EndProcedure

&AtClient
Procedure PerformerAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)

	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;

EndProcedure

&AtClient
Procedure PerformerTextEditEnd(Item, Text, ChoiceData, StandardProcessing)

	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;

EndProcedure

&AtClient
Procedure SupervisorStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	BusinessProcessesAndTasksClient.SelectPerformer(Item, Object.Supervisor);

EndProcedure

&AtClient
Procedure SupervisorOnChange(Item)

	If SupervisorChoiceFormOpened = True Then
		Return;
	EndIf;

	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;

	If TypeOf(Object.Supervisor) = Type("CatalogRef.PerformerRoles") And ValueIsFilled(Object.Supervisor) Then

		If UsedByAddressingObjects(Object.Supervisor) Then

			ChoiceContext = "SupervisorOnChange";

			FormParameters = BusinessProcessesAndTasksClient.PerformerRoleChoiceFormParameters(Object.Supervisor,
				MainAddressingObject, AdditionalAddressingObject);
	
			BusinessProcessesAndTasksClient.OpenPerformerRoleChoiceForm(FormParameters, ThisObject);

		EndIf;

	EndIf;

EndProcedure

&AtClient
Procedure SupervisorChoiceProcessing(Item, ValueSelected, StandardProcessing)

	SupervisorChoiceFormOpened = TypeOf(ValueSelected) = Type("Structure");
	If SupervisorChoiceFormOpened Then
		StandardProcessing = False;
		Object.Supervisor = ValueSelected.PerformerRole;
		Object.MainAddressingObjectSupervisor = ValueSelected.MainAddressingObject;
		Object.AdditionalAddressingObjectSupervisor = ValueSelected.AdditionalAddressingObject;
		Modified = True;
	EndIf;

EndProcedure

&AtClient
Procedure SupervisorAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)

	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;

EndProcedure

&AtClient
Procedure SupervisorTextEditEnd(Item, Text, ChoiceData, StandardProcessing)

	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;

EndProcedure

&AtClient
Procedure TaskDueDateOnChange(Item)
	If Object.TaskDueDate = BegOfDay(Object.TaskDueDate) Then
		Object.TaskDueDate = EndOfDay(Object.TaskDueDate);
	EndIf;
EndProcedure

&AtClient
Procedure VerificationDueDateOnChange(Item)
	If Object.VerificationDueDate = BegOfDay(Object.VerificationDueDate) Then
		Object.VerificationDueDate = EndOfDay(Object.VerificationDueDate);
	EndIf;
EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_PreviewFieldCheckDragging(Item, DragParameters, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item, DragParameters,
			StandardProcessing);
	EndIf;

EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)

	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;

	Write();
	Close();

EndProcedure

&AtClient
Procedure Stop(Command)

	BusinessProcessesAndTasksClient.StopBusinessProcessFromObjectForm(ThisObject);
	RefreshStopCommandsAvailability();

EndProcedure

&AtClient
Procedure ContinueBusinessProcess(Command)

	BusinessProcessesAndTasksClient.ContinueBusinessProcessFromObjectForm(ThisObject);
	RefreshStopCommandsAvailability();

EndProcedure

&AtClient
Procedure SetUpDeferredStart(Command)
	OpenDeferredStartSetup();
EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;

EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Supervisor.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.OnValidation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Supervisor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Supervisor.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.OnValidation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Supervisor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	Item.Appearance.SetParameterValue("MarkIncomplete", False);

EndProcedure

&AtServer
Procedure InitializeTheForm()

	InitialStartFlag = Object.Started;

	SetDeferredStartAttributes();

	UseDateAndTimeInTaskDeadlines    = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	ChangeJobsBackdated           = GetFunctionalOption("ChangeJobsBackdated");
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");

	SubjectString = Common.SubjectString(Object.SubjectOf);

	If Object.MainTask = Undefined Or Object.MainTask.IsEmpty() Then
		MainTaskString = NStr("en = 'not specified';");
	Else
		MainTaskString = String(Object.MainTask);
	EndIf;

	SetFormItemsProperties(ThisObject);
	If Items.StateGroup.Visible Then
		HelpTextTitle = StringFunctions.FormattedString(JobStatusMessage(ThisObject));
		Items.HelpTextTitle.Height = ?(StrLen(HelpTextTitle) > 80, 2, 1);
	EndIf;

EndProcedure

&AtClient
Procedure RefreshStopCommandsAvailability()

	If Object.Completed Then

		Items.FormStop.Visible = False;
		Items.FormContinue.Visible = False;
		Return;

	EndIf;

	If Object.State = PredefinedValue("Enum.BusinessProcessStates.Suspended") Then
		Items.FormStop.Visible = False;
		Items.FormContinue.Visible = True;
	Else
		Items.FormStop.Visible = Object.Started;
		Items.FormContinue.Visible = False;
	EndIf;

EndProcedure

&AtClientAtServerNoContext
Procedure SetSupervisorAvailability(Form)

	FieldAvailability = Form.Object.OnValidation;
	Form.Items.SupervisorGroup.Enabled = FieldAvailability;

EndProcedure

&AtServerNoContext
Function UsedByAddressingObjects(ObjectToCheck)

	Return Common.ObjectAttributeValue(ObjectToCheck, "UsedByAddressingObjects");

EndFunction

&AtClientAtServerNoContext
Procedure SetFormItemsProperties(Form)

	If Form.ReadOnly Then
		Form.Items.FormStop.Visible               = False;
		Form.Items.FormWriteAndClose.Visible         = False;
		Form.Items.FormSetUpDeferredStart.Visible = False;
		Form.Items.FormWrite.Visible                 = False;
		Form.Items.FormContinue.Visible               = False;
	Else
		ObjectStarted = ObjectStarted(Form);

		Form.Items.DueDateTime.Visible             = Form.UseDateAndTimeInTaskDeadlines;
		Form.Items.DueDateVerificationTime.Visible               = Form.UseDateAndTimeInTaskDeadlines;
		Form.Items.Date.Format                               = ?(Form.UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
		Form.Items.SubjectOf.Hyperlink                       = Form.Object.SubjectOf <> Undefined
			And Not Form.Object.SubjectOf.IsEmpty();
		Form.Items.FormStartAndClose.Visible              = Not ObjectStarted;
		Form.Items.FormStartAndClose.DefaultButton      = Not ObjectStarted;
		Form.Items.FormStart.Visible                      = Not ObjectStarted;
		Form.Items.FormSetUpDeferredStart.Visible   = Not ObjectStarted;
		Form.Items.FormWriteAndClose.Visible           = ?(Form.Object.Completed, False, ObjectStarted);
		Form.Items.FormWrite.Visible                   = Not Form.Object.Completed;
		Form.Items.FormWriteAndClose.DefaultButton   = ObjectStarted;
		Form.Items.FormSetUpDeferredStart.Enabled = Not Form.Object.Started;

		If Form.Object.MainTask = Undefined Or Form.Object.MainTask.IsEmpty() Then
			Form.Items.MainTask.Hyperlink             = False;
		EndIf;

		If Not Form.UseSubordinateBusinessProcesses Then
			Form.Items.MainTask.Visible               = False;
		EndIf;
	EndIf;

	Form.Items.StateGroup.Visible = Form.Object.Completed Or ObjectStarted(Form);
	SetSupervisorAvailability(Form);

EndProcedure

&AtClientAtServerNoContext
Function JobStatusMessage(Form)

	StateText = "";

	If Form.Object.Completed Then
		EndDateAsString = ?(Form.UseDateAndTimeInTaskDeadlines, 
			Format(Form.Object.CompletedOn, "DLF=DT"), 
			Format(Form.Object.CompletedOn, "DLF=D"));
		TextString = ?(Form.Object.Completed2, 
			NStr("en = 'The duty is completed on %1.';"), NStr("en = 'The duty is canceled on %1.';"));
		StateText = StringFunctionsClientServer.SubstituteParametersToString(TextString, EndDateAsString);

		For Each Item In Form.Items Do
			If TypeOf(Item) <> Type("FormField") And TypeOf(Item) <> Type("FormGroup") Then
				Continue;
			EndIf;
			Item.ReadOnly = True;
		EndDo;

	ElsIf Form.Object.Started Then
		StateText = ?(Form.ChangeJobsBackdated, 
			NStr("en = 'Changes to the wording, priority, author, deadlines, and revision will take into effect immediately for the previous task.';"),
			NStr("en = 'Changes to the wording, priority, author, deadlines, and revision will not apply to the previous task.';"));
	ElsIf Form.Defer Then
		DeferredStartDateAsString = ?(Form.UseDateAndTimeInTaskDeadlines, Format(Form.DeferredStartDate,
			"DLF=DT"), Format(Form.DeferredStartDate, "DLF=D"));
		StateText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The duty will be started on <a href=""%1"">%2</a>';"), "OpenDeferredStartSetup",
			DeferredStartDateAsString);
	EndIf;

	Return StateText;

EndFunction

&AtServer
Procedure CheckDeferredProcessEndDate(ObjectToCheck, Cancel)

	If Not ValueIsFilled(ObjectToCheck.TaskDueDate) Then
		Return;
	EndIf;

	DeferredStartDate = BusinessProcessesAndTasksServer.ProcessDeferredStartDate(ObjectToCheck.Ref);

	If ObjectToCheck.TaskDueDate < DeferredStartDate Then
		Common.MessageToUser(
			NStr("en = 'The duty deadline must be later than the start date.';"),, 
			"TaskDueDate", "Object.TaskDueDate");
	EndIf;

EndProcedure

&AtClient
Procedure OpenDeferredStartSetup()

	If FormKeyAttributesAreFilledIn() Then
		BusinessProcessesAndTasksClient.SetUpDeferredStart(Object.Ref, Object.TaskDueDate);
	EndIf;

EndProcedure

&AtClient
Function FormKeyAttributesAreFilledIn()

	If Object.Started Then
		Return True;
	EndIf;

	ClearMessages();

	FormAttributesAreFilledIn = True;
	If Not ValueIsFilled(Object.Performer) Then
		CommonClient.MessageToUser(NStr("en = 'Assignee is required.';"),, 
			"Performer", "Object.Performer");
		FormAttributesAreFilledIn = False;
	EndIf;
	If Not ValueIsFilled(Object.Description) Then
		CommonClient.MessageToUser(NStr("en = 'Duty is required.';"),, 
			"Performer", "Object.Description");
		FormAttributesAreFilledIn = False;
	EndIf;
	If Not ValueIsFilled(Object.TaskDueDate) Then
		CommonClient.MessageToUser(NStr("en = 'Due date is required.';"),,
			"TaskDueDate", "Object.TaskDueDate");
		FormAttributesAreFilledIn = False;
	EndIf;

	Return FormAttributesAreFilledIn;

EndFunction

&AtClientAtServerNoContext
Function ObjectStarted(Form)
	Return Form.Object.Started Or Form.Defer;
EndFunction

&AtServer
Procedure SetDeferredStartAttributes()

	DeferredStartDate = BusinessProcessesAndTasksServer.ProcessDeferredStartDate(Object.Ref);
	Defer = (DeferredStartDate <> '00010101');

EndProcedure

#EndRegion