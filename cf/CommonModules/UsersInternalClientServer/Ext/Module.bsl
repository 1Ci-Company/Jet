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

// Returns the string of the day, days kind.
//
// Parameters:
//   Number                       - Number  - an integer to which to add numeration item.
//   FormatString             - String - see the parameter of the same name of the NumberInWords method,
//                                          for example, DE=True.
//   NumerationItemOptions - String - see the parameter of the same name of the NumberInWords method,
//                                          for example, NStr("en= day, day, days,,,,,,0'").
//
//  Returns:
//   String
//
Function IntegerSubject(Number, FormatString, NumerationItemOptions) Export
	
	Integer1 = Int(Number);
	
	NumberInWords = NumberInWords(Integer1, FormatString, NStr("en = ',,,,,,,,0';"));
	
	SubjectAndNumberInWords = NumberInWords(Integer1, FormatString, NumerationItemOptions);
	
	Return StrReplace(SubjectAndNumberInWords, NumberInWords, "");
	
EndFunction

// Returns a structure that contains the names of security warning types.
// Each property contains the name of a key.
//
// Returns:
//  Structure:
//   * AfterUpdate - String
//   * BeforeAddExternalReportOrDataProcessor - String
//   * BeforeAddExtensions - String
//   * BeforeSelectUpdateFile - String
//   * BeforeSelectRole - String
//   * OnChangeDeniedExtensionsList - String
//   * BeforeOpenFile - String
//   * BeforeAddAddIn - String
//   * BeforeDeleteExtensionWithoutData - String
//   * BeforeDeleteExtensionWithData - String
//   * BeforeDisableExtensionWithData - String
//
Function SecurityWarningKinds() Export
	
	Result = New Structure;
	Result.Insert("AfterUpdate");
	Result.Insert("AfterObtainRight");
	Result.Insert("BeforeAddExternalReportOrDataProcessor");
	Result.Insert("BeforeAddExtensions");
	Result.Insert("BeforeSelectUpdateFile");
	Result.Insert("BeforeSelectRole");
	Result.Insert("OnChangeDeniedExtensionsList");
	Result.Insert("BeforeOpenFile");
	Result.Insert("BeforeAddAddIn");
	Result.Insert("BeforeDeleteExtensionWithoutData");
	Result.Insert("BeforeDeleteExtensionWithData");
	Result.Insert("BeforeDisableExtensionWithData");
	
	For Each KeyAndValue In Result Do
		Result[KeyAndValue.Key] = KeyAndValue.Key;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

// Generates the user name based on the  full name.
Function GetIBUserShortName(Val FullName) Export
	
	Separators = New Array;
	Separators.Add(" ");
	Separators.Add(".");
	
	ShortName = "";
	For Counter = 1 To 3 Do
		
		If Counter <> 1 Then
			ShortName = ShortName + Upper(Left(FullName, 1));
		EndIf;
		
		SeparatorPosition = 0;
		For Each Separator In Separators Do
			CurrentSeparatorPosition = StrFind(FullName, Separator);
			If CurrentSeparatorPosition > 0
			   And (    SeparatorPosition = 0
			      Or SeparatorPosition > CurrentSeparatorPosition ) Then
				SeparatorPosition = CurrentSeparatorPosition;
			EndIf;
		EndDo;
		
		If SeparatorPosition = 0 Then
			If Counter = 1 Then
				ShortName = FullName;
			EndIf;
			Break;
		EndIf;
		
		If Counter = 1 Then
			ShortName = Left(FullName, SeparatorPosition - 1);
		EndIf;
		
		FullName = Right(FullName, StrLen(FullName) - SeparatorPosition);
		While Separators.Find(Left(FullName, 1)) <> Undefined Do
			FullName = Mid(FullName, 2);
		EndDo;
	EndDo;
	
	Return ShortName;
	
EndFunction

// For the Users and ExternalUsers catalogs item form.
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects:
//    * Items - FormAllItems:
//        ** CanSignIn - FormField
//                                  - FormFieldExtensionForACheckBoxField
//        ** ChangeAuthorizationRestriction - FormField
//                                               - FormFieldExtensionForACheckBoxField
//
Procedure UpdateLifetimeRestriction(Form) Export
	
	Items = Form.Items;
	
	Items.ChangeAuthorizationRestriction.Visible =
		Items.IBUserProperies.Visible And Form.AccessLevel.ListManagement;
	
	If Not Items.IBUserProperies.Visible Then
		Items.CanSignIn.Title = "";
		Return;
	EndIf;
	
	Items.ChangeAuthorizationRestriction.Enabled = Form.AccessLevel.AuthorizationSettings2;
	
	TitleWithRestriction = "";
	
	If Form.UnlimitedValidityPeriod Then
		TitleWithRestriction = NStr("en = 'Login allowed (no time limit)';");
		
	ElsIf ValueIsFilled(Form.ValidityPeriod) Then
		TitleWithRestriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Login allowed (till %1)';"),
			Format(Form.ValidityPeriod, "DLF=D"));
			
	ElsIf ValueIsFilled(Form.InactivityPeriodBeforeDenyingAuthorization) Then
		TitleWithRestriction = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Login allowed (revoke access after inactivity of %1)';"),
			Format(Form.InactivityPeriodBeforeDenyingAuthorization, "NG=") + " "
				+ IntegerSubject(Form.InactivityPeriodBeforeDenyingAuthorization,
					"", NStr("en = 'day,days,,,0';")));
	EndIf;
	
	If ValueIsFilled(TitleWithRestriction) Then
		Items.CanSignIn.Title = TitleWithRestriction;
		Items.ChangeAuthorizationRestriction.Title = NStr("en = 'Change time restriction';");
	Else
		Items.CanSignIn.Title = "";
		Items.ChangeAuthorizationRestriction.Title = NStr("en = 'Set up time restriction';");
	EndIf;
	
EndProcedure

// For the Users and ExternalUsers catalogs item form.
//
// Parameters:
//  Form - See Catalog.Users.Form.ItemForm
//        - See Catalog.ExternalUsers.Form.ItemForm
//  PasswordIsSet - Boolean
//  AuthorizedUser - CatalogRef.Users
//                             - CatalogRef.ExternalUsers
//
Procedure CheckPasswordSet(Form, PasswordIsSet, AuthorizedUser) Export
	
	Items = Form.Items;
	
	If PasswordIsSet Then
		Items.PasswordExistsLabel.Title = NStr("en = 'The password is set.';");
		Items.UserMustChangePasswordOnAuthorization.Title =
			NStr("en = 'User must change password on next login';");
	Else
		Items.PasswordExistsLabel.Title = NStr("en = 'Blank password';");
		Items.UserMustChangePasswordOnAuthorization.Title =
			NStr("en = 'User must set password on next login';");
	EndIf;
	
	If PasswordIsSet
	   And Form.Object.Ref = AuthorizedUser Then
		
		Items.ChangePassword.Title = NStr("en = 'Change password…';");
	Else
		Items.ChangePassword.Title = NStr("en = 'Set password…';");
	EndIf;
	
EndProcedure

// For internal use only.
Function CurrentUser(AuthorizedUser) Export
	
	If TypeOf(AuthorizedUser) <> Type("CatalogRef.Users") Then
		Raise
			NStr("en = 'Cannot get the current external user
			           |in the external user session.';");
	EndIf;
	
	Return AuthorizedUser;
	
EndFunction

// For internal use only.
Function CurrentExternalUser(AuthorizedUser) Export
	
	If TypeOf(AuthorizedUser) <> Type("CatalogRef.ExternalUsers") Then
		Raise
			NStr("en = 'Cannot get the current external user
			           |in the user session.';");
	EndIf;
	
	Return AuthorizedUser;
	
EndFunction

#EndRegion
