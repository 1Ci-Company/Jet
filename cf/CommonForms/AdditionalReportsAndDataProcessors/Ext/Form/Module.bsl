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
Var CommandToExecute;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Parameters.SectionName)
		And Parameters.SectionName <> AdditionalReportsAndDataProcessorsClientServer.StartPageName() Then
		SectionRef = Common.MetadataObjectID(Metadata.Subsystems.Find(Parameters.SectionName));
	EndIf;
	
	DataProcessorsKind = AdditionalReportsAndDataProcessors.GetDataProcessorKindByKindStringPresentation(Parameters.Kind);
	If DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		AreAssignableDataProcessors = True;
		Title = NStr("en = 'Object filling commands';");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		AreAssignableDataProcessors = True;
		AreReports = True;
		Title = NStr("en = 'Reports';");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		AreAssignableDataProcessors = True;
		Title = NStr("en = 'Additional print forms';");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		AreAssignableDataProcessors = True;
		Title = NStr("en = 'Create related objects commands';");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		AreGlobalDataProcessors = True;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Additional data processors (%1)';"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(SectionRef));
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		AreGlobalDataProcessors = True;
		AreReports = True;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Additional reports (%1)';"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(SectionRef));
	EndIf;
	
	If ValueIsFilled(Parameters.WindowOpeningMode) Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	EndIf;
	
	If AreAssignableDataProcessors Then
		Items.CustomizeList.Visible = False;
		
		RelatedObjects.LoadValues(Parameters.RelatedObjects.UnloadValues());
		If RelatedObjects.Count() = 0 Then
			Cancel = True;
			Return;
		EndIf;
		
		OwnerInfo = AdditionalReportsAndDataProcessorsCached.AssignedObjectFormParameters(Parameters.FormName);
		ParentMetadata = Metadata.FindByType(TypeOf(RelatedObjects[0].Value));
		If ParentMetadata = Undefined Then
			ParentRef = OwnerInfo.ParentRef;
		Else
			ParentRef = Common.MetadataObjectID(ParentMetadata);
		EndIf;
		If TypeOf(OwnerInfo) = Type("FixedStructure") Then
			IsObjectForm = OwnerInfo.IsObjectForm;
		Else
			IsObjectForm = False;
		EndIf;
	EndIf;
	
	FillDataProcessorsTable();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If ValueSelected = "MyReportsAndDataProcessorsSetupDone" Then
		FillDataProcessorsTable();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersCommandsTable

&AtClient
Procedure CommandsTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	RunDataProcessorByParameters();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExecuteProcessing(Command)
	
	RunDataProcessorByParameters()
	
EndProcedure

&AtClient
Procedure CustomizeList(Command)
	FormParameters = New Structure("DataProcessorsKind, SectionRef");
	FillPropertyValues(FormParameters, ThisObject);
	OpenForm("CommonForm.MyReportsAndDataProcessorsSettings", FormParameters, ThisObject, False);
EndProcedure

&AtClient
Procedure CancelDataProcessorExecution(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillDataProcessorsTable()
	CommandsTypes = New Array;
	CommandsTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ClientMethodCall);
	CommandsTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall);
	CommandsTypes.Add(Enums.AdditionalDataProcessorsCallMethods.OpeningForm);
	CommandsTypes.Add(Enums.AdditionalDataProcessorsCallMethods.SafeModeScenario);
	
	Query = AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(DataProcessorsKind, ?(AreGlobalDataProcessors, SectionRef, ParentRef), IsObjectForm, CommandsTypes);
	ResultTable1 = Query.Execute().Unload();
	CommandsTable.Load(ResultTable1);
EndProcedure

&AtClient
Procedure RunDataProcessorByParameters()
	DataProcessorData = Items.CommandsTable.CurrentData;
	If DataProcessorData = Undefined Then
		Return;
	EndIf;
	
	CommandToExecute = New Structure(
		"Ref, Presentation, 
		|Id, StartupOption, ShouldShowUserNotification, 
		|Modifier, RelatedObjects, IsReport, Kind");
	FillPropertyValues(CommandToExecute, DataProcessorData);
	If Not AreGlobalDataProcessors Then
		CommandToExecute.RelatedObjects = RelatedObjects.UnloadValues();
	EndIf;
	CommandToExecute.IsReport = AreReports;
	CommandToExecute.Kind = DataProcessorsKind;
	
	If DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm") Then
		
		AdditionalReportsAndDataProcessorsClient.OpenDataProcessorForm(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		
	ElsIf DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall") Then
		
		AdditionalReportsAndDataProcessorsClient.ExecuteDataProcessorClientMethod(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		
	ElsIf DataProcessorsKind = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.PrintForm")
		And DataProcessorData.Modifier = "PrintMXL1" Then
		
		AdditionalReportsAndDataProcessorsClient.ExecutePrintFormOpening(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		
	ElsIf DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		Or DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.SafeModeScenario") Then
		
		// Change form items.
		Items.ExplainingDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Executing command ""%1""…';"),
			DataProcessorData.Presentation);
		Items.Pages.CurrentPage = Items.DataProcessorExecutionPage;
		Items.CustomizeList.Visible = False;
		Items.ExecuteProcessing.Visible = False;
		
		// Delaying the server call until the form state becomes consistent.
		AttachIdleHandler("ExecuteDataProcessorServerMethod", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataProcessorServerMethod()
	
	Job = RunBackgroundJob1(CommandToExecute, UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("ExecuteDataProcessorServerMethodCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServerNoContext
Function RunBackgroundJob1(Val CommandToExecute, Val UUID)
	MethodName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Additional reports and data processors: executing command %1.';"),
		CommandToExecute.Presentation);
	
	StartSettings1.RefinementErrors = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot execute the command. Reason: %1.';"),
		CommandToExecute.Presentation);
	
	MethodParameters = New Structure("AdditionalDataProcessorRef, CommandID, RelatedObjects");
	MethodParameters.AdditionalDataProcessorRef = CommandToExecute.Ref;
	MethodParameters.CommandID          = CommandToExecute.Id;
	MethodParameters.RelatedObjects             = CommandToExecute.RelatedObjects;
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings1);
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ExecuteDataProcessorServerMethodCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		If IsOpen() Then
			Close();
		EndIf;
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	EndIf;
		
	// Showing a pop-up notification and closing this form.
	If CommandToExecute.ShouldShowUserNotification Then
		ShowUserNotification(NStr("en = 'The operation is completed.';"),, CommandToExecute.Presentation);
	EndIf;
	If IsOpen() Then
		Close();
	EndIf;
	
	// Refresh owner form.
	If IsObjectForm Then
		Try
			FormOwner.Read();
		Except
			// No action required.
		EndTry;
	EndIf;
	
	// Notify other forms.
	ExecutionResult = GetFromTempStorage(Result.ResultAddress);
	NotifyForms = CommonClientServer.StructureProperty(ExecutionResult, "NotifyForms");
	If NotifyForms <> Undefined Then
		StandardSubsystemsClient.NotifyFormsAboutChange(NotifyForms);
	EndIf;
	
EndProcedure

#EndRegion