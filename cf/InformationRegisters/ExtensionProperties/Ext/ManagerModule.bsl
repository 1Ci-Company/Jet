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

// For internal use.For internal use.
// 
Procedure SaveExtensionsProperties(ExtensionID, Properties) Export
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ExtensionProperties");
		LockItem.SetValue("ExtensionID", ExtensionID);
		Block.Lock();
		
		RecordManager = CreateRecordManager();
		RecordManager.ExtensionID = ExtensionID;
		RecordManager.Read();
		
		RecordManager.ExtensionID = ExtensionID;
		FillPropertyValues(RecordManager, Properties);

		RecordManager.Write(True);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteExtensionPropertiesByID(ExtensionID)
	
	Set = InformationRegisters.ExtensionProperties.CreateRecordSet();
	Set.Filter.ExtensionID.Set(ExtensionID);
	Set.Write();
	
EndProcedure

Procedure DeletePropertiesOfDeletedExtensions() Export

	Extensions = ConfigurationExtensions.Get();
	
	UsedExtensionsIDs = New Array;
	
	For Each Extension In Extensions Do
		UsedExtensionsIDs.Add(String(Extension.UUID));
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ExtensionProperties.ExtensionID AS ExtensionID
		|FROM
		|	InformationRegister.ExtensionProperties AS ExtensionProperties
		|WHERE
		|	NOT ExtensionProperties.ExtensionID IN (&UsedExtensionsIDs)";
	
	Query.SetParameter("UsedExtensionsIDs", UsedExtensionsIDs);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		DeleteExtensionPropertiesByID(Selection.ExtensionID)
	EndDo;
	
EndProcedure

#EndRegion

#EndIf