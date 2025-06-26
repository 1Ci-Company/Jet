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

// Retrieves cache version data from the ValueStorage resource of the ProgramInterfaceCache register.
//
// Parameters:
//   Id - String - cache record ID.
//   DataType     - EnumRef.APICacheDataTypes
//   ReceivingParameters - String - parameter array serialized to XML for passing into the cache update procedure.
//   UseObsoleteData - Boolean - a flag that shows whether the procedure must wait for cache
//      update before retrieving data if it is obsolete.
//      True - always use cache data, if any. False - wait
//      for the cache update if data is obsolete.
//
// Returns:
//   FixedArray, BinaryData
//
Function VersionCacheData(Val Id, Val DataType, Val ReceivingParameters, Val UseObsoleteData = True) Export
		
	Query = New Query;
	Query.Text =
		"SELECT
		|	CacheTable.UpdateDate AS UpdateDate,
		|	CacheTable.Data AS Data,
		|	CacheTable.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS CacheTable
		|WHERE
		|	CacheTable.Id = &Id
		|	AND CacheTable.DataType = &DataType";
	Query.SetParameter("Id", Id);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	Try
		// Managed lock is not set, so other sessions can change the value while this transaction is active.
		SetPrivilegedMode(True);
		Result = Query.Execute();
		SetPrivilegedMode(False);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	UpdateRequired2 = False;
	RereadDataRequired = False;
	
	If Result.IsEmpty() Then
		
		UpdateRequired2 = True;
		RereadDataRequired = True;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		If Not InterfaceCacheCurrent(Selection.UpdateDate) Then
			UpdateRequired2 = True;
			RereadDataRequired = Not UseObsoleteData;
		EndIf;
	EndIf;
	
	If UpdateRequired2 Then
		
		UpdateInCurrentSession = RereadDataRequired
			Or Common.FileInfobase()
			Or ExclusiveMode()
			Or Common.DebugMode()
			Or CurrentRunMode() = Undefined;
		
		If UpdateInCurrentSession Then
			UpdateVersionCacheData(Id, DataType, ReceivingParameters);
			RereadDataRequired = True;
		Else
			JobMethodName = "InformationRegisters.ProgramInterfaceCache.UpdateVersionCacheData";
			JobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Version cache update. Entry ID: %1. Data type: %2.';"),
				Id,
				DataType);
			JobParameters = New Array;
			JobParameters.Add(Id);
			JobParameters.Add(DataType);
			JobParameters.Add(ReceivingParameters);
			
			JobsFilter = New Structure;
			JobsFilter.Insert("MethodName", JobMethodName);
			JobsFilter.Insert("Description", JobDescription);
			JobsFilter.Insert("State", BackgroundJobState.Active);
			
			Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
			If Jobs.Count() = 0 Then
				// Start a new one.
				ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(Undefined);
				ExecutionParameters.BackgroundJobDescription = JobDescription;
				SafeMode = SafeMode();
				SetSafeModeDisabled(True);
				TimeConsumingOperations.RunBackgroundJobWithClientContext(JobMethodName,
					ExecutionParameters, JobParameters, SafeMode);
				SetSafeModeDisabled(False);
			EndIf;
		EndIf;
		
		If RereadDataRequired Then
			
			BeginTransaction();
			Try
				// Managed lock is not set, so other sessions can change the value while this transaction is active.
				SetPrivilegedMode(True);
				Result = Query.Execute();
				SetPrivilegedMode(False);
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			If Result.IsEmpty() Then
				MessageTemplate = NStr("en = 'Version cache update error. The data is not received.
					|Entry ID: %1
					|Data type: %2';");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Id, DataType);
					
				Raise(MessageText);
			EndIf;
			
			Selection = Result.Select();
			Selection.Next();
		EndIf;
		
	EndIf;
		
	Return Selection.Data.Get();
	
EndFunction

// Updates data in the version cache.
//
// Parameters:
//  Id      - String - cache record ID.
//  DataType          - EnumRef.APICacheDataTypes - type of data to update.
//  ReceivingParameters - Array - additional options of getting data to the cache.
//
Procedure UpdateVersionCacheData(Val Id, Val DataType, Val ReceivingParameters) Export
	
	SetPrivilegedMode(True);
	
	KeyStructure1 = New Structure("Id, DataType", Id, DataType);
	Var_Key = CreateRecordKey(KeyStructure1);
	
	Try
		LockDataForEdit(Var_Key);
	Except
		// The data is being updated from another session.
		Return;
	EndTry;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CacheTable.UpdateDate AS UpdateDate,
		|	CacheTable.Data AS Data,
		|	CacheTable.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS CacheTable
		|WHERE
		|	CacheTable.Id = &Id
		|	AND CacheTable.DataType = &DataType";
	Query.SetParameter("Id", Id);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
		LockItem.SetValue("Id", Id);
		LockItem.SetValue("DataType", DataType);
		Block.Lock();
		
		Result = Query.Execute();
		
		// Committing the transaction so that other sessions can read data.
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		UnlockDataForEdit(Var_Key);
		Raise;
		
	EndTry;
	
	Try
		
		// Making sure the data must be updated.
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			If InterfaceCacheCurrent(Selection.UpdateDate) Then
				UnlockDataForEdit(Var_Key);
				Return;
			EndIf;
			
		EndIf;
		
		Set = CreateRecordSet();
		Set.Filter.Id.Set(Id);
		Set.Filter.DataType.Set(DataType);
		
		Record = Set.Add();
		Record.Id = Id;
		Record.DataType = DataType;
		Record.UpdateDate = CurrentUniversalDate();
		
		Set.AdditionalProperties.Insert("ReceivingParameters", ReceivingParameters);
		Set.PrepareDataToRecord();
		
		Set.Write();
		
		UnlockDataForEdit(Var_Key);
		
	Except
		
		UnlockDataForEdit(Var_Key);
		Raise;
		
	EndTry;
	
EndProcedure

// Prepares the data for the interface cache.
//
// Parameters:
//  DataType          - EnumRef.APICacheDataTypes - type of data to update.
//  ReceivingParameters - Array - additional options of getting data to the cache.
//  
// Returns:
//  FixedArray, BinaryData
//
Function PrepareVersionCacheData(Val DataType, Val ReceivingParameters) Export
	
	If DataType = Enums.APICacheDataTypes.InterfaceVersions Then
		Data = GetInterfaceVersionsToCache(ReceivingParameters[0], ReceivingParameters[1]);
	ElsIf DataType = Enums.APICacheDataTypes.WebServiceDetails Then
		Data = GetWSDL(ReceivingParameters[0], ReceivingParameters[1], ReceivingParameters[2], ReceivingParameters[3], ReceivingParameters[4]);
	Else
		TextTemplate1 = NStr("en = 'Unknown version cache data type: %1.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(TextTemplate1, DataType);
		Raise(MessageText);
	EndIf;
	
	Return Data;
	
EndFunction

// Generates a version cache record ID based on a server address and a resource name.
//
// Parameters:
//  Address - String - server address.
//  Name   - String - resource name.
//
// Returns:
//  String - version cache record ID.
//
Function VersionCacheRecordID(Val Address, Val Name) Export
	
	Return Address + "|" + Name;
	
EndFunction

Function InnerWSProxy(Parameters) Export
	
	Protocol = "";
	Position = StrFind(Parameters.WSDLAddress, "://");
	If Position > 0 Then
		Protocol = Lower(Left(Parameters.WSDLAddress, Position - 1));
	EndIf;
		
	SecureConnection = Parameters.SecureConnection;
	If (Protocol = "https" Or Protocol = "ftps") And SecureConnection = Undefined Then
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	WSDefinitions = WSDefinitions(Parameters.WSDLAddress, Parameters.UserName, Parameters.Password,, 
		SecureConnection);
	
	EndpointName = Parameters.EndpointName;
	If IsBlankString(EndpointName) Then
		EndpointName = Parameters.ServiceName + "Soap";
	EndIf;
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		InternetProxy = ModuleNetworkDownload.GetProxy(Parameters.WSDLAddress);
	EndIf;
	
	Location = Parameters.Location;
	If IsBlankString(Location) Then
		Location = Parameters.WSDLAddress;
		Position = StrFind(Location, "?");
		If Position > 0 Then
			Location = Left(Location, Position - 1);
		EndIf;
	EndIf;
	
	Proxy = New WSProxy(WSDefinitions, Parameters.NamespaceURI, Parameters.ServiceName, EndpointName,
		InternetProxy, Parameters.Timeout, SecureConnection, Location, Parameters.UseOSAuthentication);
	Proxy.User = Parameters.UserName;
	Proxy.Password       = Parameters.Password;
	
	Return Proxy;
EndFunction

#EndRegion

#Region Private

Function InterfaceCacheCurrent(UpdateDate)
	
	If ValueIsFilled(UpdateDate) Then
		Return UpdateDate + 24 * 60 * 60 > CurrentUniversalDate(); // caching no more than for 24 hours.
	EndIf;
	
	Return False;
	
EndFunction

Function WSDefinitions(Val WSDLAddress, Val UserName, Val Password, Val Timeout = 10, Val SecureConnection = Undefined)
	
	If Not Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Try
			InternetProxy = Undefined; // By default.
			Definitions = New WSDefinitions(WSDLAddress, UserName, Password, InternetProxy, Timeout, SecureConnection);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to get WS definitions at
				           |%1.
				           |Reason:
				           |%2';"),
				WSDLAddress,
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
			If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
				ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
				DiagnosticsResult = ModuleNetworkDownload.ConnectionDiagnostics(WSDLAddress);
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1
					           |Diagnostics result:
					           |%2';"),
					DiagnosticsResult.ErrorDescription);
			EndIf;
			
			Raise ErrorText;
		EndTry;
		Return Definitions;
	EndIf;
	
	ReceivingParameters = New Array;
	ReceivingParameters.Add(WSDLAddress);
	ReceivingParameters.Add(UserName);
	ReceivingParameters.Add(Password);
	ReceivingParameters.Add(Timeout);
	ReceivingParameters.Add(SecureConnection);

	WSDLData = VersionCacheData(
		WSDLAddress,
		Enums.APICacheDataTypes.WebServiceDetails, 
		ReceivingParameters,
		False); // BinaryData
		
	WSDLFileName = GetTempFileName("wsdl");
	WSDLData.Write(WSDLFileName);
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		InternetProxy = ModuleNetworkDownload.GetProxy(WSDLAddress);
	EndIf;
	
	Try
		Definitions = New WSDefinitions(WSDLFileName, UserName, Password, InternetProxy, Timeout, SecureConnection);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to get WS definitions from cache.
			           |Reason:
			           |%1';"),
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Raise ErrorText;
	EndTry;
	
	Try
		DeleteFiles(WSDLFileName);
	Except
		WriteLogEvent(NStr("en = 'Getting WSDL';", Common.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Definitions;
EndFunction

// Returns:
//  FixedArray
//
Function GetInterfaceVersionsToCache(Val ConnectionParameters, Val InterfaceName)
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en = 'The service URL is not set.';"));
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		And ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		
		If ConnectionParameters.Property("Password") Then
			UserPassword = ConnectionParameters.Password;
		Else
			UserPassword = Undefined;
		EndIf;
		
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + "/ws/InterfaceVersion?wsdl";
	
	IsPackageDeliveryCheckOnErrorEnabled = ConnectionParameters.IsPackageDeliveryCheckOnErrorEnabled;
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/SaaS/1.0/WS";
	ConnectionParameters.ServiceName = "InterfaceVersion";
	ConnectionParameters.UserName = UserName;
	ConnectionParameters.Password = UserPassword;
	ConnectionParameters.Timeout = 7;
	ConnectionParameters.IsPackageDeliveryCheckOnErrorEnabled = IsPackageDeliveryCheckOnErrorEnabled;
	
	VersioningProxy = Common.CreateWSProxy(ConnectionParameters);
	
	XDTOArray = VersioningProxy.GetVersions(InterfaceName);
	If XDTOArray = Undefined Then
		Return New FixedArray(New Array);
	Else	
		Serializer = New XDTOSerializer(VersioningProxy.XDTOFactory);
		Return New FixedArray(Serializer.ReadXDTO(XDTOArray));
	EndIf;
	
EndFunction

Function GetWSDL(Val Address, Val UserName, Val Password, Val Timeout, Val SecureConnection = Undefined)
	
	ReceivingParameters = New Structure;
	If Not IsBlankString(UserName) Then
		ReceivingParameters.Insert("User", UserName);
		ReceivingParameters.Insert("Password", Password);
	EndIf;
	ReceivingParameters.Insert("Timeout", Timeout);
	ReceivingParameters.Insert("SecureConnection", SecureConnection);
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		FileDetails = ModuleNetworkDownload.DownloadFileAtServer(Address, ReceivingParameters);
	Else
		Raise(NStr("en = 'The ""Network download"" subsystem is unavailable.';"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	If Not FileDetails.Status Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get web service details file %1 due to:
				|%2';"),
			Address, FileDetails.ErrorMessage), ErrorCategory.NetworkError);
	EndIf;
	
	InternetProxy = ModuleNetworkDownload.GetProxy(Address);
	Try
		Definitions = New WSDefinitions(FileDetails.Path, UserName, Password, InternetProxy, Timeout, SecureConnection);
	Except
		DiagnosticsResult = ModuleNetworkDownload.ConnectionDiagnostics(Address);
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get web service details file %1 due to:
				|%2
				|
				|Diagnostics result:
			    |%3';"),
			Address,
			ErrorProcessing.BriefErrorDescription(ErrorInfo()),
			DiagnosticsResult.ErrorDescription);
			
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |
			           |Trace parameters:
			           |Secure connection: %2
			           |Timeout: %3';"),
			ErrorText,
			Format(SecureConnection, NStr("en = 'BF=No; BT=Yes';")),
			Format(Timeout, "NG=0"));
			
		WriteLogEvent(NStr("en = 'Getting WSDL';", Common.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorMessage);
		Raise(ErrorText, ErrorCategory.NetworkError);
	EndTry;
	
	If Definitions.Services.Count() = 0 Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get the web service description file.
			           |Reason: the file does not contain web service descriptions.
			           |Probably the file address is incorrect:
			           |%1';"),
			Address),
			ErrorCategory.NetworkError);
	EndIf;
	Definitions = Undefined;
	
	FileData = New BinaryData(FileDetails.Path);
	
	Try
		DeleteFiles(FileDetails.Path);
	Except
		WriteLogEvent(NStr("en = 'Getting WSDL';", Common.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return FileData;
	
EndFunction

#EndRegion

#EndIf