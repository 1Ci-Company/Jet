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
		
	ObjectValue = Parameters.Key.GetObject();
	ObjectValue.Fill(Undefined);
	
	SetUpFormObject(ObjectValue);
	
	If TypeOf(Object.Owner) = Type("CatalogRef.Files") Then
		Items.Description0.ReadOnly = True;
	EndIf;
	
	If Users.IsFullUser() Then
		Items.Author0.ReadOnly = False;
		Items.CreationDate0.ReadOnly = False;
	Else
		Items.LocationGroup3.Visible = False;
	EndIf;
	
	VolumeFullPath = FilesOperationsInVolumesInternal.FullVolumePath(Object.Volume);
	
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	
	FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TextFilesExtensionsList, Object.Extension);
	
	If FileExtensionInList Then
		If ValueIsFilled(Object.Ref) Then
			
			EncodingValue = InformationRegisters.FilesEncoding.FileVersionEncoding(Object.Ref);
			
			EncodingsList = FilesOperationsInternal.Encodings();
			ListItem = EncodingsList.FindByValue(EncodingValue);
			If ListItem = Undefined Then
				Encoding = EncodingValue;
			Else	
				Encoding = ListItem.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Encoding) Then
			Encoding = NStr("en = 'Default';");
		EndIf;
	Else
		Items.Encoding.Visible = False;
	EndIf;
	
	Items.FormDelete.Visible =
		Object.Author = Users.AuthorizedUser();
	
	If Common.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "StandardSaveAndClose", "Representation", ButtonRepresentation.Picture);
		
		If Items.Find("Comment") <> Undefined Then
			
			CommonClientServer.SetFormItemProperty(Items, "Comment", "MaxHeight", 2);
			CommonClientServer.SetFormItemProperty(Items, "Comment", "AutoMaxHeight", False);
			CommonClientServer.SetFormItemProperty(Items, "Comment", "VerticalStretch", False);
			
		EndIf;
		
		If Items.Find("Comment0") <> Undefined Then
			
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "MaxHeight", 2);
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "AutoMaxHeight", False);
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "VerticalStretch", False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OpenExecute()
	
	VersionRef = Object.Ref;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Object.Owner, VersionRef, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveAs(Command)
	
	VersionRef = Object.Ref;
	FileData = FilesOperationsInternalServerCall.FileDataToSave(Object.Owner, VersionRef, UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	ProcessWriteFileVersionCommand();
EndProcedure

&AtClient
Procedure StandardSaveAndClose(Command)
	
	If ProcessWriteFileVersionCommand() Then
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
Procedure Delete(Command)
	
	FilesOperationsInternalClient.DeleteData(
		New NotifyDescription("AfterDeleteData", ThisObject),
		CurrentFormObject().Ref, UUID);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Close();
	
EndProcedure

&AtServer
Procedure SetUpFormObject(Val NewObject)
	
	ValueToFormAttribute(NewObject, "Object");
	For Each Item In Items Do
		
		If TypeOf(Item) = Type("FormField")
			And StrStartsWith(Item.DataPath, "PrototypeObject[0].")
			And StrEndsWith(Item.Name, "0") Then
			
			TagName = Left(Item.Name, StrLen(Item.Name) -1);
			If Items.Find(TagName) <> Undefined  Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(TagName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			If Item.Type = FormFieldType.CheckBoxField Or Item.Type = FormFieldType.PictureField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			Item.Visible = False;
			
		EndIf;
		
	EndDo;
	
	If Not NewObject.IsNew() Then
		URL = GetURL(NewObject);
	EndIf;

EndProcedure

&AtClient
Function ProcessWriteFileVersionCommand()
	
	If IsBlankString(Object.Description) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify the name of the file version.';"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FilesOperationsInternalClient.CorrectFileName(Object.Description);
	Except
		CommonClient.MessageToUser(
			ErrorProcessing.BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If Not WriteFileVersion() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(Object.Ref, DataChangeType.Update);
	NotifyChanged(Object.Ref);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("VersionSaved");
	Notify("Write_File", FileWriteNotificationParameters, Object.Owner);
	Notify("Write_FileVersion", New Structure("IsNew", False), Object.Ref);
	
	Return True;
	
EndFunction

&AtServer
Function WriteFileVersion(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object"); // CatalogObject
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	BeginTransaction();
	Try
		ObjectToWrite.Write();
		CommitTransaction();
	Except
		
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Files.Error writing version of attachment';",
			Common.DefaultLanguageCode()), EventLogLevel.Error, , ,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Raise;
		
	EndTry;
	
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure RereadDataFromServer()
	
	FileObject1 = CurrentFormObjectServer().Ref.GetObject();
	ValueToFormAttribute(FileObject1, "Object");
	
EndProcedure

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Function IsNew()
	
	Return CurrentFormObject().Ref.IsEmpty();
	
EndFunction

// Returns:
//   CatalogObject
//
&AtClient
Function CurrentFormObject()

	Return Object;

EndFunction

// Returns:
//   CatalogObject
//
&AtServer
Function CurrentFormObjectServer()

	Return Object;

EndFunction

#EndRegion