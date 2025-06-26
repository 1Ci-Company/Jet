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
	
	Date                        = Parameters.Date;
	UserName             = Parameters.UserName;
	ApplicationPresentation     = Parameters.ApplicationPresentation;
	Computer                   = Parameters.Computer;
	Event                     = Parameters.Event;
	EventPresentation        = Parameters.EventPresentation;
	Comment                 = Parameters.Comment;
	MetadataPresentation     = Parameters.MetadataPresentation;
	Data                      = Parameters.Data;
	DataPresentation         = Parameters.DataPresentation;
	Transaction                  = Parameters.Transaction;
	TransactionStatus            = Parameters.TransactionStatus;
	Session                       = Parameters.Session;
	ServerName               = Parameters.ServerName;
	PrimaryIPPort              = Parameters.PrimaryIPPort;
	SyncPort       = Parameters.SyncPort;
	
	If ValueIsFilled(Parameters.User)
	   And StringFunctionsClientServer.IsUUID(Parameters.User)
	   And Common.SeparatedDataUsageAvailable() Then
		
		SetPrivilegedMode(True);
		IBUserID = New UUID(Parameters.User);
		If ValueIsFilled(IBUserID) Then
			User = Users.FindByID(IBUserID);
			If Not ValueIsFilled(User) Then
				IBUser = InfoBaseUsers.FindByUUID(
					IBUserID);
				If IBUser <> Undefined And IBUser.Name = "" Then
					IBUserID = CommonClientServer.BlankUUID();
					User = Users.FindByID(IBUserID);
				EndIf;
			EndIf;
			If ValueIsFilled(User) Then
				Items.UserName.OpenButton = True;
			EndIf;
		EndIf;
		SetPrivilegedMode(False);
	EndIf;
	
	SeparationVisibility = Not Common.SeparatedDataUsageAvailable();
	SessionDataSeparation = Parameters.SessionDataSeparation;
	
	If EventLog.StandardSeparatorsOnly() Then
		DataArea = Parameters.DataArea;
		Items.DataArea.Visible = SeparationVisibility;
		Items.SessionDataSeparation.Visible = False;
	Else
		Items.DataArea.Visible = False;
		Items.SessionDataSeparation.Visible = SeparationVisibility;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, %2';"), 
		Parameters.Level, Date);
	
	// Enabling the open button for the metadata list.
	If TypeOf(MetadataPresentation) = Type("ValueList") Then
		Items.MetadataPresentation.OpenButton = True;
	EndIf;
	
	// Processing special event data.
	Items.TableHeading.Visible = False;
	Items.DataTree.Visible = False;
	Items.IBUserData.Visible = False;
	Items.DataPresentations.PagesRepresentation = FormPagesRepresentation.None;
	
	EventData = EventLog.EventData(Parameters.DataAsStr); // Structure
	
	If TypeOf(EventData) = Type("String") Then
		EventData = EventLog.DataFromXMLString(EventData);
	EndIf;
	
	If Event = "_$Access$_.Access" Then
		Items.Data.Visible = False;
		Items.DataPresentation.Visible = False;
		If EventData <> Undefined And EventData.Property("Data") And EventData.Data <> Undefined Then
			CreateFormTable("DataTable", "DataTable", EventData.Data);
		ElsIf EventData <> Undefined Then
			CreateFormTable("DataTable", "DataTable", EventData);
		EndIf;
		
	ElsIf Event = "_$Access$_.AccessDenied" Then
		Items.Data.Visible = False;
		
		If EventData <> Undefined Then
			If EventData.Property("Right") Then
				Items.DataPresentation.Title = NStr("en = 'Access denied';");
				DataPresentation = EventData.Right;
			Else
				Items.DataPresentation.Title = NStr("en = 'Action denied';");
				DataPresentation = EventData.Action;
				If EventData.Property("Data") And EventData.Data <> Undefined Then
					CreateFormTable("DataTable", "DataTable", EventData.Data);
				EndIf;
			EndIf;
		EndIf;
		
	ElsIf Event = "_$User$_.Delete"
		  Or Event = "_$User$_.New"
		  Or Event = "_$User$_.Update" Then
		
		Items.StandardData.Visible = False;
		Items.IBUserData.Visible = True;
		Items.DataPresentations.CurrentPage = Items.IBUserData;
		
		If EventData <> Undefined Then
			If EventData.Property("Roles") Then
				If TypeOf(EventData.Roles) = Type("Array") Then
					IBUserRoles1 = EventLog.RoleTable(EventData.Roles);
					CreateFormTable("IBUserRolesTable", "RoleTable", IBUserRoles1);
				EndIf;
				EventData.Delete("Roles");
			EndIf;
			CreateFormTable("IBUserPropertiesTable", "DataTable", EventData);
		EndIf;
		
	ElsIf TypeOf(EventData) = Type("Structure")
	      Or TypeOf(EventData) = Type("FixedStructure")
	      Or TypeOf(EventData) = Type("ValueTable") Then
		
		Items.Data.Visible = False;
		Items.DataPresentation.Visible = False;
		CreateFormTable("DataTable", "DataTable", EventData);
	EndIf;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserNameOpening(Item, StandardProcessing)
	
	If ValueIsFilled(User) Then
		StandardProcessing = False;
		ShowValue(, User);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentOpening(Item, StandardProcessing)
	
	If ValueIsFilled(Comment) Then
		Text = New TextDocument;
		Text.SetText(Comment);
		Text.Show(Title + " (" + NStr("en = 'Comment';") + ")");
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataPresentationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, MetadataPresentation);
	
EndProcedure

&AtClient
Procedure SessionDataSeparationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, SessionDataSeparation);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessActionDeniedDataTable

&AtClient
Procedure DataTableChoice(Item, RowSelected, Field, StandardProcessing)
	
	Value = Item.CurrentData[Mid(Field.Name, StrLen(Item.Name)+1)];
	
	If StrStartsWith(Value, "{""#"",")
	   And StrEndsWith(Value, "}")
	   And StrSplit(Value, ",").Count() = 3 Then
		
		Ref = SourceRef1(Value);
		If ValueIsFilled(Ref) Then
			Value = Ref;
			
		ElsIf Ref <> Undefined Then
			Value = "<" + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Empty reference: %1';"), TypeOf(Ref)) + ">";
		Else
			Value = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to retrieve the reference from the row. The reference type might be invalid:
				           |%1';"), Value);
		EndIf;
	ElsIf StrStartsWith(Value, "e1cib/") Then
		FileSystemClient.OpenURL(Value);
		Return;
	EndIf;
	
	ShowValue(, Value);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExpandTable(Command)
	SetGroupsVisibilityExceptTable(False);
EndProcedure

&AtClient
Procedure CollapseTable(Command)
	SetGroupsVisibilityExceptTable(True);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CreateFormTable(Val FormTableFieldName, Val AttributeNameFormDataCollection, Val ValueTable)
	
	If Not ValueIsFilled(Comment) Then
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
	EndIf;
	
	If TypeOf(ValueTable) = Type("Structure")
	 Or TypeOf(ValueTable) = Type("FixedStructure") Then
		
		ValueTree = EventLog.TreeWithStructureData(ValueTable);
		Filter = New Structure("ThereIsValue", False);
		HasAttachments = ValueTree.Rows.FindRows(Filter).Count() <> 0;
		If HasAttachments Then
			Items.DataTree.Visible = True;
			Items.TableHeading.Visible = True;
			ValueToFormAttribute(ValueTree, "DataTree");
			Return;
		EndIf;
		ValueTree.Columns.Delete("ThereIsValue");
		ValueTable = New ValueTable;
		For Each Column In ValueTree.Columns Do
			ValueTable.Columns.Add(Column.Name, Column.ValueType, Column.Title);
		EndDo;
		For Each String In ValueTree.Rows Do
			FillPropertyValues(ValueTable.Add(), String);
		EndDo;
		Items[FormTableFieldName].Header = False;
		
	ElsIf TypeOf(ValueTable) <> Type("ValueTable") Then
		ValueTable = New ValueTable;
		ValueTable.Columns.Add("Undefined", , " ");
	EndIf;
	
	If FormTableFieldName = "DataTable" Then
		Items.TableHeading.Visible = True;
		Items.DataTreeCommands.Visible = False;
		Items.DataTableCommands.Visible = True;
	EndIf;
	
	// Adding form table attributes.
	AttributesToBeAdded = New Array;
	For Each Column In ValueTable.Columns Do
		AttributesToBeAdded.Add(New FormAttribute(Column.Name,
			Column.ValueType, AttributeNameFormDataCollection, Column.Title));
	EndDo;
	ChangeAttributes(AttributesToBeAdded);
	
	// Add items to the form.
	For Each Column In ValueTable.Columns Do
		AttributeItem = Items.Add(FormTableFieldName + Column.Name, Type("FormField"), Items[FormTableFieldName]);
		AttributeItem.DataPath = AttributeNameFormDataCollection + "." + Column.Name;
		AttributeItem.AutoCellHeight = True;
	EndDo;
	
	For Each String In ValueTable Do
		NewRow = ThisObject[AttributeNameFormDataCollection].Add();
		Try
			FillPropertyValues(NewRow, String);
		Except
			For Each Column In ValueTable.Columns Do
				Try
					NewRow[Column.Name] = String[Column.Name];
				Except
					NewRow[Column.Name] = String(String[Column.Name]); // Type UnknownObject
				EndTry;
			EndDo;
		EndTry;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DataTreeValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DataTree.ThereIsValue");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtServerNoContext
Function SourceRef1(SerializedRef)
	
	Try
		Ref = ValueFromStringInternal(SerializedRef);
	Except
		Ref = Undefined;
	EndTry;
	
	If Not Common.IsReference(TypeOf(Ref)) Then
		Ref = Undefined;
	EndIf;
	
	Return Ref;
	
EndFunction

&AtClient
Procedure SetGroupsVisibilityExceptTable(Visible)
	
	Items.ButtonGroup.Visible = Visible;
	Items.MainGroup3.Visible = Visible;
	Items.EventGroup.Visible = Visible;
	Items.GroupData.ShowTitle = Visible;
	Items.StandardDataProperties.Visible = Visible;
	Items.TransactionConnectionGroup.Visible = Visible;
	
EndProcedure

#EndRegion
