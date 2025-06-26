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

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		// No need to check "DataExchange.Load" as
		// the register data is accessed during a data update.
		
		If Common.IsSubordinateDIBNode() And Not InfobaseUpdate.InfobaseUpdateRequired() Then 
			MarkDataUpdatedInMasterNode();
		EndIf;
		
		Clear();
		Return;
	EndIf;
		
	If Count() > 0
		And (Not ValueIsFilled(SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue)
			Or Common.IsSubordinateDIBNode()
			Or (SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
			      And Not StandardSubsystemsCached.DIBUsed())
			Or (Not SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
			      And Not StandardSubsystemsCached.DIBUsed("WithFilter"))) Then
		
		Cancel = True;
		ExceptionText = NStr("en = 'You can save data to %1 only when the deferred infobase update handler running in the root node is marked as completed.';");
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "InformationRegister.DataProcessedInMasterDIBNode");
		Raise ExceptionText;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure MarkDataUpdatedInMasterNode()
	
	For Each Record In ThisObject Do
		
		Object = Common.MetadataObjectByID(Record.MetadataObject, False);
		If TypeOf(Object) = Type("MetadataObject") Then // Metadata object was deleted in the master node configuration.
			MarkProcessingCompletion(Record, Object);
		EndIf;	
		
		If DataExchange.Sender <> Undefined Then // not creation of the initial image
			SetToRegisterResponseToMasterNode = InformationRegisters.DataProcessedInMasterDIBNode.CreateRecordSet();
			SetToRegisterResponseToMasterNode.Filter.ExchangePlanNode.Set(Record.ExchangePlanNode);
			SetToRegisterResponseToMasterNode.Filter.MetadataObject.Set(Record.MetadataObject);
			SetToRegisterResponseToMasterNode.Filter.Data.Set(Record.Data);
			SetToRegisterResponseToMasterNode.Filter.Queue.Set(Record.Queue);
			SetToRegisterResponseToMasterNode.Filter.UniqueKey.Set(Record.UniqueKey);
			
			ExchangePlans.RecordChanges(DataExchange.Sender, SetToRegisterResponseToMasterNode);
		EndIf;
		
	EndDo;

EndProcedure

Procedure MarkProcessingCompletion(Val Record, Val Object)
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	
	FullMetadataObjectName = Object.FullName();
	If StrFind(FullMetadataObjectName, "AccumulationRegister") > 0
		Or StrFind(FullMetadataObjectName, "AccountingRegister") > 0
		Or StrFind(FullMetadataObjectName, "CalculationRegister") > 0 Then
		
		AdditionalParameters.IsRegisterRecords       = True;
		AdditionalParameters.FullRegisterName = FullMetadataObjectName;
		DataToMark                          = Record.Data;
		
	ElsIf StrFind(FullMetadataObjectName, "InformationRegister") > 0 Then
		
		If Object.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			RegisterManager = Common.ObjectManagerByFullName(FullMetadataObjectName);
			
			DataToMark = RegisterManager.CreateRecordSet();
			FilterValues   = Record.IndependentRegisterFiltersValues.Get();
			
			For Each KeyValue In FilterValues Do
				DataToMark.Filter[KeyValue.Key].Set(KeyValue.Value);
			EndDo;
			
		Else
			AdditionalParameters.IsRegisterRecords = True;
			AdditionalParameters.FullRegisterName = FullMetadataObjectName;
			DataToMark = Record.Data;
		EndIf;
		
	Else
		DataToMark = Record.Data;
	EndIf;
	
	InfobaseUpdate.MarkProcessingCompletion(DataToMark, AdditionalParameters, Record.Queue);

EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf