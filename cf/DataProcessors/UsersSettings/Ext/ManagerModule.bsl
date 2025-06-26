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

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions related to getting form settings.

// Gets a form settings list for the specified user.
//
// Parameters:
//   UserName - String - name of an infobase user, for whom form
//                              settings are received.
// 
// Returns
//   ValueList - list of forms where the passed user has settings.
//
Function AllFormSettings(UserName)
	
	FormsList = MetadataObjectForms1();
	
	// Adding standard forms to the list.
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventsJournal", 
		PrefixOfStandardForms() + "." + NStr("en = 'Event log';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Event log, Event';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventsJournalFilter", 
		PrefixOfStandardForms() + "." + NStr("en = 'Event log, Event filter settings';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFindByRef.Form.MainForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Find references to objects';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFullTextSearchManagement.Form.MainForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Full-text search management';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardDocumentsPosting.Form.MainForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Post documents';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardDeleteMarkedObjects.Form.Form", 
		PrefixOfStandardForms() + "." + NStr("en = 'Delete marked objects';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardExternalDataSourceManagement.Form.Form", 
		PrefixOfStandardForms() + "." + NStr("en = 'External data source management';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardTotalsManagement.Form.MainForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Totals management';") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardActiveUsers.Form.ActiveUsersListForm", 
		PrefixOfStandardForms() + "." + NStr("en = 'Active users';") , False, PictureLib.Form);
		
	Return FormSettingsList(FormsList, UserName);
	
EndFunction

Function PrefixOfStandardForms()
	
	Return NStr("en = 'Standard';");
	
EndFunction

// Gets the list of configuration forms and populates the following fields:
// Value - form name that serves as a unique ID.
// Presentation - form synonym.
// Picture - a picture that matches the related object.
//
// Parameters:
//   List - ValueList - value list to which form details are to be added.
//
// Returns
//   ValueList - list of all metadata object forms.
//
Function MetadataObjectForms1()
	
	FormsList = New ValueList;
	PictureForm = PictureLib.Form;
	For Each Form In Metadata.CommonForms Do
		FormsList.Add("CommonForm." + Form.Name, Form.Synonym, False, PictureForm);
	EndDo;

	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.FilterCriteria, "FilterCriterion", NStr("en = 'Filter criterion';"),
		StandardFormNames, PictureLib.FilterCriterion, FormsList);
		
	StandardFormNames = New ValueList;
	FillMetadataObjectForms(Metadata.SettingsStorages, "SettingsStorage", NStr("en = 'Settings storage';"),
		StandardFormNames, PictureLib.SettingsStorage, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm", "GroupChoiceForm");
	FillMetadataObjectForms(Metadata.Catalogs, "Catalog", NStr("en = 'Catalog';"),
		StandardFormNames, PictureLib.Catalog, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Documents, "Document", NStr("en = 'Document';"),
		StandardFormNames, PictureLib.Document, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.DocumentJournals, "DocumentJournal", NStr("en = 'Document journal';"),
		StandardFormNames, PictureLib.DocumentJournal, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Enums, "Enum", NStr("en = 'Enumeration';"),
		StandardFormNames, PictureLib.Enum, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	StandardFormNames.Add("SettingsForm");
	StandardFormNames.Add("VariantForm");
	FillMetadataObjectForms(Metadata.Reports, "Report", NStr("en = 'Report';"),
		StandardFormNames, PictureLib.Report, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.DataProcessors, "DataProcessor", NStr("en = 'Data processor';"),
		StandardFormNames, PictureLib.DataProcessor, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm", "GroupChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes", NStr("en = 'Chart of characteristic types';"),
		StandardFormNames, PictureLib.ChartOfCharacteristicTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfAccounts, "ChartOfAccounts", NStr("en = 'Chart of accounts.';"),
		StandardFormNames, PictureLib.ChartOfAccounts, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes", NStr("en = 'Chart of calculation types.';"),
		StandardFormNames, PictureLib.ChartOfCalculationTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.InformationRegisters, "InformationRegister", NStr("en = 'Information register';"),
		StandardFormNames, PictureLib.InformationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.AccumulationRegisters, "AccumulationRegister", NStr("en = 'Accumulation register';"),
		StandardFormNames, PictureLib.AccumulationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.AccountingRegisters, "AccountingRegister", NStr("en = 'Accounting register';"),
		StandardFormNames, PictureLib.AccountingRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.CalculationRegisters, "CalculationRegister", NStr("en = 'Calculation register';"),
		StandardFormNames, PictureLib.CalculationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.BusinessProcesses, "BusinessProcess", NStr("en = 'Business process';"),
		StandardFormNames, PictureLib.BusinessProcess, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm_", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Tasks, "Task", NStr("en = 'Task';"),
		StandardFormNames, PictureLib.Task, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.ExternalDataSources, "ExternalDataSource", NStr("en = 'External data sources';"),
		StandardFormNames, PictureLib.ExternalDataSourceTable, FormsList);

	Return FormsList;
EndFunction

// Returns a settings list for the forms specified in the FormList parameter and for the user specified in the UserName parameter. 
//
Function FormSettingsList(FormsList, UserName)
	
	Result = FormSettingsListPeopertiesPalette();
	
	ResultString1 = Undefined; // ValueTableRow of See FormSettingsListPeopertiesPalette
	FormDetails    = Undefined;
	
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, UserName);
	
	CurrentFormName = "";
	For Each Setting In Settings Do
		ObjectKey  = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		ObjectKeyParts1 = StrSplit(ObjectKey, "/");
		If ObjectKeyParts1.Count() < 2 Then
			Continue;
		EndIf;
		
		NameParts = StrSplit(ObjectKeyParts1[0], ".", False);
		If NameParts.Count() > 4 Then
			FormName = NameParts[0] + "." + NameParts[1] + "." + NameParts[2] + "." + NameParts[3];
		Else
			FormName = ObjectKeyParts1[0];
		EndIf;
		If ValueIsFilled(FormName) And FormName = CurrentFormName Then
			ResultString1.KeysList.Add(ObjectKey, SettingsKey, FormDetails.Check);
			Continue;
		EndIf;
		
		FormDetails = FormsList.FindByValue(FormName);
		If FormDetails = Undefined Then
			Continue;
		EndIf;
		
		ResultString1 = Result.Add();
		ResultString1.Value      = FormDetails.Value;
		ResultString1.Presentation = FormDetails.Presentation;
		ResultString1.Check       = FormDetails.Check;
		ResultString1.Picture      = FormDetails.Picture;
		ResultString1.KeysList.Add(ObjectKey, SettingsKey, FormDetails.Check);
		
		CurrentFormName = FormName;
	EndDo;
	
	Return Result;
	
EndFunction

// The constructor of a form settings collection.
// 
// Returns:
//  ValueTable:
//    * Value - String
//    * Presentation - String
//    * Check - Boolean
//    * Picture - Picture
//    * KeysList - ValueList:
//        ** Value - String
//
Function FormSettingsListPeopertiesPalette()
	
	Result = New ValueTable;
	
	Result.Columns.Add("Value",      New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Check",       New TypeDescription("Boolean"));
	Result.Columns.Add("Picture",      New TypeDescription("Picture"));
	Result.Columns.Add("KeysList",  New TypeDescription("ValueList"));
	
	Return Result
	
EndFunction

Procedure FillMetadataObjectForms(MetadataObjectList, MetadataObjectType,
	MetadataObjectPresentation, StandardFormNames, Picture, FormsList)
	
	For Each Object In MetadataObjectList Do
		
		If MetadataObjectType = "ExternalDataSource" Then
			FillExternalDataSourceForms(Object, MetadataObjectType, MetadataObjectPresentation, Picture, FormsList);
			Continue;
		EndIf;
		
		If Not AccessRight("View", Object) Then
			Continue;
		EndIf;
		
		Prefix_Name = MetadataObjectType + "." + Object.Name;
		PresentationPrefix = Object.Synonym + "~";
		
		For Each Form In Object.Forms Do
			FormPresentationAndMark = FormPresentation(Object, Form, MetadataObjectType);
			FormPresentation = FormPresentationAndMark.FormName;
			Check = FormPresentationAndMark.CanOpenForm;
			FormsList.Add(Prefix_Name + ".Form." + Form.Name, PresentationPrefix + FormPresentation, Check, Picture);
		EndDo;
		
		For Each StandardFormName In StandardFormNames Do
			
			Form = Object[DefaultForm(StandardFormName.Value)];
			If Form = Undefined Then
				FormName = ?(ValueIsFilled(StandardFormName.Presentation), StandardFormName.Presentation, StandardFormName.Value);
				FormPresentationAndMark = AutogeneratedFormPresentation(Object, StandardFormName.Value, MetadataObjectType);
				FormPresentation = FormPresentationAndMark.FormName;
				Check = FormPresentationAndMark.CanOpenForm;
				FormsList.Add(Prefix_Name + "." + FormName, PresentationPrefix + FormPresentation, Check, Picture);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function DefaultForm(Form)
	
	Map = New Map;
	Map.Insert("FolderForm", "DefaultFolderForm");
	Map.Insert("ChoiceForm_", "DefaultChoiceForm");
	Map.Insert("FolderChoiceForm", "DefaultFolderChoiceForm");
	Map.Insert("ObjectForm", "DefaultObjectForm");
	Map.Insert("ListForm", "DefaultListForm");
	Map.Insert("Form", "DefaultForm");
	Map.Insert("SettingsForm", "DefaultSettingsForm");
	Map.Insert("VariantForm", "DefaultVariantForm");
	Map.Insert("RecordForm", "DefaultRecordForm");
	
	Return Map[Form];
	
EndFunction

Procedure FillExternalDataSourceForms(Object, MetadataObjectType, 
	MetadataObjectPresentation, Picture, FormsList)
	
	For Each Table In Object.Tables Do
		
		Prefix_Name = MetadataObjectType + "." + Object.Name + ".Table.";
		PresentationPrefix = Table.Synonym + ".";
		
		For Each Form In Table.Forms Do
			FormPresentation = FormPresentation(Table, Form, MetadataObjectType).FormName;
			FormsList.Add(Prefix_Name + Table.Name + ".Form." + Form.Name, PresentationPrefix + FormPresentation, False, Picture);
		EndDo;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions needed to copy and delete all user settings.

// Deletes user settings from the storage.
//
// Parameters:
//   SettingsToClear - Array - where an array element is a type of settings
//                      to clear. For example, ReportSettings or AppearanceSettings.
//   Sources - Array - where an array element is Catalog.UserRef. An array of users
//             whose settings have to be cleared.
//   UserReportOptionTable - ValueTable
//   ClearAll - Boolean
//
Procedure DeleteUserSettings(SettingsToClear, Sources,
		UserReportOptionTable = Undefined, ClearAll = False) Export
	
	SettingsItemStorageMap = New Map;
	SettingsItemStorageMap.Insert("ReportsSettings", ReportsUserSettingsStorage);
	SettingsItemStorageMap.Insert("InterfaceSettings2", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("FormData", FormDataSettingsStorage);
	SettingsItemStorageMap.Insert("PersonalSettings", CommonSettingsStorage);
	SettingsItemStorageMap.Insert("Favorites", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("PrintSettings", SystemSettingsStorage);
	
	For Each SettingsItemToClear In SettingsToClear Do
		SettingsManager = SettingsItemStorageMap[SettingsItemToClear];
		
		For Each Source In Sources Do
			
			If SettingsItemToClear = "OtherUserSettings" Then
				// Get user settings.
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", Source);
				UserInfo.Insert("InfobaseUserName", IBUserName(Source));
				OtherUserSettings = New Structure;
				UsersInternal.OnGetOtherUserSettings(UserInfo, OtherUserSettings);
				Keys = New ValueList;
				If OtherUserSettings.Count() <> 0 Then
					
					For Each OtherSetting In OtherUserSettings Do
						OtherSettingsStructure = New Structure;
						If OtherSetting.Key = "QuickAccessSetting" Then
							SettingsList = OtherSetting.Value.SettingsList; // ValueTable
							For Each Item In SettingsList Do
								Id = Item.Id; // String
								Keys.Add(Item.Object, Id);
							EndDo;
							OtherSettingsStructure.Insert("SettingID", "QuickAccessSetting");
							OtherSettingsStructure.Insert("SettingValue", Keys);
						Else
							OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
							OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
						EndIf;
						
						UsersInternal.OnDeleteOtherUserSettings(UserInfo, OtherSettingsStructure);
					EndDo;
					
				EndIf;
				
				Continue;
			EndIf;
			
			IBUser = IBUserName(Source);
			
			If SettingsItemToClear = "ReportsSettings" Then
				
				If UserReportOptionTable = Undefined
				 Or Sources.Count() <> 1 Then
					
					UserReportOptionTable = UserReportOptions(IBUser);
				EndIf;
				
				For Each ReportVariant In UserReportOptionTable Do
					
					StandardProcessing = True;
					
					SSLSubsystemsIntegration.OnDeleteUserReportOptions(ReportVariant,
						IBUser, StandardProcessing);
					
					If StandardProcessing Then
						ReportsVariantsStorage.Delete(ReportVariant.ObjectKey, ReportVariant.VariantKey, IBUser);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			// Clearing dynamic list settings.
			If SettingsItemToClear = "InterfaceSettings2" Then
				SettingsFromStorage = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, IBUser);
				DeleteSettings(DynamicListsUserSettingsStorage, SettingsFromStorage, IBUser);
			EndIf;
			
			SettingsFromStorage = SettingsList(IBUser, SettingsManager, SettingsItemToClear);
			DeleteSettings(SettingsManager, SettingsFromStorage, IBUser);
			
			If ClearAll Then
				SystemSettingsStorage.Delete(Undefined, Undefined, IBUser);
			EndIf;
			
			UsersInternal.SetInitialSettings(IBUser, 
				TypeOf(Source) = Type("CatalogRef.ExternalUsers"));
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure DeleteSettings(SettingsManager, SettingsFromStorage, UserName)
	
	For Each Setting In SettingsFromStorage Do
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		SettingsManager.Delete(ObjectKey, SettingsKey, UserName);
	EndDo;
	
EndProcedure

// Deletes user settings from the storage.
//
// Parameters:
//   Sources - Array - where an array element is Catalog.UserRef. An array of users
//             whose settings have to be cleared.
//
Procedure DeleteOutdatedUserSettings(Sources = Undefined) Export
	
	Context = New Structure;
	Context.Insert("ObjectsNames", New Map);
	Context.Insert("NamesOfObjectTypes", NamesOfObjectTypes());
	
	Store = SystemSettingsStorage;
	
	If Sources = Undefined Then
		IBUsers = InfoBaseUsers.GetUsers();
		NamesOfIBUsers = New Map;
		NamesOfIBUsers.Insert("", True);
		For Each IBUser In IBUsers Do
			NamesOfIBUsers.Insert(Upper(IBUser.Name), True);
		EndDo;
		Selection = Store.Select();
		While NextSettingsItem(Selection, "IfAnErrorOccursDelete", Store) Do
			If NamesOfIBUsers.Get(Upper(Selection.User)) = Undefined Then
				Store.Delete(Selection.ObjectKey, Selection.SettingsKey, Selection.User);
				Continue;
			EndIf;
			DeleteAnOutdatedSetting(Selection, Store, Context);
		EndDo;
	Else
		For Each Source In Sources Do
			IBUserName = IBUserName(Source);
			Filter = New Structure("User", IBUserName);
			Selection = Store.Select(Filter);
			While NextSettingsItem(Selection, "IfAnErrorOccursDelete", Store) Do
				DeleteAnOutdatedSetting(Selection, Store, Context);
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

// This method is required for the DeleteObsoleteUserSettings procedure.
Function NamesOfObjectTypes()
	
	TypeNamesRussian = "ПланОбмена,КритерийОтбора,Константа,Справочник,
	|Последовательность,Документ,ЖурналДокументов,Перечисление,ПланВидовХарактеристик,
	|ПланСчетов,ПланВидовРасчета,РегистрСведений,РегистрНакопления,
	|РегистрБухгалтерии,РегистрРасчета,БизнесПроцесс,Задача"; // @Non-NLS
	
	TypeNamesEnglish = "ExchangePlan,FilterCriterion,Constant,Catalog,
	|Sequence,Document,DocumentJournal,Enum,ChartOfCharacteristicTypes,
	|ChartOfAccounts,ChartOfCalculationTypes,InformationRegister,AccumulationRegister,
	|AccountingRegister,CalculationRegister,BusinessProcess,Task";
	
	Names = New Map;
	
	LanguageRussian = Metadata.ScriptVariant
		= Metadata.ObjectProperties.ScriptVariant.Russian;
	
	AddObjectTypeNames(Names, TypeNamesRussian, LanguageRussian);
	AddObjectTypeNames(Names, TypeNamesEnglish, Not LanguageRussian);
	
	Return Names;
	
EndFunction

// This method is required for the ObjectsTypesNames function.
Procedure AddObjectTypeNames(Names, StringOfNames, Value)
	
	NamesFromTheString = StrSplit(StringOfNames, ",", False);
	For Each Name In NamesFromTheString Do
		Names.Insert(Upper(Name), Value);
	EndDo;
	
EndProcedure

// This method is required for the DeleteObsoleteUserSettings procedure.
Procedure DeleteAnOutdatedSetting(Selection, Store, Context)
	
	FullObjectName = StrSplit(Selection.ObjectKey, "/")[0];
	NameParts = StrSplit(FullObjectName, ".", False);
	If NameParts.Count() < 2 Then
		Return;
	EndIf;
	
	TheObjectTypeIsSupported = Context.NamesOfObjectTypes.Get(Upper(NameParts[0]));
	If TheObjectTypeIsSupported = Undefined Then
		Return;
	EndIf;
	
	If NameParts.Count() > 3
	   And (    Upper(NameParts[2]) = Upper("Форма") // @Non-NLS
		  Or Upper(NameParts[2]) = Upper("Form")) Then
		
		FullObjectName = NameParts[0] + "." + NameParts[1]
			+ "." + NameParts[2] + "." + NameParts[3];
		
	ElsIf NameParts.Count() > 2 Then
		FullObjectName = NameParts[0] + "." + NameParts[1];
	EndIf;
	
	If TheObjectTypeIsSupported Then
		TheObjectNameIsCorrect = Context.ObjectsNames.Get(Upper(FullObjectName));
		If TheObjectNameIsCorrect = Undefined Then
			TheObjectNameIsCorrect = Common.MetadataObjectByFullName(FullObjectName) <> Undefined;
			Context.ObjectsNames.Insert(Upper(FullObjectName), TheObjectNameIsCorrect);
		EndIf;
		If TheObjectNameIsCorrect Then
			Return;
		EndIf;
	EndIf;
	
	Store.Delete(Selection.ObjectKey, Selection.SettingsKey, Selection.User);
	
EndProcedure

// Copies user settings and returns the flag of the settings availability.
//
// Parameters:
//  UserSourceRef - CatalogRef.Users
//                             - CatalogRef.ExternalUsers
//  UsersDestination - Array of ValueTable
//  SettingsToCopy - Array of String
//  NotCopiedReportSettings - ValueTable:
//    * User - CatalogRef.Users
//    * ReportsList - ValueList
//
// Returns:
//  Boolean
//
Function CopyUsersSettings(UserSourceRef, UsersDestination, SettingsToCopy,
										NotCopiedReportSettings = Undefined) Export
	
	SettingsItemStorageMap = New Map;
	SettingsItemStorageMap.Insert("ReportsSettings", ReportsUserSettingsStorage);
	SettingsItemStorageMap.Insert("InterfaceSettings2", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("FormData", FormDataSettingsStorage);
	SettingsItemStorageMap.Insert("PersonalSettings", CommonSettingsStorage);
	SettingsItemStorageMap.Insert("Favorites", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("PrintSettings", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("ReportsOptions", ReportsVariantsStorage);
	HasSettings = False;
	ReportOptionTable = Undefined;
	SourceUser = IBUserName(UserSourceRef);
	
	SettingsRecipients = New Array;
	For Each Item In UsersDestination Do
		SettingsRecipients.Add(IBUserName(Item));
	EndDo;
	
	// Get user settings.
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", UserSourceRef);
	UserInfo.Insert("InfobaseUserName", SourceUser);
	OtherUserSettings = New Structure;
	UsersInternal.OnGetOtherUserSettings(UserInfo, OtherUserSettings);
	Keys = New ValueList;
	OtherSettingsArray = New Array;
	If OtherUserSettings.Count() <> 0 Then
		
		For Each OtherSetting In OtherUserSettings Do
			OtherSettingsStructure = New Structure;
			If OtherSetting.Key = "QuickAccessSetting" Then
				SettingsList = OtherSetting.Value.SettingsList; // ValueTable
				For Each Item In SettingsList Do
					Id = Item.Id; // String
					Keys.Add(Item.Object, Id);
				EndDo;
				OtherSettingsStructure.Insert("SettingID", "QuickAccessSetting");
				OtherSettingsStructure.Insert("SettingValue", Keys);
			Else
				OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
				OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
			EndIf;
			OtherSettingsArray.Add(OtherSettingsStructure);
		EndDo;
		
	EndIf;
	
	For Each SettingsItemToCopy In SettingsToCopy Do
		SettingsManager = SettingsItemStorageMap[SettingsItemToCopy];
		
		If SettingsItemToCopy = "OtherUserSettings" Then
			For Each DestinationUser In UsersDestination Do
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", DestinationUser);
				UserInfo.Insert("InfobaseUserName", IBUserName(DestinationUser));
				For Each ArrayElement In OtherSettingsArray Do
					UsersInternal.OnSaveOtherUserSettings(UserInfo, ArrayElement);
				EndDo;
			EndDo;
			Continue;
		EndIf;
		
		If SettingsItemToCopy = "ReportsSettings" Then
			
			If TypeOf(SettingsItemStorageMap["ReportsOptions"]) = Type("StandardSettingsStorageManager") Then
				ReportOptionTable = UserReportOptions(SourceUser);
				ReportOptionKeyAndTypeTable = GetReportOptionKeys(ReportOptionTable);
				SettingsToCopy.Add("ReportsOptions");
			EndIf;
			
		EndIf;
		
		If SettingsItemToCopy = "InterfaceSettings2" Then
			DynamicListsSettings = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, SourceUser);
			CopyDynamicListSettings(SettingsRecipients, SourceUser, DynamicListsSettings);
		EndIf;
		
		SettingsFromStorage = SettingsList(
			SourceUser, SettingsManager, SettingsItemToCopy, ReportOptionKeyAndTypeTable, True);
		
		If SettingsFromStorage.Count() <> 0 Then
			HasSettings = True;
		EndIf;
		
		For Each DestinationUser In UsersDestination Do
			CopySettings(
				SettingsManager, SettingsFromStorage, SourceUser, DestinationUser, NotCopiedReportSettings);
			ReportOptionTable = Undefined;
		EndDo;
		
	EndDo;
	
	Return HasSettings;
	
EndFunction

// Returns the list of user settings.
//
// Parameters:
//  UserName - Undefined
//                  - String
//  SettingsManager - StandardSettingsStorageManager
//                   - SettingsStorageManager.ReportsVariantsStorage
//  SettingsItemToCopy - String
//  ReportOptionKeyAndTypeTable - Undefined
//                                      - ValueTable:
//                                          * VariantKey - String
//                                          * Check - Boolean
//  ForCopying - Boolean
//
// Returns:
//  ValueTable:
//    * ObjectKey - String
//    * SettingsKey - String
//
Function SettingsList(UserName, SettingsManager, 
	SettingsItemToCopy, ReportOptionKeyAndTypeTable = Undefined, ForCopying = False)
	
	GetFavorites = False;
	GetPrintSettings = False;
	If SettingsItemToCopy = "Favorites" Then
		GetFavorites = True;
	EndIf;
	
	If SettingsItemToCopy = "PrintSettings" Then
		GetPrintSettings = True;
	EndIf;
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ObjectKey");
	SettingsTable.Columns.Add("SettingsKey");
	
	Filter = New Structure;
	Filter.Insert("User", UserName);
	
	SettingsSelection = SettingsManager.Select(Filter);
	
	While NextSettingsItem(SettingsSelection) Do
		
		If Not GetFavorites
			And StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") <> 0 Then
			Continue;
		ElsIf GetFavorites Then
			
			If StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") = 0 Then
				Continue;
			ElsIf StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") <> 0 Then
				AddRowToValueTable(SettingsTable, SettingsSelection);
				Continue;
			EndIf;
			
		EndIf;
		
		If Not GetPrintSettings
			And StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
			Continue;
		ElsIf GetPrintSettings Then
			
			If StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") = 0 Then
				Continue;
			ElsIf StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
				AddRowToValueTable(SettingsTable, SettingsSelection);
				Continue;
			EndIf;
			
		EndIf;
		
		If ReportOptionKeyAndTypeTable <> Undefined Then
			
			FoundReportOption = ReportOptionKeyAndTypeTable.Find(SettingsSelection.ObjectKey, "VariantKey");
			If FoundReportOption <> Undefined Then
				
				If Not FoundReportOption.Check Then
					Continue;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If ForCopying And SkipSettingsItem(SettingsSelection.ObjectKey, SettingsSelection.SettingsKey) Then
			Continue;
		EndIf;
		
		AddRowToValueTable(SettingsTable, SettingsSelection);
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function NextSettingsItem(Selection, Var_ErrorProcessing = "IfAnErrorOccursSkip", Store = Undefined)
	
	HasError = False;
	Try
		HasNextObject = Selection.Next();
	Except
		HasError = True;
	EndTry;
	
	If HasError Then
		Return HasNextObject;
	EndIf;
	
	If Not HasNextObject Or Not HasError Then
		Return HasNextObject;
	EndIf;
	
	If Var_ErrorProcessing = "IfAnErrorOccursSkip" Then
		Return NextSettingsItem(Selection, Var_ErrorProcessing, Store);
	ElsIf Var_ErrorProcessing = "IfAnErrorOccursDelete" Then
		Store.Delete(Selection.ObjectKey, Selection.SettingsKey, Selection.User);
		Return NextSettingsItem(Selection, Var_ErrorProcessing, Store);
	EndIf;
	
	Return HasNextObject;
	
EndFunction

// Copies user settings.
//
// Parameters:
//  SettingsManager
//  SettingsTable - ValueTable:
//    * ObjectKey - String
//    * SettingsKey - String
//  SourceUser - Undefined
//                       - String
//  DestinationUser - CatalogRef.Users
//  NotCopiedReportSettings - Undefined
//
Procedure CopySettings(SettingsManager, SettingsTable, SourceUser,
								DestinationUser, NotCopiedReportSettings)
	
	DestinationIBUser = IBUserName(DestinationUser);
	CurrentUser = Undefined;
	
	SettingsQueue = New Map;
	IsSystemSettingsStorage = (SettingsManager = SystemSettingsStorage);
	
	For Each Setting In SettingsTable Do
		
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		
		If IsSystemSettingsStorage Then
			SettingsQueue.Insert(ObjectKey, SettingsKey);
		EndIf;
		
		If SettingsManager = ReportsUserSettingsStorage
			Or SettingsManager = ReportsVariantsStorage Then
			
			AvailableReportArray = ReportsAvailableToUser(DestinationIBUser, DestinationUser);
			ReportKey = StrSplit(ObjectKey, "/", False);
			If AvailableReportArray.Find(ReportKey[0]) = Undefined Then
				
				If SettingsManager = ReportsUserSettingsStorage
					And NotCopiedReportSettings <> Undefined Then
					
					If CurrentUser = Undefined Then
						TableRow = NotCopiedReportSettings.Add();
						TableRow.User = String(DestinationUser.Description);
						CurrentUser = String(DestinationUser.Description);
					EndIf;
					
					If TableRow.ReportsList.FindByValue(ReportKey[0]) = Undefined Then
						TableRow.ReportsList.Add(ReportKey[0]);
					EndIf;
					
				EndIf;
				
				Continue;
			EndIf;
			
		EndIf;
		
		Try
			Value = SettingsManager.Load(ObjectKey, SettingsKey, , SourceUser);
		Except
			Continue;
		EndTry;
		SettingsDescription = SettingsManager.GetDescription(ObjectKey, SettingsKey, SourceUser);
		SettingsManager.Save(ObjectKey, SettingsKey, Value,
			SettingsDescription, DestinationIBUser);
	EndDo;
	
	If Not Common.FileInfobase()
		And SettingsQueue.Count() > 0 Then
		FillSettingsQueue(SettingsQueue, DestinationIBUser);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions needed to copy and delete the selected setting settings.

// Copies user report settings.
// 
// Parameters:
//   SettingsManager - StandardSettingsStorageManager
//                    - SettingsStorageManager.ReportsVariantsStorage
//   SourceUser - String - infobase source user for copying the settings.
//   UsersDestination - Array of CatalogRef.Users - users that need to copy
//                          the selected settings.
//   SettingsToCopyArray - Array of ValueList - a list that contains keys of selected settings.
//   NotCopiedReportSettings - ValueTable:
//     * User - CatalogRef.Users
//     * ReportsList - ValueList
//
Procedure CopyReportAndPersonalSettings(SettingsManager, SourceUser,
		UsersDestination, SettingsToCopyArray, NotCopiedReportSettings = Undefined) Export
	
	For Each DestinationUser In UsersDestination Do
		CurrentUser = Undefined;
		
		For Each Item In SettingsToCopyArray Do
				
			For Each SettingsItem In Item Do
				
				SettingsKey = SettingsItem.Presentation;
				ObjectKey = SettingsItem.Value;
				If SkipSettingsItem(ObjectKey, SettingsKey) Then
					Continue;
				EndIf;
				Setting = SettingsManager.Load(ObjectKey, SettingsKey, , SourceUser);
				SettingDetails = SettingsManager.GetDescription(ObjectKey, SettingsKey, SourceUser);
				
				If Setting <> Undefined Then
					
					DestinationIBUser = IBUserName(DestinationUser);
					
					If SettingsManager = ReportsUserSettingsStorage Then
						AvailableReportArray = ReportsAvailableToUser(DestinationIBUser, DestinationUser);
						ReportKey = StrSplit(ObjectKey, "/", False);
						
						If AvailableReportArray.Find(ReportKey[0]) = Undefined Then
							
							If CurrentUser = Undefined Then
								TableRow = NotCopiedReportSettings.Add();
								TableRow.User = DestinationUser;
								CurrentUser = DestinationUser;
							EndIf;
							
							If TableRow.ReportsList.FindByValue(ReportKey[0]) = Undefined Then
								TableRow.ReportsList.Add(ReportKey[0]);
							EndIf;
								
							Continue;
						EndIf;
						
					EndIf;
					
					SettingsManager.Save(ObjectKey, SettingsKey, Setting, SettingDetails, DestinationIBUser);
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Copies the interface settings.
// 
// Parameters:
//   SourceUser - String - infobase source user for copying the settings.
//   UsersDestination - Array of CatalogRef.Users - an array of UserRef elements - users that need to copy the selected
//                          settings.
//   SettingsToCopyArray - Array of ValueList - keys of selected settings.
//
Procedure CopyInterfaceSettings(SourceUser, UsersDestination, SettingsToCopyArray) Export
	
	SettingsQueue    = New Map;
	SettingsRecipients = New Array;
	ProcessedKeys  = New Map;
	
	For Each Item In UsersDestination Do
		SettingsRecipients.Add(IBUserName(Item));
	EndDo;
	
	DynamicListsSettings = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, SourceUser);
	
	For Each Item In SettingsToCopyArray Do
		
		For Each SettingsItem In Item Do
			SettingsKey = SettingsItem.Presentation;
			ObjectKey  = SettingsItem.Value;
			
			SettingsQueue.Insert(ObjectKey, SettingsKey);
			
			If SettingsKey = "Interface"
				Or SettingsKey = "OtherItems" Then
				CopyDesktopSettings(ObjectKey, SourceUser, SettingsRecipients);
				Continue;
			EndIf;
			
			// Copying dynamic list settings.
			ObjectKeyParts = StrSplit(ObjectKey, "/");
			ObjectName = ObjectKeyParts[0];
			If ProcessedKeys[ObjectName] = Undefined Then
				SearchParameters = New Structure;
				SearchParameters.Insert("ObjectKey", ObjectName);
				SearchResult = DynamicListsSettings.FindRows(SearchParameters);
				CopyDynamicListSettings(SettingsRecipients, SourceUser, SearchResult);
				ProcessedKeys.Insert(ObjectName, True);
			EndIf;
			
			// Copy settings.
			Setting = SystemSettingsStorage.Load(ObjectKey, SettingsKey, , SourceUser);
			If Setting <> Undefined Then
				
				For Each DestinationIBUser In SettingsRecipients Do
					SystemSettingsStorage.Save(ObjectKey, SettingsKey, Setting, , DestinationIBUser);
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not Common.FileInfobase() Then
		For Each SettingsRecipient1 In SettingsRecipients Do
			FillSettingsQueue(SettingsQueue, SettingsRecipient1);
		EndDo;
	EndIf;
	
EndProcedure

Procedure CopyDynamicListSettings(SettingsRecipients, SourceUser, Settings)
	
	For Each Setting In Settings Do
		Value = DynamicListsUserSettingsStorage.Load(
			Setting.ObjectKey,
			Setting.SettingsKey, ,
			SourceUser);
		If Value <> Undefined Then
			For Each DestinationIBUser In SettingsRecipients Do
				SettingsDescription = New SettingsDescription;
				SettingsDescription.Presentation = Setting.Presentation;
				
				DynamicListsUserSettingsStorage.Save(
					Setting.ObjectKey,
					Setting.SettingsKey,
					Value,
					SettingsDescription,
					DestinationIBUser);
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillSettingsQueue(SettingsQueue, SettingsRecipient1)
	
	PreviousSettings1 = CommonSettingsStorage.Load("SettingsQueue", "NotAppliedSettings",, SettingsRecipient1);
	If TypeOf(PreviousSettings1) = Type("ValueStorage") Then
		PreviousSettings1 = PreviousSettings1.Get();
		If TypeOf(PreviousSettings1) = Type("Map") Then
			CommonClientServer.SupplementMap(SettingsQueue, PreviousSettings1, True);
		EndIf;
	EndIf;
	CommonSettingsStorage.Save(
		"SettingsQueue",
		"NotAppliedSettings",
		New ValueStorage(SettingsQueue, New Deflation(9)),
		,
		SettingsRecipient1);
	
EndProcedure

Procedure CopyDesktopSettings(ObjectKey, SourceUser, SettingsRecipients)
	
	Setting = SystemSettingsStorage.Load(ObjectKey, "", , SourceUser);
	If Setting <> Undefined Then
		
		For Each DestinationIBUser In SettingsRecipients Do
			SystemSettingsStorage.Save(ObjectKey, "", Setting, , DestinationIBUser);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DeleteSettingsForSelectedUsers(Users, SettingsForDeletionArray, StorageDescription) Export
	
	For Each User In Users Do
		InfoBaseUser = IBUserName(User);
		
		UserInfo = New Structure;
		UserInfo.Insert("InfobaseUserName", InfoBaseUser);
		UserInfo.Insert("UserRef", User);
		DeleteSelectedSettings(UserInfo, SettingsForDeletionArray, StorageDescription);
	EndDo;
	
EndProcedure

Procedure DeleteSelectedSettings(UserInfo, SettingsForDeletionArray, StorageName) Export
	
	IBUser     = UserInfo.InfobaseUserName;
	UserRef = UserInfo.UserRef;
	
	SettingsManager = SettingsStorageByName(StorageName);
	If StorageName = "ReportsUserSettingsStorage" Or StorageName = "CommonSettingsStorage" Then
		
		For Each Item In SettingsForDeletionArray Do
			
			For Each Setting In Item Do
				SettingsManager.Delete(Setting.Value, Setting.Presentation, IBUser);
			EndDo;
			
		EndDo;
		
	ElsIf StorageName = "SystemSettingsStorage" Then
		
		SetInitialSettings = False;
		ProcessedKeys = New Map;
		
		For Each Item In SettingsForDeletionArray Do
			
			For Each Setting In Item Do
				
				If Setting.Presentation = "Interface" Or Setting.Presentation = "OtherItems" Then
					
					SettingsManager.Delete(Setting.Value, , IBUser);
					
					If Setting.Value = "Common/ClientSettings" 
						Or Setting.Value = "Common/SectionsPanel/CommandInterfaceSettings" 
						Or Setting.Value = "Common/ClientApplicationInterfaceSettings" Then
						
						SetInitialSettings = True;
						
					EndIf;
					
				Else
					// Deleting dynamic list settings.
					ObjectKeyParts = StrSplit(Setting.Value, "/");
					ObjectName = ObjectKeyParts[0];
					If ProcessedKeys[ObjectName] = Undefined Then
						FilterParameters = New Structure;
						FilterParameters.Insert("ObjectKey", ObjectName);
						FilterParameters.Insert("User", IBUser);
						SettingsSelection = DynamicListsUserSettingsStorage.Select(FilterParameters);
						While SettingsSelection.Next() Do
							DynamicListsUserSettingsStorage.Delete(SettingsSelection.ObjectKey, SettingsSelection.SettingsKey, IBUser);
						EndDo;
						ProcessedKeys.Insert(ObjectName, True);
					EndIf;
					
					SettingsManager.Delete(Setting.Value, Setting.Presentation, IBUser);
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		If SetInitialSettings Then
			UsersInternal.SetInitialSettings(IBUser, 
				TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteReportOptions(ReportOptionArray, UserReportOptionTable, InfoBaseUser) Export
	
	For Each Setting In ReportOptionArray Do
		
		ObjectKey = StrSplit(Setting[0].Value, "/", False);
		ReportKey = ObjectKey[0];
		VariantKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", VariantKey);
		FoundReportOption = UserReportOptionTable.FindRows(FilterParameters);
		
		If FoundReportOption.Count() = 0 Then
			Continue;
		EndIf;
		
		StandardProcessing = True;
		
		SSLSubsystemsIntegration.OnDeleteUserReportOptions(FoundReportOption[0],
			InfoBaseUser, StandardProcessing);
		
		If StandardProcessing Then
			ReportsVariantsStorage.Delete(ReportKey, VariantKey, InfoBaseUser);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CopyReportOptions(ReportOptionArray, UserReportOptionTable,
										InfoBaseUser, RecipientUsers) Export
		
		If TypeOf(InfoBaseUser) <> Type("String") Then
			InfoBaseUser = IBUserName(InfoBaseUser);
		EndIf;
		
		For Each Setting In ReportOptionArray Do
		
		ObjectKey = StrSplit(Setting[0].Value, "/", False);
		ReportKey = ObjectKey[0];
		VariantKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", VariantKey);
		FoundReportOption = UserReportOptionTable.FindRows(FilterParameters);
		
		If FoundReportOption[0].StandardProcessing Then
			
			Try
			Value = ReportsVariantsStorage.Load(ReportKey, VariantKey, , InfoBaseUser);
			Except
				Continue;
			EndTry;
			SettingDetails = ReportsVariantsStorage.GetDescription(ReportKey, VariantKey, InfoBaseUser);
			
			For Each SettingsRecipient1 In RecipientUsers Do
				SettingsRecipient1 = IBUserName(SettingsRecipient1);
				ReportsVariantsStorage.Save(ReportKey, VariantKey, Value, SettingDetails, SettingsRecipient1);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for getting a list of users and user groups.

// Gets the list of users from the Users catalog, filtering out inactive users,
// shared users with an enabled separator, and users with blank IDs.
// 
// Parameters:
//   SourceUser - CatalogRef - a user to be removed from the resulting user table.
//   UsersTable - ValueTable - / a table to which filtered users are written.
//   ExternalUser1 - Boolean - If True, users are selected from the ExternalUsers catalog.
//   Clearing - Boolean
//
// Returns:
//  ValueTable
//
Function UsersToCopy(SourceUser, UsersTable, ExternalUser1, Clearing = False) Export
	
	Query = New Query;
	Query.Parameters.Insert("SourceUser", SourceUser);
	Query.Parameters.Insert("UnspecifiedUser", Users.UnspecifiedUserRef());
	Query.Parameters.Insert("BlankUUID",
		CommonClientServer.BlankUUID());
	
	If Clearing Then
		Query.Text = UsersListQueryText(Clearing);
		If ExternalUsers.UseExternalUsers() Then
			Query.Text = Query.Text + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF
				+ ExternalUsersListQueryText(Clearing);
		EndIf;
	Else
		Query.Text = ?(ExternalUser1, ExternalUsersListQueryText(Clearing),
			UsersListQueryText(Clearing))
	EndIf;
	
	SetPrivilegedMode(True);
	UsersList = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	For Each UserRef In UsersList Do
		UserTableRow = UsersTable.Add();
		UserTableRow.User = UserRef.User;
		UserTableRow.Department = UserRef.Department;
		UserTableRow.Individual = UserRef.Individual;
	EndDo;
	UsersTable.Sort("User Asc");
	
	Return UsersTable;
	
EndFunction

Function UsersListQueryText(Clearing)
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.Department AS Department,
	|	Users.Individual AS Individual
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	&ExceptInvalid
	|	AND &ExceptMarkedForDeletion
	|	AND &ExceptInternalUsers
	|	AND Users.Ref <> &SourceUser
	|	AND NOT (Users.IBUserID = &BlankUUID
	|			AND Users.Ref <> &UnspecifiedUser)";
	
	QueryText = StrReplace(QueryText, "&ExceptMarkedForDeletion",
		?(Clearing, "True", "NOT Users.DeletionMark"));
	QueryText = StrReplace(QueryText, "&ExceptInvalid",
		?(Clearing, "True", "NOT Users.Invalid"));
	QueryText = StrReplace(QueryText, "&ExceptInternalUsers",
		?(Clearing And Not Common.DataSeparationEnabled(),
			"True", "NOT Users.IsInternal"));
	Return QueryText;
	
EndFunction

Function ExternalUsersListQueryText(Clearing)
	
	QueryText =
	"SELECT
	|	ExternalUsers.Ref AS User,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Individual
	|FROM
	|	Catalog.Users AS ExternalUsers
	|WHERE
	|	&ExceptInvalid
	|	AND &ExceptMarkedForDeletion
	|	AND ExternalUsers.Ref <> &SourceUser
	|	AND NOT(ExternalUsers.IBUserID = &BlankUUID
	|				AND ExternalUsers.Ref <> &UnspecifiedUser)";
	
	QueryText = StrReplace(QueryText, "&ExceptMarkedForDeletion",
		?(Clearing, "True", "NOT ExternalUsers.DeletionMark"));
	QueryText = StrReplace(QueryText, "&ExceptInvalid",
		?(Clearing, "True", "NOT ExternalUsers.Invalid"));
	Return QueryText;
	
EndFunction


// Generates a user group value tree.
// 
// Parameters:
//   GroupsTree - ValueTree - a tree that is populated with user groups.
//   ExternalUser1 - Boolean - If True, users are selected from the ExternalUsersGroups catalog.
//
Procedure FillGroupTree(GroupsTree, ExternalUser1) Export
	
	GroupsArray = New Array;
	ParentGroupArray = New Array;
	GroupListAndFullComposition = UserGroups(ExternalUser1);
	UserGroupList = GroupListAndFullComposition.UserGroupList;
	GroupsAndCompositionTable = GroupListAndFullComposition.GroupsAndCompositionTable;
	
	If ExternalUser1 Then
		EmptyGroup1 = Catalogs.ExternalUsersGroups.EmptyRef();
	Else
		EmptyGroup1 = Catalogs.UserGroups.EmptyRef();
	EndIf;
	
	GenerateFilter(UserGroupList, EmptyGroup1, GroupsArray);
	
	While GroupsArray.Count() > 0 Do
		ParentGroupArray.Clear();
		
		For Each Group In GroupsArray Do
			
			If Group.Parent = EmptyGroup1 Then
				NewGroupRow = GroupsTree.Rows.Add();
				NewGroupRow.Group = Group.Ref;
				GroupComposition1 = UserGroupComposition(Group.Ref, ExternalUser1);
				FullGroupComposition = UserGroupFullComposition(GroupsAndCompositionTable, Group.Ref);
				NewGroupRow.Content = GroupComposition1;
				NewGroupRow.FullComposition = FullGroupComposition;
				NewGroupRow.Picture = ?(ExternalUser1, 9, 3);
			Else
				ParentGroup1 = GroupsTree.Rows.FindRows(New Structure("Group", Group.Parent), True);
				NewSubordinateGroupRow = ParentGroup1[0].Rows.Add();
				NewSubordinateGroupRow.Group = Group.Ref;
				GroupComposition1 = UserGroupComposition(Group.Ref, ExternalUser1);
				FullGroupComposition = UserGroupFullComposition(GroupsAndCompositionTable, Group.Ref);
				NewSubordinateGroupRow.Content = GroupComposition1;
				NewSubordinateGroupRow.FullComposition = FullGroupComposition;
				NewSubordinateGroupRow.Picture = ?(ExternalUser1, 9, 3);
			EndIf;
			
			ParentGroupArray.Add(Group.Ref);
		EndDo;
		GroupsArray.Clear();
		
		For Each Item In ParentGroupArray Do
			GenerateFilter(UserGroupList, Item, GroupsArray);
		EndDo;
		
	EndDo;
	
EndProcedure

Function UserGroups(ExternalUser1)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CatalogUserGroups.Ref AS Ref,
	|	CatalogUserGroups.Parent AS Parent
	|FROM
	|	Catalog.UserGroups AS CatalogUserGroups";
	If ExternalUser1 Then 
		Query.Text = StrReplace(Query.Text, "Catalog.UserGroups", "Catalog.ExternalUsersGroups");
	EndIf;
	
	UserGroupList = Query.Execute().Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	UserGroupCompositions.User AS User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|
	|ORDER BY
	|	UsersGroup";
	
	UserGroupsComposition = Query.Execute().Unload();
	
	GroupsAndCompositionTable = UserGroupsFullComposition(UserGroupsComposition);
	
	Return New Structure("UserGroupList, GroupsAndCompositionTable",
							UserGroupList, GroupsAndCompositionTable);
EndFunction

Function UserGroupsFullComposition(UserGroupsComposition)
	
	GroupsAndCompositionTable = New ValueTable;
	GroupsAndCompositionTable.Columns.Add("Group");
	GroupsAndCompositionTable.Columns.Add("Content");
	GroupComposition1 = New ValueList;
	CurrentGroup = Undefined;
	
	For Each CompositionRow In UserGroupsComposition Do
		
		If TypeOf(CompositionRow.UsersGroup) = Type("CatalogRef.UserGroups")
			Or TypeOf(CompositionRow.UsersGroup) = Type("CatalogRef.ExternalUsersGroups") Then
			
			If CurrentGroup <> CompositionRow.UsersGroup 
				And Not CurrentGroup = Undefined Then
				GroupsAndCompositionTableRow = GroupsAndCompositionTable.Add();
				GroupsAndCompositionTableRow.Group = CurrentGroup;
				GroupsAndCompositionTableRow.Content = GroupComposition1.Copy();
				GroupComposition1.Clear();
			EndIf;
			GroupComposition1.Add(CompositionRow.User);
			
		CurrentGroup = CompositionRow.UsersGroup;
		EndIf;
		
	EndDo;
	
	GroupsAndCompositionTableRow = GroupsAndCompositionTable.Add();
	GroupsAndCompositionTableRow.Group = CurrentGroup;
	GroupsAndCompositionTableRow.Content = GroupComposition1.Copy();
	
	Return GroupsAndCompositionTable;
EndFunction

Function UserGroupComposition(GroupRef, ExternalUser1)
	
	GroupComposition1 = New ValueList;
	For Each Item In GroupRef.Content Do
		
		If ExternalUser1 Then
			GroupComposition1.Add(Item.ExternalUser);
		Else
			GroupComposition1.Add(Item.User);
		EndIf;
		
	EndDo;
	
	Return GroupComposition1;
EndFunction

Function UserGroupFullComposition(GroupsAndCompositionTable, GroupRef)
	
	FullGroupComposition = GroupsAndCompositionTable.FindRows(New Structure("Group", GroupRef));
	If FullGroupComposition.Count() <> 0 Then
		Return FullGroupComposition[0].Content;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Generates an array of reports that are available to the specified user.
//
// Parameters:
//  InfobaseUser - String - name of the infobase user
//                                   whose report access rights are checked.
//
// Returns:
//   Array - Result - Array - keys of reports available to the passed user.
//
Function ReportsAvailableToUser(IBUserName, UserRef)
	Result = New Array;
	
	SetPrivilegedMode(True);
	IBUser = ?(UserRef = Users.AuthorizedUser(),
		InfoBaseUsers.CurrentUser(),
		InfoBaseUsers.FindByName(IBUserName));
	
	For Each ReportMetadata In Metadata.Reports Do
		If AccessRight("View", ReportMetadata, IBUser) Then
			Result.Add("Report." + ReportMetadata.Name);
		EndIf;
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddAdditionalReportsAvailableToSpecifiedUser(Result,
			IBUser, UserRef);
	EndIf;
	
	Return Result;
	
EndFunction

// Gets the name of an infobase user by a catalog
// reference.
//
// Parameters:
//   UserRef - CatalogRef.Users - user that requires the name
//                        of an infobase user.
//
// Returns:
//   String, Undefined - a name of an infobase user or Undefined
//                          if the Infobase user is not found.
// 
Function IBUserName(UserRef) Export
	
	SetPrivilegedMode(True);
	IBUserID = Common.ObjectAttributeValue(UserRef, "IBUserID");
	IBUser = InfoBaseUsers.FindByUUID(IBUserID);
	
	If IBUser <> Undefined Then
		Return IBUser.Name;
	ElsIf UserRef = Users.UnspecifiedUserRef() Then
		Return "";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function FormPresentation(Object, Form, MetadataObjectType)
	
	CanOpenForm = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		If Form = Object.DefaultForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		If Form = Object.DefaultListForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultListForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Form = Object.DefaultForm Then
			If Not IsBlankString(Object.ExtendedPresentation) Then
				FormName = Object.ExtendedPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			CanOpenForm = True;
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "SettingsStorage" Then
		FormName = Form.Synonym;
	ElsIf MetadataObjectType = "Enum" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm
			Or Form = Object.DefaultFolderForm 
			Or Form = Object.DefaultFolderChoiceForm Then
			
			FormName = Common.ListPresentation(Object);
			AddFormTypeToPresentation(Object, Form, FormName);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
			
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = Common.ObjectPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = Object.DefaultListForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		ElsIf Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultObjectForm Then
			Common.ObjectPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	Else // Getting form presentation for Document, Chart of accounts, Chart of calculation types, Business process, and Task.
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = Common.ObjectPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
		AddFormTypeToPresentation(Object, Form, FormName);
		
	EndIf;
	
	Return New Structure("FormName, CanOpenForm", FormName, CanOpenForm);
	
EndFunction

Function AutogeneratedFormPresentation(Object, Form, MetadataObjectType)
	
	CanOpenForm = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		FormName = Common.ListPresentation(Object);
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		FormName = Common.ListPresentation(Object);
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = "RecordForm" Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = "ListForm" Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Not IsBlankString(Object.ExtendedPresentation) Then
			FormName = Object.ExtendedPresentation;
		Else
			FormName = Object.Presentation();
		EndIf;
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "Enum" Then
		
		FormName = Common.ListPresentation(Object);
		CanOpenForm = ?(Form = "ListForm", True, False);
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = "ListForm"
			Or Form = "ChoiceForm_"
			Or Form = "FolderForm"
			Or Form = "FolderChoiceForm" Then
			FormName = Common.ListPresentation(Object);
			AddFormTypeToAutogeneratedFormPresentation(Object, Form, FormName);
			CanOpenForm = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = Common.ObjectPresentation(Object);
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = "ListForm" Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = True;
		ElsIf Form = "RecordForm" Then
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
		ElsIf Form = "ObjectForm" Then
			Common.ObjectPresentation(Object);
		EndIf;
		
	Else // Getting form presentation for Document, Chart of accounts, Chart of calculation types, Business process, and Task.
		
		If Form = "ListForm"
			Or Form = "ChoiceForm_" Then
			FormName = Common.ListPresentation(Object);
			CanOpenForm = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = Common.ObjectPresentation(Object);
		EndIf;
		
	EndIf;
	
	Return New Structure("FormName, CanOpenForm", FormName, CanOpenForm);
	
EndFunction

Procedure AddFormTypeToPresentation(Object, Form, FormName)
	
	ObjectValues = New Structure;
	ObjectValues.Insert("DefaultListForm");
	ObjectValues.Insert("DefaultChoiceForm");
	ObjectValues.Insert("DefaultFolderForm");
	ObjectValues.Insert("DefaultFolderChoiceForm");
	
	FillPropertyValues(ObjectValues, Object);
	
	If Form = ObjectValues.DefaultListForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (list)';"), FormName);
	ElsIf Form = ObjectValues.DefaultChoiceForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (choice)';"), FormName);
	ElsIf Form = ObjectValues.DefaultFolderForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (group)';"), FormName);
	ElsIf Form = ObjectValues.DefaultFolderChoiceForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (select group)';"), FormName);
	EndIf;
	
EndProcedure

Procedure AddFormTypeToAutogeneratedFormPresentation(Object, Form, FormName)
	
	If Form = "ListForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (list)';"), FormName);
	ElsIf Form = "ChoiceForm_" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (choice)';"), FormName);
	ElsIf Form = "FolderChoiceForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (group)';"), FormName);
	EndIf;
	
EndProcedure

Procedure AddRowToValueTable(SettingsTable, SettingsSelection)
	
	If StrFind(SettingsSelection.ObjectKey, "ExternalReport.") <> 0 Then
		Return;
	EndIf;
	
	NewRow = SettingsTable.Add();
	NewRow.ObjectKey = SettingsSelection.ObjectKey;
	NewRow.SettingsKey = SettingsSelection.SettingsKey;
	
EndProcedure

Function ReportOptionPresentation(SettingsItemKey, ReportOptionName)
	
	ReportName = StrSplit(ReportOptionName[0], ".", False);
	Report = Metadata.Reports.Find(ReportName[1]);
	
	If Report = Undefined Then
		Return Undefined;
	EndIf;
	
	VariantsStorage = Report.VariantsStorage; // MetadataObjectSettingsStorage
	
	If VariantsStorage = Undefined Then
		VariantsStorage = Metadata.ReportsVariantsStorage;
	EndIf;
	
	If VariantsStorage = Undefined Then
		VariantsStorage = ReportsVariantsStorage;
	Else
		VariantsStorage = SettingsStorages[VariantsStorage.Name];
	EndIf;
	
	If ReportOptionName.Count() = 1 Then
		OptionID1 = ReportName[1];
	Else
		OptionID1 = ReportOptionName[1];
	EndIf;
	
	ReportOptionPresentation = VariantsStorage.GetDescription(ReportOptionName[0], OptionID1);
	
	If ReportOptionPresentation <> Undefined Then
		Return ReportOptionPresentation.Presentation;
	Else
		Return ReportName[1];
	EndIf;
	
EndFunction

Function ReadSettingsFromStorage(SettingsManager, User)
	
	Settings = New ValueTable;
	Settings.Columns.Add("ObjectKey");
	Settings.Columns.Add("SettingsKey");
	Settings.Columns.Add("Presentation");
	
	Filter = New Structure;
	Filter.Insert("User", User);
	
	SettingsSelection = SettingsManager.Select(Filter);
	While NextSettingsItem(SettingsSelection) Do
		
		NewRow = Settings.Add();
		NewRow.ObjectKey = SettingsSelection.ObjectKey;
		NewRow.SettingsKey = SettingsSelection.SettingsKey;
		NewRow.Presentation = SettingsSelection.Presentation;
		
	EndDo;
	
	Return Settings;
	
EndFunction

Function UserReportOptions(InfoBaseUser)
	
	CurrentUser = Users.CurrentUser();
	CurrentIBUser = IBUserName(CurrentUser);
	
	ReportOptionTable = New ValueTable;
	ReportOptionTable.Columns.Add("ObjectKey");
	ReportOptionTable.Columns.Add("VariantKey");
	ReportOptionTable.Columns.Add("Presentation");
	ReportOptionTable.Columns.Add("StandardProcessing");
	
	AvailableReports = ReportsAvailableToUser(CurrentIBUser, CurrentUser);
	
	For Each FullReportName In AvailableReports Do
		
		StandardProcessing = True;
		
		SSLSubsystemsIntegration.OnReceiveUserReportsOptions(FullReportName,
			InfoBaseUser, ReportOptionTable, StandardProcessing);
		
		If Not StandardProcessing Then 
			Continue;
		EndIf;
		
		ReportOptions = ReportsVariantsStorage.GetList(FullReportName, InfoBaseUser);
		For Each ReportVariant In ReportOptions Do
			ReportOptionRow = ReportOptionTable.Add();
			ReportOptionRow.ObjectKey = FullReportName;
			ReportOptionRow.VariantKey = ReportVariant.Value;
			ReportOptionRow.Presentation = ReportVariant.Presentation;
			ReportOptionRow.StandardProcessing = True;
		EndDo;
		
	EndDo;
	
	Return ReportOptionTable;
	
EndFunction

Function UserSettingsKeys()
	
	KeysArray = New Array;
	KeysArray.Add("CurrentVariantKey");
	KeysArray.Add("CurrentUserSettingsKey");
	KeysArray.Add("CurrentUserSettings");
	KeysArray.Add("CurrentDataSettingsKey");
	KeysArray.Add("ClientSettings");
	KeysArray.Add("AddInSettings");
	KeysArray.Add("HelpSettings");
	KeysArray.Add("ComparisonSettings");
	KeysArray.Add("TableSearchParameters");
	
	Return KeysArray;
EndFunction

Function SettingsStorageByName(StorageDescription)
	
	If StorageDescription = "ReportsUserSettingsStorage" Then
		Return ReportsUserSettingsStorage;
	ElsIf StorageDescription = "CommonSettingsStorage" Then
		Return CommonSettingsStorage;
	Else
		Return SystemSettingsStorage;
	EndIf;
	
EndFunction

Procedure GenerateFilter(UserGroupList, GroupRef, GroupsArray)
	
	FilterParameters = New Structure("Parent", GroupRef);
	PickedRows = UserGroupList.FindRows(FilterParameters);
	
	For Each Item In PickedRows Do 
		GroupsArray.Add(Item);
	EndDo;
	
EndProcedure

Function GetReportOptionKeys(ReportOptionTable)
	
	ReportOptionKeyAndTypeTable = New ValueTable;
	ReportOptionKeyAndTypeTable.Columns.Add("VariantKey");
	ReportOptionKeyAndTypeTable.Columns.Add("Check");
	For Each TableRow In ReportOptionTable Do
		ValueTableRow = ReportOptionKeyAndTypeTable.Add();
		ValueTableRow.VariantKey = TableRow.ObjectKey + "/" + TableRow.VariantKey;
		ValueTableRow.Check = TableRow.StandardProcessing;
	EndDo;
	
	Return ReportOptionKeyAndTypeTable;
EndFunction

Function CreateReportOnCopyingSettings(NotCopiedReportSettings,
										UserReportOptionTable = Undefined) Export
	
	TabDoc = New SpreadsheetDocument;
	TabTemplate = GetTemplate("ReportTemplate"); // SpreadsheetDocument
	
	ReportIsNotEmpty = False;
	If UserReportOptionTable <> Undefined
		And UserReportOptionTable.Count() <> 0 Then
		HeaderArea_ = TabTemplate.GetArea("Title");
		HeaderArea_.Parameters.LongDesc = 
			NStr("en = 'Cannot copy personal report options.
			|To make a personal report option available to other users,
			|save it with the ""Available to author only"" check box cleared.
			|List of skipped report options:';");
		TabDoc.Put(HeaderArea_);
		
		TabDoc.Put(TabTemplate.GetArea("IsBlankString"));
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow In UserReportOptionTable Do
			
			If Not TableRow.StandardProcessing Then
				AreaContent.Parameters.Name1 = TableRow.Presentation;
				TabDoc.Put(AreaContent);
			EndIf;
			
		EndDo;
		
		ReportIsNotEmpty = True;
	EndIf;
	
	If NotCopiedReportSettings.Count() <> 0 Then
		HeaderArea_ = TabTemplate.GetArea("Title");
		HeaderArea_.Parameters.LongDesc = 
			NStr("en = 'The following users have insufficient access rights for reports:';");
		TabDoc.Put(HeaderArea_);
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow In NotCopiedReportSettings Do
			TabDoc.Put(TabTemplate.GetArea("IsBlankString"));
			AreaContent.Parameters.Name1 = String(TableRow.User) + ":";
			TabDoc.Put(AreaContent);
			For Each ReportTitle In TableRow.ReportsList Do
				AreaContent.Parameters.Name1 = ReportTitle.Value;
				TabDoc.Put(AreaContent);
			EndDo;
			
		EndDo;
		
	ReportIsNotEmpty = True;
	EndIf;
	
	If ReportIsNotEmpty Then
		Report = New SpreadsheetDocument;
		Report.Put(TabDoc);
		
		Return Report;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function SkipSettingsItem(ObjectKey, SettingsKey)
	
	ExceptionsByObjectKey = New Array;
	ExceptionsBySettingsKey = New Array;
	
	// Exceptions. Non-copyable settings.
	ExceptionsByObjectKey.Add("LocalFileCache");
	ExceptionsBySettingsKey.Add("PathToLocalFileCache");
	
	If ExceptionsByObjectKey.Find(ObjectKey) <> Undefined
		And ExceptionsBySettingsKey.Find(SettingsKey) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for UsersSettings and SelectSettings forms.

Procedure FillSettingsLists(Parameters) Export
	FillReportSettingsList(Parameters);
	FillInterfaceSettingsList(Parameters);
	FillOtherSettingsList(Parameters);
EndProcedure

// Fills in a collection of report settings.
// 
// Parameters:
//  Parameters - Structure:
//    * ReportSettingsTree - ValueTree:
//        ** Keys - ValueList
//
Procedure FillReportSettingsList(Parameters)
	
	FormName = StrSplit(Parameters.FormName, ".", False);
	Parameters.ReportSettingsTree.Rows.Clear();
	ReportOptionTable = UserReportOptions(Parameters.InfoBaseUser);
	Parameters.UserReportOptions.Clear();
	Parameters.UserReportOptions = ReportOptionTable.Copy();
	
	Settings = ReadSettingsFromStorage(
		ReportsUserSettingsStorage, Parameters.InfoBaseUser);
	
	CurrentObject = Undefined;
	PictureReport = PictureLib.Report;
	PictureForm = PictureLib.Form;
	
	For Each Setting In Settings Do
		SettingObject = Setting.ObjectKey;
		SettingsItemKey = Setting.SettingsKey;
		SettingName1 = Setting.Presentation;
		
		ReportOptionName = StrSplit(SettingObject, "/", False);
		If ReportOptionName.Count() < 2 Then
			Continue; // Invalid setting.
		EndIf;
		
		ReportOptionPresentation = ReportOptionPresentation(SettingsItemKey, ReportOptionName);
		
		// If a report option (report) has been deleted, but the setting remains, it is not displayed to the user.
		If ReportOptionPresentation = ""
			Or ReportOptionPresentation = Undefined Then
			Continue;
		EndIf;
		
		// Checking whether the report option is a user-defined one.
		FoundReportOption = ReportOptionTable.Find(ReportOptionName[1], "VariantKey");
		// If the settings selection form is opened, hide the settings that cannot be copied
		If FormName[3] = "SettingsChoice"
			And FoundReportOption <> Undefined
			And Not FoundReportOption.StandardProcessing Then
			Continue;
		EndIf;
		
		// Filling a report option row.
		If CurrentObject <> ReportOptionPresentation Then
			NewRowReportOption = Parameters.ReportSettingsTree.Rows.Add();
			NewRowReportOption.Setting = ReportOptionPresentation;
			NewRowReportOption.Picture = PictureReport;
			NewRowReportOption.Type =
				?(FoundReportOption <> Undefined, 
					?(Not FoundReportOption.StandardProcessing, "PersonalOption", "StandardOptionPersonal"), "StandardReportOption");
			NewRowReportOption.RowType = "Report" + ReportOptionPresentation;
		EndIf;
		// Populate setting string.
		NewRowSettingsItem = NewRowReportOption.Rows.Add();
		NewRowSettingsItem.Setting = ?(Not IsBlankString(SettingName1), SettingName1, ReportOptionPresentation);
		NewRowSettingsItem.Picture = PictureForm;
		NewRowSettingsItem.Type = 
			?(FoundReportOption <> Undefined,
				?(Not FoundReportOption.StandardProcessing, "SettingsItemPersonal", "StandardSettingsItemPersonal"), "StandardReportSettings");
		NewRowSettingsItem.RowType = ReportOptionPresentation + SettingName1;
		NewRowSettingsItem.Keys.Add(SettingObject, SettingsItemKey);
		// Filling object key and settings item key for a report option.
		NewRowReportOption.Keys.Add(SettingObject, SettingsItemKey);
		
		CurrentObject = ReportOptionPresentation;
		
		// Deleting reports that have settings from the list of user-defined report options.
		If FoundReportOption <> Undefined Then
			ReportOptionTable.Delete(FoundReportOption);
		EndIf;
		
	EndDo;
	
	For Each ReportVariant In ReportOptionTable Do
		
		If FormName[3] = "SettingsChoice"
			And Parameters.SettingsOperation = "Copy"
			And Not ReportVariant.StandardProcessing Then
			Continue;
		EndIf;
		
		NewRowReportOption = Parameters.ReportSettingsTree.Rows.Add(); // ValueTreeRow
		NewRowReportOption.Setting = ReportVariant.Presentation;
		NewRowReportOption.Picture = PictureReport;
		NewRowReportOption.Keys.Add(ReportVariant.ObjectKey + "/" + ReportVariant.VariantKey);
		NewRowReportOption.Type = ?(Not ReportVariant.StandardProcessing, "PersonalOption", "StandardOptionPersonal");
		NewRowReportOption.RowType = "Report" + ReportVariant.Presentation;
		
	EndDo;
	
	Parameters.ReportSettingsTree.Rows.Sort("Setting Asc", True);
	
EndProcedure

// Parameters:
//  Parameters - Structure:
//     * InterfaceSettings2 - ValueTree
//
Procedure FillInterfaceSettingsList(Parameters)
	
	Parameters.InterfaceSettings2.Rows.Clear();
	
	CurrentObject = Undefined;
	FormSettings = AllFormSettings(Parameters.InfoBaseUser);
	PictureForm = PictureLib.Form;
	
	For Each FormSettingsItem In FormSettings Do
		MetadataObjectName = StrSplit(FormSettingsItem.Value, ".", False);
		MetadataObjectPresentation = StrSplit(FormSettingsItem.Presentation, "~", False);
		
		If MetadataObjectName[0] = "CommonForm" Then
			NewRowCommonForm = Parameters.InterfaceSettings2.Rows.Add();
			NewRowCommonForm.Setting = FormSettingsItem.Presentation;
			NewRowCommonForm.Picture = PictureForm;
			MergeValueLists(NewRowCommonForm.Keys, FormSettingsItem.KeysList);
			NewRowCommonForm.Type = "InterfaceSettings1";
			NewRowCommonForm.RowType = "CommonForm" + MetadataObjectName[1];
		ElsIf MetadataObjectName[0] = "SettingsStorage" Then
			NewRowSettingsStorage = Parameters.InterfaceSettings2.Rows.Add();
			NewRowSettingsStorage.Setting = FormSettingsItem.Presentation;
			NewRowSettingsStorage.Picture = PictureForm;
			MergeValueLists(NewRowSettingsStorage.Keys, FormSettingsItem.KeysList);
			NewRowSettingsStorage.RowType = "SettingsStorage" + MetadataObjectName[2];
			NewRowSettingsStorage.Type = "InterfaceSettings1";
		ElsIf StrStartsWith(FormSettingsItem.Value, "ExternalDataProcessor.Standard") Then
			
			If MetadataObjectPresentation.Count() = 1 Then
				MetadataObjectPresentation = StrSplit(FormSettingsItem.Presentation, ".", False);
			EndIf;
			
			// Settings tree group.
			If CurrentObject <> MetadataObjectPresentation[0] Then
				NewRowMetadataObject = Parameters.InterfaceSettings2.Rows.Add(); // ValueTreeRow
				NewRowMetadataObject.Setting = MetadataObjectPresentation[0];
				NewRowMetadataObject.Picture = FormSettingsItem.Picture;
				NewRowMetadataObject.RowType = "Object" + MetadataObjectName[1];
				NewRowMetadataObject.Type = "InterfaceSettings1";
			EndIf;
			
			// Settings tree item.
			NewFormInterfaceRow = NewRowMetadataObject.Rows.Add();
			NewFormInterfaceRow.Setting = MetadataObjectPresentation[1];
			NewFormInterfaceRow.Picture = PictureForm;
			NewFormInterfaceRow.RowType = MetadataObjectName[1] + MetadataObjectName[2];
			NewFormInterfaceRow.Type = "InterfaceSettings1";
			MergeValueLists(NewFormInterfaceRow.Keys, FormSettingsItem.KeysList);
			MergeValueLists(NewRowMetadataObject.Keys, FormSettingsItem.KeysList);
			
			CurrentObject = MetadataObjectPresentation[0];
			
		Else
			
			// Settings tree group.
			If CurrentObject <> MetadataObjectName[1] Then
				NewRowMetadataObject = Parameters.InterfaceSettings2.Rows.Add();
				NewRowMetadataObject.Setting = MetadataObjectPresentation[0];
				NewRowMetadataObject.Picture = FormSettingsItem.Picture;
				NewRowMetadataObject.RowType = "Object" + MetadataObjectName[1];
				NewRowMetadataObject.Type = "InterfaceSettings1";
			EndIf;
			
			// Settings tree item.
			If MetadataObjectName.Count() = 3 Then
				FormName = MetadataObjectName[2];
			Else
				FormName = MetadataObjectName[3];
			EndIf;
			
			NewFormInterfaceRow = NewRowMetadataObject.Rows.Add();
			If MetadataObjectPresentation.Count() = 1 Then
				NewFormInterfaceRow.Setting = MetadataObjectPresentation[0];
			Else
				NewFormInterfaceRow.Setting = MetadataObjectPresentation[1];
			EndIf;
			NewFormInterfaceRow.Picture = PictureForm;
			NewFormInterfaceRow.RowType = MetadataObjectName[1] + FormName;
			NewFormInterfaceRow.Type = "InterfaceSettings1";
			MergeValueLists(NewFormInterfaceRow.Keys, FormSettingsItem.KeysList);
			MergeValueLists(NewRowMetadataObject.Keys, FormSettingsItem.KeysList);
			
			CurrentObject = MetadataObjectName[1];
		EndIf;
		
	EndDo;
	
	AddDesktopAndCommandInterfaceSettings(Parameters, Parameters.InterfaceSettings2);
	
	Parameters.InterfaceSettings2.Rows.Sort("Setting Asc", True);
	
	Setting = NStr("en = 'Command interface and home page';");
	DesktopAndCommandInterface = Parameters.InterfaceSettings2.Rows.Find(Setting, "Setting");
	
	If DesktopAndCommandInterface <> Undefined Then
		RowIndex = Parameters.InterfaceSettings2.Rows.IndexOf(DesktopAndCommandInterface);
		Parameters.InterfaceSettings2.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	
	
EndProcedure

Procedure FillOtherSettingsList(Parameters)
	
	// ACC:1391-off Search by setting presentation described in the code.
	
	Parameters.OtherSettingsTree.Rows.Clear();
	Settings = ReadSettingsFromStorage(CommonSettingsStorage, Parameters.InfoBaseUser);
	Keys = New ValueList;
	OtherKeys = New ValueList;
	
	// Populate personal settings.
	For Each Setting In Settings Do
		Keys.Add(Setting.ObjectKey, Setting.SettingsKey);
	EndDo;
	
	If Keys.Count() > 0 Then
		Setting = NStr("en = 'Personal settings';");
		SettingType = "PersonalSettings";
		If TypeOf(Parameters.UserRef) = Type("CatalogRef.ExternalUsers") Then
			Picture = PictureLib.UserState08;
		Else
			Picture = PictureLib.UserState02;
		EndIf;
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
	EndIf;
	
	// Filling print settings and favorites settings.
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, Parameters.InfoBaseUser);
	
	Keys.Clear();
	HasFavorites = False;
	HasPrintSettings = False;
	KeyEnds = UserSettingsKeys();
	For Each Setting In Settings Do
		
		SettingName = StrSplit(Setting.ObjectKey, "/", False);
		If SettingName.Count() = 1 Then
			Continue;
		EndIf;
		
		If KeyEnds.Find(SettingName[1]) <> Undefined Then
			OtherKeys.Add(Setting.ObjectKey, "OtherItems");
		EndIf;
		
		If SettingName[1] = "UserWorkFavorites" Then
			HasFavorites = True;
		ElsIf SettingName[1] = "SpreadsheetDocumentPrintSettings" Then
			Keys.Add(Setting.ObjectKey, "OtherItems");
			HasPrintSettings = True;
		EndIf;
		
	EndDo;
	
	// Adding print settings tree row.
	If HasPrintSettings Then
		Setting = NStr("en = 'Spreadsheet document print settings';");
		Picture = PictureLib.Print;
		SettingType = "PrintSettings";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
	EndIf;
	
	// Adding "Favorites" tree row.
	If HasFavorites Then
		
		Setting = NStr("en = 'Favorites';");
		Picture = PictureLib.AddToFavorites;
		Keys.Clear();
		Keys.Add("Common/UserWorkFavorites", "OtherItems");
		SettingType = "FavoritesSettings";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
		
	EndIf;
	
	// Adding other settings supported by the configuration.
	OtherSettings = New Structure;
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", Parameters.UserRef);
	UserInfo.Insert("InfobaseUserName", Parameters.InfoBaseUser);
	
	UsersInternal.OnGetOtherUserSettings(UserInfo, OtherSettings);
	Keys = New ValueList;
	
	If OtherSettings <> Undefined Then
		PictureOtherUserSettings = PictureLib.OtherUserSettings;
		For Each OtherSetting In OtherSettings Do
			
			Result = OtherSetting.Value;
			If Result.SettingsList.Count() <> 0 Then
				
				If OtherSetting.Key = "QuickAccessSetting" Then
					For Each Item In Result.SettingsList Do
						SettingValue = Item[0];
						SettingID = Item[1];
						Keys.Add(SettingValue, SettingID);
					EndDo;
				Else
					Keys = Result.SettingsList.Copy();
				EndIf;
				
				Setting = Result.SettingName1;
				If Result.PictureSettings = "" Then
					Picture = PictureOtherUserSettings;
				Else
					Picture = Result.PictureSettings;
				EndIf;
				Type = "OtherUserSettingsItem1";
				SettingType = OtherSetting.Key;
				AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, Type, SettingType);
				Keys.Clear();
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Other settings that are not included in other sections.
	If OtherKeys.Count() <> 0 Then
		Setting = NStr("en = 'Other settings';");
		Picture = PictureLib.OtherUserSettings;
		SettingType = "OtherSetting";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, OtherKeys, SettingType);
	EndIf;
	
	// ACC:1391-on
		
EndProcedure

// Adds the settings.
//
// Parameters:
//  Parameters - Structure
//  SettingsTree - ValueTree
//
Procedure AddDesktopAndCommandInterfaceSettings(Parameters, SettingsTree)
	
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, Parameters.InfoBaseUser);
	DesktopSettingsKeys = New ValueList;
	InterfaceSettingsKeys = New ValueList;
	AllSettingsKeys = New ValueList; 
	
	SuffixKeySettings = "ThinClientWindowSettings";
	
	For Each Setting In Settings Do
		SettingName = StrSplit(Setting.ObjectKey, "/", False);
		SettingsItemNamePart = StrSplit(SettingName[0], ".", False);
		If SettingsItemNamePart[0] = "Subsystem" Then
			
			InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		ElsIf SettingName[0] = "Common" Then
			
			If SettingName[1] = "SectionsPanel"
			 Or SettingName[1] = "ActionsPanel" 
			 Or SettingName[1] = "ClientSettings" 
			 Or SettingName[1] = "ClientApplicationInterfaceSettings" Then
				
				InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
				
			ElsIf SettingName[1] = "DesktopSettings"
			      Or SettingName[1] = "HomePageSettings" Then
				
				DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		ElsIf SettingName[0] = "Desktop" Then
			
			If SettingName[1] = SuffixKeySettings Then
				DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			Else
				InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		ElsIf SettingName[0] = "HomePage" Then
			
			// Dialog settings.
			DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		ElsIf SettingName[0] = "MainSection" Then
			
			InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		EndIf;
		
	EndDo;
	
	If AllSettingsKeys.Count() > 0 Then
		// Adding top-level groups for desktop settings and command-interface settings.
		NewInterfaceRow = SettingsTree.Rows.Add();
		NewInterfaceRow.Setting = NStr("en = 'Command interface and home page';");
		NewInterfaceRow.Picture = PictureLib.Picture;
		NewInterfaceRow.RowType = NStr("en = 'Command interface and home page';");
		NewInterfaceRow.Type = "InterfaceSettings1";
		NewInterfaceRow.Keys = AllSettingsKeys.Copy();
	EndIf;
	
	If DesktopSettingsKeys.Count() > 0 Then
		// Creating a desktop settings row.
		NewSubordinateInterfaceRow = NewInterfaceRow.Rows.Add();
		NewSubordinateInterfaceRow.Setting = StandardSubsystemsServer.HomePagePresentation();
		NewSubordinateInterfaceRow.Picture = PictureLib.Picture;
		NewSubordinateInterfaceRow.RowType = "DesktopSettings";
		NewSubordinateInterfaceRow.Type = "InterfaceSettings1";
		NewSubordinateInterfaceRow.Keys = DesktopSettingsKeys.Copy();
	EndIf;
	
	If InterfaceSettingsKeys.Count() > 0 Then
		// Creating a command interface settings row.
		NewSubordinateInterfaceRow = NewInterfaceRow.Rows.Add();
		NewSubordinateInterfaceRow.Setting = NStr("en = 'Command interface';");
		NewSubordinateInterfaceRow.Picture = PictureLib.Picture;
		NewSubordinateInterfaceRow.RowType = "CommandInterfaceSettings";
		NewSubordinateInterfaceRow.Type = "InterfaceSettings1";
		NewSubordinateInterfaceRow.Keys = InterfaceSettingsKeys.Copy();
	EndIf;
	
EndProcedure

// Merges value lists.
// 
// Parameters:
//  DestinationList - ValueList
//  SourceList - ValueList
//
Procedure MergeValueLists(DestinationList, SourceList)
	For Each Item In SourceList Do
		FillPropertyValues(DestinationList.Add(), Item);
	EndDo;
EndProcedure

// Adds a tree row.
// 
// Parameters:
//  ValueTree - ValueTree
//  Setting - String
//  Picture - Picture
//  Keys - ValueList
//  Type - String
//  RowType - Arbitrary
//            - String
//
Procedure AddTreeRow(ValueTree, Setting, Picture, Keys, Type = "", RowType = "")
	
	NewRow = ValueTree.Rows.Add();
	NewRow.Setting = Setting;
	NewRow.Picture = Picture;
	NewRow.Type = Type;
	NewRow.RowType = ?(RowType <> "", RowType, Type);
	NewRow.Keys = Keys.Copy();
	
EndProcedure

#EndRegion

#EndIf