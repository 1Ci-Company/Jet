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
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		FilesStorageCatalogName = Parameters.FileOwner.Metadata().Name;
		FileOwner = Parameters.FileOwner;
		List.Parameters.SetParameterValue("Owner", Parameters.FileOwner);
		Items.Folders.Visible = (TypeOf(Parameters.FileOwner) = Type("CatalogRef.FilesFolders"));
	Else
		FilesStorageCatalogName = "Files";
		FileOwner = Catalogs.FilesFolders.EmptyRef();
	EndIf;
	If TypeOf(FileOwner) = Type("CatalogRef.FilesFolders") Then
		If Parameters.SelectTemplate1 Then
			FileOwner = Catalogs.FilesFolders.Templates;
			DefinePossibilityAddFilesTemplates();
			TemplateSelectionMode = Parameters.SelectTemplate1;
			CommonClientServer.SetDynamicListFilterItem(
				Folders, "Ref", Catalogs.FilesFolders.Templates,
				DataCompositionComparisonType.InHierarchy, , True);
		ElsIf ValueIsFilled(Parameters.CurrentRow) And FileOwner.IsEmpty() Then
			 NewValue = Common.ObjectAttributeValue(Parameters.CurrentRow, "FileOwner", True);
			 If NewValue <> Undefined Then
			 	FileOwner = NewValue;
			 EndIf;
		EndIf;	
		Items.Folders.CurrentRow = FileOwner;
		Items.Folders.SelectedRows.Clear();
		Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
		
	If ValueIsFilled(Parameters.CurrentRow) Then 
		Items.List.CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	OnChangeUseSignOrEncryptionAtServer();
	
	If Common.IsMobileClient() Then
		Items.Folders.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
	SSLSubsystemsIntegration.OnCreateFilesListForm(ThisObject);
	FilesOperationsOverridable.OnCreateFilesListForm(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" Then
				
		If Parameter.IsNew = True Then
			If Parameter.Owner = Items.Folders.CurrentRow Then
				Items.List.Refresh();
				
				If ValueIsFilled(Parameter.File) Then
					Items.List.CurrentRow = Parameter.File;
				EndIf;
			EndIf;
			
			Items.List.Refresh();
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		And (    Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If MobileClient Then
	SetFoldersTreeTitle();
#EndIf

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFolders

&AtClient
Procedure FoldersOnActivateRow(Item)
	
	AttachIdleHandler("IdleHandler", 0.2, True);
	
#If MobileClient Then
	AttachIdleHandler("SetFoldersTreeTitle", 0.1, True);
	CurrentItem = Items.List;
#EndIf

EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	If Not Copy Then
		AddFileToApplication();
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AppendFile(Command)
	
	AddFileToApplication();
	
EndProcedure

&AtClient
Procedure AddFileToApplication()
	
	If TemplateSelectionMode Then
		
		FilesOperationsInternalClient.AddFileFromFileSystem(Items.Folders.CurrentRow, ThisObject);
		
	Else
		
		DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
		If DCParameterValue = Undefined Then
			FileOwner = Undefined;
		Else
			FileOwner = DCParameterValue.Value;
		EndIf;
		FilesOperationsInternalClient.AppendFile(Undefined, FileOwner, ThisObject);
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

// The procedure updates the Files list.
&AtClient
Procedure IdleHandler()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	
EndProcedure

&AtClient
Procedure SetFoldersTreeTitle()
	
	Items.Folders.Title = ?(Items.Folders.CurrentData = Undefined, "",
		Items.Folders.CurrentData.Description);
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
EndProcedure

&AtServer
Procedure DefinePossibilityAddFilesTemplates()
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		HasRightAddFiles = ModuleAccessManagement.HasRight("AddFilesAllowed", Catalogs.FilesFolders.Templates);
	Else
		HasRightAddFiles = AccessRight("Insert", Metadata.Catalogs.Files) 
			And AccessRight("Read", Metadata.Catalogs.FilesFolders);
	EndIf;
	
	If Not HasRightAddFiles Then
		Items.AppendFile.Visible = False;
	EndIf;

EndProcedure

#EndRegion
