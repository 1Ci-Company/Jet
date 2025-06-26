///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Reading handler of report option settings.
//
// Parameters:
//   ReportKey        - String - Full report name (dot-delimited).
//   VariantKey      - String - Report option key.
//   Settings         - Arbitrary     - Report option settings.
//   SettingsDescription  - SettingsDescription - Additional details of the settings.
//   User      - String           - Name of the infobase user.
//       It is not used, because the "Report options" subsystem does not group report options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of the report key–option key pairs.
//
// See also::
//   "SettingsStorageManager.<Storage name>.LoadProcessing" in Syntax Assistant.
//
Procedure LoadProcessing(ReportKey, VariantKey, Settings, SettingsDescription, User)
	If Not ReportsOptionsCached.ReadRight1() Then
		Return;
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	ReportsOptions.Presentation,
	|	ReportsOptions.Settings
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey = &VariantKey");
	
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If SettingsDescription = Undefined Then
			SettingsDescription = New SettingsDescription;
			SettingsDescription.ObjectKey  = ReportKey;
			SettingsDescription.SettingsKey = VariantKey;
			SettingsDescription.User = User;
		EndIf;
		SettingsDescription.Presentation = Selection.Presentation;
		Settings = Selection.Settings.Get();
	EndIf;
EndProcedure

// Handler of writing report option settings.
//
// Parameters:
//   ReportKey        - String - Full report name (dot-delimited).
//   VariantKey      - String - Report option key.
//   Settings         - Arbitrary         - Report option settings.
//   SettingsDescription  - SettingsDescription     - Additional details of the settings.
//   User      - String
//                     - Undefined - Name of the infobase user.
//       It is not used, because the "Report options" subsystem does not group report options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of the report key–option key pairs.
//
// See also::
//   "SettingsStorageManager.<Storage name>.SaveProcessing" in Syntax Assistant.
//
Procedure SaveProcessing(ReportKey, VariantKey, Settings, SettingsDescription, User)
	If Not ReportsOptionsCached.InsertRight1() Then
		Raise(NStr("en = 'Insufficient rights to save report options.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
	
	Query = New Query(
	"SELECT ALLOWED
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey = &VariantKey");
	
	Query.SetParameter("Report",        ReportInformation.Report);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	OptionRef1 = Selection.Ref;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
		LockItem.SetValue("Ref", OptionRef1);
		Block.Lock();
		
		OptionObject = OptionRef1.GetObject();
		
		If TypeOf(Settings) = Type("DataCompositionSettings") Then
			Address = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "Address");
			If TypeOf(Address) = Type("String") And IsTempStorageURL(Address) Then
				SettingsFromStorage = GetFromTempStorage(Address);
			EndIf;
			Settings.AdditionalProperties.Delete("Address");
			Settings = ?(SettingsFromStorage = Undefined, Settings, SettingsFromStorage);
			
			Context = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "OptionContext");
			If ValueIsFilled(Context) Then 
				OptionObject.Context = Context;
			EndIf;
		EndIf;
		
		OptionObject.Settings = New ValueStorage(Settings);
		
		If SettingsDescription <> Undefined Then
			OptionObject.Description = SettingsDescription.Presentation;
		EndIf;
		
		OptionObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Receiving handler of report option settings details.
//
// Parameters:
//   ReportKey       - String - Full report name (dot-delimited).
//   VariantKey     - String - Report option key.
//   SettingsDescription - SettingsDescription     - Additional details of the settings.
//   User     - String
//                    - Undefined - Name of the infobase user.
//       It is not used, because the "Report options" subsystem does not group report options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of the report key–option key pairs.
//
// See also::
//   "SettingsStorageManager.<Storage name>.GetDescriptionProcessing" in Syntax Assistant.
//
Procedure GetDescriptionProcessing(ReportKey, VariantKey, SettingsDescription, User)
	If Not ReportsOptionsCached.ReadRight1() Then
		Return;
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	If SettingsDescription = Undefined Then
		SettingsDescription = New SettingsDescription;
	EndIf;
	
	SettingsDescription.ObjectKey  = ReportKey;
	SettingsDescription.SettingsKey = VariantKey;
	
	If TypeOf(User) = Type("String") Then
		SettingsDescription.User = User;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	Variants.Presentation,
	|	Variants.DeletionMark,
	|	Variants.Custom
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey");
	
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		SettingsDescription.Presentation = Selection.Presentation;
		SettingsDescription.AdditionalProperties.Insert("DeletionMark", Selection.DeletionMark);
		SettingsDescription.AdditionalProperties.Insert("Custom", Selection.Custom);
	EndIf;
EndProcedure

// Installation handler of report option settings details.
//
// Parameters:
//   ReportKey       - String - Full report name (dot-delimited).
//   VariantKey     - String - Report option key.
//   SettingsDescription - SettingsDescription - Additional details of the settings.
//   User     - String           - Name of the infobase user.
//       It is not used, because the "Report options" subsystem does not group report options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of the report key–option key pairs.
//
// See also::
//   "SettingsStorageManager.<Storage name>.SetDescriptionProcessing" in Syntax Assistant.
//
Procedure SetDescriptionProcessing(ReportKey, VariantKey, SettingsDescription, User)
	If Not ReportsOptionsCached.InsertRight1() Then
		Raise(NStr("en = 'Insufficient rights to save report options.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey");
	
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	OptionRef1 = Selection.Ref;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
		LockItem.SetValue("Ref", OptionRef1);
		Block.Lock();
		
		OptionObject = OptionRef1.GetObject();
		OptionObject.Description = SettingsDescription.Presentation;
		OptionObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

#EndIf

#EndRegion

#Region Private

// ACC:361-off - The preprocessor command wraps only the function implementation
// (rather than the entire function) to make it return a "ValueList" type value.

// Returns a list of user report options.
//
Function GetList(ReportKey, Val User = Undefined) Export // CAC:307 - Same as the standard setting storage method.
	List = New ValueList;

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

	AuthorReportsOptions = AuthorReportsOptions(ReportKey, User);
	If AuthorReportsOptions <> Undefined Then
		For Each ReportVariant In AuthorReportsOptions Do
			List.Add(ReportVariant.VariantKey, ReportVariant.Description);
		EndDo;
	EndIf;

#EndIf

	Return List;
EndFunction

// ACC:361-on

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Parameters:
//  ReportKey - CatalogRef.MetadataObjectIDs
//             - CatalogRef.ExtensionObjectIDs
//             - CatalogRef.AdditionalReportsAndDataProcessors
//             - String
//  Author - CatalogRef.Users
//        - CatalogRef.ExternalUsers
//        - UUID
//
// Returns:
//  - Undefined
//  - ValueTable:
//      * VariantKey - String
//      * Description - String
//
Function AuthorReportsOptions(ReportKey, Author)
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
		Report = ReportInformation.Report;
	Else
		Report = ReportKey;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	Variants.VariantKey,
	|	Variants.Description
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Author
	|	AND Variants.Author.IBUserID = &GUID
	|	AND NOT Variants.DeletionMark
	|	AND Variants.Custom");
	
	Query.SetParameter("Report", Report);
	
	If Author = "" Then
		Author = Users.UnspecifiedUserRef();
	ElsIf Author = Undefined Then
		Author = Users.AuthorizedUser();
	EndIf;
	
	If TypeOf(Author) = Type("CatalogRef.Users") Then
		
		Query.SetParameter("Author", Author);
		Query.Text = StrReplace(Query.Text, "AND Variants.Author.IBUserID = &GUID", ""); // @query-part-1
	Else
		If TypeOf(Author) = Type("UUID") Then
			UserIdentificator = Author;
		Else
			If TypeOf(Author) = Type("String") Then
				
				SetPrivilegedMode(True);
				IBUser = InfoBaseUsers.FindByName(Author);
				SetPrivilegedMode(False);
				
				If IBUser = Undefined Then
					Return Undefined;
				EndIf;
				
			ElsIf TypeOf(Author) = Type("InfoBaseUser") Then
				
				IBUser = Author;
			Else
				Return Undefined;
			EndIf;
			
			UserIdentificator = IBUser.UUID;
		EndIf;
		
		Query.SetParameter("GUID", UserIdentificator);
		Query.Text = StrReplace(Query.Text, "AND Variants.Author = &Author", ""); // @query-part-1
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction

#EndIf

Procedure Delete(ReportKey, VariantKey, Val User) Export
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
	QueryText = 
	"SELECT ALLOWED DISTINCT
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Author
	|	AND Variants.Author.IBUserID = &GUID
	|	AND Variants.VariantKey = &VariantKey
	|	AND NOT Variants.DeletionMark
	|	AND Variants.Custom";
	
	Query = New Query;
	
	If ReportKey = Undefined Then
		QueryText = StrReplace(QueryText, "Variants.Report = &Report", "TRUE");
	Else
		ReportInformation = ReportsOptions.ReportInformation(ReportKey, True);
		Query.SetParameter("Report", ReportInformation.Report);
	EndIf;
	
	If VariantKey = Undefined Then
		QueryText = StrReplace(QueryText, "AND Variants.VariantKey = &VariantKey", ""); // @query-part-1
	Else
		Query.SetParameter("VariantKey", VariantKey);
	EndIf;
	
	If User = "" Then
		User = Users.UnspecifiedUserRef();
	EndIf;
	
	If User = Undefined Then
		QueryText = StrReplace(QueryText, "AND Variants.Author = &Author", ""); // @query-part-1
		QueryText = StrReplace(QueryText, "AND Variants.Author.IBUserID = &GUID", ""); // @query-part-1
		
	ElsIf TypeOf(User) = Type("CatalogRef.Users") Then
		Query.SetParameter("Author", User);
		QueryText = StrReplace(QueryText, "AND Variants.Author.IBUserID = &GUID", ""); // @query-part-1
		
	Else
		If TypeOf(User) = Type("UUID") Then
			UserIdentificator = User;
		Else
			If TypeOf(User) = Type("String") Then
				SetPrivilegedMode(True);
				IBUser = InfoBaseUsers.FindByName(User);
				SetPrivilegedMode(False);
				If IBUser = Undefined Then
					Return;
				EndIf;
			ElsIf TypeOf(User) = Type("InfoBaseUser") Then
				IBUser = User;
			Else
				Return;
			EndIf;
			UserIdentificator = IBUser.UUID;
		EndIf;
		Query.SetParameter("GUID", UserIdentificator);
		QueryText = StrReplace(QueryText, "AND Variants.Author = &Author", "");
	EndIf;
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		OptionObject = Selection.Ref.GetObject();
		OptionObject.SetDeletionMark(True);
	EndDo;
	
#EndIf
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Parameters:
//  ReportOptions - See ReportsOptions.SourceTableOfReportVariants
//  FullReportName - String
//  ReportName - String
//
// Returns:
//  Boolean
//
Function AddExternalReportOptions(ReportOptions, FullReportName, ReportName) Export
	Try
		ReportObject = ReportsServer.ReportObject(FullReportName);
	Except
		MessageTemplate = NStr("en = 'Failed to get the list of predefined options of external report %1: %2%3';");
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate, ReportName, Chars.LF, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		ReportsOptions.WriteToLog(EventLogLevel.Error, Message, FullReportName);
		
		Return False;
	EndTry;
	
	If ReportObject.DataCompositionSchema = Undefined Then
		Return False;
	EndIf;
	
	For Each DCSettingsOption In ReportObject.DataCompositionSchema.SettingVariants Do
		Variant = ReportOptions.Add();
		Variant.Custom = False;
		Variant.Description = DCSettingsOption.Presentation;
		Variant.VariantKey = DCSettingsOption.Name;
		Variant.AuthorOnly = False;
		Variant.CurrentUserIsAuthor = False;
		Variant.Order = 1;
		Variant.PictureIndex = 5;
	EndDo;
	
	Return True;
EndFunction

#EndIf

#EndRegion