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
	HandlerName = Parameters.HandlerName;
	If Not ValueIsFilled(HandlerName) Then
		Raise NStr("en = 'Handler name wasn''t passed.';");
	EndIf;
	
	Title = NStr("en = 'Data registered on handler ""%1""';");
	Title = StringFunctionsClientServer.SubstituteParametersToString(Title, HandlerName);
	
	TextSummaryInformation = NStr("en = '%1 out of %2 objects remain to be processed, progress - %3%. %4 objects have been processed for the selected period.';");
	If Not ValueIsFilled(Number(Parameters.ProcessedForPeriod)) Then
		TextSummaryInformation = NStr("en = '%1 out of %2 objects remain to be processed, progress - %3. No data has been processed for the selected period.';");
	EndIf;
	
	Items.CaptionSummaryInformation.Title = StringFunctionsClientServer.SubstituteParametersToString(
		TextSummaryInformation,
		Parameters.LeftToProcess,
		Parameters.TotalObjectCount,
		Parameters.Progress,
		Parameters.ProcessedForPeriod);
	
	Query = New Query;
	Query.SetParameter("HandlerName", HandlerName);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.DeferredProcessingQueue AS Queue,
		|	UpdateHandlers.DataToProcess AS DataToProcess
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.HandlerName = &HandlerName";
	Result = Query.Execute().Unload();
	
	HandlerDetails = Result[0];
	Queue = HandlerDetails.Queue;
	DataToProcess = HandlerDetails.DataToProcess.Get();
	For Each ObjectData2 In DataToProcess.HandlerData Do
		FullObjectName = ObjectData2.Key;
		Items.TableName.ChoiceList.Add(FullObjectName);
	EndDo;
	
	TableName = Items.TableName.ChoiceList[0].Value;
	SetListRequest();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TableNameOnChange(Item)
	SetListRequest();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListRequest()
	
	ObjectMetadata = Common.MetadataObjectByFullName(TableName);
	IsReferenceObject = Common.IsRefTypeObject(ObjectMetadata);
	
	For Each AddedElement In AddedItems Do
		Item = Items.Find(AddedElement.Value);
		Items.Delete(Item);
	EndDo;
	
	AddedItems.Clear();
	
	QueryTemplate =
		"SELECT
		|	*
		|FROM
		|	&TableName AS ChangesTable1
		|WHERE
		|	ChangesTable1.Node = &Node";
	ChangeTableName = TableName + ".Changes";
	
	QueryText = StrReplace(QueryTemplate, "&TableName", ChangeTableName);
	Node = ExchangePlans.InfobaseUpdate.NodeInQueue(Queue);
	
	Properties = Common.DynamicListPropertiesStructure();
	Properties.QueryText = QueryText;
	Properties.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, Properties);
	CommonClientServer.SetDynamicListParameter(
		List, "Node", Node, True);
	
	Parent = Items.List;
	If Not IsReferenceObject Then
		StructureToCheck = New Structure;
		StructureToCheck.Insert("MainFilter", Undefined);
		For Each Dimension In ObjectMetadata.Dimensions Do // MetadataObjectDimension
			FillPropertyValues(StructureToCheck, Dimension);
			If StructureToCheck.MainFilter = Undefined
				Or Not StructureToCheck.MainFilter Then
				Continue;
			EndIf;
			
			NewItem = Items.Add("List" + Dimension.Name, Type("FormField"), Parent);
			NewItem.DataPath = "List" + "." + Dimension.Name;
			AddedItems.Add(NewItem.Name);
		EndDo;
		
		For Each StandardAttribute In ObjectMetadata.StandardAttributes Do // StandardAttributeDescription
			If StandardAttribute.Name = "Recorder" Then
				NewItem = Items.Add("List" + StandardAttribute.Name, Type("FormField"), Parent);
				NewItem.DataPath = "List" + "." + StandardAttribute.Name;
				AddedItems.Add(NewItem.Name);
				Break;
			EndIf;
		EndDo;
	Else
		NewItem = Items.Add("ListRef", Type("FormField"), Parent);
		NewItem.DataPath = "List" + "." + "Ref";
		AddedItems.Add(NewItem.Name);
	EndIf;
	
EndProcedure

#EndRegion