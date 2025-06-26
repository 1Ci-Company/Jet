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
	
	OnAuthorization        = Parameters.OnAuthorization;
	ReturnPasswordAndDoNotSet = Parameters.ReturnPasswordAndDoNotSet;
	PreviousPassword              = Parameters.PreviousPassword;
	LoginName               = Parameters.LoginName;
	
	If ReturnPasswordAndDoNotSet Or ValueIsFilled(Parameters.User) Then
		User = Parameters.User;
	Else
		User = Users.AuthorizedUser();
	EndIf;
	
	AdditionalParameters = New Structure;
	If Not ReturnPasswordAndDoNotSet Then
		AdditionalParameters.Insert("CheckUserValidity");
		AdditionalParameters.Insert("CheckIBUserExists");
	EndIf;
	If Not UsersInternal.CanChangePassword(User, AdditionalParameters) Then
		ErrorText = AdditionalParameters.ErrorText;
		Return;
	EndIf;
	IsCurrentIBUser = AdditionalParameters.IsCurrentIBUser;
	PasswordIsSet         = AdditionalParameters.PasswordIsSet;
	If Not ValueIsFilled(LoginName) Then
		LoginName = AdditionalParameters.LoginName;
	EndIf;
	
	If Not ReturnPasswordAndDoNotSet Then
		Try
			LockDataForEdit(User, , UUID);
		Except
			ErrorInfo = ErrorInfo();
			If Not OnAuthorization Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot open the password change form. Reason:
					           |
					           |%1';"),
					ErrorProcessing.BriefErrorDescription(ErrorInfo));
				Return;
			EndIf;
		EndTry;
	EndIf;
	
	If Not OnAuthorization Then
		Items.AuthorizationNote.Visible = False;
		Items.FormCloseForm.Title = NStr("en = 'Cancel';");
		
	ElsIf Not PasswordIsSet Then
		Items.AuthorizationNote.Title =
			NStr("en = 'To log in, set a password.';")
	EndIf;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
	If Not IsCurrentIBUser
	 Or Not PasswordIsSet Then
		
		Items.PreviousPassword.Visible = False;
		AutoTitle = False;
		Title = NStr("en = 'Set password';");
		
	ElsIf Parameters.PreviousPassword <> Undefined Then
		CurrentItem = Items.NewPassword;
	
	ElsIf OnAuthorization
	        And IsCurrentIBUser
	        And Not Common.DataSeparationEnabled() Then
		
		Items.PreviousPassword.Visible = False;
	EndIf;
	
	Items.NewPassword.ToolTip  = UsersInternal.NewPasswordHint();
	Items.NewPassword2.ToolTip = UsersInternal.NewPasswordHint();
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(ErrorText) Then
		Cancel = True;
		StandardSubsystemsClient.SetFormStorageOption(ThisObject, True);
		AttachIdleHandler("ShowErrorTextAndNotifyAboutClosing", 0.1, True);
	Else
		CheckPasswordConformation();
		RefreshShowOldPasswordWaitHandler();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PasswordOnChange(Item)
	
	CheckPasswordConformation();
	
EndProcedure

&AtClient
Procedure PasswordEditTextChange(Item, Text, StandardProcessing)
	
	CheckPasswordConformation(Item);
	RefreshShowOldPasswordWaitHandler();
	
EndProcedure

&AtClient
Procedure ShowNewPasswordOnChange(Item)
	
	ShowNewPasswordOnChangeAtServer();
	CheckPasswordConformation();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreatePassword(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ForExternalUser",
		TypeOf(User) = Type("CatalogRef.ExternalUsers"));
	
	OpenForm("CommonForm.NewPassword", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetPassword(Command)
	
	If Not ShowNewPassword And NewPassword <> Confirmation Then
		CurrentItem = Items.Confirmation;
		Items.Confirmation.SelectedText = Items.Confirmation.EditText;
		ShowMessageBox(, NStr("en = 'The passwords do not match.';"));
		Return;
	EndIf;
	
	If Not ReturnPasswordAndDoNotSet
	   And Not IsCurrentIBUser
	   And CommonClient.DataSeparationEnabled()
	   And ServiceUserPassword = Undefined Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("SetPasswordCompletion", ThisObject),
			ThisObject,
			ServiceUserPassword);
	Else
		SetPasswordCompletion(Null, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshShowOldPasswordWaitHandler()
	
	If OnAuthorization
	   And IsCurrentIBUser
	   And PasswordIsSet
	   And Not Items.PreviousPassword.Visible Then
		
		DetachIdleHandler("ShowOldPasswordWaitHandler");
		AttachIdleHandler("ShowOldPasswordWaitHandler", 60, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowOldPasswordWaitHandler()
	
	Items.PreviousPassword.Visible = True;
	
EndProcedure

&AtClient
Procedure ShowErrorTextAndNotifyAboutClosing()
	
	StandardSubsystemsClient.SetFormStorageOption(ThisObject, False);
	
	ShowMessageBox(New NotifyDescription(
		"ShowErrorTextAndNotifyAboutClosingCompletion", ThisObject), ErrorText);
	
EndProcedure

&AtClient
Procedure ShowErrorTextAndNotifyAboutClosingCompletion(Context) Export
	
	If OnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OnCloseNotifyDescription);
		OnCloseNotifyDescription = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckPasswordConformation(PasswordField = Undefined)
	
	If ShowNewPassword Then
		PasswordMatches = True;
	
	ElsIf PasswordField = Items.NewPassword
	      Or PasswordField = Items.NewPassword2 Then
		
		PasswordMatches = (PasswordField.EditText = Confirmation);
		
	ElsIf PasswordField = Items.Confirmation Then
		PasswordMatches = (NewPassword = PasswordField.EditText);
	Else
		PasswordMatches = (NewPassword = Confirmation);
	EndIf;
	
	Items.PasswordMismatchLabel.Visible = Not PasswordMatches;
	
EndProcedure

&AtServer
Procedure ShowNewPasswordOnChangeAtServer()
	
	Items.Confirmation.Enabled = Not ShowNewPassword;
	
	Items.NewPassword.Visible  = Not ShowNewPassword;
	Items.NewPassword2.Visible =    ShowNewPassword;
	
	If ShowNewPassword Then
		Confirmation = "";
	EndIf;
	
EndProcedure

// The procedure that follows SetPassword procedure.
&AtClient
Procedure SetPasswordCompletion(SaaSUserNewPassword, Context) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ErrorText = SetPasswordAtServer();
	If Not ValueIsFilled(ErrorText) Then
		Items.FormSetPassword.Enabled = False;
		AttachIdleHandler("ReturnResultAndCloseForm", 0.1, True);
	Else
		ShowMessageBox(, ErrorText);
	EndIf;
	
EndProcedure

&AtServer
Function SetPasswordAtServer()
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("User",              User);
	ExecutionParameters.Insert("LoginName",               LoginName);
	ExecutionParameters.Insert("NewPassword",               NewPassword);
	ExecutionParameters.Insert("PreviousPassword",              PreviousPassword);
	ExecutionParameters.Insert("OnAuthorization",        OnAuthorization);
	ExecutionParameters.Insert("ServiceUserPassword", ServiceUserPassword);
	ExecutionParameters.Insert("CheckOnly",           ReturnPasswordAndDoNotSet);
	
	If Not Common.DataSeparationEnabled()
	   And Not Items.PreviousPassword.Visible Then
		ExecutionParameters.PreviousPassword = Undefined;
	EndIf;
	
	Try
		ErrorText = UsersInternal.ProcessNewPassword(ExecutionParameters);
	Except
		ErrorInfo = ErrorInfo();
		If ExecutionParameters.Property("ErrorSavedToEventLog") Then
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		Else
			Raise;
		EndIf;
	EndTry;
	
	If Not ValueIsFilled(ErrorText) Then
		Return "";
	EndIf;
	
	If Not ExecutionParameters.PreviousPasswordMatches Then
		CurrentItem = Items.PreviousPassword;
		PreviousPassword = "";
	EndIf;
	
	ServiceUserPassword = ExecutionParameters.ServiceUserPassword;
	
	Return ErrorText;
	
EndFunction

&AtClient
Procedure ReturnResultAndCloseForm()
	
	Result = New Structure;
	If ReturnPasswordAndDoNotSet Then
		Result.Insert("NewPassword",  NewPassword);
		Result.Insert("PreviousPassword", ?(Items.PreviousPassword.Visible, PreviousPassword, Undefined));
	Else
		Result.Insert("BlankPasswordSet", NewPassword = "");
	EndIf;
	Close(Result);
	
EndProcedure

#EndRegion
