///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

// 
Var IsNew, PreviousParent, PreviousComposition, IsFullUser;

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Check the parent.
	If Parent = Users.AllUsersGroup() Then
		CommonClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en = 'Cannot set the ""All users"" group as a parent.';tr = '""Tüm kullanıcılar"" grubu ana grup olarak belirlenemez.'"),
			"");
	EndIf;
	
	// Checking for unfilled and duplicate users.
	VerifiedObjectAttributes.Add("Content.User");
	
	For Each CurrentRow In Content Do;
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Check whether the value is filled.
		If Not ValueIsFilled(CurrentRow.User) Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'User is not selected.';tr = 'Kullanıcı seçilmedi.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'User is not selected in line #%1.';tr = '%1 satırındaki kullanıcı seçilmedi.'"));
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = Content.FindRows(New Structure("User", CurrentRow.User));
		If FoundValues.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'Duplicate user.';tr = 'Kopya kullanıcı.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'Duplicate user in line #%1.';tr = '%1 satırındaki kullanıcı tekrarlandı.'"));
		EndIf;
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, VerifiedObjectAttributes);
	
EndProcedure

// Cancels actions that cannot be performed on the "All users" group.
Procedure BeforeWrite(Cancel)
	
	// ACC:75-off - The check "DataExchange.Import" should run after the registers are locked.
	If Common.FileInfobase() Then
		UsersInternal.LockRegistersBeforeWritingToFileInformationSystem(True);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	IsFullUser = Users.IsFullUser();
	
	If Not IsNew Then
		PreviousValues1 = Common.ObjectAttributesValues(Ref,
			"Parent" + ?(IsFullUser, "", ", Content"));
		PreviousParent = PreviousValues1.Parent;
		PreviousComposition   = ?(IsFullUser,
			Undefined, PreviousValues1.Content.Unload());
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AllUsersGroup = Users.AllUsersGroup();
	
	If Ref = AllUsersGroup Then
		If Not Parent.IsEmpty() Then
			ErrorText = NStr("en = 'The position of the ""All users"" group cannot be changed. It is the root of the group tree.';tr = '""Tüm kullanıcılar"" grubu, grup ağacının kökü olduğundan, pozisyonu değiştirilemiyor.'");
			Raise ErrorText;
		EndIf;
		If Content.Count() > 0 Then
			ErrorText = NStr("en = 'Cannot add members to the ""All users"" group.';tr = '""Tüm kullanıcılar"" grubuna üye eklenemiyor.'");
			Raise ErrorText;
		EndIf;
	Else
		If Parent = AllUsersGroup Then
			ErrorText = NStr("en = 'Cannot set the ""All users"" group as a parent.';tr = '""Tüm kullanıcılar"" grubu ana grup olarak belirlenemez.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If Not IsFullUser And Ref <> AllUsersGroup Then
		CompositionChange = UsersInternal.ColumnValueDifferences("User",
			Content.Unload(), PreviousComposition);
		CheckChangeCompositionRight(CompositionChange);
	EndIf;
	
	ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
	
	If Ref = AllUsersGroup Then
		UsersInternal.UpdateAllUsersGroupComposition(
			Catalogs.Users.EmptyRef(), ChangesInComposition);
	Else
		If PreviousParent <> Parent Then
			UsersInternal.UpdateGroupsHierarchy(Ref, ChangesInComposition, False);
			
			If ValueIsFilled(PreviousParent) Then
				UsersInternal.UpdateHierarchicalUserGroupCompositions(PreviousParent,
					ChangesInComposition);
			EndIf;
		EndIf;
		
		UsersInternal.UpdateHierarchicalUserGroupCompositions(Ref,
			ChangesInComposition);
	EndIf;
	
	UsersInternal.AfterUserGroupsUpdate(ChangesInComposition);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	UsersInternal.UpdateGroupsCompositionBeforeDeleteUserOrGroup(Ref);
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckChangeCompositionRight(CompositionChange)
	
	If Not ValueIsFilled(CompositionChange) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Users", CompositionChange);
	Query.Text =
	"SELECT
	|	Users.Description AS Description
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref IN(&Users)
	|	AND NOT Users.Prepared";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	UsersContent = QueryResult.Unload().UnloadColumn("Description");
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Insufficient access rights to modify:
		           |%1
		           |
		           |Only new users who have not yet been approved by the administrator
		           |can be included in or excluded from user groups
		           |(that is, the administrator has not yet allowed users to log in).';tr = 'Değiştirmek için gerekli yetkiler yok:
		           |%1
		           |
		           |Sadece yönetici tarafından henüz onaylanmamış yeni kullanıcılar 
		           |(yöneticinin, giriş yapmasına henüz izin veremediği kullanıcılar) 
		           |kullanıcı gruplarına eklenebilir veya çıkarılabilir.'"),
		StrConcat(UsersContent, Chars.LF));
	Raise(ErrorText, ErrorCategory.AccessViolation);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';tr = 'İstemcide geçersiz nesne çağrısı.'");
#EndIf