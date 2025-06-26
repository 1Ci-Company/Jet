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

#Region Internal

// Fills in the register of updated data to pass to the subordinate DIB nodes.
//
// Parameters:
//  Queue - Number - the position in the queue for the current handler.
//  Data  - AnyRef
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - Array of AnyRef - the data the changes to be recorded for.
//            Registration by the independent information register is not supported.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingMarkParameters
//
Procedure MarkProcessingCompletion(Queue, Data, AdditionalParameters) Export
	
	If (SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly 
			And Not StandardSubsystemsCached.DIBUsed())
			Or (Not SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
				And Not StandardSubsystemsCached.DIBUsed("WithFilter"))
			Or SessionParameters.UpdateHandlerParameters.RunAlsoInSubordinateDIBNodeWithFilters Then
		Return;
	EndIf;
	
	DataType = TypeOf(Data);
	
	If DataType = Type("Array")
		And Data.Count() = 0 Then
		Return;
	EndIf;
	
	If SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly Then
		DIBNodes = StandardSubsystemsCached.DIBNodes();
	Else
		DIBNodes = StandardSubsystemsCached.DIBNodes("WithFilter");
	EndIf;
	
	If DIBNodes.Count() = 0 Then
		Return;
	EndIf;
	
	If AdditionalParameters.IsRegisterRecords
		Or AdditionalParameters.IsIndependentInformationRegister Then
		MetadataObjectID = Common.MetadataObjectID(AdditionalParameters.FullRegisterName);
	Else
		
		If DataType = Type("Array") Then
			MetadataObjectID = Undefined;
		Else
			MetadataObjectID = Common.MetadataObjectID(DataType);
		EndIf;
		
	EndIf;
	
	DataSet = CreateRecordSet();
	
	If ValueIsFilled(MetadataObjectID) Then
		DataSet.Filter.MetadataObject.Set(MetadataObjectID);
	EndIf;
	
	DataSet.Filter.Queue.Set(Queue);
	
	If AdditionalParameters.IsRegisterRecords Then
		AddDataToSet(DIBNodes, DataSet, Data);
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		For Each DataElement In Data Do
			
			DimensionValueStructure = New Structure;
			Id              = New UUID;
			
			DataSet.Filter.UniqueKey.Set(Id);
			
			For Each FilterElement In Data.Columns Do
				DimensionValueStructure.Insert(FilterElement.Name, DataElement[FilterElement.Name]);
			EndDo;
			
			For Each DIBNode In DIBNodes Do
				
				NewRow = DataSet.Add();
				
				NewRow.ExchangePlanNode                     = DIBNode.Value;
				NewRow.MetadataObject                    = MetadataObjectID;
				NewRow.UniqueKey                    = Id;
				NewRow.Queue                             = Queue;
				NewRow.IndependentRegisterFiltersValues = New ValueStorage(DimensionValueStructure, New Deflation(9));
				
			EndDo;
			
			WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
			
			DataSet = CreateRecordSet();
			If ValueIsFilled(MetadataObjectID) Then
				DataSet.Filter.MetadataObject.Set(MetadataObjectID);
			EndIf;
			DataSet.Filter.Queue.Set(Queue);
			
		EndDo;
		
	Else
		If TypeOf(Data) <> Type("Array") Then
			
			MetadataObject = Metadata.FindByType(DataType);
			If Common.IsConstant(MetadataObject) Then
				Return;
			EndIf;
			
			If Common.IsInformationRegister(MetadataObject)
				And MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				DimensionValueStructure = New Structure;
				Id                       = New UUID;
				
				DataSet.Filter.UniqueKey.Set(Id);
				
				For Each FilterElement In Data.Filter Do
					DimensionValueStructure.Insert(FilterElement.Name, FilterElement.Value);
				EndDo;
				
				For Each DIBNode In DIBNodes Do
					
					NewRow = DataSet.Add();
					
					NewRow.ExchangePlanNode                     = DIBNode.Value;
					NewRow.MetadataObject                    = MetadataObjectID;
					NewRow.UniqueKey                    = Id;
					NewRow.Queue                             = Queue;
					NewRow.IndependentRegisterFiltersValues = New ValueStorage(DimensionValueStructure, New Deflation(9));
					
				EndDo;
				
				WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
				Return;
				
			EndIf;
			
			AddDataToSet(DIBNodes, DataSet, Data, MetadataObject);
			
		Else
			
			AddDataToSet(DIBNodes, DataSet, Data, , Queue);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure AddDataToSet(DIBNodes, DataSet, Data, MetadataObject = Undefined, Queue = Undefined)
	
	If TypeOf(Data) = Type("Array") Then
		
		For Each DataElement In Data Do
			
			LinkID = DataElement.UUID();
			
			DataSet = CreateRecordSet();
			DataSet.Filter.Data.Set(DataElement);
			DataSet.Filter.Queue.Set(Queue);
			DataSet.Filter.MetadataObject.Set(Common.MetadataObjectID(TypeOf(DataElement)));
			DataSet.Filter.UniqueKey.Set(LinkID);
			
			For Each DIBNode In DIBNodes Do
				NewRow = DataSet.Add();
				
				NewRow.ExchangePlanNode  = DIBNode.Value;
				NewRow.MetadataObject = DataSet.Filter.MetadataObject.Value;
				NewRow.Data           = DataElement;
				NewRow.Queue          = DataSet.Filter.Queue.Value;
				NewRow.UniqueKey = LinkID;
				
			EndDo;
			
			WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
			
		EndDo;
		
	Else
		
		Value = Undefined;
		
		If MetadataObject = Undefined Then
			MetadataObject = Metadata.FindByType(TypeOf(Data));
		EndIf;
		
		If Common.IsReference(TypeOf(Data)) Then
			Value = Data;
		ElsIf Common.IsRefTypeObject(MetadataObject) Then
			Value = Data.Ref;
		Else
			Value = Data.Filter.Recorder.Value;
		EndIf;
		
		UniqueKey = New UUID("00000000-0000-0000-0000-000000000000");
		If Value <> Undefined Then
			UniqueKey = Value.UUID();
		EndIf;
		
		DataSet.Filter.Data.Set(Value);
		DataSet.Filter.UniqueKey.Set(UniqueKey);
		
		If Not DataSet.Filter.MetadataObject.Use
			Or Not ValueIsFilled(DataSet.Filter.MetadataObject.Value) Then
			DataSet.Filter.MetadataObject.Set(Common.MetadataObjectID(TypeOf(Value)));
		EndIf;
		
		For Each DIBNode In DIBNodes Do
			
			NewRow = DataSet.Add();
			
			NewRow.ExchangePlanNode  = DIBNode.Value;
			NewRow.MetadataObject = DataSet.Filter.MetadataObject.Value;
			NewRow.Data           = Value;
			NewRow.UniqueKey = UniqueKey;
			NewRow.Queue          = DataSet.Filter.Queue.Value;
			
		EndDo;
		
		WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
		
	EndIf;
	
EndProcedure

Procedure WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes)
	
	// Write a set, replacing the standard registration logic by your own.
	For Each Item In DataSet Do
		RecordableSet = CreateRecordSet();
		For Each FilterElement In DataSet.Filter Do
			RecordableSet.Filter[FilterElement.Name].Set(FilterElement.Value);
		EndDo;
		RecordableSet.Filter.ExchangePlanNode.Set(Item.ExchangePlanNode);
		
		FillPropertyValues(RecordableSet.Add(), Item);
		
		RecordableSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		RecordableSet.Write();
	EndDo;
	
	SetToRegister = CreateRecordSet();
	For Each FilterElement In DataSet.Filter Do
		SetToRegister.Filter[FilterElement.Name].Set(FilterElement.Value);
	EndDo;
	
	For Each ListItem In DIBNodes Do
		
		DIBNode = ListItem.Value;
		SetToRegister.Filter.ExchangePlanNode.Set(DIBNode);
		ExchangePlans.RecordChanges(DIBNode, SetToRegister);
		
	EndDo;
EndProcedure

#EndRegion

#EndIf