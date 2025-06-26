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
	
	IsNewGroup = Parameters.IsNewGroup;
	If IsNewGroup Then
		
		ObjectValue = Catalogs[Parameters.FilesStorageCatalogName].CreateFolder();
		If Parameters.Parent <> Undefined
			And TypeOf(Parameters.Parent) = TypeOf(ObjectValue.Ref) Then
			
			ParentProperties = Common.ObjectAttributesValues(Parameters.Parent, "IsFolder,Parent");
			If ParentProperties.IsFolder Then
				ObjectValue.Parent = Parameters.Parent;
			ElsIf ParentProperties.Parent <> Undefined
				And TypeOf(ParentProperties.Parent) = TypeOf(ObjectValue.Ref) Then
				
				ObjectValue.Parent = ParentProperties.Parent; // As the first parent, the reference to the item was passed.
			EndIf;
			
		Else
			ObjectValue.Parent = Undefined;
		EndIf;
		
		ObjectValue.FileOwner = Parameters.FileOwner;
		ObjectValue.CreationDate  = CurrentUniversalDate();
		ObjectValue.Author         = Users.AuthorizedUser();
		ObjectValue.ChangedBy       = ObjectValue.Author;
		
	ElsIf ValueIsFilled(Parameters.CopyingValue) Then
		
		ObjectToCopy        = Parameters.CopyingValue.GetObject();
		ObjectValue          = Catalogs[ObjectToCopy.Metadata().Name].CreateFolder();
		ObjectValue.Parent = Parameters.Parent;
		
		FillPropertyValues(ObjectValue, ObjectToCopy,
			"FileOwner, CreationDate, LongDesc, Description, UniversalModificationDate, ChangedBy");
		
		ObjectValue.Author = Users.AuthorizedUser();
		
	Else
		
		If ValueIsFilled(Parameters.AttachedFile) Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		ElsIf ValueIsFilled(Parameters.Key) Then
			ObjectValue = Parameters.Key.GetObject();
		Else
			Raise NStr("en = 'You cannot create a file group.';");
		EndIf;
		
	EndIf;
	ObjectValue.Fill(Undefined);
	
	CatalogName = ObjectValue.Metadata().Name;
	
	SetUpFormObject(ObjectValue);
	
	If ReadOnly
		Or Not AccessRight("Update", ThisObject.Object.FileOwner.Metadata()) Then
		
		Items.FormStandardWrite.Enabled                  = False;
		Items.FormStandardSaveAndClose.Enabled          = False;
		Items.FormStandardMarkForDeletion.Enabled = False;
		
	EndIf;
	
	If Not ReadOnly
		And Not CurrentRefToFileServer().IsEmpty() Then
		
		LockDataForEdit(CurrentRefToFileServer(), , UUID);
	EndIf;
	
	RefreshTitle();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Modified Then
		
		Cancel = True;
		ResponseNotification = New NotifyDescription("CloseFormAfterAnswerQuestion", ThisObject);
		ShowQueryBox(ResponseNotification, NStr("en = 'The data has been changed. Do you want to save the changes?';"), QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure StandardWrite(Command)
	HandleFileRecordCommand();
EndProcedure

&AtClient
Procedure StandardSaveAndClose(Command)
	
	If HandleFileRecordCommand() Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardReread(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Not Modified Then
		RereadDataFromServer();
		Return;
	EndIf;
	
	QueryText = NStr("en = 'The data has been changed. Do you want to refresh the data?';");
	
	NotifyDescription = New NotifyDescription("StandardRereadAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure StandardCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", CurrentRefToFile());
	OpenForm("DataProcessor.FilesOperations.Form.FilesGroup", FormParameters);
	
EndProcedure

&AtClient
Procedure StandardShowInList(Command)
	
	StandardSubsystemsClient.ShowInList(CurrentRefToFile(), Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetUpFormObject(Val NewObject)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(NewAttribute);
	
	ChangeAttributes(AttributesToBeAdded);
	
	ValueToFormAttribute(NewObject, "Object");
	
	For Each Item In Items Do
		If TypeOf(Item) = Type("FormField")
			And StrStartsWith(Item.DataPath, "PrototypeObject[0].")
			And StrEndsWith(Item.Name, "0") Then
			
			TagName = Left(Item.Name, StrLen(Item.Name) -1);
			If Items.Find(TagName) <> Undefined Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(TagName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			
			If Item.Type = FormFieldType.LabelField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			
			Item.Visible = False;
		EndIf;
	EndDo;
	
	CreatedStatus = StringFunctions.FormattedString(NStr("en = '<a href=""%1"">%2</a>';"),
		GetURL(ThisObject["Object"].Author), String(ThisObject["Object"].Author));
	
	RefreshInformationAboutChange();
	
	If Parameters.Parent <> Undefined
			And TypeOf(Parameters.Parent) = TypeOf(NewObject.Ref) Then
		NewObject.Parent = Parameters.Parent;
	EndIf;
	
	If Not NewObject.IsNew() Then
		URL = GetURL(NewObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshTitle()
	
	CurrentRefToFile = CurrentRefToFileServer();
	If ValueIsFilled(CurrentRefToFile) Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (File group)';"), String(CurrentRefToFile));
	Else
		Title = NStr("en = 'File group (Create)';")
	EndIf;
	
EndProcedure

&AtClient
Function HandleFileRecordCommand()
	
	ClearMessages();
	
	If IsBlankString(ThisObject.Object.Description) Then
		CommonClient.MessageToUser(
			NStr("en = 'To proceed, please provide the file name.';"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FilesOperationsInternalClient.CorrectFileName(ThisObject.Object.Description);
	Except
		CommonClient.MessageToUser(
			ErrorProcessing.BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If Not WriteFile() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	FileWriteNotificationParameters.IsNew = FileCreated;
	Notify("Write_File", FileWriteNotificationParameters, ThisObject.Object.Ref);
	
	Return True;
	
EndFunction

&AtClient
Function IsNew()
	
	Return CurrentRefToFile().IsEmpty();
	
EndFunction

&AtServer
Function WriteFile(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object"); //CatalogObject
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	BeginTransaction();
	Try
		ObjectToWrite.ChangedBy                      = Users.AuthorizedUser();
		ObjectToWrite.UniversalModificationDate = CurrentUniversalDate();
		ObjectToWrite.Write();
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Files.Error writing group of attachments';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()) );
		Raise;
		
	EndTry;
	
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	RefreshTitle();
	RefreshInformationAboutChange();
	
	Return True;
	
EndFunction

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure RereadDataFromServer()
	
	FileObject1 = CurrentRefToFileServer().GetObject();
	ValueToFormAttribute(FileObject1, "Object");
	
	RefreshInformationAboutChange();

EndProcedure

&AtServer
Procedure RefreshInformationAboutChange()
	
	ChangedStatus = StringFunctions.FormattedString(NStr("en = '<a href=""%1"">%2</a>';"),
		GetURL(ThisObject.Object.ChangedBy), String(ThisObject.Object.ChangedBy));
	
EndProcedure

&AtClient
Procedure CloseFormAfterAnswerQuestion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes
		And HandleFileRecordCommand() Then
		Close();
	ElsIf Response = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Function CurrentRefToFile()
	
	FormObject = ThisObject.Object; // CatalogObject
	Return FormObject.Ref;
	
EndFunction

&AtServer
Function CurrentRefToFileServer()

	FormObject = ThisObject.Object; // CatalogObject
	Return FormObject.Ref;

EndFunction

#EndRegion