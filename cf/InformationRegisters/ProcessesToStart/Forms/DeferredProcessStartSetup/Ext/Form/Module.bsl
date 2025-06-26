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
	
	If Not ValueIsFilled(Parameters.BusinessProcess) Then
		Cancel = True;
	EndIf;
	
	BusinessProcess = Parameters.BusinessProcess;
	TaskDueDate = Parameters.TaskDueDate;
	
	// Populate settings.
	FillFormAttributes();
	// Specifying setting availability.
	SetFormItemsProperties();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshIntervalRepresentation();
	UpdateTimeSelectionList();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PostponedProcessStartOnChange(Item)
	
	SetDeferredProcessStartState();
	
EndProcedure

&AtClient
Procedure DeferredStartDateOnChange(Item)
	
	OnChangeDateTime();
	
EndProcedure

&AtClient
Procedure DeferredStartDateTimeOnChange(Item)
	
	OnChangeDateTime();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Done(Command)
	
	If FormIsFilledInCorrectly() Then
		WriteSettingsOnClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnChangeDateTime()

	RefreshIntervalRepresentation();
	UpdateTimeSelectionList();

EndProcedure

// Writes settings.
//
&AtClient
Procedure WriteSettingsOnClient()
	
	SaveSettings1();
	Close();
	
	DeferredStartSettings = New Structure;
	DeferredStartSettings.Insert("BusinessProcess", BusinessProcess);
	DeferredStartSettings.Insert("Defer", PostponedProcessStart);
	DeferredStartSettings.Insert("DeferredStartDate", DeferredStartDate);
	DeferredStartSettings.Insert("State", State);
	
	Notify("DeferredStartSettingsChanged", DeferredStartSettings);
	
	If PostponedProcessStart <> DeferredProcessStartOnOpen Then 
		
		NotificationText1 = ?(PostponedProcessStart, NStr("en = 'Deferred start:';"), NStr("en = 'Deferred start canceled:';"));
		ProcessURL = GetURL(BusinessProcess);
		
		ShowUserNotification(
			NotificationText1,
			ProcessURL,
			BusinessProcess,
			PictureLib.Information32);
			
		NotifyChanged(BusinessProcess);
		NotifyChanged(Type("InformationRegisterRecordKey.BusinessProcessesData"));
			
	EndIf;
	
EndProcedure

// Fills in the State form attribute and sets availability of the DeferredStartDate
// and DeferredStartDateTime fields.
//
&AtServer
Procedure SetDeferredProcessStartState()
	
	If PostponedProcessStart Then
		State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart");
	Else
		State = PredefinedValue("Enum.ProcessesStatesForStart.EmptyRef");
	EndIf;
	
	SetFormItemsProperties();
	
EndProcedure

// Saves deferred start settings in the register.
//
&AtServer
Procedure SaveSettings1()
	
	If PostponedProcessStart Then
		BusinessProcessesAndTasksServer.AddProcessForDeferredStart(BusinessProcess, DeferredStartDate);
	Else
		BusinessProcessesAndTasksServer.DisableProcessDeferredStart(BusinessProcess);
	EndIf;
	
EndProcedure

// Fills in the DecorationInterval decoration title.
//
&AtClient
Procedure RefreshIntervalRepresentation()
	
	If Not ValueIsFilled(DeferredStartDate)
		Or ProcessIsStarted Then
		
		Items.IntervalDecoration.Title = "";
		Return;
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(
		Items,
		"IntervalDecoration",
		"Title",
		IntevalText(CurrentServerDate, DeferredStartDate));
			
EndProcedure

// Fills in the selection list for the DeferredStartDateTime form item with time
// values.
//
&AtClient
Procedure UpdateTimeSelectionList()
	
	Items.DeferredStartDateTime.ChoiceList.Clear();
	
	DateEmpty = BegOfDay(DeferredStartDate);
	
	For Indus = 1 To 48 Do
		Items.DeferredStartDateTime.ChoiceList.Add(DateEmpty, Format(DateEmpty, NStr("en = 'DF=HH:mm';")));
		DateEmpty = DateEmpty + 1800;
	EndDo;
	
EndProcedure

&AtClient
Function IntevalText(StartDate, EndDate)

	If StartDate > EndDate Then
		Return NStr("en = 'Duty start date is in the past.';");
	EndIf;	
	
	If UseDateAndTimeInTaskDeadlines Then
		NumberOfHours = Round((EndDate - StartDate) / (60*60));
		NumberOfDays = Round(NumberOfHours / 24);
		NumberOfHours = NumberOfHours - NumberOfDays * 24;
	Else
		NumberOfHours = 0;
		NumberOfDays = (BegOfDay(EndDate) - BegOfDay(StartDate)) / (60*60*24);
	EndIf;
		
	If NumberOfHours < 0 Then
		NumberOfDays = NumberOfDays - 1;
		NumberOfHours = NumberOfHours + 24;
	EndIf;
	
	DateDiff = "";
	If UseDateAndTimeInTaskDeadlines Then
		If NumberOfDays > 0 And NumberOfHours > 0 Then
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The duty will be started in %1 days and %2 hours.';"),
				String(NumberOfDays),
				String(NumberOfHours));
		ElsIf NumberOfDays > 0 Then
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The duty will be started in %1 days.';"), String(NumberOfDays));
		ElsIf NumberOfHours > 0 Then
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The duty will be started in %1 hours.';"), String(NumberOfHours));
		Else
			DateDiff = NStr("en = 'The duty will be started in less than an hour.';");
		EndIf;
	Else
		If NumberOfDays > 0 Then
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The duty will be started in %1 days.';"), String(NumberOfDays));
		Else
			DateDiff = NStr("en = 'The duty will be started in less than a day.';");
		EndIf;
	EndIf;
	
	Return DateDiff;
	
EndFunction

&AtServer
Procedure FillFormAttributes()
	
	ProcessAttributes = Common.ObjectAttributesValues(
		Parameters.BusinessProcess, "Started, Completed");
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	CurrentServerDate = CurrentSessionDate();
	
	ProcessIsStarted = ProcessAttributes.Started;
	ProcessCompleted = ProcessAttributes.Completed;
	
	Setting = BusinessProcessesAndTasksServer.DeferredProcessParameters(Parameters.BusinessProcess);
	
	If ValueIsFilled(Setting) Then
		// If the process is already deferred, filling the attributes for it.
		FillPropertyValues(ThisObject, Setting);
		
		PostponedProcessStart = (Setting.State = Enums.ProcessesStatesForStart.ReadyToStart);
		DeferredProcessStartOnOpen = PostponedProcessStart;
		
	ElsIf Not ProcessIsStarted Then
		// If it is not deferred, filling with default values.
		DeferredProcessStartOnOpen = False;
		PostponedProcessStart = True;
		DeferredStartDate = BegOfDay(CurrentSessionDate() + 86400);
		State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemsProperties()
	
	CommonClientServer.SetFormItemProperty(
		Items,
		"PostponedProcessStart",
		"ReadOnly",
		ProcessIsStarted);
	CommonClientServer.SetFormItemProperty(
		Items,
		"GroupInfoLabel",
		"Visible",
		ProcessIsStarted);
		
	If ProcessIsStarted Then
		Items.CommandsPages.CurrentPage = Items.ProcessIsStartedPage;
		CommonClientServer.SetFormItemProperty(Items, "Close", "DefaultButton", True);

		If ProcessCompleted Then
			Items.FooterPages.CurrentPage = Items.JobIsCompletedPage;
		Else
			Items.FooterPages.CurrentPage = Items.JobStartedPage;
		EndIf;
	Else
		Items.CommandsPages.CurrentPage = Items.ProcessIsNotStartedPage;
		CommonClientServer.SetFormItemProperty(Items, "Done", "DefaultButton", True);
		
		If State = PredefinedValue("Enum.ProcessesStatesForStart.StartCanceled") Then
			Items.FooterPages.CurrentPage = Items.CancelStartPage;
		Else
			Items.FooterPages.CurrentPage = Items.EmptyPage;
		EndIf;
	EndIf;
		
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDate",
		"ReadOnly",
		ProcessIsStarted Or Not PostponedProcessStart);
		
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDateTime",
		"Visible",
		UseDateAndTimeInTaskDeadlines);
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDateTime",
		"ReadOnly",
		ProcessIsStarted Or Not PostponedProcessStart);
		
EndProcedure

&AtClient
Function FormIsFilledInCorrectly()
	
	FilledInCorrectly = True;
	ClearMessages();
	
	If PostponedProcessStart And DeferredStartDate < CurrentServerDate Then
		CommonClient.MessageToUser(NStr("en = 'Date and time of the deferred start must be greater than the current date.';"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
		
	If PostponedProcessStart And DeferredStartDate > TaskDueDate Then
		CommonClient.MessageToUser(NStr("en = 'Date and time of the deferred start must be less than the duty due date.';"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
	
	Return FilledInCorrectly;
	
EndFunction

#EndRegion

