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

	SetConditionalAppearance();
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If Not Users.IsFullUser(, Not DataSeparationEnabled) Then
		Raise(NStr("en = 'Insufficient rights to access the infobase user list.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	Users.FindAmbiguousIBUsers(Undefined);
	
	UsersTypes.Add(Type("CatalogRef.Users"));
	If GetFunctionalOption("UseExternalUsers") Then
		UsersTypes.Add(Type("CatalogRef.ExternalUsers"));
	EndIf;
	
	ShowOnlyItemsProcessedInDesigner = True;
	
	FillIBUsers();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "IBUserAdded"
	 Or EventName = "IBUserChanged"
	 Or EventName = "IBUserDeleted"
	 Or EventName = "MappingToNonExistingIBUserCleared" Then
		
		FillIBUsers();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowOnlyItemsProcessedInDesignerOnChange(Item)
	
	FillIBUsers();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersIBUsers

&AtClient
Procedure IBUsersOnActivateRow(Item)
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		CanDelete     = False;
		CanMap = False;
		CanGoToUser  = False;
		CanCancelMapping = False;
	Else
		CanDelete     = Not ValueIsFilled(CurrentData.Ref);
		CanMap = Not ValueIsFilled(CurrentData.Ref);
		CanGoToUser  = ValueIsFilled(CurrentData.Ref);
		CanCancelMapping = ValueIsFilled(CurrentData.Ref);
	EndIf;
	
	Items.Delete.Enabled = CanDelete;
	
	Items.GoToUser.Enabled                = CanGoToUser;
	Items.ContextMenuNavigateToUser.Enabled = CanGoToUser;
	
	Items.MapUser.Enabled       = CanMap;
	Items.MapToNewUser.Enabled = CanMap;
	
	Items.CancelMapping.Enabled = CanCancelMapping;
	
EndProcedure

&AtClient
Procedure IBUsersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Not ValueIsFilled(Items.IBUsers.CurrentData.Ref) Then
		DeleteCurrentIBUser(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	FillIBUsers();
	
EndProcedure

&AtClient
Procedure MapUser(Command)
	
	MapIBUser();
	
EndProcedure

&AtClient
Procedure MapToNewUser(Command)
	
	MapIBUser(True);
	
EndProcedure

&AtClient
Procedure GoToUser(Command)
	
	OpenUserByRef();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	If Items.IBUsers.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("CancelMapping", NStr("en = 'Clear mapping';"));
	Buttons.Add("KeepMapping", NStr("en = 'Keep mapping';"));
	
	ShowQueryBox(
		New NotifyDescription("CancelMappingFollowUp", ThisObject),
		NStr("en = 'Do you want to clear the mapping between the infobase user and the application user?
		           |
		           |It is required in rare cases when a mapping is incorrect
		           |(for example, an infobase update might generate an incorrect mapping). It is recommended that you never clear correct mappings.';"),
		Buttons,
		,
		"KeepMapping");
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDConnectAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AccessTokenAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.AddedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDConnectAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AccessTokenAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.ModifiedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDConnectAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AccessTokenAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en = '<No data>';"));
	Item.Appearance.SetParameterValue("Format", NStr("en = 'BF=No; BT=Yes';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.OSUser");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Format", NStr("en = 'BF=; BT=Yes';"));

EndProcedure

&AtServer
Procedure FillIBUsers()
	
	BlankUUID = CommonClientServer.BlankUUID();
	
	If Items.IBUsers.CurrentRow <> Undefined Then
		String = IBUsers.FindByID(Items.IBUsers.CurrentRow);
	Else
		String = Undefined;
	EndIf;
	
	IBUserCurrentID =
		?(String = Undefined, BlankUUID, String.IBUserID);
	
	IBUsers.Clear();
	NonExistingIBUsersIDs.Clear();
	NonExistingIBUsersIDs.Add(BlankUUID);
	
	Query = New Query;
	Query.SetParameter("BlankUUID", BlankUUID);
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS FullName,
	|	Users.IBUserID,
	|	FALSE AS IsExternalUser
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &BlankUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.IBUserID,
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &BlankUUID";
	
	Upload0 = Query.Execute().Unload();
	Upload0.Indexes.Add("IBUserID");
	Upload0.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	RequestForInfoRecords = InformationRegisters.UsersInfo.PropertiesQuery(Undefined);
	InfoRecordsExport = RequestForInfoRecords.Execute().Unload();
	InfoRecordsExport.Indexes.Add("Ref");
	
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For Each IBUser In AllIBUsers Do
		
		ModifiedInDesigner = False;
		String = Upload0.Find(IBUser.UUID, "IBUserID");
		PropertiesIBUser = Users.IBUserProperies(IBUser.UUID);
		If PropertiesIBUser = Undefined Then
			PropertiesIBUser = Users.NewIBUserDetails(False);
		EndIf;
		
		If String <> Undefined Then
			String.Mapped = True;
			If String.FullName <> PropertiesIBUser.FullName Then
				ModifiedInDesigner = True;
			Else
				InformationLine = InfoRecordsExport.Find(String.Ref, "Ref");
				If InformationLine = Undefined Then
					ModifiedInDesigner = True;
				Else
					NewProperties = InformationRegisters.UsersInfo.UserNewProperties(
						InformationLine.Ref, InformationLine,, IBUser);
					If NewProperties <> Undefined Then
						ModifiedInDesigner = True;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		If ShowOnlyItemsProcessedInDesigner
		   And String <> Undefined
		   And Not ModifiedInDesigner Then
			
			Continue;
		EndIf;
		
		IBUser = IBUsers.Add();
		IBUser.FullName                    = PropertiesIBUser.FullName;
		IBUser.Name                          = PropertiesIBUser.Name;
		IBUser.IBUserID  = PropertiesIBUser.UUID;
		IBUser.StandardAuthentication    = PropertiesIBUser.StandardAuthentication;
		IBUser.OpenIDAuthentication         = PropertiesIBUser.OpenIDAuthentication;
		IBUser.OpenIDConnectAuthentication  = PropertiesIBUser.OpenIDConnectAuthentication;
		IBUser.AccessTokenAuthentication = PropertiesIBUser.AccessTokenAuthentication;
		IBUser.OSAuthentication             = PropertiesIBUser.OSAuthentication;
		IBUser.OSUser               = PropertiesIBUser.OSUser;
		
		If String = Undefined Then
			// The infobase user is not in the catalog.
			IBUser.AddedInDesigner = True;
		Else
			IBUser.Ref                           = String.Ref;
			IBUser.MappedToExternalUser = String.IsExternalUser;
			
			IBUser.ModifiedInDesigner = ModifiedInDesigner;
		EndIf;
		
	EndDo;
	
	Filter = New Structure("Mapped", False);
	UsersUnmapped = Upload0.FindRows(Filter);
	For Each TableRow In UsersUnmapped Do
		IBUser = IBUsers.Add();
		IBUser.FullName                        = TableRow.FullName;
		IBUser.Ref                           = TableRow.Ref;
		IBUser.MappedToExternalUser = TableRow.IsExternalUser;
		IBUser.DeletedInDesigner             = True;
		NonExistingIBUsersIDs.Add(TableRow.IBUserID);
	EndDo;
	
	Filter = New Structure("IBUserID", IBUserCurrentID);
	CurrentUser = IBUsers.FindRows(Filter);
	If CurrentUser.Count() > 0 Then
		Items.IBUsers.CurrentRow = CurrentUser[0].GetID();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteIBUser(IBUserID, Cancel)
	
	Try
		Users.DeleteIBUser(IBUserID);
	Except
		Common.MessageToUser(ErrorProcessing.BriefErrorDescription(ErrorInfo()), , , , Cancel);
	EndTry;
	
EndProcedure

&AtClient
Procedure OpenUserByRef()
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.Ref) Then
		OpenForm(
			?(CurrentData.MappedToExternalUser,
				"Catalog.ExternalUsers.ObjectForm",
				"Catalog.Users.ObjectForm"),
			New Structure("Key", CurrentData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUser(DeleteRow = False)
	
	ShowQueryBox(
		New NotifyDescription("DeleteCurrentIBUserCompletion", ThisObject, DeleteRow),
		NStr("en = 'Do you want to delete the infobase user?';"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUserCompletion(Response, DeleteRow) Export
	
	If Response = DialogReturnCode.Yes Then
		Cancel = False;
		DeleteIBUser(
			Items.IBUsers.CurrentData.IBUserID, Cancel);
		
		If Not Cancel And DeleteRow Then
			IBUsers.Delete(Items.IBUsers.CurrentData);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUser(WithNew = False)
	
	If UsersTypes.Count() > 1 Then
		UsersTypes.ShowChooseItem(
			New NotifyDescription("MapIBUserForItemType", ThisObject, WithNew),
			NStr("en = 'Select data type';"),
			UsersTypes[0]);
	Else
		MapIBUserForItemType(UsersTypes[0], WithNew);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserForItemType(ListItem, WithNew) Export
	
	If ListItem = Undefined Then
		Return;
	EndIf;
	
	CatalogName = ?(ListItem.Value = Type("CatalogRef.Users"), "Users", "ExternalUsers");
	
	If Not WithNew Then
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("NonExistingIBUsersIDs", NonExistingIBUsersIDs);
		
		OpenForm("Catalog." + CatalogName + ".ChoiceForm", FormParameters,,,,,
			New NotifyDescription("MapIBUserToItem", ThisObject, CatalogName));
	Else
		MapIBUserToItem("New", CatalogName);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserToItem(Item, CatalogName) Export
	
	If Not ValueIsFilled(Item) And Item <> "New" Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	
	If Item <> "New" Then
		FormParameters.Insert("Key", Item);
	EndIf;
	
	FormParameters.Insert("IBUserID",
		Items.IBUsers.CurrentData.IBUserID);
	
	OpenForm("Catalog." + CatalogName + ".ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CancelMappingFollowUp(Response, Context) Export
	
	If Response = "CancelMapping" Then
		CancelMappingAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer()
	
	CurrentRow = IBUsers.FindByID(Items.IBUsers.CurrentRow);
	If TypeOf(CurrentRow.Ref) = Type("CatalogRef.Users") Then
		TableName = "Catalog.Users";
	Else	
		TableName = "Catalog.ExternalUsers";
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add(TableName);
		LockItem.SetValue("Ref", CurrentRow.Ref);
		Block.Lock();
		
		Object = CurrentRow.Ref.GetObject();
		Object.IBUserID = Undefined;
		InfobaseUpdate.WriteData(Object);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	
	FillIBUsers();
	
EndProcedure

#EndRegion
