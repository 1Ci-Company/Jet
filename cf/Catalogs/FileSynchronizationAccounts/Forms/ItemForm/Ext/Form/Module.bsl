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
	
	If ValueIsFilled(Object.FilesAuthor) Then
		AsFilesAuthor = "User";
		Items.FilesAuthor.Enabled = True;
	Else
		AsFilesAuthor = "ExchangePlan";
		Items.FilesAuthor.Enabled = False;
	EndIf;
	
	AutoDescription = IsBlankString(Object.Description); 
	If Not IsBlankString(Object.Description) Then
		Items.AsFilesAuthor.ChoiceList[0].Presentation =
			StringFunctionsClientServer.SubstituteParametersToString(Items.AsFilesAuthor.Title, "(" + Object.Description + ")");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
		ModuleObjectAttributesLock = Common.CommonModule("ObjectAttributesLock");
		ModuleObjectAttributesLock.LockAttributes(ThisObject);
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		
		SetPrivilegedMode(True);
		AccountParameters1 = Common.ReadDataFromSecureStorage(Object.Ref, "Login, Password");
		SetPrivilegedMode(False);
		
		Login  = AccountParameters1.Login;
		Password = ?(ValueIsFilled(AccountParameters1.Password), UUID, "");
		
	EndIf;

	If Common.IsMobileClient() Then
		Items.Description.TitleLocation = FormItemTitleLocation.Top;
	EndIf
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Cancel Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Common.WriteDataToSecureStorage(CurrentObject.Ref, Login, "Login");
	If PasswordChanged Then
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
	EndIf;
	SetPrivilegedMode(False);
		
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	AutoDescription = IsBlankString(Object.Description); 
EndProcedure

&AtClient
Procedure ServiceChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If Not AutoDescription Then
		Return;
	EndIf;

	SelectedService = Items.Service.ChoiceList.FindByValue(ValueSelected);
	If Not IsBlankString(ValueSelected) And SelectedService <> Undefined Then
		Object.Description = SelectedService.Presentation;	
	Else
		Object.Description = NStr("en = 'Cloud file service';tr = 'Bulut dosya servisi'");	
	EndIf;
	
EndProcedure

&AtClient
Procedure AsFilesAuthorOnChange(Item)
	
	Object.FilesAuthor = Undefined;
	Items.FilesAuthor.Enabled = False;
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	PasswordChanged = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CheckSettings(Command)
	
	ClearMessages();
	
	If Object.Ref.IsEmpty() Or Modified Then
		NotifyDescription = New NotifyDescription("CheckSettingsCompletion", ThisObject);
		QueryText = NStr("en = 'To proceed with the settings validation, save the account data. Do you want to continue?';tr = 'Ayarları doğrulamak için hesap bilgilerini kaydetmeniz gerekir. Devam etmek istiyor musunuz?'");
		Buttons = New ValueList;
		Buttons.Add("Continue", NStr("en = 'Continue';tr = 'Devam'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QueryText, Buttons);
		Return;
	EndIf;
	
	CheckCanSyncWithCloudService();
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributeEdit(Command)
	
	ModuleObjectAttributesLockClient = CommonClient.CommonModule("ObjectAttributesLockClient");
	ModuleObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CheckSettingsCompletion(DialogResult, AdditionalParameters) Export
	
	If DialogResult <> "Continue" Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	CheckCanSyncWithCloudService();
	
EndProcedure

&AtClient
Procedure CheckCanSyncWithCloudService()
	
	ResultStructure1 = ExecuteConnectionCheck(Object.Ref);
	
	ResultProtocol = ResultStructure1.ResultProtocol;
	ResultText = ResultStructure1.ResultText;
	
	If ResultStructure1.Cancel Then
		
		ErrorMessage = NStr("en = 'Failed to check parameters for file synchronization.
				|
				|We recommend that you:
				|%3
				|
				|Technical details:
				|The %1 service returned the error code %2.
				|%5%4';tr = 'Dosya senkronizasyonu parametreleri kontrol edilemedi.
				|
				|Öneri:
				|%3
				|
				|Teknik bilgiler:
				|%1 servisi hata kodu verdi %2.
				|%5%4'");
		Recommendations = New Array;
		Recommendations.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Try again later (there might be temporary issues in the service). Contact the technical service %1.';tr = 'Daha sonra tekrar deneyin (serviste geçici sorunlar olabilir). %1 teknik servisiyle iletişime geçin.'"),
			Object.Service));
		Recommendations.Add(NStr("en = 'Select another service for file synchronization.';tr = 'Dosya senkronizasyonu için başka bir servis seçin.'"));
		
		ErrorText = "";
		
		ProtocolText = StringFunctionsClientServer.ExtractTextFromHTML(ResultProtocol);
		If Not ValueIsFilled(ResultStructure1.ErrorCode) Then
			
			DiagnosticsResult = CheckConnection(Object.Service, ProtocolText);
			ErrorText          = DiagnosticsResult.ErrorDescription;
			ProtocolText       = DiagnosticsResult.DiagnosticsLog;
			
		ElsIf ResultStructure1.ErrorCode = 404 Then
			Recommendations.Insert(0, NStr("en = 'Check whether the specified root folder exists in the cloud service.';tr = 'Belirtilen kök klasörün bulut servisinde mevcut olup olmadığını kontrol edin.'"));
		ElsIf ResultStructure1.ErrorCode = 401 Then
			Recommendations.Insert(0, NStr("en = 'Check whether the username and password are valid.';tr = 'Kullanıcı adı ve şifrenin doğru olup olmadığını kontrol edin.'"));
		ElsIf ResultStructure1.ErrorCode = 10404 Then
			ResultStructure1.ErrorCode = ResultStructure1.ErrorCode - 10000;
			// The server does not allow saving additional file properties
		ElsIf ResultStructure1.ErrorCode = 501 Then
			// No WebDAV protocol method is implemented on the server
		Else
			Recommendations.Insert(0, NStr("en = 'Check the validity of the data you entered.';tr = 'Girdiğiniz verileri kontrol edin.'"));
		EndIf;
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		QuestionParameters.Picture = PictureLib.DialogStop;
		QuestionParameters.Title = NStr("en = 'Check the setting';tr = 'Ayarı kontrol et'");
		
		RecommendationsText = "";
		
		For RecommendationIndex = 0 To Recommendations.UBound() Do
			RecommendationsText = RecommendationsText + StringFunctionsClientServer.SubstituteParametersToString("
			|    %1. %2", RecommendationIndex+1, Recommendations[RecommendationIndex]);
		EndDo;
			
		StandardSubsystemsClient.ShowQuestionToUser(
			Undefined,
			 StringFunctionsClientServer.SubstituteParametersToString(
			ErrorMessage,
				Object.Service, ResultStructure1.ErrorCode, RecommendationsText, ProtocolText, 
				?(ValueIsFilled(ErrorText),"", Chars.LF+ErrorText)),
			QuestionDialogMode.OK,
			QuestionParameters);
		
	Else

		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		QuestionParameters.Picture = PictureLib.Success32;
		QuestionParameters.Title = NStr("en = 'Check the setting';tr = 'Ayarı kontrol et'");
	
		StandardSubsystemsClient.ShowQuestionToUser(
			Undefined,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameters for file synchronization are successfully checked. 
						   |%1';tr = 'Dosyaların senkronizasyonu için parametre kontrolü başarı ile tamamlandı. 
						   |%1'"),
				ResultText),
			QuestionDialogMode.OK,
			QuestionParameters);
		
	EndIf;
		
EndProcedure

&AtServer
Function ExecuteConnectionCheck(Val Account)
	ResultStructure1 = Undefined;
	FilesOperationsInternal.ExecuteConnectionCheck(Account, ResultStructure1);
	Return ResultStructure1; 
EndFunction

&AtServerNoContext
Function CheckConnection(Val Service, Val ProtocolText)
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		Return ModuleNetworkDownload.ConnectionDiagnostics(Service);
	Else
		
		Return New Structure("ErrorDescription, DiagnosticsLog",
			NStr("en = 'Please check the Internet connection.';tr = 'İnternet bağlantınızı kontrol edin.'"), ProtocolText);
			
	EndIf;
	
EndFunction

&AtClient
Procedure AsFilesAuthorUserOnChange(Item)
	
	Items.FilesAuthor.Enabled = True;
	
EndProcedure

#EndRegion