///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Checks whether the passed string is an internal URL.
//  
// Parameters:
//  String - String - URL.
//
// Returns:
//  Boolean - check result.
//
Function IsURL(String) Export
	
	Return StrStartsWith(String, "e1c:")
		Or StrStartsWith(String, "e1cib/")
		Or StrStartsWith(String, "e1ccs/");
	
EndFunction

// Converts startup parameters of the current session to the parameters to be passed to the script
// For example, you can start the application using the key:
// /C ExternalOperationStartupParameters=/TestClient -TPort 48050 /C DebugMode;DebugMode.
// In this case, the following string will be passed to the script: /TestClient -TPort 48050 /C DebugMode.
//
// Returns:
//  String - a parameter value.
//
Function EnterpriseStartupParametersFromScript() Export
	
	Var ParameterValue;
	
	StartupParameters = StringFunctionsClientServer.ParametersFromString(LaunchParameter);
	If Not StartupParameters.Property("ExternalOperationStartupParameters", ParameterValue) Then 
		ParameterValue = "";
	EndIf;
	
	Return ParameterValue;
	
EndFunction

#Region AddIns

// Add-in attachment context.
// 
// Returns:
//  Structure - Add-in attachment context:
//   * Notification - Undefined, NotifyDescription - notification.
//   * Id - String - an add-in object ID, add-in ID.
//   * Version - Undefined, String - an add-in version.
//   * Location - String - template location or an add-in reference.
//   * OriginalLocation - String - Initial call location, for cache storage.
//   * Cached - Boolean -  Flag indicating whether to save the attached add-in to the cache.
//                 If False, multiple add-in objects can be saved to memory (this might cause errors).
//                 By default, True.
//   * SuggestInstall - Boolean - prompt to install the add-in.
//   * WasInstallationAttempt - Boolean - Attachment attempt flag.
//   * SuggestToImport - Boolean - prompt to import the add-in from the ITS website.
//   * ExplanationText - String - a text that describes the add-in purpose and which functionality requires the add-in. 
//   * ObjectsCreationIDs - Array -the creation IDs of object module instances.
//                 Applicable only with add-ins that have a number of object creation IDs.
//                 Ignored if the ID parameter is specified.
//   * ASearchForANewVersionHasBeenPerformed - Boolean - a new add-in version was searched.
//   * Isolated - Boolean, Undefined - If True, the add-in is attached isolatedly (it is uploaded to a separate OS process).
//                If False, the add-in is executed in the same OS process that runs the 1C:Enterprise code.
//                If Undefined, the add-in is executed according to the default 1C:Enterprise settings
//                Isolatedly if the add-in supports only isolated execution; otherwise, non-isolatedly.:
//                By default, Undefined.
//                See https://its.1c.eu/db/v83doc
//                                           #bookmark:dev:TI000001866
//    * AutoUpdate - Boolean - Flag indicating whether UpdateFrom1CITSPortal will be set to True, 
//                if SuggestToImport is set to True. By default, True.
//
Function AddInAttachmentContext() Export
	
	Context = New Structure;
	Context.Insert("Notification", Undefined);
	Context.Insert("Id", Undefined);
	Context.Insert("Version", "");
	Context.Insert("Location", "");
	Context.Insert("OriginalLocation", "");
	Context.Insert("Cached", True);
	Context.Insert("SuggestInstall", True);
	Context.Insert("SuggestToImport", False);
	Context.Insert("AutoUpdate", True);
	Context.Insert("ExplanationText", "");
	Context.Insert("ObjectsCreationIDs", New Array);
	Context.Insert("ASearchForANewVersionHasBeenPerformed", False);
	Context.Insert("Isolated", Undefined);
	Context.Insert("WasInstallationAttempt", False);
	
	Return Context;
	
EndFunction

// Parameters:
//  Context - See AddInAttachmentContext.
//
Async Function AttachAddInSSLAsync(Context) Export
	
	If IsBlankString(Context.Id) Then 
		AddInContainsOneObjectClass = (Context.ObjectsCreationIDs.Count() = 0);
		
		If AddInContainsOneObjectClass Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot apply add-in ""%1"" in the client application
				           |due to:
				           |Either %2 or %3 must be specified.';"), 
				Context.Location, "Id", "ObjectsCreationIDs");
		Else
			// If an add-in has multiple object classes, "Id" is used only to
			// display the add-in in the error text. In this case, build an ID.
			// 
			Context.Id = StrConcat(Context.ObjectsCreationIDs, ", ");
		EndIf;
	EndIf;
	
	CheckTheLocationOfTheComponent(Context.Id, Context.Location); 
	
	If Not Context.ASearchForANewVersionHasBeenPerformed Then
		
		If Context.Cached Then

			AttachableModuleProperties = GetAddInObjectFromCache(Context.Location);

			If AttachableModuleProperties <> Undefined Then
				Result = AddInAttachmentResult();
				Result.Attached = True;
				Result.Attachable_Module = AttachableModuleProperties.Attachable_Module;
				Result.Location = AttachableModuleProperties.Location;
				Result.SymbolicName = AttachableModuleProperties.Name;
				Return Result;
			EndIf;

		// Checking the connection of the external add in in this session earlier.
			SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);

			If SymbolicName <> Undefined Then
		// If the cache already has a symbolic name, it means that the add-in has already been attached to this session.
				Attached = True;
				Context.Insert("SymbolicName", SymbolicName);
				Return Await AttachAddInSSLAfterAttachmentAttemptAsync(Attached, Context);
			EndIf;
			
		EndIf;
		
		// Search templates and the catalog for a newer version of the add-in.
		If IsTemplate(Context.Location) Then
			
			AddInSearchResult = Undefined;
			Context.OriginalLocation = Context.Location;
			
			If CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
				ModuleAddInsInternalClient = CommonClient.CommonModule(
					"AddInsInternalClient");

				ComponentValidationContext = AddInAttachmentContext();
				ComponentValidationContext.Id = Context.Id;
				ComponentValidationContext.Version = Undefined;
				ComponentValidationContext.SuggestInstall = Context.SuggestInstall;
				ComponentValidationContext.SuggestToImport = Context.SuggestToImport;
				ComponentValidationContext.AutoUpdate = Context.AutoUpdate;
				ComponentValidationContext.ExplanationText = Context.ExplanationText;
				ComponentValidationContext.OriginalLocation = Context.OriginalLocation;
				ComponentValidationContext.ObjectsCreationIDs = Context.ObjectsCreationIDs;

				AddInSearchResult = Await ModuleAddInsInternalClient.AddInAvailabilityCheckResult(
					ComponentValidationContext);
			
			EndIf;
			
			Context.ASearchForANewVersionHasBeenPerformed = True;
			If AddInSearchResult = Undefined Or AddInSearchResult.TheComponentOfTheLatestVersion = Undefined Then
				TheComponentOfTheLatestVersion = StandardSubsystemsServerCall.TheComponentOfTheLatestVersion(
					Context.Id, Context.OriginalLocation, Result);
			Else
				TheComponentOfTheLatestVersion = AddInSearchResult.TheComponentOfTheLatestVersion;
			EndIf;

			Context.Location = TheComponentOfTheLatestVersion.Location;
			Context.Version = TheComponentOfTheLatestVersion.Version;
			
			Return Await AttachAddInSSLAsync(Context);
				
		EndIf;
	EndIf;
	
	// Generate a unique name.
	SymbolicName = "From1" + StrReplace(String(New UUID), "-", "");
	Context.Insert("SymbolicName", SymbolicName);
	
	Try
		
#If MobileAppClient Or MobileClient Then
		Attached = Await AttachAddInAsync(Context.Location, SymbolicName);
#Else
		Attached = Await AttachAddInAsync(Context.Location, SymbolicName,,
			CommonInternalClientServer.AddInAttachType(Context.Isolated));
#EndIf
		
	Except
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach add-in ""%1"" on the client
			           |%2
			           |Reason:
			           |%3';"),
			Context.Id,
			Context.Location,
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		
		Return AddInAttachmentError(ErrorText);
		
	EndTry;
	
	Return Await AttachAddInSSLAfterAttachmentAttemptAsync(Attached, Context);
	
EndFunction

// Parameters:
//  Context - See AddInAttachmentContext.
//
Procedure AttachAddInSSL(Context) Export
	
	If IsBlankString(Context.Id) Then 
		AddInContainsOneObjectClass = (Context.ObjectsCreationIDs.Count() = 0);
		
		If AddInContainsOneObjectClass Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot apply add-in ""%1"" in the client application
				           |due to:
				           |Either %2 or %3 must be specified.';"), 
				Context.Location, "Id", "ObjectsCreationIDs");
		Else
			// If an add-in has multiple object classes, "Id" is used only to
			// display the add-in in the error text. In this case, build an ID.
			// 
			Context.Id = StrConcat(Context.ObjectsCreationIDs, ", ");
		EndIf;
	EndIf;
	
	CheckTheLocationOfTheComponent(Context.Id, Context.Location); 
	
	If Not Context.ASearchForANewVersionHasBeenPerformed Then
		
		If Context.Cached Then
			
			AttachableModuleProperties = GetAddInObjectFromCache(Context.Location);
			
			If AttachableModuleProperties <> Undefined Then
				AttachAddInSSLNotifyOnAttachment(AttachableModuleProperties, Context);
				Return;
			EndIf;

			// Checking the connection of the external add in in this session earlier.
			SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);

			If SymbolicName <> Undefined Then
					// If the cache already has a symbolic name, it means that the add-in has already been attached to this session.
				Attached = True;
				Context.Insert("SymbolicName", SymbolicName);
				AttachAddInSSLAfterAttachmentAttempt(Attached, Context);
				Return;
			EndIf;
		
		EndIf;
		
		// Search templates and the catalog for a newer version of the add-in.
		If IsTemplate(Context.Location) Then
			Context.OriginalLocation = Context.Location;
			Notification = New NotifyDescription("ConnectAfterSearchingForAnExternalComponent", ThisObject, Context);
			If CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
				ModuleAddInsInternalClient = CommonClient.CommonModule(
					"AddInsInternalClient");

				ComponentValidationContext = AddInAttachmentContext();
				ComponentValidationContext.Id = Context.Id;
				ComponentValidationContext.Version = Undefined;
				ComponentValidationContext.SuggestInstall = Context.SuggestInstall;
				ComponentValidationContext.SuggestToImport = Context.SuggestToImport;
				ComponentValidationContext.AutoUpdate = Context.AutoUpdate;
				ComponentValidationContext.ExplanationText = Context.ExplanationText;
				ComponentValidationContext.OriginalLocation = Context.OriginalLocation;
				ComponentValidationContext.ObjectsCreationIDs = Context.ObjectsCreationIDs;

				ModuleAddInsInternalClient.CheckAddInAvailability(Notification,
					ComponentValidationContext);
			Else
				ExecuteNotifyProcessing(Notification, Undefined);
			EndIf;
			Return;
		EndIf;
	EndIf;
	
	// Generate a unique name.
	SymbolicName = "From1" + StrReplace(String(New UUID), "-", "");
	Context.Insert("SymbolicName", SymbolicName);
	
	Notification = New NotifyDescription(
		"AttachAddInSSLAfterAttachmentAttempt", ThisObject, Context,
		"AttachAddInSSLOnProcessError", ThisObject);
	
#If MobileAppClient Or MobileClient Then
	BeginAttachingAddIn(Notification, Context.Location, SymbolicName);
#Else
	BeginAttachingAddIn(Notification, Context.Location, SymbolicName,,
		CommonInternalClientServer.AddInAttachType(Context.Isolated));
#EndIf
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLNotifyOnAttachment(AttachableModuleProperties, Context) Export
	
	Result = AddInAttachmentResult();
	Result.Attached = True;
	Result.Attachable_Module = AttachableModuleProperties.Attachable_Module;
	Result.SymbolicName = AttachableModuleProperties.Name;
	Result.Location = AttachableModuleProperties.Location;
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLNotifyOnError(ErrorDescription, Context, ShouldLogError = True) Export
	
	If Not IsBlankString(ErrorDescription) And ShouldLogError Then
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Attaching add-in on the client';", CommonClient.DefaultLanguageCode()),
			"Error", ErrorDescription,, True);
	EndIf;
		
	Notification = Context.Notification;
	Result = AddInAttachmentResult();
	Result.ErrorDescription = ErrorDescription;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Function AddInAttachmentResult() Export
	
	Result = New Structure;
	Result.Insert("Attached", False);
	Result.Insert("ErrorDescription", "");
	Result.Insert("Attachable_Module", Undefined);
	Result.Insert("Location", "");
	Result.Insert("SymbolicName", "");
	
	Return Result;
	
EndFunction

Function AddInAttachmentError(ErrorDescription, ShouldLogError = True) Export
	
	If Not IsBlankString(ErrorDescription) And ShouldLogError Then
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Attaching add-in on the client';", CommonClient.DefaultLanguageCode()),
			"Error", ErrorDescription,, True);
	EndIf;
		
	Result = AddInAttachmentResult();
	Result.ErrorDescription = ErrorDescription;
	Return Result;
	
EndFunction

// Parameters:
//  Context - Structure:
//      * Notification     - NotifyDescription
//      * Location - String
//      * ExplanationText - String
//      * Id - String
//
Procedure InstallAddInSSL(Context) Export
	
	CheckTheLocationOfTheComponent(Context.Id, Context.Location);
	
	// Checking the connection of the external add in in this session earlier.
	SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);
	
	If SymbolicName = Undefined Then
		
		Notification = New NotifyDescription(
			"InstallAddInSSLAfterAnswerToInstallationQuestion", ThisObject, Context);
		
		FormParameters = New Structure;
		FormParameters.Insert("ExplanationText", Context.ExplanationText);
		
		OpenForm("CommonForm.AddInInstallationQuestion", 
			FormParameters,,,,, Notification);
		
	Else 
		
		// If the cache already has a symbolic name, it means that the add-in
		// has already been attached to this session and, therefore, to this configuration.
		Result = AddInInstallationResult();
		Result.Insert("IsSet", True);
		ExecuteNotifyProcessing(Context.Notification, Result);
		
	EndIf;
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	Result = AddInInstallationResult();
	Result.ErrorDescription = ErrorDescription;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// Parameters:
//  Context - See AddInAttachmentContext.
//
Async Function InstallAddInSSLAsync(Context) Export
	
	CheckTheLocationOfTheComponent(Context.Id, Context.Location);
	
	// Checking the connection of the external add in in this session earlier.
	SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);
	
	If SymbolicName = Undefined Then 
		
		ExplanationText =  ?(IsBlankString(Context.ExplanationText),
			NStr("en = 'Do you want to install the add-in?';"), Context.ExplanationText);
		
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes,  NStr("en = 'Install and continue';"));
		ButtonsList.Add(DialogReturnCode.No, NStr("en = 'Cancel';"));
		
		Response = Await DoQueryBoxAsync(ExplanationText, ButtonsList,,
			DialogReturnCode.Yes, NStr("en = 'Install add-in';"));

		If Response = DialogReturnCode.Yes Then
			Try
				
				Await InstallAddInAsync(Context.Location);
				Result = AddInInstallationResult();
				Result.IsSet = True;
				Return Result;
				
			Except
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot install add-in ""%1"" on the client
					           |%2
					           |Reason:
					           |%3';"),
					Context.Id,
					Context.Location,
					ErrorProcessing.BriefErrorDescription(ErrorInfo()));
					
				Return AddInInstallationError(ErrorText);
				
			EndTry;
		Else
			Return AddInInstallationResult();
		EndIf;
	Else 
		
		// If the cache already has a symbolic name, it means that the add-in
		// has already been attached to this session and, therefore, to this configuration.
		
		Result = AddInInstallationResult();
		Result.IsSet = True;
		Return Result;
		
	EndIf;

EndFunction

Function AddInInstallationError(ErrorDescription) Export
	
	Result = AddInInstallationResult();
	Result.ErrorDescription = ErrorDescription;
	Return Result;
	
EndFunction

Function ApplicationKind() Export

	SystemInfo = New SystemInfo();
	Result = "";
#If WebClient Then
	Result = NStr("en = 'Web client';") + SystemInfo.UserAgentInformation;
#ElsIf ThickClientOrdinaryApplication Or ThickClientManagedApplication Then
	Result = NStr("en = 'Thick client';");
#ElsIf ThinClient Then
	Result = NStr("en = 'Thin client';");
#EndIf
	Return Result + " (" + SystemInfo.PlatformType + ")";

EndFunction

#EndRegion

#Region SpreadsheetDocument

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document functions.

// Calculates and displays indicators of the selected spreadsheet document cell areas.
//
// Parameters:
//  Form - ClientApplicationForm - a form, where values of estimates are output.
//  SpreadsheetDocumentName - String - form attribute name of the SpreadsheetDocument type, whose indicators are calculated.
//  CurrentCommand - String - an indicator calculation command name, for example, "CalculateAmount".
//                            Defines which indicator is the main one.
//  MinimumNumber - Number
//
Procedure CalculateIndicators(Form, SpreadsheetDocumentName, CurrentCommand = "", MinimumNumber = 0) Export 
	
	Items = Form.Items;
	SpreadsheetDocument = Form[SpreadsheetDocumentName];
	SpreadsheetDocumentField = Items[SpreadsheetDocumentName];
	
	If Not ValueIsFilled(CurrentCommand) Then 
		CurrentCommand = CurrentIndicatorsCalculationCommand(Items);
	EndIf;
	
	CalculationParameters = CommonClientServer.CellsIndicatorsCalculationParameters(SpreadsheetDocumentField);
	
	If CalculationParameters.CalculateAtServer Then 
		
		TimeConsumingOperation = StandardSubsystemsServerCall.CalculationCellsIndicators(
			SpreadsheetDocument, CalculationParameters.SelectedAreas, Form.UUID);
		
		If TimeConsumingOperation = Undefined Then
			Return;
		EndIf;
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(Form);
		IdleParameters.OwnerForm = Form;
		IdleParameters.OutputIdleWindow = False;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Form", Form);
		AdditionalParameters.Insert("CurrentCommand", CurrentCommand);
		AdditionalParameters.Insert("MinimumNumber", MinimumNumber);
		
		CallbackOnCompletion = New NotifyDescription("ContinueCalculatingIndicators", ThisObject, AdditionalParameters);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
		
	Else
		
		CalculationIndicators = CommonClientServer.CalculationCellsIndicators(
			SpreadsheetDocument, SpreadsheetDocumentField, CalculationParameters);
		
		CompleteTheCalculationOfIndicators(Form, CurrentCommand, MinimumNumber, CalculationIndicators);
		
	EndIf;
	
EndProcedure

// Controls whether a calculation indicator panel is visible.
//
// Parameters:
//  FormItems - FormItems
//  Visible - Boolean - The indicator panel visibility flag.
//              See also: "FormGroup.Visibility" in Syntax Assistant.
//
Procedure SetIndicatorsPanelVisibiility(FormItems, Visible = False) Export 
	
	FormItems.IndicatorsArea.Visible = Visible;
	EditIindicatorsCalculationItemProperty(FormItems, "CalculateAllIndicators", "Check", Visible);
	
EndProcedure

#EndRegion

// Shortens a filename.
// Applicable to filenames whose size with extension exceeds 255 B.
// The procedure replaces a part of the filename with this part's hash, followed by the file extension. 
// 
// 
// Parameters:
//  FileName - String - File name including the extension.
//
Procedure ShortenFileName(FileName) Export

	BytesLimit = 127;
	File = New File(FileName);
	
	If StringSizeInBytes(File.Name) <= BytesLimit Then
		Return;
	EndIf;
	
	String = "";
	RowBalance = "";
	LineSize = 0;
	MaximumRowSize = BytesLimit - 32;
	
	ExtensionSize = StringSizeInBytes(File.Extension);
	ShortenAlongWithExtension = ExtensionSize > 32;
	
	If ShortenAlongWithExtension Then
		AbbreviatedName = File.Name;
	Else
		AbbreviatedName = File.BaseName;
		LineSize = ExtensionSize;
	EndIf;
	
	For CharacterNumber = 1 To StrLen(AbbreviatedName) Do
		Char = Mid(AbbreviatedName, CharacterNumber, 1);
		SymbolSize = StringSizeInBytes(Char);
		
		If LineSize + SymbolSize > MaximumRowSize Then
			RowBalance = Mid(AbbreviatedName, CharacterNumber);
			Break;
		EndIf;
		
		String = String + Char;
		LineSize = LineSize + SymbolSize;
	EndDo;
	
	FileName = String;
	
	HashSum = CalculateStringHashByMD5Algorithm(RowBalance);
	FileName = File.Path + FileName + HashSum + ?(ShortenAlongWithExtension, "", File.Extension);
	
EndProcedure

#Region Other

// The parameter constructor for the print form format choice form.
// 
// Returns:
//  Structure - Print form format settings:
//   * PackToArchive - Boolean - Attachment archiving flag.
//   * SaveFormats - Array of See StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings
//   * Recipients - Array of Structure:
//                            * ContactInformationSource - CatalogRef - a contact information owner.
//                            * Address - String - an email recipient address.
//                            * Presentation - String - Addressee presentation.
//   * TransliterateFilesNames - Boolean - Cyrillic-to-Latin conversion flag. 
//   * Sign  - Undefined, 
// 				- Boolean - Flag indicating whether print forms must be digitally signed. If Undefined, the flag is hidden from the format choice form.
//   * SignatureAndSeal - Boolean - Stamp and signature usage flag.
//
Function PrintFormFormatSettings() Export
	Result = New Structure;
	Result.Insert("PackToArchive", False);
	Result.Insert("SaveFormats", New Array);
	Result.Insert("Recipients", New Array);
	Result.Insert("TransliterateFilesNames", False);
	Result.Insert("Sign", Undefined);
	Result.Insert("SignatureAndSeal", False);
	Return Result;
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region Data

#Region CopyRecursive

Function CopyStructure(SourceStructure, FixData) Export 
	
	ResultingStructure = New Structure;
	
	For Each KeyAndValue In SourceStructure Do
		ResultingStructure.Insert(KeyAndValue.Key, 
			CommonClient.CopyRecursive(KeyAndValue.Value, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceStructure) = Type("FixedStructure") Then 
		Return New FixedStructure(ResultingStructure);
	EndIf;
	
	Return ResultingStructure;
	
EndFunction

Function CopyMap(SourceMap, FixData) Export 
	
	ResultingMap = New Map;
	
	For Each KeyAndValue In SourceMap Do
		ResultingMap.Insert(KeyAndValue.Key, 
			CommonClient.CopyRecursive(KeyAndValue.Value, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceMap) = Type("FixedMap") Then 
		Return New FixedMap(ResultingMap);
	EndIf;
	
	Return ResultingMap;
	
EndFunction

Function CopyArray(SourceArray1, FixData) Export 
	
	ResultingArray = New Array;
	
	For Each Item In SourceArray1 Do
		ResultingArray.Add(CommonClient.CopyRecursive(Item, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceArray1) = Type("FixedArray") Then 
		Return New FixedArray(ResultingArray);
	EndIf;
	
	Return ResultingArray;
	
EndFunction

Function CopyValueList(SourceList, FixData) Export
	
	ResultingList = New ValueList;
	
	For Each ListItem In SourceList Do
		ResultingList.Add(
			CommonClient.CopyRecursive(ListItem.Value, FixData), 
			ListItem.Presentation, 
			ListItem.Check, 
			ListItem.Picture);
	EndDo;
	
	Return ResultingList;
	
EndFunction

#EndRegion

#EndRegion

#Region Forms

Function MetadataObjectName(Type) Export
	
	ParameterName = "StandardSubsystems.MetadataObjectNames";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Map);
	EndIf;
	MetadataObjectNames = ApplicationParameters[ParameterName];
	
	Result = MetadataObjectNames[Type];
	If Result = Undefined Then
		Result = StandardSubsystemsServerCall.MetadataObjectName(Type);
		MetadataObjectNames.Insert(Type, Result);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure ConfirmFormClosing() Export
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("ConfirmFormClosingCompletion", ThisObject, Parameters);
	If IsBlankString(Parameters.WarningText) Then
		QueryText = NStr("en = 'The data has been changed. Do you want to save the changes?';");
	Else
		QueryText = Parameters.WarningText;
	EndIf;
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNoCancel, ,
		DialogReturnCode.Yes);
	
EndProcedure

Procedure ConfirmFormClosingCompletion(Response, Parameters) Export
	
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Undefined;
	
	If Response = DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.SaveAndCloseNotification);
		
	ElsIf Response = DialogReturnCode.No Then
		Form = Parameters.SaveAndCloseNotification.Module;
		Form.Modified = False;
		Form.Close();
	Else
		Form = Parameters.SaveAndCloseNotification.Module;
		Form.Modified = True;
	EndIf;
	
EndProcedure

Procedure ConfirmArbitraryFormClosing() Export
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Undefined;
	QuestionMode = QuestionDialogMode.YesNo;
	
	Notification = New NotifyDescription("ConfirmArbitraryFormClosingCompletion", ThisObject, Parameters);
	
	ShowQueryBox(Notification, Parameters.WarningText, QuestionMode);
	
EndProcedure

Procedure ConfirmArbitraryFormClosingCompletion(Response, Parameters) Export
	
	Form = Parameters.Form;
	If Response = DialogReturnCode.Yes
		Or Response = DialogReturnCode.OK Then
		Form[Parameters.CloseFormWithoutConfirmationAttributeName] = True;
		If Parameters.CloseNotifyDescription <> Undefined Then
			ExecuteNotifyProcessing(Parameters.CloseNotifyDescription);
		EndIf;
		Form.Close();
	Else
		Form[Parameters.CloseFormWithoutConfirmationAttributeName] = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region EditingForms

Procedure CommentInputCompletion(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;	
	
	FormAttribute = AdditionalParameters.OwnerForm;
	
	PathToFormAttribute = StrSplit(AdditionalParameters.AttributeName, ".");
	// If the type of the attribute is "Object.Comment" and so on
	If PathToFormAttribute.Count() > 1 Then
		For IndexOf = 0 To PathToFormAttribute.Count() - 2 Do 
			FormAttribute = FormAttribute[PathToFormAttribute[IndexOf]];
		EndDo;
	EndIf;	
	
	FormAttribute[PathToFormAttribute[PathToFormAttribute.Count() - 1]] = EnteredText;
	AdditionalParameters.OwnerForm.Modified = True;
	
EndProcedure

#EndRegion

#Region AddIns

// Continue the AttachAddInSSL procedure.
// 
// Parameters:
//  Result - Undefined - If the AddIns subsystem is not integrated.
//            - See AddInsInternalClient.AddInAvailabilityResult
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Procedure ConnectAfterSearchingForAnExternalComponent(Result, Context) Export
	
	Context.ASearchForANewVersionHasBeenPerformed = True;
	If Result = Undefined Or Result.TheComponentOfTheLatestVersion = Undefined Then
		TheComponentOfTheLatestVersion = StandardSubsystemsServerCall.TheComponentOfTheLatestVersion(
			Context.Id, Context.OriginalLocation, Result);
	Else
		TheComponentOfTheLatestVersion = Result.TheComponentOfTheLatestVersion;
	EndIf;
	
	Context.Location = TheComponentOfTheLatestVersion.Location;
	Context.Version = TheComponentOfTheLatestVersion.Version;
	AttachAddInSSL(Context);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLAfterAttachmentAttempt(Attached, Context) Export 
	
	If Attached Then 
		
		// Saving the fact of attaching the external add-in to this session.
		
		OriginalLocation = ?(ValueIsFilled(Context.OriginalLocation),
			Context.OriginalLocation, Context.Location);
		
		WriteAddInSymbolicNameToCache(OriginalLocation, Context.SymbolicName);
		
		Attachable_Module = Undefined;
		
		Try
			Attachable_Module = NewAddInObject(Context);
		Except
			// The error text has already been composed to the NewAddInObject, you just need to notify.
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			AttachAddInSSLNotifyOnError(ErrorText, Context);
			Return;
		EndTry;
		
		If Context.Cached Then 
			WriteAddInObjectToCache(OriginalLocation, Attachable_Module, Context.Location, Context.SymbolicName);
		EndIf;
		
		AttachAddInSSLNotifyOnAttachment(New Structure("Attachable_Module, Location, Name",
			Attachable_Module, Context.Location, Context.SymbolicName), Context);
		
	Else 
		
		If Context.SuggestInstall And Not Context.WasInstallationAttempt Then 
			AttachAddInSSLStartInstallation(Context);
		ElsIf Not Context.SuggestInstall Then
			Notification = Context.Notification;
			Result = AddInAttachmentResult();
			ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the %1 add-in.
				|It might not have been installed.';"), Context.Id);
			
			Result.ErrorDescription = ErrorText;
			
			ExecuteNotifyProcessing(Notification, Result);
		Else
			
			If CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
				Notification = New NotifyDescription("AfterTemplateAddInCheckedForCompatibility", ThisObject, Context);
				ModuleAddInsInternalClient = CommonClient.CommonModule("AddInsInternalClient");
				ModuleAddInsInternalClient.CheckTemplateAddInForCompatibility(Notification, Context);
				Return;
			EndIf;
			
			AfterTemplateAddInCheckedForCompatibility("", Context);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AfterTemplateAddInCheckedForCompatibility(Result, Context) Export
	
	If ValueIsFilled(Result) Then
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot apply add-in ""%1"".
						 |%2.
						 |
						 |Technical details:
						 |%3
						 |Method %4 returned False.';"), Context.Id, Result,
			Context.Location, "BeginAttachingAddIn");
	Else
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot apply add-in ""%1"".
						 |The add-in might not be intended for use in the client application: %2.
						 |
						 |Technical details:
						 |%3
						 |Method %4 returned False.';"), Context.Id, ApplicationKind(), Context.Location,
			"BeginAttachingAddIn");
	EndIf;

	AttachAddInSSLNotifyOnError(ErrorText, Context, Context.SuggestInstall);
	
EndProcedure

Function TemplateAddInCompatibilityError(Location)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
		Return "";
	EndIf;
	
	ModuleAddInsInternalClient = CommonClient.CommonModule("AddInsInternalClient");
	
	Return ModuleAddInsInternalClient.TemplateAddInCompatibilityError(
		Location);
	
EndFunction

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLStartInstallation(Context)
	
	Notification = New NotifyDescription(
		"AttachAddInSSLAfterInstallation", ThisObject, Context);
	
	InstallationContext = New Structure;
	InstallationContext.Insert("Notification", Notification);
	InstallationContext.Insert("Location", Context.Location);
	InstallationContext.Insert("ExplanationText", Context.ExplanationText);
	InstallationContext.Insert("Id", Context.Id);
	
	InstallAddInSSL(InstallationContext);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLAfterInstallation(Result, Context) Export 
	
	If Result.IsSet Then 
		// An attempt to attach the add-in was made.
		// If it failed, don't prompt the user to try again.
		Context.WasInstallationAttempt = True;
		AttachAddInSSL(Context);
	Else 
		// No need to drill down "ErrorDetails", its text was generated when attaching the add-in.
		// If the user terminated the process, "ErrorDetails" is an empty string.
		AttachAddInSSLNotifyOnError(Result.ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the AttachAddInSSL procedure.
// 
// Parameters:
//  ErrorInfo- ErrorInfo
//  StandardProcessing - Boolean
//  Context - See AttachAddInSSL.Context
//
Procedure AttachAddInSSLOnProcessError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot attach add-in ""%1"" on the client
		           |%2
		           |Reason:
		           |%3';"),
		Context.Id,
		Context.Location,
		ErrorProcessing.BriefErrorDescription(ErrorInfo));

	AttachAddInSSLNotifyOnError(ErrorText, Context);
	
EndProcedure

// Creates an instance of external component (or a couple of instances)
Function NewAddInObject(Context)
	
	AddInContainsOneObjectClass = (Context.ObjectsCreationIDs.Count() = 0);
	
	If AddInContainsOneObjectClass Then 
		
		Try
			Attachable_Module = New("AddIn." + Context.SymbolicName + "." + Context.Id);
			If Attachable_Module = Undefined Then 
				Raise NStr("en = 'The New operator returned Undefined.';");
			EndIf;
		Except
			Attachable_Module = Undefined;
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		
		If Attachable_Module = Undefined Then 
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create an object for add-in ""%1"" attached on the client
				           |%2
				           |Reason:
				           |%3';"),
				Context.Id,
				Context.Location,
				ErrorText);
			
		EndIf;
		
	Else 
		
		AttachableModules = New Map;
		For Each ObjectID In Context.ObjectsCreationIDs Do 
			
			Try
				Attachable_Module = New("AddIn." + Context.SymbolicName + "." + ObjectID);
				If Attachable_Module = Undefined Then 
					Raise NStr("en = 'The New operator returned Undefined.';");
				EndIf;
			Except
				Attachable_Module = Undefined;
				ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			EndTry;
			
			If Attachable_Module = Undefined Then 
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot create object ""%1"" for add-in ""%2"" attached on the client
					           |%3
					           |Reason:
					           |%4';"),
					ObjectID,
					Context.Id,
					Context.Location,
					ErrorText);
				
			EndIf;
			
			AttachableModules.Insert(ObjectID, Attachable_Module);
			
		EndDo;
		
		Attachable_Module = New FixedMap(AttachableModules);
		
	EndIf;
	
	Return Attachable_Module;
	
EndFunction

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLAfterAnswerToInstallationQuestion(Response, Context) Export
	
	// Result: 
	// - DialogReturnCode.Yes - Attach the add-in.
	// - DialogReturnCode.Cancel - Cancel attachment.
	// - Undefined - Close the dialog.
	If Response = DialogReturnCode.Yes Then
		InstallAddInSSLStartInstallation(Context);
	Else
		Result = AddInInstallationResult();
		ExecuteNotifyProcessing(Context.Notification, Result);
	EndIf;
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLStartInstallation(Context)
	
	Notification = New NotifyDescription(
		"InstallAddInSSLAfterInstallationAttempt", ThisObject, Context,
		"InstallAddInSSLOnProcessError", ThisObject);
	
	BeginInstallAddIn(Notification, Context.Location);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLAfterInstallationAttempt(Context) Export 
	
	Result = AddInInstallationResult();
	Result.Insert("IsSet", True);
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
// 
// Parameters:
//  ErrorInfo - ErrorInfo
//  StandardProcessing - Boolean
//  Context - See AttachAddInSSL.Context 
// 
Procedure InstallAddInSSLOnProcessError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot install add-in ""%1"" on the client
		           |%2
		           |Reason:
		           |%3';"),
		Context.Id,
		Context.Location,
		ErrorProcessing.BriefErrorDescription(ErrorInfo));
	
	Result = AddInInstallationResult();
	Result.ErrorDescription = ErrorText;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Function AddInInstallationResult()
	
	Result = New Structure;
	Result.Insert("IsSet", False);
	Result.Insert("ErrorDescription", "");
	
	Return Result;
	
EndFunction

Procedure CheckTheLocationOfTheComponent(Id, Location)
	
	If IsTemplate(Location) Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternalClient = CommonClient.CommonModule("AddInsInternalClient");
		ModuleAddInsInternalClient.CheckTheLocationOfTheComponent(Id, Location);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the %1 add-in in the client application
			           |due to:
			           |Add-in
			           |%2 location is incorrect';"),
			Id, Location);
	EndIf;

EndProcedure

Async Function AttachAddInSSLAfterAttachmentAttemptAsync(Attached, Context)
	
	If Attached Then 
		
		// Saving the fact of attaching the external add-in to this session.
		
		OriginalLocation = ?(ValueIsFilled(Context.OriginalLocation),
			Context.OriginalLocation, Context.Location);
		
		WriteAddInSymbolicNameToCache(OriginalLocation, Context.SymbolicName);
		
		Attachable_Module = Undefined;
		
		Try
			Attachable_Module = NewAddInObject(Context);
		Except
			// The error text has already been composed to the NewAddInObject, you just need to notify.
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			Return AddInAttachmentError(ErrorText);
		EndTry;
		
#If WebClient Then
		SystemInfo = New SystemInfo;
		If CommonClientServer.CompareVersions(SystemInfo.AppVersion, "8.3.24.0") >= 0 Then
			Await PauseAsync(2);
		EndIf;
#EndIf

		If Context.Cached Then
			WriteAddInObjectToCache(
				OriginalLocation, Attachable_Module, Context.Location, Context.SymbolicName);
		EndIf;
		
		Result = AddInAttachmentResult();
		Result.Attached = True;
		Result.Attachable_Module = Attachable_Module;
		Result.Location = Context.Location;
		Result.SymbolicName = Context.SymbolicName;
		Return Result;
		
	Else 
		
		If Context.SuggestInstall And Not Context.WasInstallationAttempt Then 
			
			InstallationContext = New Structure;
			InstallationContext.Insert("Location", Context.Location);
			InstallationContext.Insert("ExplanationText", Context.ExplanationText);
			InstallationContext.Insert("Id", Context.Id);   
			InstallResult = Await InstallAddInSSLAsync(InstallationContext);
			
			If InstallResult.IsSet Then 
				// An attempt to attach the add-in was made.
				// If it failed, don't prompt the user to try again.
				Context.WasInstallationAttempt = True;
				Return AttachAddInSSLAsync(Context);
			Else 
				// No need to drill down "ErrorDetails", its text was generated when attaching the add-in.
				// If the user terminated the process, "ErrorDetails" is an empty string.
				
				Return AddInAttachmentError(InstallResult.ErrorDescription);
			EndIf;
		ElsIf Not Context.SuggestInstall Then
			Notification = Context.Notification;
			Result = AddInAttachmentResult();
			ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the %1 add-in.
				|It might not have been installed.';"), Context.Id);
			
			Result.ErrorDescription = ErrorText;
			
			Return Result;	
		Else
			
			AddInCompatibilityError = TemplateAddInCompatibilityError(Context.Location);
			
			If ValueIsFilled(AddInCompatibilityError) Then
				ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot apply add-in ""%1"".
						 |%2.
						 |
						 |Technical details:
						 |%3
						 |Method %4 returned False.';"), Context.Id, AddInCompatibilityError,
					Context.Location, "AttachAddInAsync");
					
				WarningText =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t attach add-in ""%1"".
						 |%2.';"), Context.Id, AddInCompatibilityError);
					
				Await DoMessageBoxAsync(WarningText);
			Else
				ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot apply add-in ""%1"".
					 |The add-in might not be intended for use in the client application: %2.
					 |
					 |Technical details:
					 |%3
					 |Method %4 returned False.';"), Context.Id, ApplicationKind(), Context.Location,
					"AttachAddInAsync");
			EndIf;
			
			Return AddInAttachmentError(ErrorText, Context.SuggestInstall);
			
		EndIf;
		
	EndIf;
	 
EndFunction

Async Function PauseAsync(TimeInSeconds)
	
	EndDate = CurrentDate() + TimeInSeconds; // ACC:143 - Session date is not used in interval checks
	While CurrentDate() < EndDate Do         // ACC:143 - Session date is not used in interval checks
		Await 1;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function IsTemplate(Location)
	
	If StrFind(Location, "/") > 0 Then
		Return False;
	EndIf;
	
	PathSteps = StrSplit(Location, ".");
	Count = PathSteps.Count();
	
	If Not Count = 2 And Not Count = 4 Then
		Return False;
	EndIf;
	
	If Count = 2 And Not Upper(PathSteps[0]) = "COMMONTEMPLATE" Then
		Return False;
	EndIf;

	If Count = 4 And Not Upper(PathSteps[2]) = "TEMPLATE" Then
		Return False;
	EndIf;
	
	For Each PathStep In PathSteps Do
		If Not CommonClientServer.NameMeetPropertyNamingRequirements(PathStep) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Gets the symbolic name of the external add-in from the cache, if it was previously attached.
Function GetAddInSymbolicNameFromCache(ObjectKey)
	
	SymbolicName = Undefined;
	CachedSymbolicNames = ApplicationParameters["StandardSubsystems.AddIns.SymbolicNames"];
	
	If TypeOf(CachedSymbolicNames) = Type("FixedMap") Then
		SymbolicName = CachedSymbolicNames.Get(ObjectKey);
	EndIf;
	
	Return SymbolicName;
	
EndFunction

// Writes the symbolic name of the external add-in to the cache.
Procedure WriteAddInSymbolicNameToCache(ObjectKey, SymbolicName)
	
	Map = New Map;
	CachedSymbolicNames = ApplicationParameters["StandardSubsystems.AddIns.SymbolicNames"];
	
	If TypeOf(CachedSymbolicNames) = Type("FixedMap") Then
		
		If CachedSymbolicNames.Get(ObjectKey) <> Undefined Then // It is already in the cache.
			Return;
		EndIf;
		
		For Each Item In CachedSymbolicNames Do
			Map.Insert(Item.Key, Item.Value);
		EndDo;
		
	EndIf;
	
	Map.Insert(ObjectKey, SymbolicName);
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.SymbolicNames",
		New FixedMap(Map));
	
EndProcedure

Function GetAddInObjectFromCache(ObjectKey)
	
	Attachable_Module = Undefined;
	CachedObjects = ApplicationParameters["StandardSubsystems.AddIns.Objects"];
	
	If TypeOf(CachedObjects) = Type("FixedMap") Then
		AttachableModuleProperties = CachedObjects.Get(ObjectKey);
		If AttachableModuleProperties <> Undefined Then
			If CheckAddInAttachment(AttachableModuleProperties.Location,
				AttachableModuleProperties.Name) Then
					Return AttachableModuleProperties;
			Else
				ClearCachedAddInObject(ObjectKey);
			EndIf;
		EndIf;
	EndIf;
	
	Return Attachable_Module;
	
EndFunction

Procedure WriteAddInObjectToCache(ObjectKey, Attachable_Module, Location, Name)
	
	Map = New Map;
	CachedObjects = ApplicationParameters["StandardSubsystems.AddIns.Objects"];
	
	If TypeOf(CachedObjects) = Type("FixedMap") Then
		For Each Item In CachedObjects Do
			Map.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	AttachableModuleProperties = New Structure("Attachable_Module, Location, Name",
		Attachable_Module, Location, Name);
	Map.Insert(ObjectKey, AttachableModuleProperties);
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.Objects",
		New FixedMap(Map));
	
EndProcedure

Procedure ClearCachedAddInObject(ObjectKey)
	
	CachedObjects = ApplicationParameters["StandardSubsystems.AddIns.Objects"];
	
	If TypeOf(CachedObjects) = Type("FixedMap")
		And CachedObjects.Get(ObjectKey) <> Undefined Then
		
		Map = New Map;
		For Each Item In CachedObjects Do
			If Item.Key = ObjectKey Then
				Continue;
			EndIf;
			Map.Insert(Item.Key, Item.Value);
		EndDo;
		
		ApplicationParameters.Insert("StandardSubsystems.AddIns.Objects",
			New FixedMap(Map));
	EndIf;
	
	CachedSymbolicNames = ApplicationParameters["StandardSubsystems.AddIns.SymbolicNames"];
	
	If TypeOf(CachedSymbolicNames) = Type("FixedMap")
		And CachedSymbolicNames.Get(ObjectKey) <> Undefined Then
		
		Map = New Map;
		For Each Item In CachedSymbolicNames Do
			If Item.Key = ObjectKey Then
				Continue;
			EndIf;
			Map.Insert(Item.Key, Item.Value);
		EndDo;
		ApplicationParameters.Insert("StandardSubsystems.AddIns.SymbolicNames",
			New FixedMap(Map));
	EndIf;
	
EndProcedure

#EndRegion

#Region ExternalConnection

// Continuation of procedure CommonClient.RegisterCOMConnector.
Procedure RegisterCOMConnectorOnCheckRegistration(Result, Context) Export
	
	ApplicationStarted = Result.ApplicationStarted;
	ErrorDescription = Result.ErrorDescription;
	ReturnCode = Result.ReturnCode;
	RestartSession = Context.RestartSession;
	
	If ApplicationStarted Then
		
		If RestartSession Then
			Notification = New NotifyDescription("RegisterCOMConnectorOnCheckAnswerAboutRestart", 
				CommonInternalClient, Context);
			QueryText = 
				NStr("en = 'To complete the reregistration of comcntr, restart the app.
				           |Restart now?';");
			ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
		Else 
			Notification = Context.Notification;
			IsRegistered = True;
			ExecuteNotifyProcessing(Notification, IsRegistered);
		EndIf;
		
	Else 
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot register the comcntr component.
			           |Regsvr32 error code: %1';"),
			ReturnCode);
			
		If ReturnCode = 1 Then
			MessageText = MessageText + " " + NStr("en = 'An error occurred upon parsing a command line.';");
		ElsIf ReturnCode = 2 Then
			MessageText = MessageText + " " + NStr("en = 'An error occurred upon initializing a COM library.';");
		ElsIf ReturnCode = 3 Then
			MessageText = MessageText + " " + NStr("en = 'An error occurred upon loading a module from a COM library.';");
		ElsIf ReturnCode = 4 Then
			MessageText = MessageText + " " + NStr("en = 'An error occurred upon getting the address of a function or a variable from a COM-library.';");
		ElsIf ReturnCode = 5 Then
			MessageText = MessageText + " " + NStr("en = 'An error occurred upon executing the registration function.';");
		Else 
			MessageText = MessageText + Chars.LF + ErrorDescription;
		EndIf;
		
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Registration of comcntr component';", CommonClient.DefaultLanguageCode()),
			"Error",
			MessageText,,
			True);
		
		Notification = New NotifyDescription("RegisterCOMConnectorNotifyOnError", 
			CommonInternalClient, Context);
		
		ShowMessageBox(Notification, MessageText);
		
	EndIf;
	
EndProcedure

// Continuation of procedure CommonClient.RegisterCOMConnector.
Procedure RegisterCOMConnectorOnCheckAnswerAboutRestart(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
		Exit(True, True);
	Else 
		RegisterCOMConnectorNotifyOnError(Context);
	EndIf;

EndProcedure

// Continuation of procedure CommonClient.RegisterCOMConnector.
Procedure RegisterCOMConnectorNotifyOnError(Context) Export
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then
		IsRegistered = False;
		ExecuteNotifyProcessing(Notification, IsRegistered);
	EndIf;
	
EndProcedure

// Continuation of procedure CommonClient.RegisterCOMConnector.
//
// Returns:
//   Boolean
//
Function RegisterCOMConnectorRegistrationIsAvailable() Export
	
#If WebClient Or MobileClient Then
	Return False;
#Else
	Return Not CommonClient.ClientConnectedOverWebServer()
	      And Not StandardSubsystemsClient.IsBaseConfigurationVersion()
	      And Not StandardSubsystemsClient.IsTrainingPlatform();
#EndIf
	
EndFunction

#EndRegion

#Region SpreadsheetDocument

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Structure
//
Procedure ContinueCalculatingIndicators(Result, AdditionalParameters) Export 
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	If Result.Status <> "Completed2" Then
		Return;
	EndIf;
		
	CalculationIndicators = GetFromTempStorage(Result.ResultAddress);
	
	CompleteTheCalculationOfIndicators(
		AdditionalParameters.Form,
		AdditionalParameters.CurrentCommand,
		AdditionalParameters.MinimumNumber,
		CalculationIndicators);
	
EndProcedure

Procedure CompleteTheCalculationOfIndicators(Form, CurrentCommand, MinimumNumber, CalculationIndicators) 
	
	Items = Form.Items;
	
	FillPropertyValues(Form, CalculationIndicators);
	
	IndicatorsCommands = IndicatorsCommands();
	
	For Each Command In IndicatorsCommands Do 
		EditIindicatorsCalculationItemProperty(Items, Command.Key, "Check", False);
		
		IndicatorValue = CalculationIndicators[Command.Value];
		Items[Command.Value].EditFormat = IndicatorEditFormat(IndicatorValue);
	EndDo;
	
	EditIindicatorsCalculationItemProperty(Items, CurrentCommand, "Check", True);
	
	CurrentIndicator = IndicatorsCommands[CurrentCommand];
	
	If CurrentIndicator = Undefined Then
		Return;
	EndIf;
	
	If CalculationIndicators.Count >= MinimumNumber  Then 
		Form.Factor = Form[CurrentIndicator];
		Items.Factor.EditFormat = Items[CurrentIndicator].EditFormat;
	EndIf;
	
	EditIindicatorsCalculationItemProperty(
		Items, "IndicatorsKindsCommands", "Picture", PictureLib[CurrentIndicator]);
	
	EditIindicatorsCalculationItemProperty(
		Items, "SelectIndicator", "Picture", PictureLib[CurrentIndicator]);
	
	Form.MainIndicator = CurrentCommand;
	Form.ExpandIndicatorsArea = Items.CalculateAllIndicators.Check;
	
EndProcedure

Function CurrentIndicatorsCalculationCommand(FormItems)
	
	Var CurrentCommand;
	
	IndicatorsCommands = IndicatorsCommands();
	For Each Command In IndicatorsCommands Do 
		
		If FormItems[Command.Key].Check Then 
			
			CurrentCommand = Command.Key;
			Break;
			
		EndIf;
		
	EndDo;
	
	If CurrentCommand = Undefined Then 
		CurrentCommand = "CalculateAmount";
	EndIf;
	
	Return CurrentCommand;
	
EndFunction

// Defines the correspondence between indicator calculation commands and indicators.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - String - command name;
//     * Value - String - an indicator name.
//
Function IndicatorsCommands()
	
	IndicatorsCommands = New Map();
	IndicatorsCommands.Insert("CalculateAmount", "Sum");
	IndicatorsCommands.Insert("CalculateCount", "Count");
	IndicatorsCommands.Insert("CalculateAverage", "Mean");
	IndicatorsCommands.Insert("CalculateMin", "Minimum");
	IndicatorsCommands.Insert("CalculateMax", "Maximum");
	
	Return IndicatorsCommands;
	
EndFunction

Function IndicatorEditFormat(IndicatorValue)
	
	EditFormatTemplate = "NFD=%1; NGS=' '; NZ=0";
	
	FractionalPartValue = Max(IndicatorValue, -IndicatorValue) % 1;
	FractionDigits = Min(?(FractionalPartValue = 0, 0, StrLen(FractionalPartValue) - 2), 5);
	
	EditFormat = StringFunctionsClientServer.SubstituteParametersToString(
		EditFormatTemplate, FractionDigits);
	
	IndicatorPresentation = Format(IndicatorValue, EditFormat);
	
	While FractionDigits > 0
		And StrEndsWith(IndicatorPresentation, "0") Do 
		
		IndicatorPresentation = Mid(IndicatorPresentation, 1, StrLen(IndicatorPresentation) - 1);
		FractionDigits = FractionDigits - 1;
		
	EndDo;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		EditFormatTemplate, FractionDigits);
	
EndFunction

Procedure EditIindicatorsCalculationItemProperty(FormItems, TagName, PropertyName, PropertyValue)
	
	ItemsNamesList = StringFunctionsClientServer.SubstituteParametersToString("%1, %1%2", TagName, "More");
	ItemsNames = StrSplit(ItemsNamesList, ", ", False);
	
	For Each Name In ItemsNames Do 
		
		FoundItem = FormItems.Find(Name);
		
		If FoundItem <> Undefined Then 
			FoundItem[PropertyName] = PropertyValue;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region StringHashByMD5Algorithm

// ACC:1353-off, ACC-247-off - Short names of math operands. 

// Returns the MD5 hash of the passed string.
//
// Parameters:
//  String - String - Arbitrary string of any length.
//
// Returns:
//  String - Generated hash.
//
Function CalculateStringHashByMD5Algorithm(Val String)
	
	a = 1732584193; // 01 23 45 67; (hexadecimal representation, low byte first)
	b = 4023233417; // 01 23 45 67; (hexadecimal representation, low byte first)
	c = 2562383102; // 89 AB CD EF;
	d = 271733878;  // FE DC BA 98;
	
	X = New Array(16); // "X" is a 512-bit data block, an array of 32-bit words.
	
	EmptyByte = GetBinaryDataFromHexString("00");
	EndByte = GetBinaryDataFromHexString("80");
	BinaryData = AddToBinaryData(GetBinaryDataFromString(String, "UTF-8"), EndByte);
	
	// Split the string in 512-bit blocks.
	BlocksArrayFromString = SplitBinaryData(BinaryData, 64);
	
	LastBlock = BlocksArrayFromString[BlocksArrayFromString.UBound()];
	While LastBlock.Size() < 64 Do
		LastBlock = AddToBinaryData(LastBlock, EmptyByte);
	EndDo;
	
	BlocksArrayFromString[BlocksArrayFromString.UBound()] = LastBlock;
	
	DataBuffer = GetBinaryDataBufferFromBinaryData(LastBlock);
	If DataBuffer.ReadInt64(56) <> 0 Then
		BlocksArrayFromString.Add(0);
	EndIf;

	// Run the calculation for each of the blocks.
	For BlockNumber = 0 To BlocksArrayFromString.Count() - 1 Do 
		Block = BlocksArrayFromString[BlockNumber];
		
		If Block = 0 Then
			X = New Array(16);
			For WordNumber = 0 To 15 Do
				X[WordNumber] = 0;
			EndDo;
		Else
			DataBuffer = GetBinaryDataBufferFromBinaryData(Block);
			For WordNumber = 0 To 15 Do
				Word = DataBuffer.ReadInt32(WordNumber*4);
				X[WordNumber] = ?(Word = Undefined, 0, Word);
			EndDo;
		EndIf;
 
		// Append the string length in bits to the last block.
		If BlockNumber = BlocksArrayFromString.Count() - 1 Then
			StringSizeInBits = GetBinaryDataFromString(String).Size()* 8;
			X[14] = StringSizeInBits % Pow(2,32); // 
			X[15] = Int(StringSizeInBits / Pow(2,32)) % Pow(2,64); // 
		EndIf;
		CalculateBlock(a, b, c, d, X);
	EndDo;
	                                                   
	Result = GetHexStringFromBinaryData(NumberToBinaryData(a))
			  + GetHexStringFromBinaryData(NumberToBinaryData(b))
			  + GetHexStringFromBinaryData(NumberToBinaryData(c))
			  + GetHexStringFromBinaryData(NumberToBinaryData(d));
	
	Return Result;
	
EndFunction

Function StringSizeInBytes(Val String)
	
	Return GetBinaryDataFromString(String, "UTF-8").Size();

EndFunction

Procedure CalculateBlock(a, b, c, d, X)
	aa = a;
	bb = b;
	cc = c;
	dd = d;
	
	// Round 1.
	ExecuteOperationWithFunctionF(a,b,c,d, X[ 0],  7, 3614090360); // 0xd76aa478 /* 1 */
	ExecuteOperationWithFunctionF(d,a,b,c, X[ 1], 12, 3905402710); // 0xe8c7b756 /* 2 */
	ExecuteOperationWithFunctionF(c,d,a,b, X[ 2], 17,  606105819); // 0x242070db /* 3 */
	ExecuteOperationWithFunctionF(b,c,d,a, X[ 3], 22, 3250441966); // 0xc1bdceee /* 4 */
	ExecuteOperationWithFunctionF(a,b,c,d, X[ 4],  7, 4118548399); // 0xf57c0faf /* 5 */
	ExecuteOperationWithFunctionF(d,a,b,c, X[ 5], 12, 1200080426); // 0x4787c62a /* 6 */
	ExecuteOperationWithFunctionF(c,d,a,b, X[ 6], 17, 2821735955); // 0xa8304613 /* 7 */
	ExecuteOperationWithFunctionF(b,c,d,a, X[ 7], 22, 4249261313); // 0xfd469501 /* 8 */
	ExecuteOperationWithFunctionF(a,b,c,d, X[ 8],  7, 1770035416); // 0x698098d8 /* 9 */
	ExecuteOperationWithFunctionF(d,a,b,c, X[ 9], 12, 2336552879); // 0x8b44f7af /* 10 */
	ExecuteOperationWithFunctionF(c,d,a,b, X[10], 17, 4294925233); // 0xffff5bb1 /* 11 */
	ExecuteOperationWithFunctionF(b,c,d,a, X[11], 22, 2304563134); // 0x895cd7be /* 12 */
	ExecuteOperationWithFunctionF(a,b,c,d, X[12],  7, 1804603682); // 0x6b901122 /* 13 */
	ExecuteOperationWithFunctionF(d,a,b,c, X[13], 12, 4254626195); // 0xfd987193 /* 14 */
	ExecuteOperationWithFunctionF(c,d,a,b, X[14], 17, 2792965006); // 0xa679438e /* 15 */
	ExecuteOperationWithFunctionF(b,c,d,a, X[15], 22, 1236535329); // 0x49b40821 /* 16 */
	
	// Round 2.
	ExecuteOperationWithFunctionG(a,b,c,d, X[ 1],  5, 4129170786); // 0xf61e2562 /* 17 */
	ExecuteOperationWithFunctionG(d,a,b,c, X[ 6],  9, 3225465664); // 0xc040b340 /* 18 */
	ExecuteOperationWithFunctionG(c,d,a,b, X[11], 14,  643717713); // 0x265e5a51 /* 19 */
	ExecuteOperationWithFunctionG(b,c,d,a, X[ 0], 20, 3921069994); // 0xe9b6c7aa /* 20 */
	ExecuteOperationWithFunctionG(a,b,c,d, X[ 5],  5, 3593408605); // 0xd62f105d /* 21 */
	ExecuteOperationWithFunctionG(d,a,b,c, X[10],  9,   38016083); //  0x2441453 /* 22 */
	ExecuteOperationWithFunctionG(c,d,a,b, X[15], 14, 3634488961); // 0xd8a1e681 /* 23 */
	ExecuteOperationWithFunctionG(b,c,d,a, X[ 4], 20, 3889429448); // 0xe7d3fbc8 /* 24 */
	ExecuteOperationWithFunctionG(a,b,c,d, X[ 9],  5,  568446438); // 0x21e1cde6 /* 25 */
	ExecuteOperationWithFunctionG(d,a,b,c, X[14],  9, 3275163606); // 0xc33707d6 /* 26 */
	ExecuteOperationWithFunctionG(c,d,a,b, X[ 3], 14, 4107603335); // 0xf4d50d87 /* 27 */
	ExecuteOperationWithFunctionG(b,c,d,a, X[ 8], 20, 1163531501); // 0x455a14ed /* 28 */
	ExecuteOperationWithFunctionG(a,b,c,d, X[13],  5, 2850285829); // 0xa9e3e905 /* 29 */
	ExecuteOperationWithFunctionG(d,a,b,c, X[ 2],  9, 4243563512); // 0xfcefa3f8 /* 30 */
	ExecuteOperationWithFunctionG(c,d,a,b, X[ 7], 14, 1735328473); // 0x676f02d9 /* 31 */
	ExecuteOperationWithFunctionG(b,c,d,a, X[12], 20, 2368359562); // 0x8d2a4c8a /* 32 */
	
	// Round 3.
	ExecuteOperationWithFunctionH(a,b,c,d, X[ 5],  4, 4294588738); // 0xfffa3942 /* 33 */
	ExecuteOperationWithFunctionH(d,a,b,c, X[ 8], 11, 2272392833); // 0x8771f681 /* 34 */
	ExecuteOperationWithFunctionH(c,d,a,b, X[11], 16, 1839030562); // 0x6d9d6122 /* 35 */
	ExecuteOperationWithFunctionH(b,c,d,a, X[14], 23, 4259657740); // 0xfde5380c /* 36 */
	ExecuteOperationWithFunctionH(a,b,c,d, X[ 1],  4, 2763975236); // 0xa4beea44 /* 37 */
	ExecuteOperationWithFunctionH(d,a,b,c, X[ 4], 11, 1272893353); // 0x4bdecfa9 /* 38 */
	ExecuteOperationWithFunctionH(c,d,a,b, X[ 7], 16, 4139469664); // 0xf6bb4b60 /* 39 */
	ExecuteOperationWithFunctionH(b,c,d,a, X[10], 23, 3200236656); // 0xbebfbc70 /* 40 */
	ExecuteOperationWithFunctionH(a,b,c,d, X[13],  4,  681279174); // 0x289b7ec6 /* 41 */
	ExecuteOperationWithFunctionH(d,a,b,c, X[ 0], 11, 3936430074); // 0xeaa127fa /* 42 */
	ExecuteOperationWithFunctionH(c,d,a,b, X[ 3], 16, 3572445317); // 0xd4ef3085 /* 43 */
	ExecuteOperationWithFunctionH(b,c,d,a, X[ 6], 23,   76029189); //  0x4881d05 /* 44 */
	ExecuteOperationWithFunctionH(a,b,c,d, X[ 9],  4, 3654602809); // 0xd9d4d039 /* 45 */
	ExecuteOperationWithFunctionH(d,a,b,c, X[12], 11, 3873151461); // 0xe6db99e5 /* 46 */
	ExecuteOperationWithFunctionH(c,d,a,b, X[15], 16,  530742520); // 0x1fa27cf8 /* 47 */
	ExecuteOperationWithFunctionH(b,c,d,a, X[ 2], 23, 3299628645); // 0xc4ac5665 /* 48 */
	
	// Round 4.
	ExecuteOperationWithFunctionI(a,b,c,d, X[ 0],  6, 4096336452); // 0xf4292244 /* 49 */
	ExecuteOperationWithFunctionI(d,a,b,c, X[ 7], 10, 1126891415); // 0x432aff97 /* 50 */
	ExecuteOperationWithFunctionI(c,d,a,b, X[14], 15, 2878612391); // 0xab9423a7 /* 51 */
	ExecuteOperationWithFunctionI(b,c,d,a, X[ 5], 21, 4237533241); // 0xfc93a039 /* 52 */
	ExecuteOperationWithFunctionI(a,b,c,d, X[12],  6, 1700485571); // 0x655b59c3 /* 53 */
	ExecuteOperationWithFunctionI(d,a,b,c, X[ 3], 10, 2399980690); // 0x8f0ccc92 /* 54 */
	ExecuteOperationWithFunctionI(c,d,a,b, X[10], 15, 4293915773); // 0xffeff47d /* 55 */
	ExecuteOperationWithFunctionI(b,c,d,a, X[ 1], 21, 2240044497); // 0x85845dd1 /* 56 */
	ExecuteOperationWithFunctionI(a,b,c,d, X[ 8],  6, 1873313359); // 0x6fa87e4f /* 57 */
	ExecuteOperationWithFunctionI(d,a,b,c, X[15], 10, 4264355552); // 0xfe2ce6e0 /* 58 */
	ExecuteOperationWithFunctionI(c,d,a,b, X[ 6], 15, 2734768916); // 0xa3014314 /* 59 */
	ExecuteOperationWithFunctionI(b,c,d,a, X[13], 21, 1309151649); // 0x4e0811a1 /* 60 */
	ExecuteOperationWithFunctionI(a,b,c,d, X[ 4],  6, 4149444226); // 0xf7537e82 /* 61 */
	ExecuteOperationWithFunctionI(d,a,b,c, X[11], 10, 3174756917); // 0xbd3af235 /* 62 */
	ExecuteOperationWithFunctionI(c,d,a,b, X[ 2], 15,  718787259); // 0x2ad7d2bb /* 63 */
	ExecuteOperationWithFunctionI(b,c,d,a, X[ 9], 21, 3951481745); // 0xeb86d391 /* 64 */
	
	a = BinarySum(a, aa);
	b = BinarySum(b, bb);
	c = BinarySum(c, cc);
	d = BinarySum(d, dd);
EndProcedure

Procedure ExecuteOperationWithFunctionF(a, b, c, d, X, s, t)
	ExecuteOperation(BitwiseOr(BitwiseAnd(b, c), BitwiseAnd(BitwiseNot(b), d)), a, b, X, s, t);
EndProcedure

Procedure ExecuteOperationWithFunctionG(a, b, c, d, X, s, t)
	ExecuteOperation(BitwiseOr(BitwiseAnd(b, d), BitwiseAnd(BitwiseNot(d), c)), a, b, X, s, t);
EndProcedure

Procedure ExecuteOperationWithFunctionH(a, b, c, d, X, s, t)
	ExecuteOperation(BitwiseXor(BitwiseXor(b, c), d), a, b, X, s, t);
EndProcedure

Procedure ExecuteOperationWithFunctionI(a, b, c, d, X, s, t)
	ExecuteOperation(BitwiseXor(BitwiseOr(BitwiseNot(d), b), c), a, b, X, s, t);
EndProcedure

Procedure ExecuteOperation(q, a, b, X, s, t)
	a = BinarySum(RotateLeft(BinarySum(BinarySum(a, q), BinarySum(X, t)), s), b);
EndProcedure

Function RotateLeft(Number, DigitsCount)
	Result = Number;
	For DigitNumber = 1 To DigitsCount Do
		Bit = CheckBit(Result, 31);
		Result = BitwiseShiftLeft(Result, 1)% Pow(2,32);
		Result = SetBit(Result, 0, Bit);
	EndDo;
	Return Result;
EndFunction

Function NumberToBinaryData(Number)
	
	DataBuffer = New BinaryDataBuffer(4);
	DataBuffer.WriteInt32(0, Number);
	BinaryData = GetBinaryDataFromBinaryDataBuffer(DataBuffer);
	Return BinaryData;
	
EndFunction

Function BinarySum(Argument1, Argument2)
	Result = (Argument1+Argument2)% Pow(2,32);
	Return Result;
EndFunction

Function AddToBinaryData(BinaryData, Create)
	BinaryDataArray = New Array;
	BinaryDataArray.Add(BinaryData);
	BinaryDataArray.Add(Create);
	Return ConcatBinaryData(BinaryDataArray);
EndFunction

// ACC:1353-on, ACC-247-on 

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Used in the obsolete function "CommonClient.CheckFileSystemExtensionAttached".
Procedure CheckFileSystemExtensionAttachedCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached Then
		ExecuteNotifyProcessing(AdditionalParameters.OnCloseNotifyDescription);
		Return;
	EndIf;
	
	MessageText = AdditionalParameters.WarningText;
	If IsBlankString(MessageText) Then
		MessageText = NStr("en = 'Cannot perform the operation because 1C:Enterprise Extension is not installed.';")
	EndIf;
	ShowMessageBox(, MessageText);
	
EndProcedure

#EndRegion

#EndRegion