///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Handles bunch message writing to the event log.
// The EventsForEventLog variable is cleared after writing.
//
// Parameters:
//  EventsForEventLog - ValueList:
//    * Value - Structure:
//        ** EventName  - String - Name of the logging event.
//        ** LevelPresentation  - String - Presentation of the "EventLogLevel" collection members.
//                                    Valid values are Information, Error, Warning, and Note.
//        ** Comment - String - Event comment.
//        ** EventDate - Date   - Event date. It is added to the comment upon logging.
//     * Presentation - String - Not used.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	If TypeOf(EventsForEventLog) <> Type("ValueList") Then
		Return;
	EndIf;
	
	If EventsForEventLog.Count() = 0 Then
		Return;
	EndIf;
	
	For Each LogMessage In EventsForEventLog Do
		MessageValue = LogMessage.Value;
		EventName = MessageValue.EventName;
		EventLevel = EventLevelByPresentation(MessageValue.LevelPresentation);
		EventDate = CurrentSessionDate();
		If MessageValue.Property("EventDate") And ValueIsFilled(MessageValue.EventDate) Then
			EventDate = MessageValue.EventDate;
		EndIf;
		Comment = String(EventDate) + " " + MessageValue.Comment;
		WriteLogEvent(EventName, EventLevel,,, Comment);
	EndDo;
	EventsForEventLog.Clear();
	
EndProcedure

#EndRegion

#Region Internal

// Write the message to the event log.
//
//  Parameters: 
//   EventName       - String - an event name for the event log.
//   Level          - EventLogLevel - events importance level of the log event.
//   MetadataObject - MetadataObject - metadata object that the event refers to.
//   Data           - AnyRef
//                    - Number
//                    - String
//                    - Date
//                    - Boolean
//                    - Undefined
//                    - Type - data that the event is related to.
//                      It is recommended to specify references to the data objects (catalog items, documents that the event
//                      refers to).
//   Comment      - String - the comment to the log event.
//
Procedure AddMessageForEventLog(Val EventName, Val Level,
		Val MetadataObject = Undefined, Val Data = Undefined, Val Comment = "") Export
		
	If IsBlankString(EventName) Then
		EventName = "Event"; // not localized to prevent startup from stopping in a partially translated configuration
	EndIf;

	WriteLogEvent(EventName, Level, MetadataObject, Data, Comment, EventLogEntryTransactionMode.Independent);
	
EndProcedure

// Reads event log message texts taking into account the filter settings.
//
// Parameters:
//
//     ReportParameters - Structure - contains parameters for reading events from the event log. Contains fields:
//      *  Log                  - ValueTable         - contains records of the event log.
//      *  EventLogFilter   - Structure             - filter settings used to read the event log records:
//          ** StartDate - Date - start date of events (optional).
//          ** EndDate - Date - end date of events (optional).
//      *  EventCount1       - Number                   - maximum number of records that can be read from the event log.
//      *  UUID - UUID - a form UUID.
//      *  OwnerManager       - Arbitrary            - event
//                                                             log is displayed in the form of this object. The manager is used to call back appearance
//                                                             functions.
//      *  AddAdditionalColumns - Boolean           - determines whether callback is needed to add
//                                                             additional columns.
//     StorageAddress - String
//                    - UUID - Address of the temporary storage that stores the result.
//
// Result is a structure with the following fields::
//     LogEvents - ValueTable - Selected events.
//
Procedure ReadEventLogEvents(ReportParameters, StorageAddress) Export
	
	EventLogFilterAtClient          = ReportParameters.EventLogFilter;
	EventCount1              = ReportParameters.EventsCountLimit;
	OwnerManager              = ReportParameters.OwnerManager;
	AddAdditionalColumns = ReportParameters.AddAdditionalColumns;
	
	// Verifying the parameters.
	StartDate    = Undefined;
	EndDate = Undefined;
	FilterDatesSpecified = EventLogFilterAtClient.Property("StartDate", StartDate) And EventLogFilterAtClient.Property("EndDate", EndDate)
		And ValueIsFilled(StartDate) And ValueIsFilled(EventLogFilterAtClient.EndDate);
		
	If FilterDatesSpecified And StartDate > EndDate Then
		Raise NStr("en = 'Invalid event log filter settings. The start date is later than the end date.';");
	EndIf;
	ServerTimeOffset = ServerTimeOffset();
	
	// Prepare the filter.
	Filter = New Structure;
	For Each FilterElement In EventLogFilterAtClient Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	
	FilterTransformation(Filter, ServerTimeOffset);
	
	// Exporting the selected events and generating the table structure.
	LogEvents = New ValueTable;
	UnloadEventLog(LogEvents, Filter, , , EventCount1);
	
	LogEvents.Columns.Date.Name = "DateAtServer";
	LogEvents.Columns.Add("Date", New TypeDescription("Date"));
	
	LogEvents.Columns.Add("PicNumber", New TypeDescription("Number"));
	LogEvents.Columns.Add("DataAsStr", New TypeDescription("String"));
	LogEvents.Columns.Add("EventKey", New TypeDescription("String"));
	
	If Common.SeparatedDataUsageAvailable() Then
		LogEvents.Columns.Add("SessionDataSeparation", New TypeDescription("ValueList"));
		LogEvents.Columns.Add("SessionDataSeparationPresentation", New TypeDescription("String"));
	EndIf;
	LogEvents.Columns.Add("DataArea", New TypeDescription("String"));
	
	If AddAdditionalColumns Then
		OwnerManager.AddAdditionalEventColumns(LogEvents);
	EndIf;
	
	LogEvents.Columns.Add("MetadataList", New TypeDescription("ValueList"));
	LogEvents.Columns.Add("IsDataStringMatchesDataPresentation", New TypeDescription("Boolean"));
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable()
	   And Common.SubsystemExists("CloudTechnology.Core") Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		UserAliases    = New Map();
	Else
		ModuleSaaSOperations = Undefined;
		UserAliases    = Undefined;
	EndIf;
	
	KeyStructure1 = New Structure;
	For Each Column In LogEvents.Columns Do
		KeyStructure1.Insert(Column.Name);
	EndDo;
	
	KeysPresentation = StructuresKeysPresentation();
	
	For Each LogEvent In LogEvents Do
		LogEvent.Date = LogEvent.DateAtServer - ServerTimeOffset;
		
		// Filling numbers of row pictures.
		OwnerManager.SetPictureNumber(LogEvent);
		
		If AddAdditionalColumns Then
			// Filling additional fields that are defined for the owner only.
			OwnerManager.FillInAdditionalEventColumns(LogEvent);
		EndIf;
		
		// Converting the array of metadata into a value list.
		If TypeOf(LogEvent.Metadata) = Type("Array") Then
			AddPresentation = TypeOf(LogEvent.MetadataPresentation) = Type("Array")
			   And LogEvent.MetadataPresentation.Count() = LogEvent.Metadata.Count();
			IndexOf = 0;
			For Each FullName In LogEvent.Metadata Do
				LogEvent.MetadataList.Add(FullName,
					?(AddPresentation, LogEvent.MetadataPresentation[IndexOf], ""));
				IndexOf = IndexOf + 1;
			EndDo;
		Else
			LogEvent.MetadataList.Add(LogEvent.Metadata,
				LogEvent.MetadataPresentation);
		EndIf;
		
		// Convert an array of metadata presentations into a string.
		If TypeOf(LogEvent.MetadataPresentation) = Type("Array") Then
			LogEvent.MetadataPresentation = StrConcat(LogEvent.MetadataPresentation, ", ");
		Else
			LogEvent.MetadataPresentation = String(LogEvent.MetadataPresentation);
		EndIf;
		
		// Convert the "SessionDataSeparation" array into a value list.
		If Not Common.SeparatedDataUsageAvailable() Then
			FullSessionDataSeparationPresentation = "";
			SessionDataSeparation = LogEvent.SessionDataSeparation;
			SeparatedDataAttributeList = New ValueList;
			For Each SessionSeparator In SessionDataSeparation Do
				SeparatorPresentation = Metadata.CommonAttributes.Find(SessionSeparator.Key).Presentation();
				SeparatorPresentation = SeparatorPresentation + " = " + SessionSeparator.Value;
				SeparatorValue = SessionSeparator.Key + "=" + SessionSeparator.Value;
				SeparatedDataAttributeList.Add(SeparatorValue, SeparatorPresentation);
				FullSessionDataSeparationPresentation = ?(Not IsBlankString(FullSessionDataSeparationPresentation),
				                                            FullSessionDataSeparationPresentation + "; ", "")
				                                            + SeparatorPresentation;
			EndDo;
			If Not ValueIsFilled(SessionDataSeparation) Then
				LogEvent.DataArea = "-";
				For Each CommonAttribute In Metadata.CommonAttributes Do
					If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.DontUse Then
						Continue;
					EndIf;
					SeparatorPresentation = CommonAttribute.Presentation() + " = " + NStr("en = '<Not set>';");
					SeparatorValue = CommonAttribute.Name + "=";
					SeparatedDataAttributeList.Add(SeparatorValue, SeparatorPresentation);
				EndDo;
			ElsIf Not SessionDataSeparation.Property("DataAreaMainData") Then
				LogEvent.DataArea = "?";
			Else
				LogEvent.DataArea = Format(SessionDataSeparation.DataAreaMainData, "NZ=0; NG=");
			EndIf;
			LogEvent.SessionDataSeparation = SeparatedDataAttributeList;
			LogEvent.SessionDataSeparationPresentation = FullSessionDataSeparationPresentation;
		EndIf;
		
		// Processing special event data.
		If LogEvent.Event = "_$Access$_.Access" Then
			SetDataString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				LogEvent.Data = TableDataPresentation(LogEvent.Data);
			EndIf;
			
		ElsIf LogEvent.Event = "_$Access$_.AccessDenied" Then
			SetDataString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				If LogEvent.Data.Property("Right") Then
					LogEvent.Data = StructureDataPresentation(LogEvent.Data,
						KeysPresentation);
				Else
					LogEvent.Data = StructureDataPresentation(LogEvent.Data,
						KeysPresentation, True) + "
						|" + TableDataPresentation(LogEvent.Data);
				EndIf;
			EndIf;
			
		ElsIf TypeOf(LogEvent.Data) = Type("Structure")
		      Or TypeOf(LogEvent.Data) = Type("FixedStructure") Then
			
			SetDataString(LogEvent);
			LogEvent.Data = StructureDataPresentation(LogEvent.Data,
				KeysPresentation);
			
		ElsIf TypeOf(LogEvent.Data) = Type("String") Then
			Data = DataFromXMLString(LogEvent.Data);
			If Data <> Undefined Then
				SetDataString(LogEvent);
				LogEvent.Data = StructureDataPresentation(Data, KeysPresentation);
			EndIf;
		EndIf;
		
		SetPrivilegedMode(True);
		// Refine the user name.
		If LogEvent.User = New UUID("00000000-0000-0000-0000-000000000000") Then
			LogEvent.UserName = NStr("en = '<Undefined>';");
			
		ElsIf LogEvent.UserName = "" Then
			LogEvent.UserName = Users.UnspecifiedUserFullName();
			
		ElsIf InfoBaseUsers.FindByUUID(LogEvent.User) = Undefined Then
			LogEvent.UserName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 <Deleted>';"), LogEvent.UserName);
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			If UserAliases.Get(LogEvent.User) = Undefined Then
				UserAlias = ModuleSaaSOperations.AliasOfUserOfInformationBase(LogEvent.User);
				UserAliases.Insert(LogEvent.User, UserAlias);
			Else
				UserAlias = UserAliases.Get(LogEvent.User);
			EndIf;
			
			If ValueIsFilled(UserAlias) Then
				LogEvent.UserName = UserAlias;
			EndIf;
		EndIf;
		
		If String(LogEvent.DataPresentation) = String(LogEvent.Data) Then
			LogEvent.IsDataStringMatchesDataPresentation = True;
		EndIf;
		
		LogEvent.Comment = CommonClientServer.ReplaceProhibitedXMLChars(
			LogEvent.Comment);
		
		FillPropertyValues(KeyStructure1, LogEvent);
		Hashing = New DataHashing(HashFunction.SHA256);
		Hashing.Append(ValueToStringInternal(KeyStructure1));
		LogEvent.EventKey = Base64String(Hashing.HashSum);
		
		SetPrivilegedMode(False);
	EndDo;
	
	LogEvents.Columns.Delete("Metadata");
	LogEvents.Columns.MetadataList.Name = "Metadata";
	
	// Completed successfully.
	Result = New Structure;
	Result.Insert("LogEvents", LogEvents);
	
	PutToTempStorage(Result, StorageAddress);
EndProcedure

// Creates a custom event log presentation.
//
// Parameters:
//  FilterPresentation - String - the string that contains custom presentation of the filter.
//  EventLogFilter - Structure - values of the event log filter.
//  DefaultEventLogFilter - Structure - default values of the event log filter 
//     (not included in the user presentation).
//
Procedure GenerateFilterPresentation(FilterPresentation, EventLogFilter, 
		DefaultEventLogFilter = Undefined) Export
	
	FilterPresentation = "";
	// Interval.
	PeriodStartDate    = Undefined;
	PeriodEndDate = Undefined;
	If Not EventLogFilter.Property("StartDate", PeriodStartDate)
		Or PeriodStartDate = Undefined Then
		PeriodStartDate    = '00010101000000';
	EndIf;
	
	If Not EventLogFilter.Property("EndDate", PeriodEndDate)
		Or PeriodEndDate = Undefined Then
		PeriodEndDate = '00010101000000';
	EndIf;
	
	If Not (PeriodStartDate = '00010101000000' And PeriodEndDate = '00010101000000') Then
		FilterPresentation = PeriodPresentation(PeriodStartDate, PeriodEndDate);
	EndIf;
	
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "User");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"Event", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"ApplicationName", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Session");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Level");
	
	// All other restrictions are specified by presentations without values.
	For Each FilterElement In EventLogFilter Do
		RestrictionName = FilterElement.Key;
		If Upper(RestrictionName) = Upper("StartDate")
			Or Upper(RestrictionName) = Upper("EndDate")
			Or Upper(RestrictionName) = Upper("Event")
			Or Upper(RestrictionName) = Upper("ApplicationName")
			Or Upper(RestrictionName) = Upper("User")
			Or Upper(RestrictionName) = Upper("Session")
			Or Upper(RestrictionName) = Upper("Level") Then
			Continue; // Interval and special restrictions are already displayed.
		EndIf;
		
		// Changing restrictions for some of presentations.
		If Upper(RestrictionName) = Upper("ApplicationName") Then
			RestrictionName = NStr("en = 'Application';");
		ElsIf Upper(RestrictionName) = Upper("TransactionStatus") Then
			RestrictionName = NStr("en = 'Transaction status';");
		ElsIf Upper(RestrictionName) = Upper("DataPresentation") Then
			RestrictionName = NStr("en = 'Data presentation';");
		ElsIf Upper(RestrictionName) = Upper("ServerName") Then
			RestrictionName = NStr("en = 'Production server';");
		ElsIf Upper(RestrictionName) = Upper("PrimaryIPPort") Then
			RestrictionName = NStr("en = 'IP port';");
		ElsIf Upper(RestrictionName) = Upper("SyncPort") Then
			RestrictionName = NStr("en = 'Auxiliary IP port';");
		ElsIf Upper(RestrictionName) = Upper("SessionDataSeparation") Then
			If StandardSeparatorsOnly() Then
				RestrictionName = NStr("en = 'Data area';");
			Else
				RestrictionName = NStr("en = 'Session data separation';");
			EndIf;
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		FilterPresentation = FilterPresentation + RestrictionName;
		
	EndDo;
	
	If IsBlankString(FilterPresentation) Then
		FilterPresentation = NStr("en = 'Not set';");
	EndIf;
	
EndProcedure

// Determines the server time offset relative to the application time.
//
// Returns:
//   Number - time offset, in seconds.
//       Can be used to convert log filters to the server date
//       and also to convert dates obtained from the log to the application dates.
//
Function ServerTimeOffset() Export
	
	ServerTimeOffset = CurrentDate() - CurrentSessionDate(); // ACC:143 - Computer data is required
	If ServerTimeOffset >= -1 And ServerTimeOffset <= 1 Then
		ServerTimeOffset = 0;
	EndIf;
	Return ServerTimeOffset;
	
EndFunction

// Returns the address of the XML file containing the Event log intended for the support.
// Filtered log records in the EventLogFilter parameter align with the UnloadEventLog method.
// If a filter property is missing or set to Undefined, the filter won't apply.
// 
// Parameters:
//  EventLogFilter - Structure:
//   * StartDate - Date
//   * EndDate - Date
//   * Level - EventLogLevel
//   * ApplicationName - String
//                   - Array of String
//                   - ValueList
//   * User - InfoBaseUser
//                  - String
//                  - Array of InfoBaseUser
//                  - ValueList
//   * Computer - String
//               - Array of String
//                - ValueList
//   * Event - String
//             - ValueList
//             - Array of String - See Syntax Assistant for the names of system events.
//   * Metadata - MetadataObject 
//                - Array of MetadataObject
//                - ValueList
//   * Data - AnyRef
//   * DataPresentation - String
//   * Comment - String
//   * TransactionStatus - EventLogEntryTransactionStatus
//   * Transaction - String 
//   * Session - Number
//           - Array of Number
//           - ValueList
//   * ServerName - String
//                   - Array of String
//                   - ValueList
//   * PrimaryIPPort - Number
//                    - Array of Number
//                    - ValueList
//   * SyncPort - Number
//                    - Array of Number
//                    - ValueList
//   * SessionDataSeparation - ValueList - Property names align with common attribute names. 
//                            - Structure
//  EventCount1 - Number
//  UUID - UUID - Intended for creating a temporary storage.
// 
// Returns:
//  String 
//
Function TechnicalSupportLog(EventLogFilter, EventCount1, UUID = Undefined) Export
	
	Filter = New Structure;
	For Each FilterElement In EventLogFilter Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	ServerTimeOffset = ServerTimeOffset();
	FilterTransformation(Filter, ServerTimeOffset);
	
	TempFile = GetTempFileName("xml");
	UnloadEventLog(TempFile, Filter, , , EventCount1);
	BinaryData = New BinaryData(TempFile);
	DeleteFiles(TempFile);
	
	Return PutToTempStorage(BinaryData, UUID);
	
EndFunction

// Returns an infobase user to be passed to the "User" property
// of the Event Log filter.
//
// Parameters:
//  Id - UUID - Infobase user id.
//
// Returns:
//  InfoBaseUser
//  Undefined
//
Function InfobaseUserForFilter(Id) Export
	
	IBUser = InfoBaseUsers.FindByUUID(Id);
	
	If IBUser <> Undefined Then
		Return IBUser;
	EndIf;
	
	Try
		IsEmpty = InfoBaseUsers.FindByName("");
		InfobaseUserString = ValueToStringInternal(IsEmpty);
		InfobaseUserString = StrReplace(InfobaseUserString,
			Lower(IsEmpty.UUID), Lower(Id));
		IBUser = ValueFromStringInternal(InfobaseUserString);
	Except
		IBUser = Undefined;
	EndTry;
	
	Return IBUser;
	
EndFunction

#EndRegion

#Region Private

// Parameters:
//  DataAsStr - String
//
Function EventData(DataAsStr) Export
	
	If Not ValueIsFilled(DataAsStr) Then
		Return Undefined;
	EndIf;
	
	Try
		Result = ValueFromStringInternal(DataAsStr);
	Except
		Result = Undefined;
	EndTry;
	
	Return Result;
	
EndFunction

// Parameters:
//  EventData - String
//
// Returns:
//  Structure - If the conversion is successful.
//  Undefined - If the conversion failed.
//
Function DataFromXMLString(EventData) Export
	
	If TypeOf(EventData) <> Type("String")
	 Or Not StrStartsWith(EventData, "<")
	 Or Not StrEndsWith(EventData, ">") Then
		Return Undefined;
	EndIf;
	
	Try
		Data = Common.ValueFromXMLString(EventData);
	Except
		Data = Undefined;
	EndTry;
	
	If TypeOf(Data) = Type("Structure") Then
		Return Data;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function TableDataPresentation(EventData)
	
	If TypeOf(EventData) <> Type("Structure")
	   And TypeOf(EventData) <> Type("FixedStructure")
	 Or Not EventData.Property("Data")
	 Or TypeOf(EventData.Data) <> Type("ValueTable") Then
		Return "";
	EndIf;
	
	Data = EventData.Data; // ValueTable
	
	RowsCount = Data.Count();
	If RowsCount = 0 Then
		Return "";
	EndIf;
	
	Table = New ValueTable;
	For Each Column In Data.Columns Do
		NewColumn = Table.Columns.Add(Column.Name,
			New TypeDescription("String"), Column.Title);
		If Not ValueIsFilled(NewColumn.Title) Then
			NewColumn.Title = NewColumn.Name;
		EndIf;
	EndDo;
	For Each TableRow In Data Do
		FillPropertyValues(Table.Add(), TableRow);
	EndDo;
	
	Copy = Table.Copy();
	For Each Column In Table.Columns Do
		Copy.Sort(Column.Name);
		Width = StrLen(Copy.Get(RowsCount - 1)[Column.Name]);
		TitleWidth = StrLen(Column.Title);
		Column.Width = ?(Width > TitleWidth, Width, TitleWidth);
	EndDo;
	
	IndentChars = "                                                             ";
	
	Rows = New Array;
	StringParts1 = New Array;
	For Each Column In Table.Columns Do
		StringParts1.Add(Mid(Column.Title + IndentChars, 1, Column.Width));
	EndDo;
	Rows.Add("| " + StrConcat(StringParts1, " | ") + " |");
	
	For Each TableRow In Table Do
		StringParts1 = New Array;
		For Each Column In Table.Columns Do
			StringParts1.Add(Mid(TableRow[Column.Name] + IndentChars, 1, Column.Width));
		EndDo;
		Rows.Add("| " + StrConcat(StringParts1, " | ") + " |");
	EndDo;
	
	Return StrConcat(Rows, Chars.LF);
	
EndFunction

Function StructureDataPresentation(EventData, KeysPresentation, IsDataPropertyExcluded = False)
	
	If TypeOf(EventData) <> Type("Structure")
	   And TypeOf(EventData) <> Type("FixedStructure") Then
		Return "";
	EndIf;
	
	PropertiesToExclude = New Map;
	If IsDataPropertyExcluded Then
		PropertiesToExclude.Insert(Lower("Data"), True);
	EndIf;
	
	EndingPresentation = "";
	
	If EventData.Property("Roles") Then
		PropertyNameAtEnd = Lower("Roles");
	ElsIf EventData.Property("Message") Then
		PropertyNameAtEnd = Lower("Message");
	Else
		PropertyNameAtEnd = "";
	EndIf;
	
	If ValueIsFilled(PropertyNameAtEnd) Then
		PropertiesToExclude.Insert(PropertyNameAtEnd, True);
		
		ValuePresentation = ValuePresentation(PropertyNameAtEnd,
			EventData[PropertyNameAtEnd]);
		
		If ValueIsFilled(ValuePresentation) Then
			KeyPresentation = KeysPresentation.Get(Lower(PropertyNameAtEnd));
			IsKeyPresentationFilled = ValueIsFilled(KeyPresentation);
			If Not IsKeyPresentationFilled Then
				KeyPresentation = PropertyNameAtEnd;
			EndIf;
			
			If StrFind(ValuePresentation, Chars.LF) > 0 Then
				EndingPresentation = KeyPresentation + ":
				|" + ValuePresentation;
			Else
				EndingPresentation = KeyPresentation + ": " + ValuePresentation;
			EndIf;
		EndIf;
	EndIf;
	
	Tree = TreeWithStructureData(EventData,
		KeysPresentation, True, PropertiesToExclude);
	
	Rows = New Array;
	AddTreeRowsPresentations(Rows, Tree.Rows);
	
	If ValueIsFilled(EndingPresentation) Then
		Rows.Add(EndingPresentation);
	EndIf;
	
	Return StrConcat(Rows, Chars.LF);
	
EndFunction

// Intended for function "StructureDataPresentation".
Procedure AddTreeRowsPresentations(Rows, TreeRows, Indent = "")
	
	For Each TreeRow In TreeRows Do
		If TreeRow.ThereIsValue Then
			Rows.Add(Indent + TreeRow.Property + ": " + TreeRow.Value);
		Else
			Rows.Add(Indent + TreeRow.Property);
			AddTreeRowsPresentations(Rows, TreeRow.Rows, Indent + "    ");
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  EventData - Structure, FixedStructure
//  KeysPresentation - See StructuresKeysPresentation
//                      - Undefined - Receive automatically.
//  OnlyFilledValues - Boolean
//  PropertiesToExclude - Map
//                      - Undefined
//
// Returns:
//  ValueTree:
//   * Property - String
//   * Value - String
//   * ThereIsValue - Boolean
//
Function TreeWithStructureData(EventData, KeysPresentation = Undefined,
			OnlyFilledValues = False, PropertiesToExclude = Undefined) Export
	
	If KeysPresentation = Undefined Then
		KeysPresentation = StructuresKeysPresentation();
	EndIf;
	
	Tree = New ValueTree;
	Tree.Columns.Add("Property", New TypeDescription("String"), NStr("en = 'Property';"));
	Tree.Columns.Add("Value", New TypeDescription("String"), NStr("en = 'Value';"));
	Tree.Columns.Add("IsPropertyWithoutPresentation", New TypeDescription("Boolean"));
	Tree.Columns.Add("ThereIsValue", New TypeDescription("Boolean"));
	
	AddPropertiesToTree(Tree.Rows, EventData, KeysPresentation,
		OnlyFilledValues, PropertiesToExclude);
	
	Tree.Columns.Delete("IsPropertyWithoutPresentation");
	
	Return Tree;
	
EndFunction

Procedure AddPropertiesToTree(TreeRows, PropertiesDetails, KeysPresentation,
			OnlyFilledValues, PropertiesToExclude, Val ParentKey = "")
	
	If ParentKey <> "" Then
		ParentKey = ParentKey + ".";
	EndIf;
	
	For Each KeyAndValue In PropertiesDetails Do
		FullKey = ParentKey + KeyAndValue.Key;
		Value = KeyAndValue.Value;
		
		If PropertiesToExclude <> Undefined
		   And PropertiesToExclude.Get(Lower(FullKey)) <> Undefined
		 Or OnlyFilledValues
		   And Not ValueIsFilled(Value)
		   And TypeOf(Value) <> Type("Boolean")
		   And TypeOf(Value) <> Type("Number")
		   And TypeOf(Value) <> Type("Date") Then
			Continue;
		EndIf;
		
		NewRow = TreeRows.Add();
		
		If TypeOf(PropertiesDetails) = Type("Map")
		 Or TypeOf(PropertiesDetails) = Type("FixedMap") Then
			
			NewRow.Property = ValuePresentation("", KeyAndValue.Key);
		Else
			NewRow.Property = KeysPresentation.Get(Lower(KeyAndValue.Key));
			If Not ValueIsFilled(NewRow.Property) Then
				NewRow.Property = KeyAndValue.Key;
				NewRow.IsPropertyWithoutPresentation = True;
			EndIf;
		EndIf;
		
		If TypeOf(Value) = Type("Structure")
		 Or TypeOf(Value) = Type("FixedStructure")
		 Or TypeOf(Value) = Type("Map")
		 Or TypeOf(Value) = Type("FixedMap") Then
			
			AddPropertiesToTree(NewRow.Rows, Value, KeysPresentation,
				OnlyFilledValues, PropertiesToExclude, FullKey);
			
		ElsIf (    TypeOf(Value) = Type("Array")
		           Or TypeOf(Value) = Type("FixedArray"))
		        And Value.Count() > 0
		        And (    TypeOf(Value[0]) = Type("Structure")
		           Or TypeOf(Value[0]) = Type("FixedStructure")
		           Or TypeOf(Value[0]) = Type("Map")
		           Or TypeOf(Value[0]) = Type("FixedMap")) Then
			
			CountOfCharacters = StrLen(XMLString(Value.Count()));
			Number = 1;
			For Each ArrayElement In Value Do
				NewSubstring = NewRow.Rows.Add();
				NewSubstring.Property = Right("         " + XMLString(Number), CountOfCharacters);
				AddPropertiesToTree(NewSubstring.Rows, ArrayElement, KeysPresentation,
					OnlyFilledValues, PropertiesToExclude, FullKey);
				Number = Number + 1;
			EndDo;
		Else
			ValuePresentation = ValuePresentation(FullKey, Value);
			NewRow.Value = ValuePresentation;
			NewRow.ThereIsValue = True;
		EndIf;
		
		If Not OnlyFilledValues Then
			Continue;
		EndIf;
		
		If NewRow.ThereIsValue
		   And Not ValueIsFilled(ValuePresentation)
		 Or Not NewRow.ThereIsValue
		   And Not ValueIsFilled(NewRow.Rows) Then
			
			TreeRows.Delete(NewRow);
		EndIf;
	EndDo;
	
	TreeRows.Sort("IsPropertyWithoutPresentation, Property");
	
EndProcedure

// Parameters:
//   Var_Key - String - Property name
//   Value - Arbitrary
//
// Returns:
//  String
//
Function ValuePresentation(Var_Key, Value)
	
	FormatString = NStr("en = 'NZ=0; DLF=DT; DE=''01.01.0001 00:00:00''';");
	
	If TypeOf(Value) <> Type("Array") Then
		If Upper(Var_Key) = Upper("EventName") And StrStartsWith(Value, "_$") Then
			EventPresentation = EventLogEventPresentation(Value);
			If ValueIsFilled(EventPresentation) Then
				Return EventPresentation;
			EndIf;
		EndIf;
		Return CommonClientServer.ReplaceProhibitedXMLChars(
			Format(Value, FormatString));
	EndIf;
	
	If Upper(Var_Key) = Upper("Roles") Then
		Table = RoleTable(Value);
		Rows = Table.UnloadColumn("Presentation");
		Connector = Chars.LF;
	Else
		Rows = New Array;
		For Each CurrentValue In Value Do
			Rows.Add(CommonClientServer.ReplaceProhibitedXMLChars(
				Format(CurrentValue, FormatString)));
		EndDo;
		Connector = ", ";
	EndIf;
	
	If Rows.Count() = 1 Then
		Return Rows[0];
	EndIf;
	
	Return StrConcat(Rows, Connector);
	
EndFunction

// Parameters:
//  Roles - Array of String
//
// Returns:
//  ValueTable:
//   * Presentation - String
//
Function RoleTable(Roles) Export
	
	IBUserRoles1 = New ValueTable;
	IBUserRoles1.Columns.Add("Exists");
	IBUserRoles1.Columns.Add("Presentation",, NStr("en = 'Presentation';"));
	
	For Each FullNameOfTheRole In Roles Do
		NameParts = StrSplit(FullNameOfTheRole, ".", False);
		If NameParts.Count() = 2 Then
			NameOfRole = NameParts[1];
			RoleMetadata = Metadata.Roles.Find(NameOfRole);
		Else
			NameOfRole = FullNameOfTheRole;
		EndIf;
		NewRow = IBUserRoles1.Add();
		NewRow.Exists = RoleMetadata <> Undefined;
		NewRow.Presentation = ?(RoleMetadata = Undefined,
			NameOfRole, RoleMetadata.Presentation());
	EndDo;
	
	IBUserRoles1.Sort("Exists DESC, Presentation");
	IBUserRoles1.Columns.Delete("Exists");
	
	Return IBUserRoles1;
	
EndFunction

// Returns:
//  Map of KeyAndValue:
//   * Key - String - Lower-case name of a structure key.
//   * Value - String - Key presentation.
//
Function StructuresKeysPresentation()
	
	Result = New Map;
	
	// _$Access$_.*
	Result.Insert(Lower("Right"),
		NStr("en = 'Access right';"));
	
	Result.Insert(Lower("Action"),
		NStr("en = 'Action';"));
	
	// _$Debug$_.*
	Result.Insert(Lower("DebuggingServerUser"),
		NStr("en = 'Debug server user';"));
	
	Result.Insert(Lower("DebugItemType"),
		NStr("en = 'Debug item type';"));
	
	Result.Insert(Lower("Expression"),
		NStr("en = 'Expression';"));
	
	// _$InfoBase$_.AdditionalAuthenticationSettingsUpdate
	Result.Insert(Lower("PasswordRecoveryMethod"),
		NStr("en = 'Password recovery method';"));
	
	Result.Insert(Lower("PasswordRecoveryURL"),
		NStr("en = 'Password recovery URL';"));
	
	Result.Insert(Lower("HelpURL"),
		NStr("en = 'Help URL';"));
	
	Result.Insert(Lower("ShowHelpHyperlink"),
		NStr("en = 'Show Help URL';"));
	
	Result.Insert(Lower("VerificationCodeLength"),
		NStr("en = 'Confirmation code length';"));
	
	Result.Insert(Lower("MaxUnsuccessfulVerificationCodeValidationAttemptsCount"),
		NStr("en = 'Limit for unsuccessful code entries';"));
	
	Result.Insert(Lower("VerificationCodeRefreshRequestLockDuration"),
		NStr("en = 'Confirmation code cooldown time';"));
	
	Result.Insert(Lower("SMTPServerAddress"),
		NStr("en = 'SMTP server address';"));
	
	Result.Insert(Lower("SMTPUser"),
		NStr("en = 'SMTP user';"));
	
	Result.Insert(Lower("SMTPPasswordChanged"),
		NStr("en = 'SMTP password changed';"));
	
	Result.Insert(Lower("SMTPPort"),
		NStr("en = 'SMTP port';"));
	
	Result.Insert(Lower("SenderName"),
		NStr("en = 'Sender name';"));
	
	Result.Insert(Lower("Title"),
		NStr("en = 'Header';"));
	
	Result.Insert(Lower("HTMLMessageText"),
		NStr("en = 'HTML message body';"));
	
	Result.Insert(Lower("UseSSL"),
		NStr("en = 'SSL user';"));
	
	Result.Insert(Lower("AllowSaveCredentialsForReAuthentication"),
		NStr("en = 'Allow save credentials for auto-login';"));
	
	Result.Insert(Lower("SaveCredentialsForReAuthenticationByDefault"),
		NStr("en = 'Save credentials for auto-login by default';"));
	
	Result.Insert(Lower("SavedCredentialsLifetime"),
		NStr("en = 'Credentials lifetime';"));
	
	// _$InfoBase$_.AdministrationParametersChange
	Result.Insert(Lower("LockScheduledJobs"),
		NStr("en = 'Scheduled job lock';"));
	
	Result.Insert(Lower("SessionsLockEnabled"),
		NStr("en = 'Session startup lock enabled';"));
	
	Result.Insert(Lower("LockBeginTime"),
		NStr("en = 'Lock start time';"));
	
	Result.Insert(Lower("LockEndTime"),
		NStr("en = 'Lock end time';"));
	
	Result.Insert(Lower("DelayConfigurationExportByWorkProcessWithoutActiveUsers"),
		NStr("en = 'Delay for importing configuration by an idle process';"));
	
	Result.Insert(Lower("RestrictLocalSpeechRecognition"),
		NStr("en = 'Restrict local speech recognition';"));
	
	Result.Insert(Lower("InfoBaseID"),
		NStr("en = 'Infobase ID';"));
	
	Result.Insert(Lower("DataBaseName"),
		NStr("en = 'Database name';"));
	
	Result.Insert(Lower("SessionStartPermissionCode"),
		NStr("en = 'Access code for session startup';"));
	
	Result.Insert(Lower("MaxStartupShiftForScheduledJobsWithoutActiveUsers"),
		NStr("en = 'Maximum startup offset for idle scheduled jobs';"));
	
	Result.Insert(Lower("MaxRuntimeForScheduledJobsWithoutActiveUsers"),
		NStr("en = 'Minimal startup period for idle scheduled jobs';"));
	
	Result.Insert(Lower("ExternalSessionManagementRequired"),
		NStr("en = 'Mandatory external session management';"));
	
	Result.Insert(Lower("LongDesc"),
		NStr("en = 'Details';"));
	
	Result.Insert(Lower("LockParameter"),
		NStr("en = 'Lock parameter';"));
	
	Result.Insert(Lower("DatabaseUserPassword"),
		NStr("en = 'Database user password';"));
	
	Result.Insert(Lower("DatabaseUser"),
		NStr("en = 'Database user';"));
	
	Result.Insert(Lower("SafeModeSecurityProfile"),
		NStr("en = 'Safe mode security profile';"));
	
	Result.Insert(Lower("AllowLicenseDistribution"),
		NStr("en = 'Allow issuing licenses';"));
	
	Result.Insert(Lower("ReserveWorkingProcesses"),
		NStr("en = 'Working process reservation';"));
	
	Result.Insert(Lower("DataBaseServer"),
		NStr("en = 'Database server';"));
	
	Result.Insert(Lower("DateOffset"),
		NStr("en = 'Dates offset';"));
	
	Result.Insert(Lower("CreateDatabase"),
		NStr("en = 'Create database';"));
	
	Result.Insert(Lower("LockMessage"),
		NStr("en = 'Lock message';"));
	
	Result.Insert(Lower("ExternalSessionManagementConnectionString"),
		NStr("en = 'String of external session management parameters';"));
	
	Result.Insert(Lower("DBMS"),
		NStr("en = 'DBMS';"));
	
	Result.Insert(Lower("ConnectionsSecurityLevel"),
		NStr("en = 'Connection security level';"));
	
	// _$InfoBase$_.ConfigUpdate*
	Result.Insert(Lower("Vendor"),
		NStr("en = 'Vendor';"));
	
	// _$InfoBase$_.ConfigExtensionUpdate
	Result.Insert(Lower("Version"),
		NStr("en = 'Version';"));
	
	// _$InfoBase$_.DBConfigUpdate
	Result.Insert(Lower("ExclusiveMode"),
		NStr("en = 'Exclusive mode';"));
	
	// _$InfoBase$_.DBConfigExtension*
	Result.Insert(Lower("Active"),
		NStr("en = 'Active';"));
	
	Result.Insert(Lower("SafeMode"),
		NStr("en = 'Safe mode';"));
	
	Result.Insert(Lower("SecurityProfile"),
		NStr("en = 'Security profile';"));
	
	Result.Insert(Lower("UseDefaultRolesForAllUsers"),
		NStr("en = 'Use main roles for all users';"));
	
	Result.Insert(Lower("UsedInDistributedInfoBase"),
		NStr("en = 'Used in a distributed infobase';"));
	
	Result.Insert(Lower("Purpose"),
		NStr("en = 'Used on';"));
	
	Result.Insert(Lower("Scope"),
		NStr("en = 'Scope';"));
	
	Result.Insert(Lower("DefaultRoles"),
		NStr("en = 'Default roles';"));
	
	Result.Insert(Lower("Synonym"),
		NStr("en = 'Synonym';"));
	
	Result.Insert(Lower("UUID"),
		NStr("en = 'UUID';"));
	
	Result.Insert(Lower("HashSum"),
		NStr("en = 'Hash';"));
	
	// _$InfoBase$_.EventLogReduce
	Result.Insert(Lower("Date"),
		NStr("en = 'Date';"));
	
	// _$InfoBase$_.EventLogSettingsUpdateError
	Result.Insert(Lower("Levels"),
		NStr("en = 'Levels';"));
	
	Result.Insert(Lower("SeparationPeriod"),
		NStr("en = 'Separation period';"));
	
	Result.Insert(Lower("EventLogFormat"),
		NStr("en = 'Event log format';"));
	
	Result.Insert(Lower("EventName"),
		NStr("en = 'Event name';"));
	
	Result.Insert(Lower("RegistrableEvent"),
		NStr("en = 'Event loggable';"));
	
	// _$InfoBase$_.ExclusiveModeChange
	Result.Insert(Lower("AllowTerminationAtSessionStart"),
		NStr("en = 'Allow exit on startup';"));
	
	// _$InfoBase$_.ParametersUpdate
	Result.Insert(Lower("DataLockTimeout"),
		NStr("en = 'Data lock wait time';"));
	
	Result.Insert(Lower("UserPasswordsMaxLifetime"),
		NStr("en = 'Maximum password lifetime';"));
	
	Result.Insert(Lower("UserPasswordsMinLifetime"),
		NStr("en = 'Minimum password lifetime';"));
	
	Result.Insert(Lower("UserPasswordsMinLength"),
		NStr("en = 'Minimum password length';"));
	
	Result.Insert(Lower("UserPasswordReuseLimit"),
		NStr("en = 'Prevent re-use of recent passwords';"));
	
	Result.Insert(Lower("UserPasswordComplexityCheck"),
		NStr("en = 'Password complexity check';"));
	
	Result.Insert(Lower("UserPasswordExpirationNotificationPeriod"),
		NStr("en = 'Password expiration notification lead';"));
	
	Result.Insert(Lower("PassiveSessionHibernateTime"),
		NStr("en = 'Idle session sleep timeout';"));
	
	Result.Insert(Lower("HibernateSessionTerminateTime"),
		NStr("en = 'Sleeping session termination timeout';"));
	
	Result.Insert(Lower("InactiveSessionTerminationTime"),
		NStr("en = 'Inactive session termination timeout';"));
	
	Result.Insert(Lower("NotificationLeadTimeBeforeInactiveSessionTermination"),
		NStr("en = 'Lead time for inactive session termination notification';"));
	
	Result.Insert(Lower("TotalRecalcJobCount"),
		NStr("en = 'Number of totals recalculation tasks';"));
	
	Result.Insert(Lower("MaxUnsuccessfulAttemptsCount"),
		NStr("en = 'Limit of unsuccessful attempts';"));
	
	Result.Insert(Lower("LockDuration"),
		NStr("en = 'Lock duration';"));
	
	Result.Insert(Lower("UserNameAdditionCodes"),
		NStr("en = 'Username addition codes';"));
	
	// _$InfoBase$_.RegionalSettingsChange
	Result.Insert(Lower("UseCurrentSessionSettings"),
		NStr("en = 'Use current session settings';"));
	
	Result.Insert(Lower("LocalizationCode"),
		NStr("en = 'Localization code';"));
	
	Result.Insert(Lower("FirstDayOfWeek"),
		NStr("en = 'First day of the week';"));
	
	Result.Insert(Lower("BooleanTruePresentation"),
		NStr("en = 'Logical ""True"" presentation';"));
	
	Result.Insert(Lower("BooleanFalsePresentation"),
		NStr("en = 'Logical ""False"" presentation';"));
	
	Result.Insert(Lower("NegativeNumberPresentation"),
		NStr("en = 'Negative numbers presentation';"));
	
	Result.Insert(Lower("NumbersDigitGroupSeparator"),
		NStr("en = 'Digit grouping separator';"));
	
	Result.Insert(Lower("NumbersDecimalSeparator"),
		NStr("en = 'Decimal separator';"));
	
	Result.Insert(Lower("NumbersDigitGroupFormat"),
		NStr("en = 'Digit grouping format';"));
	
	Result.Insert(Lower("TimePresentationFormat"),
		NStr("en = 'Time format';"));
	
	Result.Insert(Lower("DatePresentationFormat"),
		NStr("en = 'Date format';"));
	
	// _$InfoBase$_.RoleUpdate
	Result.Insert(Lower("Rights"),
		NStr("en = 'Access rights';"));
	
	Result.Insert(Lower("AccessEnabled"),
		NStr("en = 'Access granted';"));
	
	Result.Insert(Lower("AccessDisabled"),
		NStr("en = 'Access denied';"));
	
	Result.Insert(Lower("Restrictions"),
		NStr("en = 'Restrictions';"));
	
	Result.Insert(Lower("RestrictionTemplates"),
		NStr("en = 'Restriction templates';"));
	
	Result.Insert(Lower("ItemsAdded"),
		NStr("en = 'Added';"));
	
	Result.Insert(Lower("ItemsChanged"),
		NStr("en = 'Modified';"));
	
	Result.Insert(Lower("ItemsDeleted"),
		NStr("en = 'Deleted';"));
	
	Result.Insert(Lower("Description"),
		NStr("en = 'Description';"));
	
	Result.Insert(Lower("TemplateText"),
		NStr("en = 'Template text';"));
	
	// _$InfoBase$_.SecurityProfileChange
	Result.Insert(Lower("ClusterAdmin"),
		NStr("en = 'Cluster administrator';"));
	
	Result.Insert(Lower("CryptoAvailable"),
		NStr("en = 'Access to cryptography';"));
	
	Result.Insert(Lower("ModulesAvailableForExtension"),
		NStr("en = 'Extensible modules';"));
	
	Result.Insert(Lower("ModulesNotAvailableForExtension"),
		NStr("en = 'Non-extensible modules';"));
	
	Result.Insert(Lower("COMObjectFullAccess"),
		NStr("en = 'Full access to COM objects';"));
	
	Result.Insert(Lower("AddInFullAccess"),
		NStr("en = 'Full access to add-ins';"));
	
	Result.Insert(Lower("ExternalModuleFullAccess"),
		NStr("en = 'Full access to external modules';"));
	
	Result.Insert(Lower("ExternalApplicationsFullAccess"),
		NStr("en = 'Unlimited access to external apps';"));
	
	Result.Insert(Lower("InternetResourcesFullAccess"),
		NStr("en = 'Full access to online resources';"));
	
	Result.Insert(Lower("FileSystemFullAccess"),
		NStr("en = 'Full access to file system';"));
	
	Result.Insert(Lower("FullPrivilegedMode"),
		NStr("en = 'Unlimited privileged mode';"));
	
	Result.Insert(Lower("SafeModeProfile"),
		NStr("en = 'Security mode profile';"));
	
	Result.Insert(Lower("AllowExternalCodeExecutionInUnsafeMode"),
		NStr("en = 'Allow executing external code in unsafe mode';"));
	
	Result.Insert(Lower("AllowAccessRightsExtension"),
		NStr("en = 'Allow extension of access rights';"));
	
	Result.Insert(Lower("AccessRightsExtensionLimitingRoles"),
		NStr("en = 'Roles that restrict extension of access rights';"));
	
	Result.Insert(Lower("PrivilegedModeRoles"),
		NStr("en = 'Privileged mode roles';"));
	
	Result.Insert(Lower("AllowedCOMClasses"),
		NStr("en = 'Allowed COM classes';"));
	
	Result.Insert(Lower("AllowedVirtualDirs"),
		NStr("en = 'Allowed virtual directories';"));
	
	Result.Insert(Lower("WritingAllowed"),
		NStr("en = 'Writing is allowed';"));
	
	Result.Insert(Lower("Alias"),
		NStr("en = 'Alias';"));
	
	Result.Insert(Lower("ReadingAllowed"),
		NStr("en = 'Reading is allowed';"));
	
	Result.Insert(Lower("AllowedAddIns"),
		NStr("en = 'Allowed add-ins';"));
	
	Result.Insert(Lower("AllowedExternalModules"),
		NStr("en = 'Allowed external modules';"));
	
	Result.Insert(Lower("AllowedExternalApps"),
		NStr("en = 'Allowed external apps';"));
	
	Result.Insert(Lower("AllowedInternetResources"),
		NStr("en = 'Allowed internet resources';"));
	
	Result.Insert(Lower("Address"),
		NStr("en = 'Address';"));
	
	Result.Insert(Lower("Port"),
		NStr("en = 'Port';"));
	
	Result.Insert(Lower("Protocol"),
		NStr("en = 'Protocol';"));
	
	Result.Insert(Lower("PrivilegedModeAllowed"),
		NStr("en = 'Allow setting privileged mode';"));
	
	// _$InfoBase$_.SessionLockChange*
	Result.Insert(Lower("KeyCode"),
		NStr("en = 'Access code';"));
	
	Result.Insert(Lower("End"),
		NStr("en = 'End';"));
	
	Result.Insert(Lower("Parameter"),
		NStr("en = 'Parameter';"));
	
	Result.Insert(Lower("Message"),
		NStr("en = 'Message';"));
	
	Result.Insert(Lower("Use"),
		NStr("en = 'Set';"));
	
	// _$InfoBase$_.UserPasswordPolicy*
	Result.Insert(Lower("PasswordMaxEffectivePeriod"),
		NStr("en = 'Maximum password lifetime';"));
	
	Result.Insert(Lower("PasswordMinEffectivePeriod"),
		NStr("en = 'Minimum password lifetime';"));
	
	Result.Insert(Lower("PasswordMinLength"),
		NStr("en = 'Minimum password length';"));
	
	Result.Insert(Lower("PasswordReuseLimit"),
		NStr("en = 'Prevent re-use of recent passwords';"));
	
	Result.Insert(Lower("PasswordStrengthCheck"),
		NStr("en = 'Password complexity check';"));
	
	Result.Insert(Lower("PasswordExpirationNotificationPeriod"),
		NStr("en = 'Password expiration notification lead';"));
	
	Result.Insert(Lower("ActionUponAuthenticationIfPasswordsNonCompliant"),
		NStr("en = 'Action if password doesn''t meet requirements';"));
	
	Result.Insert(Lower("PasswordCompromiseCheck"),
		NStr("en = 'Leaked password check';"));
	
	// _$OpenIDProvider$_.*
	Result.Insert(Lower("RelyingPartyURL"),
		NStr("en = 'Relying party URL';"));
	
	// _$Session$_.Authentication*
	Result.Insert(Lower("CurrentOSUser"),
		NStr("en = 'Current OS user';"));
	
	Result.Insert(Lower("AuthenticationMethod"),
		NStr("en = 'Authentication method';"));
	
	Result.Insert(Lower("UsernameAdditionCode"),
		NStr("en = 'Username addition code';"));
	
	Result.Insert(Lower("UserIDAtOpenIDProvider"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 provider user ID';"), "OpenID"));
	
	Result.Insert(Lower("IssuerOfAccessToken"),
		NStr("en = 'Access token emitter';"));
	
	Result.Insert(Lower("AccessTokenID"),
		NStr("en = 'Access token ID';"));
	
	Result.Insert(Lower("OpenIDProviderURL"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 provider URL';"), "OpenID"));
	
	// _$Session$_.ExternalDataProcessorConnect*
	Result.Insert(Lower("Path"),
		NStr("en = 'Path';"));
	
	Result.Insert(Lower("LanguageCode"),
		NStr("en = 'Language code';"));
	
	// _$Session$_.AddInAttach*
	Result.Insert(Lower("Location"),
		NStr("en = 'Location';"));
	
	Result.Insert(Lower("Type"),
		NStr("en = 'Type';"));
	
	Result.Insert(Lower("AttachmentType"),
		NStr("en = 'Connection type';"));
	
	// _$User$_.*
	Result.Insert(Lower("Email"),
		NStr("en = 'Email address';"));
	
	Result.Insert(Lower("OpenIDAuthentication"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 authentication';"), "OpenID"));
	
	Result.Insert(Lower("OpenIDConnectAuthentication"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 authentication';"), "OpenID-Connect"));
	
	Result.Insert(Lower("QRCodeAuthentication"),
		NStr("en = 'QR code authentication';"));
	
	Result.Insert(Lower("OSAuthentication"),
		NStr("en = 'OS authentication';"));
	
	Result.Insert(Lower("StandardAuthentication"),
		NStr("en = '1C:Enterprise authentication';"));
	
	Result.Insert(Lower("AccessTokenAuthentication"),
		NStr("en = 'Access token authentication';"));
	
	Result.Insert(Lower("PasswordSettingDate"),
		NStr("en = 'Password set date';"));
	
	Result.Insert(Lower("CannotRecoveryPassword"),
		NStr("en = 'User cannot recover password';"));
	
	Result.Insert(Lower("CannotChangePassword"),
		NStr("en = 'User cannot change password';"));
	
	Result.Insert(Lower("UnsafeActionProtection"),
		NStr("en = 'Unsafe action protection';"));
	
	Result.Insert(Lower("Name"),
		NStr("en = 'Name';"));
	
	Result.Insert(Lower("PasswordPolicyName"),
		NStr("en = 'Password policy name';"));
	
	Result.Insert(Lower("UserMapKeys"),
		NStr("en = 'User map keys';"));
	
	Result.Insert(Lower("SecondAuthenticationFactorSettings"),
		NStr("en = 'Second authentication factor settings';"));
	
	Result.Insert(Lower("SecondAuthenticationFactorSettingsProcessing"),
		NStr("en = 'Second authentication factor settings processing';"));
	
	Result.Insert(Lower("PasswordChanged"),
		NStr("en = 'Password is changed';"));
	
	Result.Insert(Lower("PasswordNonCompliant"),
		NStr("en = 'Password does not meet requirements';"));
	
	Result.Insert(Lower("PasswordIsSet"),
		NStr("en = 'Password is set';"));
	
	Result.Insert(Lower("ShowInList"),
		NStr("en = 'Show in list';"));
	
	Result.Insert(Lower("FullName"),
		NStr("en = 'Full name';"));
	
	Result.Insert(Lower("OSUser"),
		NStr("en = 'OS user';"));
	
	Result.Insert(Lower("RunMode"),
		NStr("en = 'Run mode';"));
	
	Result.Insert(Lower("DefaultInterface"),
		NStr("en = 'Main interface';"));
	
	Result.Insert(Lower("Roles"),
		NStr("en = 'Roles';"));
	
	Result.Insert(Lower("PasswordHashAlgorithmType"),
		NStr("en = 'Password hashing algorithm type';"));
	
	Result.Insert(Lower("Language"),
		NStr("en = 'Language';"));
	
	Result.Insert(Lower("Users"),
		NStr("en = 'Users';"));
	
	Result.Insert(Lower("DataSeparation"),
		NStr("en = 'Data separation';"));
	
	Return Result;
	
EndFunction

// Returns:
//  Boolean
//
Function StandardSeparatorsOnly() Export
	
	If Not Common.SubsystemExists(
			"StandardSubsystems.SaaSOperations.CoreSaaS") Then
		Return False;
	EndIf;
	
	ModuleSaaSSSL = Common.CommonModule("SaaSOperationsSSL");
	
	Return ModuleSaaSSSL.StandardSeparatorsOnly();
	
EndFunction

Function StringDelimitersList(SeparatorLine) Export
	
	List = New ValueList;
	Values = StrSplit(SeparatorLine, ",");
	List.LoadValues(Values);
	
	ListItem = List.FindByValue("");
	If ListItem <> Undefined Then
		ListItem.Presentation = NStr("en = '<Not set>';");
	EndIf;
	
	Return List;
	
EndFunction

// Filter transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//
Procedure FilterTransformation(Filter, ServerTimeOffset)
	
	For Each FilterElement In Filter Do
		If TypeOf(FilterElement.Value) = Type("ValueList") Then
			FilterItemTransform(Filter, FilterElement);
		ElsIf Upper(FilterElement.Key) = Upper("Transaction") Then
			If StrFind(FilterElement.Value, "(") = 0 Then
				Filter.Insert(FilterElement.Key, "(" + FilterElement.Value);
			EndIf;
		ElsIf ServerTimeOffset <> 0
			And (Upper(FilterElement.Key) = Upper("StartDate") Or Upper(FilterElement.Key) = Upper("EndDate")) Then
			Filter.Insert(FilterElement.Key, FilterElement.Value + ServerTimeOffset);
		EndIf;
	EndDo;
	
EndProcedure

// Filter item transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//  Filter - FilterElement - an item of the filter to be passed.
//
Procedure FilterItemTransform(Filter, FilterElement)
	
	FilterStructureKey = FilterElement.Key;
	// The procedure is called when the filter item is a value list
	// (the filter should take an array). Convert the list into an array.
	If Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
		NewValue = New Structure;
	Else
		NewValue = New Array;
	EndIf;
	
	FilterStructureKey = FilterElement.Key;
	
	For Each ValueFromList In FilterElement.Value Do
		If Upper(FilterStructureKey) = Upper("Level") Then
			// Message text level is a string, it must be converted into an enumeration.
			NewValue.Add(DataProcessors.EventLog.EventLogLevelValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("TransactionStatus") Then
			// Transaction status is a string, it must be converted into an enumeration.
			NewValue.Add(DataProcessors.EventLog.EventLogEntryTransactionStatusValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
			SeparatorValueArray = New Array;
			FilterStructureKey = "SessionDataSeparation";
			DataSeparationArray = StrSplit(ValueFromList.Value, "=", True);
			
			SeparatorValues = StrSplit(DataSeparationArray[1], ",", True);
			For Each SeparatorValue In SeparatorValues Do
				If Not ValueIsFilled(SeparatorValue) Then
					SeparatorValue = Undefined;
				Else
					SeparatorValue = Number(SeparatorValue);
				EndIf;
				SeparatorFilterItem = New Structure("Value, Use",
					SeparatorValue, SeparatorValue <> Undefined);
				SeparatorValueArray.Add(SeparatorFilterItem);
			EndDo;
			
			NewValue.Insert(DataSeparationArray[0], SeparatorValueArray);
			
		ElsIf Upper(FilterStructureKey) = Upper("User") Then
			If StringFunctionsClientServer.IsUUID(ValueFromList.Value) Then
				IBUserID = New UUID(ValueFromList.Value);
				SetPrivilegedMode(True);
				IBUser = InfobaseUserForFilter(IBUserID);
				SetPrivilegedMode(False);
			Else
				IBUser = Undefined;
			EndIf;
			If IBUser = Undefined Then
				NewValue.Add(ValueFromList.Presentation);
			Else
				NewValue.Add(IBUser);
			EndIf;
			
		ElsIf Upper(FilterStructureKey) = Upper("Data") Then
			Value = ValueFromList.Value;
			If Common.IsReference(TypeOf(Value)) Then
				NewValue.Add(ValueToStringInternal(Value));
			ElsIf ValueIsFilled(ValueFromList.Presentation) Then
				EventData = EventData(ValueFromList.Value);
				If EventData <> Undefined Then
					Value = EventData;
				EndIf;
			EndIf;
			NewValue.Add(Value);
		Else
			NewValue.Add(ValueFromList.Value);
		EndIf;
	EndDo;
	
	If TypeOf(NewValue) = Type("Array") And NewValue.Count() = 1 Then
		NewValue = NewValue[0];
	EndIf;
	
	Filter.Insert(FilterElement.Key, NewValue);
	
EndProcedure

// Adds a restriction to the filter presentation.
//
// Parameters:
//  EventLogFilter - Filter - the event log filter.
//  FilterPresentation - String - filter presentation.
//  RestrictionName - String - the name of the restriction.
//  DefaultEventLogFilter - Filter - the default event log filter.
//
Procedure AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, RestrictionName,
	DefaultEventLogFilter = Undefined)
	
	If Not EventLogFilter.Property(RestrictionName) Then
		Return;
	EndIf;
	
	RestrictionList = EventLogFilter[RestrictionName];
	Restriction       = "";
	
	// If filter value is a default value there is no need to get a presentation of it.
	If DefaultEventLogFilter <> Undefined Then
		DefaultRestrictionList = "";
		If DefaultEventLogFilter.Property(RestrictionName, DefaultRestrictionList) Then
			If ValueToStringInternal(DefaultRestrictionList) = ValueToStringInternal(RestrictionList) Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	If RestrictionName = "Event" And RestrictionList.Count() > 5 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Events (%1)';"), RestrictionList.Count());
		
	ElsIf RestrictionName = "Session" And RestrictionList.Count() > 3 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Sessions (%1)';"), RestrictionList.Count());
		
	Else
		
		For Each ListItem In RestrictionList Do
			If Not IsBlankString(Restriction) Then
				Restriction = Restriction + ", ";
			EndIf;
			
			If Not ValueIsFilled(ListItem.Presentation) Then
				RestrictionValue = ListItem.Value;
			Else
				RestrictionValue = ListItem.Presentation;
			EndIf;
			
			If (Upper(RestrictionName) = Upper("Session")
				Or Upper(RestrictionName) = Upper("Level"))
				And IsBlankString(Restriction) Then
				
				If RestrictionName = "Session" Then
					RestrictionPresentation = NStr("en = 'Session';");
				Else
					RestrictionPresentation = NStr("en = 'Level';");
				EndIf;
				
				Restriction = NStr("en = '%1: %2';");
				Restriction = StringFunctionsClientServer.SubstituteParametersToString(Restriction, RestrictionPresentation, RestrictionValue);
			Else
				Restriction = Restriction + RestrictionValue;
			EndIf;
		EndDo;
		
	EndIf;
	
	If Not IsBlankString(FilterPresentation) Then 
		FilterPresentation = FilterPresentation + "; ";
	EndIf;
	
	FilterPresentation = FilterPresentation + Restriction;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For internal use only.
//
Procedure SetDataString(LogEvent)
	
	DataAsStr = ValueToStringInternal(LogEvent.Data);
	RefinedString = CommonClientServer.ReplaceProhibitedXMLChars(DataAsStr);
	
	If DataAsStr <> RefinedString Then
		Try
			ValueFromStringInternal(RefinedString);
			DataAsStr = RefinedString;
		Except
			DataAsStr = "";
		EndTry;
	EndIf;
	
	LogEvent.DataAsStr = DataAsStr;
	
EndProcedure

Function EventLevelByPresentation(LevelPresentation)
	If LevelPresentation = "Information" Then
		Return EventLogLevel.Information;
	ElsIf LevelPresentation = "Error" Then
		Return EventLogLevel.Error;
	ElsIf LevelPresentation = "Warning" Then
		Return EventLogLevel.Warning; 
	ElsIf LevelPresentation = "Note" Then
		Return EventLogLevel.Note;
	EndIf;	
EndFunction

#EndRegion
