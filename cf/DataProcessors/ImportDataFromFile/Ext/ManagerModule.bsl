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

// Reports the details required for importing data from a file for an external data processor.
//
// Parameters: 
//    CommandName - String - Command name (ID).
//    DataProcessorRef - AnyRef - a link to the data processor.
//    ImportParameters - Structure:
//     * Presentation                           - String - a presentation in the list of import options.
//     * DataStructureTemplateName                      - String - a template name with data structure (optional
//                                                          parameter, default value is ImportDataFromFile).
//     * RequiredTemplateColumns               - Array - contains the list of required fields.
//     * TitleMappingColumns            - String - Mapping column presentation in the data mapping
//                                                           table header (an optional parameter, its default
//                                                           value is formed as follows: "Catalog: <catalog
//                                                           synonym>").
//     * ObjectName                               - String - the Object name.
//
Procedure ParametersOfImportFromFileExternalDataProcessor(CommandName, DataProcessorRef, ImportParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(DataProcessorRef);
		ExternalObject.DefineParametersForLoadingDataFromFile(CommandName, ImportParameters);
		ImportParameters.Insert("Template", ExternalObject.GetTemplate(ImportParameters.DataStructureTemplateName));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Reports the details required for importing data from a file into the Tabular section.
Function FileToTSImportParameters(TabularSectionName, AdditionalParameters)
	
	DefaultParameters= New Structure;
	DefaultParameters.Insert("RequiredColumns2", New Array);
	DefaultParameters.Insert("DataStructureTemplateName", "LoadingFromFile");
	DefaultParameters.Insert("TabularSectionName", TabularSectionName);
	DefaultParameters.Insert("ColumnDataType", New Map);
	DefaultParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	Return DefaultParameters;
	
EndFunction

Procedure CreateCatalogsListForImport(CatalogsListForImport) Export

	CatalogsToImport = CatalogsInformation();
	FunctionalOptions = StandardSubsystemsCached.ObjectsEnabledByOption();
	
	For Each MetadataObjectForOutput In Metadata.Catalogs Do
		
		FullName = MetadataObjectForOutput.FullName();
		If FunctionalOptions.Get(FullName) = False Then
			Continue;
		EndIf;
	
		If CanImportDataFromFile(MetadataObjectForOutput) Then
			
			CatalogInformation = CatalogsToImport.Add();
			CatalogInformation.Presentation = MetadataObjectForOutput.Presentation();
			CatalogInformation.FullName     = FullName;
			
		EndIf;
		
	EndDo;
	
	SSLSubsystemsIntegration.OnDefineCatalogsForDataImport(CatalogsToImport);
	ImportDataFromFileOverridable.OnDefineCatalogsForDataImport(CatalogsToImport);
	
	CatalogsInformation = ExtendedCatalogsInformation();
	
	For Each CatalogInformation In CatalogsToImport Do
		
		TableRow = CatalogsInformation.Find(CatalogInformation.FullName, "FullName");
		If TableRow = Undefined Then
			
			TableRow = CatalogsInformation.Add();
			TableRow.FullName      = CatalogInformation.FullName;
			
			TableRowFromPresentation = CatalogsInformation.Find(CatalogInformation.Presentation, "Presentation");
			If TableRowFromPresentation <> Undefined Then
				TableRowFromPresentation.Presentation = TableRowFromPresentation.Presentation + " (" + TableRowFromPresentation.FullName + ")";
				TableRow.Presentation                = CatalogInformation.Presentation + " (" + CatalogInformation.FullName + ")";
			Else
				TableRow.Presentation                = CatalogInformation.Presentation;
			EndIf;
			
		ElsIf TableRow.AppliedImport Then
			Continue;
		EndIf;
		
		TableRow.AppliedImport = CatalogInformation.AppliedImport; 
		
		ImportTypeInformation     = NewInfoOnImportType();
		ImportTypeInformation.Type = ?(CatalogInformation.AppliedImport, "AppliedImport", "UniversalImport");
		ImportTypeInformation.Insert("FullMetadataObjectName", CatalogInformation.FullName);
		TableRow.ImportTypeInformation = ImportTypeInformation;
		
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		Query = ModuleAdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(Enums["AdditionalReportsAndDataProcessorsKinds"].AdditionalDataProcessor,
			Undefined, False, Enums["AdditionalDataProcessorsCallMethods"].ImportDataFromFile);
		CommandsTable = Query.Execute().Unload(); // See AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands
		
		For Each TableRow In CommandsTable Do
			
			ImportTypeInformation = NewInfoOnImportType();
			ImportTypeInformation.Type = "ExternalImport";
			ImportTypeInformation.FullMetadataObjectName  = TableRow.Modifier;
			ImportTypeInformation.Ref = TableRow.Ref;
			ImportTypeInformation.Id = TableRow.Id;
			ImportTypeInformation.Presentation = TableRow.Presentation;
			
			CatalogInformation = CatalogsInformation.Add();
			CatalogInformation.FullName = MetadataObjectForOutput.FullName();
			CatalogInformation.ImportTypeInformation = ImportTypeInformation;
			CatalogInformation.Presentation = TableRow.Presentation;
		EndDo;
	EndIf;
	
	CatalogsListForImport.Clear();
	For Each CatalogInformation In CatalogsInformation Do 
		
		Presentation = "";
		If CatalogInformation.AppliedImport And IsBlankString(CatalogInformation.Presentation) Then
			Presentation = CatalogPresentation(CatalogInformation.FullName);
		EndIf;
				
		If IsBlankString(Presentation) Then
			Presentation = CatalogInformation.Presentation;
		EndIf;
		
		If IsBlankString(CatalogInformation.ImportTypeInformation.Presentation) Then
			CatalogInformation.ImportTypeInformation.Presentation = Presentation;
		EndIf;
		
		CatalogsListForImport.Add(CatalogInformation.ImportTypeInformation, Presentation);
		
	EndDo;
		
	CatalogsListForImport.SortByPresentation();
	
EndProcedure 

// Returns:
//  ValueTable:
//   * FullName          - String
//   * Presentation      - String
//   * AppliedImport - Boolean
// 
Function CatalogsInformation()
	
	StringType = New TypeDescription("String");
	
	Result = New ValueTable;
	Result.Columns.Add("FullName",          StringType);
	Result.Columns.Add("Presentation",      StringType);
	Result.Columns.Add("AppliedImport", New TypeDescription("Boolean"));
	
	Return Result;
	
EndFunction

// Returns:
//  ValueTable:
//   * FullName               - String
//   * Presentation           - String
//   * AppliedImport      - Boolean
//   * ImportTypeInformation - Structure
// 
Function ExtendedCatalogsInformation()
	
	StructureType = New TypeDescription("Structure");
	
	Result = CatalogsInformation();
	Result.Columns.Add("ImportTypeInformation", StructureType);
	
	Return Result;
	
EndFunction


// Returns:
//  Structure:
//   * Type - String
//   * FullMetadataObjectName - String 
//   * Ref - Undefined, CatalogRef
//   * Id - String 
//   * Presentation - String
// 
Function NewInfoOnImportType() Export
	
	ImportTypeInformation = New Structure;
	ImportTypeInformation.Insert("Type",                        "");
	ImportTypeInformation.Insert("FullMetadataObjectName", "");
	ImportTypeInformation.Insert("Ref",                     Undefined);
	ImportTypeInformation.Insert("Id",              "");
	ImportTypeInformation.Insert("Presentation",              "");
	
	Return ImportTypeInformation;
	
EndFunction

Function CatalogPresentation(MappingObjectName)
	
	DefaultImportParameters = ImportDataFromFile.ImportFromFileParameters(MappingObjectName);
	ObjectManager(MappingObjectName).DefineParametersForLoadingDataFromFile(DefaultImportParameters);
	
	Return DefaultImportParameters.Title;
	
EndFunction

Function CanImportDataFromFile(Catalog)
	
	If StrStartsWith(Upper(Catalog.Name), Upper("DELETE")) Then
		Return False;
	EndIf;
	
	For Each Attribute In Catalog.Attributes Do 
		For Each AttributeType In Attribute.Type.Types() Do
			If AttributeType = Type("ValueStorage") Then
				Return False;
			EndIf;
		EndDo;
	EndDo;
	
	Return True;
	
EndFunction

#Region RefsSearch


// Description
// 
// Parameters:
//  TemplateWithData - SpreadsheetDocument
//  ColumnsInformation - ValueTable:
//   * ColumnName - String
//   * Id - String
//   * ColumnPresentation - String
//   * ColumnType - Arbitrary
//   * IsRequiredInfo - Boolean
//   * Position - Number
//   * Group - String
//   * Visible - Boolean
//   * Note - String
//   * Width - Number
//  TypeDescription - TypeDescription
// 
Procedure SetInsertModeFromClipboard(TemplateWithData, ColumnsInformation, TypeDescription) Export
	ColumnsMap = New Map;
	ColumnTitle    = "";
	Separator         = "";
	ObjectsTypesSupportingInputByString = ObjectsTypesSupportingInputByString();
	
	For Each Type In TypeDescription.Types() Do
		MetadataObject = Metadata.FindByType(Type); // MetadataObjectCatalog, MetadataObjectDocument
		
		If MetadataObject <> Undefined Then
			ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
			
			If ObjectsTypesSupportingInputByString[ObjectStructure.ObjectType] = True Then
				
				For Each Column In MetadataObject.InputByString Do
					
					If ColumnsMap.Get(Column.Name) = Undefined Then
						ColumnTitle = ColumnTitle + Separator + Column.Name;
						Separator = ", ";
						ColumnsMap.Insert(Column.Name, Column.Name);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			If ObjectStructure.ObjectType = "Document" Then
				ColumnTitle = ColumnTitle + Separator + "Presentation";
			EndIf;
		EndIf;
		
		ColumnTitle = NStr("en = 'Entered data';");
		
	EndDo;
	
	AddInformationByColumn(ColumnsInformation, "References", ColumnTitle, New TypeDescription("String"), False, 1);
	
	Header = HeaderOfTemplateForFillingColumnsInformation(ColumnsInformation);
	TemplateWithData.Clear();
	TemplateWithData.Put(Header);
	
EndProcedure

Function ObjectsTypesSupportingInputByString()
	
	ListOfObjects = New Map;
	ListOfObjects.Insert("BusinessProcess",          True);
	ListOfObjects.Insert("Document",               True);
	ListOfObjects.Insert("Task",                 True);
	ListOfObjects.Insert("ChartOfCalculationTypes",       True);
	ListOfObjects.Insert("ChartOfCharacteristicTypes", True);
	ListOfObjects.Insert("ExchangePlan",             True);
	ListOfObjects.Insert("ChartOfAccounts",             True);
	ListOfObjects.Insert("Catalog",             True);
	
	Return ListOfObjects;
	
EndFunction

Procedure MapAutoColumnValue(MappingTable, ColumnName) Export
	
	Types = MappingTable.Columns.MappingObject.ValueType.Types();
	ObjectsTypesSupportingInputByString = ObjectsTypesSupportingInputByString();
	
	ValuesToMap = New ValueTable();
	
	QueryText = "";
	
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type); // MetadataObjectCatalog, MetadataObjectDocument
		If MetadataObject <> Undefined And AccessRight("Read", MetadataObject) Then
			ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
			
			ColumnsArray1 = New Array;
			If ObjectsTypesSupportingInputByString[ObjectStructure.ObjectType] = True Then
				For Each Field In MetadataObject.InputByString Do
					ColumnsArray1.Add(Field.Name);
				EndDo;
				If ObjectStructure.ObjectType = "Document" Then
					ColumnsArray1.Add("Ref");
				EndIf;
			EndIf;
			
			QueryText = QueryString(QueryText, ObjectStructure.ObjectType,
				ObjectStructure.NameOfObject, ColumnsArray1);
		EndIf;
	EndDo;
	
	If IsBlankString(QueryText) Then
		Return;
	EndIf;
	
	QueryText = "SELECT
		|ValuesToMap.SearchValue AS SearchValue, 
		|ValuesToMap.Key AS Key
		|INTO ValuesToMap
		|FROM
		|	&ValuesToMap AS ValuesToMap" 
		+ Common.QueryBatchSeparator()
		+ QueryText + "
		|TOTALS BY Key";
	
	Types.Add(Type("String"));
	RowParameters = New StringQualifiers(500);
	AllowedTypes = New TypeDescription(Types, , RowParameters);
	ValuesToMap.Columns.Add("SearchValue", AllowedTypes);
	ValuesToMap.Columns.Add("Key", Common.TypeDescriptionNumber(10));
	
	For Each TableRow In MappingTable Do 
		If Not ValueIsFilled(TableRow[ColumnName]) Then 
			Continue;
		EndIf;
		
		Value = DocumentByPresentation(TableRow[ColumnName], Types);
		NewRow = ValuesToMap.Add();
		NewRow.SearchValue =?(Value = Undefined, TrimAll(TableRow[ColumnName]), Value);
		NewRow.Key = MappingTable.IndexOf(TableRow);

	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("ValuesToMap", ValuesToMap);

	ResultsTable = Query.Execute().Select(QueryResultIteration.ByGroups);

	While ResultsTable.Next() Do

		SearchResult = ResultsTable.Select();
		DataString1 = MappingTable.Get(ResultsTable.Key);
		If DataString1 = Undefined Then
			Continue;
		EndIf;
		
		FoundOptions = New Array;
		While SearchResult.Next() Do
			If SearchResult.ObjectReference <> Undefined Then
				FoundOptions.Add(SearchResult.ObjectReference);
			EndIf;
		EndDo;

		If FoundOptions.Count() = 1 Then
			DataString1.MappingObject = FoundOptions[0];
			DataString1.RowMappingResult =  ImportDataFromFileClientServer.StatusMapped();
		ElsIf FoundOptions.Count() > 1 Then
			DataString1.ConflictsList.LoadValues(FoundOptions);
			DataString1.RowMappingResult = ImportDataFromFileClientServer.StatusAmbiguity();
		Else
			DataString1.RowMappingResult = ImportDataFromFileClientServer.StatusUnmapped();
		EndIf;
		
	EndDo;
	
EndProcedure

// Recognizes the document by presentation for reference search mode.
//
Function DocumentByPresentation(Presentation, Types)
	
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		ObjectNameStructure = SplitFullObjectName(MetadataObject.FullName());
		If Upper(ObjectNameStructure.ObjectType) <> Upper("Document") Then
			Continue;
		EndIf;
		
		ItemPresentation = Common.ObjectPresentation(MetadataObject);
		
		If StrFind(Presentation, ItemPresentation) > 0 Then
			PresentationNumberAndDate = TrimAll(Mid(Presentation, StrLen(ItemPresentation) + 1));
			NumberEndPosition = StrFind(PresentationNumberAndDate, " ");
			Number = Left(PresentationNumberAndDate, NumberEndPosition - 1);
			PositionFrom = StrFind(Lower(PresentationNumberAndDate), NStr("en = 'dated';"));
			PresentationDate = TrimL(Mid(PresentationNumberAndDate, PositionFrom + 2));
			DateEndPosition = StrFind(PresentationDate, " ");
			DateRoundedToDay = Left(PresentationDate, DateEndPosition - 1) + " 00:00:00";
			NumberDocument = Number;
			DocumentDate = StringFunctionsClientServer.StringToDate(DateRoundedToDay);
		EndIf;
		
		SetPrivilegedMode(True);
		Document = Documents[MetadataObject.Name].FindByNumber(NumberDocument, DocumentDate); // MetadataObjectDocument
		SetPrivilegedMode(False);
		
		If Document = Undefined Or Document = Documents[MetadataObject.Name].EmptyRef() Then
			Continue;
		EndIf;
		
		Return Document;
	
	EndDo;
	
	Return Undefined;
	
EndFunction

Function QueryString(QueryText, ObjectType, ObjectName, ColumnsArray1)
	
	If ColumnsArray1.Count() = 0 Then
		Return QueryText;
	EndIf;

	TextsON = New Array;
	For Each Field In ColumnsArray1 Do 
		TextsON.Add("DataTable." + Field + " = ValuesToMap.SearchValue");
	EndDo;
	
	TextPattern = "SELECT ALLOWED
	|	ISNULL(DataTable.Ref, UNDEFINED) AS ObjectReference,
	|	ValuesToMap.Key AS Key
	|FROM
	|	ValuesToMap AS ValuesToMap 
	|	LEFT JOIN &TableName AS DataTable
	|	ON &Conditions";
	TextPattern = StrReplace(TextPattern, "&Conditions", StrConcat(TextsON, " OR ")); // @query-part-2
	TextPattern = StrReplace(TextPattern, "&TableName", ObjectType + "." + ObjectName);
	If Not IsBlankString(QueryText) Then
		TextPattern = StrReplace(TextPattern, "SELECT ALLOWED", "SELECT"); // @query-part-1, @query-part-2
		QueryText = QueryText + Chars.LF + "UNION ALL" + Chars.LF; // @query-part-1
	EndIf;
	QueryText = QueryText + TextPattern;
	
	Return QueryText;
	
EndFunction

// Adding information by column for reference search mode.
//
Procedure AddInformationByColumn(ColumnsInformation, Name, Presentation, Type, IsRequiredInfo, Position, Group = "")
	ColumnsInfoRow = ColumnsInformation.Add();
	ColumnsInfoRow.ColumnName = Name;
	ColumnsInfoRow.ColumnPresentation = Presentation;
	ColumnsInfoRow.ColumnType = Type;
	ColumnsInfoRow.IsRequiredInfo = IsRequiredInfo;
	ColumnsInfoRow.Position = Position;
	ColumnsInfoRow.Group = ?(ValueIsFilled(Group), Group, Name);
	ColumnsInfoRow.Visible = True;
EndProcedure

#EndRegion

// Fills in the data mapping value table by template data.
//
// Parameters:
//  ExportingParameters - Structure:
//   * MappingTable - ValueTable:
//       ** Id - String
//    * ColumnsInformation - ValueTable
//  StorageAddress- String 
// 
Procedure FillMappingTableWithDataFromTemplateBackground(ExportingParameters, StorageAddress) Export
	
	TemplateWithData = ExportingParameters.TemplateWithData;
	MappingTable = ExportingParameters.MappingTable;
	ColumnsInformation = ExportingParameters.ColumnsInformation;
	
	MappingTable.Clear();
	FillMappingTableWithDataToImport(TemplateWithData, ColumnsInformation, MappingTable, True);
	
	PutToTempStorage(MappingTable, StorageAddress);
	
EndProcedure

Procedure FillMappingTableWithDataFromTemplate(TemplateWithData, MappingTable, ColumnsInformation) Export
	
	DetermineColumnsPositionsInTemplate(TemplateWithData, ColumnsInformation);
	MappingTable.Clear();
	FillMappingTableWithDataToImport(TemplateWithData, ColumnsInformation, MappingTable);
	
EndProcedure

Procedure FillMappingTableWithDataToImport(TemplateWithData, TableColumnsInformation, MappingTable, BackgroundJob = False)
	
	FirstTableRow = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(TableColumnsInformation), 3, 2);
	
	BlankRowsCount = 0;
	NumberOfBlankLinesInRowToInterruptDownload = 30;
	
	IDAdjustment = FirstTableRow - 2;
	For LineNumber = FirstTableRow To TemplateWithData.TableHeight Do 
		EmptyTableRow = True;
		NewRow = MappingTable.Add();
		NewRow.Id = LineNumber - 1 - IDAdjustment;
		NewRow.RowMappingResult = ImportDataFromFileClientServer.StatusUnmapped();
		
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			
			Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber).CurrentArea;
			Column = FindColumnInfo(TableColumnsInformation, "Position", ColumnNumber);
			
			If Column <> Undefined Then
				
				CellData =  Undefined;
				
				ColumnName = Column.ColumnName;
				DataType = TypeOf(NewRow[ColumnName]);
				
				If DataType <> Type("String") And DataType <> Type("Boolean") And DataType <> Type("Number") And DataType <> Type("Date")  And DataType <> Type("UUID") Then 
					//@skip-check query-in-loop - Row-by-row import of heterogeneous data.
					CellData = CellValue(Column, Cell.Text);
				Else
					If DataType = Type("Boolean") Then
						CellValue = Upper(TrimAll(Cell.Text));
						If CellValue = "1" 
						   Or StrCompare(CellValue, ImportDataFromFile.PresentationOfTextYesForBoolean()) = 0
						   Or StrCompare(CellValue, "TRUE") = 0 Then
							CellData = True;
						Else
							CellData = False;
						EndIf;
					Else
						CellData = Cell.Text;
					EndIf;
				EndIf;
				If EmptyTableRow Then
					EmptyTableRow = Not ValueIsFilled(CellData);
				EndIf;
				NewRow[ColumnName] = CellData;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			MappingTable.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
			BlankRowsCount       = BlankRowsCount + 1;
		Else
			BlankRowsCount       = 0;
		EndIf;
		
		If BlankRowsCount > NumberOfBlankLinesInRowToInterruptDownload Then
			Break;
		EndIf;
		
		If BackgroundJob Then
			Percent = Round(LineNumber *100 / TemplateWithData.TableHeight);
			ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
			ModuleTimeConsumingOperations.ReportProgress(Percent);
		EndIf;
		
	EndDo;
	
EndProcedure

Function CellValue(Column, CellValue)
	
	CellData = "";
	For Each DataType In Column.ColumnType.Types() Do
		MetadataObject = Metadata.FindByType(DataType);
		
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		ObjectDetails = SplitFullObjectName(MetadataObject.FullName());
		If ObjectDetails.ObjectType = "Catalog" Then
			If Not MetadataObject.Autonumbering 
			   And MetadataObject.CodeLength > 0 Then 
				CellData = Catalogs[ObjectDetails.NameOfObject].FindByCode(CellValue, True);
			EndIf;
			If Not ValueIsFilled(CellData)
			   And ValueIsFilled(CellValue)
			   And MetadataObject.DescriptionLength > 0 Then
				//@skip-check query-in-loop - Individual queries for heterogeneous data.
				CellData = FindByDescription(CellValue, MetadataObject, Column);
			EndIf;
			If Not ValueIsFilled(CellData)
			   And MetadataObject.CodeLength > 0 Then 
				If MetadataObject.CodeSeries = Metadata.ObjectProperties.CatalogCodesSeries.WholeCatalog Then
					CellData = Catalogs[ObjectDetails.NameOfObject].FindByCode(CellValue);
				Else
					CellData = Catalogs[ObjectDetails.NameOfObject].FindByCode(CellValue, True);
				EndIf;
			EndIf;
		ElsIf ObjectDetails.ObjectType = "Enum" Then 
			For Each EnumerationValue In Enums[ObjectDetails.NameOfObject] Do 
				If String(EnumerationValue) = TrimAll(CellValue) Then 
					CellData = EnumerationValue; 
				EndIf;
			EndDo;
		ElsIf ObjectDetails.ObjectType = "ChartOfAccounts" Then
			CellData = ChartsOfAccounts[ObjectDetails.NameOfObject].FindByCode(CellValue);
			If CellData.IsEmpty() Then 
				CellData = ChartsOfAccounts[ObjectDetails.NameOfObject].FindByDescription(CellValue, True);
			EndIf;
		ElsIf ObjectDetails.ObjectType = "ChartOfCharacteristicTypes" Then
			If Not MetadataObject.Autonumbering And MetadataObject.CodeLength > 0 Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDetails.NameOfObject].FindByCode(CellValue);
			EndIf;
			If Not ValueIsFilled(CellData) Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDetails.NameOfObject].FindByDescription(CellValue, True);
			EndIf;
		Else
			CellData =  String(CellValue);
		EndIf;
		If ValueIsFilled(CellData) Then 
			Break;
		EndIf;
	EndDo;
	
	Return CellData;
	
EndFunction

Function FindByDescription(CellValue, MetadataObject, Column)
	
	Query = New Query;
	
	If MetadataObject.Hierarchical
	   And MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
	
		Query.Text =
		"SELECT TOP 1
		|	CatalogName.Ref AS Ref
		|FROM
		|	#CatalogName AS CatalogName
		|WHERE
		|	CatalogName.Description = &Description
		|	AND CatalogName.IsFolder = &IsFolder
		|
		|ORDER BY
		|	CatalogName.IsFolder";
		
		If Column.Use = "ForFolder" Then
			Query.SetParameter("IsFolder", True);
		ElsIf Column.Use = "ForItem" Then
			Query.SetParameter("IsFolder", False);
		Else
			Query.Text = StrReplace(Query.Text, "AND CatalogName.IsFolder = &IsFolder", "");
		EndIf;
		
	Else
		
		Query.Text =
		"SELECT TOP 1
		|	CatalogName.Ref AS Ref
		|FROM
		|	#CatalogName AS CatalogName
		|WHERE
		|	CatalogName.Description = &Description";
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "#CatalogName", MetadataObject.FullName());
	Query.SetParameter("Description", CellValue);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction


Procedure DetermineColumnsPositionsInTemplate(TemplateWithData, ColumnsInformation)
	
	TitleArea = TableTemplateHeaderArea(TemplateWithData);
	
	ColumnsMap = New Map;
	For ColumnNumber = 1 To TitleArea.TableWidth Do 
		Cell=TemplateWithData.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		ColumnNameInTemplate = Cell.Text;
		ColumnsMap.Insert(ColumnNameInTemplate, ColumnNumber);
	EndDo;
	
	For Each Column In ColumnsInformation Do 
		Position = ColumnsMap.Get(Column.ColumnPresentation);
		If Position <> Undefined Then 
			Column.Position = Position;
		Else
			Column.Position = -1;
		EndIf;
	EndDo;
	
EndProcedure

#Region PrepareToImportData

Function TableTemplateHeaderArea(Template)
	
	HeaderHeight = 1;
	For ColumnNumber = 1 To Template.TableWidth Do
		Cell = Template.GetArea(2, ColumnNumber, 2, ColumnNumber).CurrentArea;
		If ValueIsFilled(Cell.Text) Then
			HeaderHeight = 2;
			Break;
		EndIf;
	EndDo;
	TableHeaderArea = Template.GetArea(1, 1, HeaderHeight, Template.TableWidth);
	
	Return TableHeaderArea;
	
EndFunction

// Generates a spreadsheet document template based on catalog attributes for universal import.
//
Procedure ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformation)
	
	ColumnsInformation.Clear();
	Position = 1;
	
	CatalogMetadata= Common.MetadataObjectByFullName(ImportParameters.FullObjectName); // MetadataObjectCatalog, MetadataObjectDocument
	
	If Not CatalogMetadata.Autonumbering And CatalogMetadata.CodeLength > 0  Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Code", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.DescriptionLength > 0  Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Description", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.Hierarchical Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Parent", Position);
		Position = Position + 1;
	EndIf;
	 
	If CatalogMetadata.Owners.Count() > 0 Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Owner", Position);
		Position = Position + 1;
	EndIf;
	
	For Each Attribute In CatalogMetadata.Attributes Do
		
		If Attribute.Name = "Id" Then
			Continue;
		EndIf;
		
		If Attribute.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		ColumnTypeDetails = "";
		
		If Attribute.Type.ContainsType(Type("Boolean")) Then 
			ColumnTypeDetails = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Check box, %1 or 1 / No or 0';"), ImportDataFromFile.PresentationOfTextYesForBoolean());
		ElsIf Attribute.Type.ContainsType(Type("Number")) Then 
			ColumnTypeDetails =  StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Digit, Length: %1, Precision: %2';"),
				String(Attribute.Type.NumberQualifiers.Digits),
				String(Attribute.Type.NumberQualifiers.FractionDigits));
		ElsIf Attribute.Type.ContainsType(Type("String")) Then
			If Attribute.Type.StringQualifiers.Length > 0 Then
				StringLength = String(Attribute.Type.StringQualifiers.Length);
				ColumnTypeDetails =  StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'String, length limit: %1';"), StringLength);
			Else
				ColumnTypeDetails = NStr("en = 'String of unlimited length';");
			EndIf;
		ElsIf Attribute.Type.ContainsType(Type("Date")) Then
			ColumnTypeDetails = String(Attribute.Type.DateQualifiers.DateFractions);
		ElsIf Attribute.Type.ContainsType(Type("UUID")) Then
			ColumnTypeDetails = NStr("en = 'UUID';");
		EndIf;
		
		ColumnWidth = ColumnWidthByType(Attribute.Type);
		ToolTip = ?(ValueIsFilled(Attribute.Tooltip), Attribute.Tooltip, Attribute.Presentation()) +  Chars.LF + ColumnTypeDetails;
		RequiredField = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
		
		ColumnsInfoRow = ColumnsInformation.Add();
		ColumnsInfoRow.ColumnName = Attribute.Name;
		ColumnsInfoRow.ColumnPresentation = Attribute.Presentation();
		ColumnsInfoRow.ColumnType = Attribute.Type;
		ColumnsInfoRow.IsRequiredInfo = RequiredField;
		ColumnsInfoRow.Position = Position;
		ColumnsInfoRow.Group = CatalogMetadata.Presentation();
		ColumnsInfoRow.Visible = True;
		ColumnsInfoRow.Note = ToolTip;
		ColumnsInfoRow.Width = ColumnWidth;

		Position = Position + 1;
		
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
	EndIf;
	
EndProcedure

// Adding information on a column for a standard attribute upon universal import.
//
Procedure CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, ColumnName, Position)
	
	Attribute = CatalogMetadata.StandardAttributes[ColumnName];
	Presentation = CatalogMetadata.StandardAttributes[ColumnName].Presentation();
	DataType = CatalogMetadata.StandardAttributes[ColumnName].Type.Types()[0];
	TypeDetails = CatalogMetadata.StandardAttributes[ColumnName].Type;
	
	ColumnWidth = 11;
	
	If DataType = Type("String") Then 
		TypePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'String (up to %1 characters)';"), TypeDetails.StringQualifiers.Length);
		ColumnWidth = ?(TypeDetails.StringQualifiers.Length < 30, TypeDetails.StringQualifiers.Length + 1, 30);
	ElsIf DataType = Type("Number") Then
		TypePresentation = NStr("en = 'Number';");
	Else
		If CatalogMetadata.StandardAttributes[ColumnName].Type.Types().Count() = 1 Then 
			TypePresentation = String(DataType); 
		Else
			TypePresentation = "";
			Separator = "";
			For Each TypeData In CatalogMetadata.StandardAttributes[ColumnName].Type.Types() Do 
				TypePresentation = TypePresentation  + Separator + String(TypeData);
				Separator = " or ";
			EndDo;
		EndIf;
	EndIf;
	NoteText2 = Attribute.ToolTip + Chars.LF + TypePresentation;
	
	IsRequiredInfo = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
	ColumnsInfoRow = ColumnsInformation.Add();
	ColumnsInfoRow.ColumnName = ColumnName;
	ColumnsInfoRow.ColumnPresentation = Presentation;
	ColumnsInfoRow.ColumnType = TypeDetails;
	ColumnsInfoRow.IsRequiredInfo = IsRequiredInfo;
	ColumnsInfoRow.Position = Position;
	ColumnsInfoRow.Group = CatalogMetadata.Presentation();
	ColumnsInfoRow.Visible = True;
	ColumnsInfoRow.Note = NoteText2;
	ColumnsInfoRow.Width = ColumnWidth;
	
EndProcedure

// Determines column content for data import.
//
// Parameters:
//  ImportParameters - Structure
//  ColumnsInformation - ValueTable:
//   * ColumnName - String
//   * ColumnPresentation - String
//   * ColumnType - TypeDescription
//   * IsRequiredInfo - Boolean
//   * Use - String
//   * Position - Number
//   * Group - String
//   * Visible - Boolean
//   * Note - String
//   * Width - Number
//  NamesOfColumnsToAdd - Undefined
//
Procedure DetermineColumnsInformation(ImportParameters, ColumnsInformation, NamesOfColumnsToAdd = Undefined) Export
	
	If ImportParameters.ImportType = "AppliedImport" Then
		
		If ImportParameters.Property("Template") Then
			Template = ImportParameters.Template;
		Else
			Template = ObjectManager(ImportParameters.FullObjectName).GetTemplate("LoadingFromFile");
		EndIf;
		
		TableHeaderArea = TableTemplateHeaderArea(Template);
		
		If ColumnsInformation.Count() = 0 Then
			CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation, Undefined);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "UniversalImport" Then
		
		ColumnsInformationBasedOnAttributes = ColumnsInformation.CopyColumns();
		
		If ColumnsInformation.Count() = 0 Then
			ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformation);
		Else
			ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformationBasedOnAttributes);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "ExternalImport" Then
		
		TableHeaderArea = TableTemplateHeaderArea(ImportParameters.Template);
		TableHeaderArea.Protection = True;
		
		If ColumnsInformation.Count() = 0 Then
			CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "TabularSection" Then
		
		If ColumnsInformation.Count() = 0 Then
			DetermineColumnsInformationTabularSection(ColumnsInformation, Template, TableHeaderArea, ImportParameters);
		Else
			MetadataObject = Metadata.FindByFullName(ImportParameters.FullObjectName);
			
			If MetadataObject = Undefined Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot import data from a file to a table for object of the %1 type';"),
					ImportParameters.FullObjectName);
				Raise ErrorText;
			EndIf;
			
			If MetadataObject.Parent().Templates.Find(ImportParameters.Template) = Undefined Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot import data from a file to a table since there is no %1 template for object of the %2 type';"),
					ImportParameters.Template, ImportParameters.FullObjectName);
				Raise ErrorText;
			EndIf;
			
			Template = ObjectManager(ImportParameters.FullObjectName).GetTemplate(ImportParameters.Template);
			TableHeaderArea = TableTemplateHeaderArea(Template);
		EndIf;
		
	EndIf;
	
	PositionsRecalculationRequired = False;
	ColumnsListWithFunctionalOptions = ColumnsDependentOnFunctionalOptions(ImportParameters.FullObjectName);
	For Each ColumnFunctionalOptionOn In ColumnsListWithFunctionalOptions Do 
		RowWithColumnInformation = ColumnsInformation.Find(ColumnFunctionalOptionOn.Key, "ColumnName");
		If RowWithColumnInformation <> Undefined Then
			If Not ColumnFunctionalOptionOn.Value Then
				ColumnsInformation.Delete(RowWithColumnInformation);
				PositionsRecalculationRequired = True;
			EndIf;
		Else
			If ColumnFunctionalOptionOn.Value Then
				If ImportParameters.ImportType = "UniversalImport" Then
					RowWithColumn = ColumnsInformationBasedOnAttributes.Find(ColumnFunctionalOptionOn.Key, "ColumnName");
					NewRow = ColumnsInformation.Add();
					FillPropertyValues(NewRow, RowWithColumn);
				Else
					CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation, ColumnFunctionalOptionOn.Key);
				EndIf;
				PositionsRecalculationRequired = True;
			EndIf;
		EndIf;
	EndDo;
	
	If PositionsRecalculationRequired Then
		ColumnsInformation.Sort("Position");
		Position = 1;
		For Each Column In ColumnsInformation Do
			Column.Position = Position;
			Position = Position + 1;
		EndDo;
	EndIf;
	
EndProcedure

Procedure DetermineColumnsInformationTabularSection(Val ColumnsInformation, Template, TableHeaderArea, Val ImportParameters)
	
	ObjectDescriptionStructure = SplitFullObjectName(ImportParameters.FullObjectName);
	MetadataObjectName = ObjectDescriptionStructure.ObjectType + "." + ObjectDescriptionStructure.NameOfObject;
	
	MetadataObject = Common.MetadataObjectByFullName(MetadataObjectName);
	If MetadataObject = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot import data from a file to a table for objects of the %1 type';"),
				MetadataObjectName);
		Raise ErrorText;
	EndIf;
	
	MetadataObjectTemplates = MetadataObject.Templates;
	
	ImportFromFileParameters = FileToTSImportParameters(ImportParameters.FullObjectName, ImportParameters.AdditionalParameters);
	ImportFromFileParameters.Insert("FullObjectName", ImportParameters.FullObjectName);
	
	ObjectManager = Common.ObjectManagerByFullName(ImportParameters.FullObjectName);
	ObjectManager.SetDownloadParametersFromVHFFile(ImportFromFileParameters);
	
	MetadataTemplate = MetadataObjectTemplates.Find(ImportParameters.Template); // MetadataObjectTemplate
	If MetadataTemplate = Undefined Then
		MetadataTemplate= MetadataObjectTemplates.Find("LoadingFromFile" + ObjectDescriptionStructure.TabularSectionName);
		If MetadataTemplate = Undefined Then
			MetadataTemplate = MetadataObjectTemplates.Find("LoadingFromFile");
		EndIf;
	EndIf;
	
	If MetadataTemplate <> Undefined Then
		Template = ObjectManager.GetTemplate(MetadataTemplate.Name);
	Else
		Raise NStr("en = 'Cannot find a template for importing data.';");
	EndIf;
	
	TableHeading = TableTemplateHeaderArea(Template);
	If ColumnsInformation.Count() = 0 Then
		CreateColumnsInformationFromTemplate(TableHeading, ImportFromFileParameters, ColumnsInformation);
	EndIf;
	
	TableHeaderArea = TableTemplateHeaderArea(Template);

EndProcedure

// Fills in the table on template columns. This information is used for generating a mapping table.
//
// Parameters:
//  TableHeaderArea  - SpreadsheetDocument - a table header area.
//  ImportFromFileParameters - Structure - import parameters.
//  ColumnsInformation     - ValueTable - TabularSectionDetails with column details.
//  NamesOfColumnsToAdd  - String - Comma-separated list of columns. If a value is not filled in,
//                                      then all values are added.
//
Procedure CreateColumnsInformationFromTemplate(TableHeaderArea, ImportFromFileParameters, ColumnsInformation, NamesOfColumnsToAdd = Undefined)
	
	SelectiveAddition = False;
	If ValueIsFilled(NamesOfColumnsToAdd) Then
		SelectiveAddition = True;
		ColumnsToAddArray = StrSplit(NamesOfColumnsToAdd, ",", False);
		Position = ColumnsInformation.Count() + 1;
	Else
		ColumnsInformation.Clear();
		Position = 1;
	EndIf;
	
	If ImportFromFileParameters.Property("ColumnDataType") Then
		ColumnsDataTypeMap = ImportFromFileParameters.ColumnDataType;
	Else
		ColumnsDataTypeMap = New Map;
	EndIf;
	
	HeaderHeight = TableHeaderArea.TableHeight;
	If HeaderHeight = 2 Then
		ColumnNumber = 1;
		Groups = New Map;
		GroupUsed = True;
		While ColumnNumber <= TableHeaderArea.TableWidth Do
			Area = TableHeaderArea.GetArea(1, ColumnNumber);
			Cell = TableHeaderArea.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
			Group = Cell.Text;
			For IndexOf = ColumnNumber To ColumnNumber + Area.TableWidth -1 Do
				Groups.Insert(IndexOf, Group);
			EndDo;
			ColumnNumber = ColumnNumber + Area.TableWidth;
		EndDo;
	Else
		GroupUsed = False;
	EndIf;
	
	PredefinedLayoutAreas = PredefinedLayoutAreas();
	MetadataObject = Common.MetadataObjectByFullName(ImportFromFileParameters.FullObjectName);
	
	For ColumnNumber = 1 To TableHeaderArea.TableWidth Do
		Cell = TableHeaderArea.GetArea(HeaderHeight, ColumnNumber, HeaderHeight, ColumnNumber).CurrentArea;
		
		If Cell.Name = "R1C1" Then
			AttributeName = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
			AttributeRepresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.DetailsParameter);
			Parent = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
		Else
			AttributeName = Cell.Name;
			AttributeRepresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.Name);
			Parent = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Name);
		EndIf;
		
		If StrCompare(AttributeRepresentation, PredefinedLayoutAreas.AdditionalAttributes) = 0 Then
			If Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
				ModulePropertyManagerInternal.ColumnsForDataImport(MetadataObject, ColumnsInformation);
			EndIf;
		ElsIf StrCompare(AttributeRepresentation, PredefinedLayoutAreas.ContactInformation) = 0 Then
			
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				ModuleContactsManager = Common.CommonModule("ContactsManager");
				ModuleContactsManager.ColumnsForDataImport(MetadataObject, ColumnsInformation);
			EndIf;
		Else
			ColumnDataType = New TypeDescription("String");
			If ColumnsDataTypeMap <> Undefined Then
				ColumnDataTypeOverridden = ColumnsDataTypeMap.Get(AttributeName);
				If ColumnDataTypeOverridden <> Undefined Then
					ColumnDataType = ColumnDataTypeOverridden;
				EndIf;
			EndIf;
			
			If SelectiveAddition And ColumnsToAddArray.Find(AttributeName) = Undefined Then
				Continue;
			EndIf;
			
			If ValueIsFilled(AttributeName) Then
				
				IsRequiredInfo = Cell.Font.Bold = True
				                           Or ImportFromFileParameters.RequiredColumns2.Find(AttributeName) <> Undefined;
				
				NoteInTheColumnHeader = Cell.Comment.Text + ?(IsRequiredInfo,
					Chars.LF + NStr("en = 'Required.';"), "");
				
				ColumnsInfoRow                          = ColumnsInformation.Add();
				ColumnsInfoRow.ColumnName               = AttributeName;
				ColumnsInfoRow.ColumnPresentation     = AttributeRepresentation;
				ColumnsInfoRow.ColumnType               = ColumnDataType;
				ColumnsInfoRow.IsRequiredInfo = IsRequiredInfo;
				ColumnsInfoRow.Position                  = Position;
				ColumnsInfoRow.Parent                 = Parent;
				ColumnsInfoRow.Visible                = True;
				ColumnsInfoRow.Note               = NoteInTheColumnHeader;
				ColumnsInfoRow.Width                   = Cell.ColumnWidth;
				
				If MetadataObject <> Undefined And Common.IsCatalog(MetadataObject) Then
					AttributeMetadata = MetadataObject.Attributes.Find(AttributeName);
					If AttributeMetadata <> Undefined Then
						
						If AttributeMetadata.Use = Metadata.ObjectProperties.AttributeUse.ForFolder Then
							ColumnsInfoRow.Use = "ForFolder";
						ElsIf AttributeMetadata.Use = Metadata.ObjectProperties.AttributeUse.ForFolderAndItem Then
							ColumnsInfoRow.Use = "ForFolderAndItem";
						Else
							ColumnsInfoRow.Use = "ForItem";
						EndIf;
						
					EndIf;
				EndIf;
				
				If GroupUsed Then
					ColumnsInfoRow.Group = Groups.Get(ColumnNumber);
				EndIf;
				
				Position = Position + 1;
				
			EndIf;
		
		EndIf;
	EndDo;
	
EndProcedure

// Returns:
//  Structure:
//   * AdditionalAttributes - String
//   * ContactInformation - String
//
Function PredefinedLayoutAreas()
	
	PredefinedLayoutAreas = New Structure();
	PredefinedLayoutAreas.Insert("AdditionalAttributes", NStr("en = '<Additional attributes>';"));
	PredefinedLayoutAreas.Insert("ContactInformation", NStr("en = '<Contact information>';"));
	
	Return PredefinedLayoutAreas
	
EndFunction

Function ColumnWidthByType(Type) 
	
	ColumnWidth = 20;
	If Type.ContainsType(Type("Boolean")) Then 
		ColumnWidth = 3;
	ElsIf Type.ContainsType(Type("Number")) Then 
		ColumnWidth = Type.NumberQualifiers.Digits + 1;
	ElsIf Type.ContainsType(Type("String")) Then 
		If Type.StringQualifiers.Length > 0 Then 
			ColumnWidth = ?(Type.StringQualifiers.Length > 20, 20, Type.StringQualifiers.Length);
		Else
			ColumnWidth = 20;
		EndIf;
	ElsIf Type.ContainsType(Type("Date")) Then 
		ColumnWidth = 12;
	ElsIf Type.ContainsType(Type("UUID")) Then 
		ColumnWidth = 20;
	Else
		For Each ObjectType In  Type.Types() Do
			ObjectMetadata = Metadata.FindByType(ObjectType); // MetadataObjectCatalog
			ObjectStructure = SplitFullObjectName(ObjectMetadata.FullName());
			If ObjectStructure.ObjectType = "Catalog" Then 
				If Not ObjectMetadata.Autonumbering And ObjectMetadata.CodeLength > 0  Then
					ColumnWidth = ObjectMetadata.CodeLength + 1;
				EndIf;
				If ObjectMetadata.DescriptionLength > 0  Then
					If ObjectMetadata.DescriptionLength > ColumnWidth Then
						ColumnWidth = ?(ObjectMetadata.DescriptionLength > 30, 30, ObjectMetadata.DescriptionLength + 1);
					EndIf;
			EndIf;
		ElsIf ObjectStructure.ObjectType = "Enum" Then
				PresentationLength =  StrLen(ObjectMetadata.Presentation());
				ColumnWidth = ?( PresentationLength > 30, 30, PresentationLength + 1);
			EndIf;
		EndDo;
	EndIf;
	
	Return ColumnWidth;
	
EndFunction

// Parameters:
//  Cell - SpreadsheetDocument
//  Text - String
//  Width - Number
//  ToolTip - String
//  RequiredField - Boolean
//  Name - String
//
Procedure FillTemplateHeaderCell(Cell, Text, Width, ToolTip, RequiredField, Name = "")
	
	Cell.CurrentArea.Text = Text;
	Cell.CurrentArea.Name = Name;
	Cell.CurrentArea.DetailsParameter = Name;
	Cell.CurrentArea.BackColor =  StyleColors.ReportHeaderBackColor;
	Cell.CurrentArea.ColumnWidth = Width;
	Cell.CurrentArea.Comment.Text = ToolTip;
	If RequiredField Then 
		Cell.CurrentArea.Font = StyleFonts.ImportantLabelFont;
	Else
		Cell.CurrentArea.Font = Undefined;
	EndIf;
	
EndProcedure

// Generates a template header by column information.
//
Function HeaderOfTemplateForFillingColumnsInformation(ColumnsInformation) Export

	SpreadsheetDocument = New SpreadsheetDocument;
	ColumnsHaveGroup = ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation);
	If ColumnsHaveGroup Then
		HeaderArea_ = GetTemplate("SimpleTemplate").GetArea("Line2Header");
		Line = New Line(SpreadsheetDocumentCellLineType.Solid);
		LineNumber = 2;
	Else
		HeaderArea_ = GetTemplate("SimpleTemplate").GetArea("Title");
		LineNumber = 1;
	EndIf;
	ColumnsInformation.Sort("Position");
	
	Group = Undefined;
	PositionGroupStart = 1;
	Move = 0;
	For Position = 0 To ColumnsInformation.Count() -1 Do
		Column = ColumnsInformation.Get(Position);
		
		If Column.Visible = True Then
			If Group = Undefined Then
				Group = Column.Group;
			EndIf;
			ColumnNameArea = HeaderArea_.Area(LineNumber, 1, LineNumber, 1);
			ColumnNameArea.Name = Column.ColumnName;
			ColumnNameArea.Details = Column.Group;
			ColumnNameArea.Comment.Text = Column.Note;
			If Column.IsRequiredInfo Then
				ColumnNameArea.Font = StyleFonts.ImportantLabelFont;
			Else
				ColumnNameArea.Font = Undefined;
			EndIf;
			
			ColumnNameArea.ColumnWidth = ?(Column.Width = 0, ColumnWidthByType(Column.ColumnType), Column.Width);
			HeaderArea_.Parameters.Title = ?(IsBlankString(Column.Synonym), Column.ColumnPresentation, Column.Synonym);
			SpreadsheetDocument.Join(HeaderArea_);
			
			If ColumnsHaveGroup Then
				If Column.Group <> Group Then
					Area = SpreadsheetDocument.Area(1, PositionGroupStart, 1, Position - Move);
					Area.Text = Group;
					Area.Merge();
					Area.Outline(Line, Line, Line,Line);
					PositionGroupStart = Position + 1 - Move ;
					Group = Column.Group;
				EndIf;
			EndIf;
		Else
			Move = Move + 1;
		EndIf;
	EndDo;
	If ColumnsHaveGroup Then
		Area = SpreadsheetDocument.Area(1, PositionGroupStart, 1, Position - Move);
		Area.Text = Group;
		Area.Merge();
		Area.Outline(Line, Line, Line,Line);
	EndIf;
	
	Return SpreadsheetDocument;
EndFunction

#EndRegion

// Creates a value table by the template data and saves it to a temporary storage.
//
Procedure SpreadsheetDocumentIntoValuesTable(TemplateWithData, ColumnsInformation, ImportedDataAddress) Export
	
	TypeDescriptionNumber  = New TypeDescription("Number");
	StringTypeDetails = New TypeDescription("String");
	
	TableColumnsInformation = ColumnsInformation.Copy();
	DataToImport = New ValueTable;
	
	For Each Column In TableColumnsInformation Do
		If Column.ColumnType = Undefined Then
			ColumnType = StringTypeDetails;
		Else
			ColumnType = Column.ColumnType;
		EndIf;
		DataToImport.Columns.Add(Column.ColumnName, ColumnType, Column.ColumnPresentation);
	EndDo;
	
	DataToImport.Columns.Add("Id",                TypeDescriptionNumber,  "Id");
	DataToImport.Columns.Add("RowMappingResult", StringTypeDetails, "Result");
	DataToImport.Columns.Add("ErrorDescription",               StringTypeDetails, "Cause");
	
	IDAdjustment = 0;
	HeaderHeight = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(TableColumnsInformation), 2, 1);
	
	InitializeColumns(TableColumnsInformation, TemplateWithData, HeaderHeight);
	If Not AreColumnsInitialized(TableColumnsInformation) Then
		InitializeColumns(TableColumnsInformation, TemplateWithData, ?(HeaderHeight = 1, 2, 1));
	EndIf;
	
	For LineNumber = HeaderHeight + 1 To TemplateWithData.TableHeight Do
		EmptyTableRow = True;
		NewRow               = DataToImport.Add();
		NewRow.Id =  LineNumber - IDAdjustment - 1;
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			Cell = TemplateWithData.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			
			FoundColumn = FindColumnInfo(TableColumnsInformation, "Position", ColumnNumber);
			If FoundColumn <> Undefined Then
				ColumnName = FoundColumn.ColumnName;
				NewRow[ColumnName] = AdjustValueToType(Cell.Text, FoundColumn.ColumnType);
				If Not ValueIsFilled(NewRow[ColumnName]) And ValueIsFilled(Cell.Text) Then
					//@skip-check query-in-loop - Row-by-row import of heterogeneous data.
					NewRow[ColumnName] = CellValue(FoundColumn, Cell.Text);
				EndIf;
				If EmptyTableRow Then
					EmptyTableRow = Not ValueIsFilled(Cell.Text);
				EndIf;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			DataToImport.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
		EndIf;
	EndDo;
	
	ImportedDataAddress = PutToTempStorage(DataToImport);
	
EndProcedure

Function AreColumnsInitialized(ColumnsInformation)
	
	For Each InfoOnColumn In ColumnsInformation Do
		If InfoOnColumn.Position >=0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function AdjustValueToType(Value, TypeDescription)
	
	For Each Type In TypeDescription.Types() Do
		If Type = Type("Date") Then
			
			Return StringFunctionsClientServer.StringToDate(Value, TypeDescription.DateQualifiers.DateFractions);
			
		ElsIf Type = Type("Boolean") Then
			
			BooleanTypeDetails = New TypeDescription("Boolean");
			Return BooleanTypeDetails.AdjustValue(Value);
			
		ElsIf Type = Type("String") Then
			
			BooleanTypeDetails = New TypeDescription("String");
			Return BooleanTypeDetails.AdjustValue(Value);
			
		ElsIf Type = Type("Number") Then
			
			NonNumericCharacters = StrConcat(StrSplit(Value, "-1234567890,."));
			Value = StrConcat(StrSplit(Value, NonNumericCharacters));
			TypeDescriptionNumber = New TypeDescription("Number");
			Return TypeDescriptionNumber.AdjustValue(Value);
			
		EndIf;
	EndDo;
	
	Return Value;
	
EndFunction

Procedure FillTableByDataToImportFromFile(DataFromFile, TemplateWithData, ColumnsInformation)
	
	RowHeader= DataFromFile.Get(0);
	ColumnsMap = New Map;
	
	For Each Column In DataFromFile.Columns Do
		FoundColumn = FindColumnInfo(ColumnsInformation, "Synonym", RowHeader[Column.Name]);
		If FoundColumn = Undefined Then
			FoundColumn = FindColumnInfo(ColumnsInformation, "ColumnPresentation", RowHeader[Column.Name]);
		EndIf;
		If FoundColumn <> Undefined Then
			ColumnsMap.Insert(FoundColumn.Position, Column.Name);
		EndIf;
	EndDo;
	
	For IndexOf= 1 To DataFromFile.Count() - 1 Do
		SpecificationRow = DataFromFile.Get(IndexOf);
		NewRow = True;
		For ColumnNumber =1 To TemplateWithData.TableWidth Do
			TableColumn1 = ColumnsMap.Get(ColumnNumber);
			Column = ColumnsInformation.Find(ColumnNumber, "Position");
			If Column <> Undefined And Column.Visible = False Then
				Continue;
			EndIf;
			Cell = TemplateWithData.GetArea(2, ColumnNumber, 2, ColumnNumber);
			If TableColumn1 <> Undefined Then 
				Cell.CurrentArea.Text = SpecificationRow[TableColumn1];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Else
				Cell.CurrentArea.Text = "";
			EndIf;
			If NewRow Then
				TemplateWithData.Put(Cell);
				NewRow = False;
			Else
				TemplateWithData.Join(Cell);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function FindColumnInfo(TableColumnsInformation, ColumnName, Value)
	
	Filter = New Structure(ColumnName, Value);
	FoundColumns = TableColumnsInformation.FindRows(Filter);
	Column = Undefined;
	If FoundColumns.Count() > 0 Then 
		Column = FoundColumns[0];
	EndIf;
	
	Return Column;
EndFunction

Function FullTabularSectionObjectName(ObjectName) Export
	
	Result = StrSplit(ObjectName, ".", False);
	If Result.Count() = 4 Then
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
	ElsIf Result.Count() = 3 Then
		If Result[2] <> "TabularSection" Then 
			ObjectName = Result[0] + "." + Result[1] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
		ElsIf Result[1] = "TabularSection" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		
		Return Undefined;
	ElsIf Result.Count() = 2 Then
		If Result[0] <> "Document" Or Result[0] <> "Catalog" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		MetadataObjectName2 = Result[0];
		MetadataObjectType = Metadata.Catalogs.Find(MetadataObjectName2);
		If MetadataObjectType <> Undefined Then 
			MetadataObjectType = "Catalog";
		Else
			MetadataObjectType = Metadata.Documents.Find(MetadataObjectName2);
			If MetadataObjectType <> Undefined Then 
				MetadataObjectType = "Document";
			Else 
				Return Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns an object name as a structure.
//
// Parameters:
//  FullObjectName - String
//  
// Returns:
//  Structure:
//    * ObjectType - String - object type.
//    * NameOfObject - String - an object name.
//    * TabularSectionName - String - tabular section name.
//
Function SplitFullObjectName(FullObjectName) Export
	Result = StrSplit(FullObjectName, ".", False);
	
	ObjectName = New Structure;
	ObjectName.Insert("FullObjectName", FullObjectName);
	ObjectName.Insert("ObjectType");
	ObjectName.Insert("NameOfObject");
	ObjectName.Insert("TabularSectionName");
	
	If Result.Count() = 2 Then
		If Result[0] = "Document" Or Result[0] = "Catalog" Or Result[0] = "BusinessProcess" 
			Or Result[0] = "Enum" Or Result[0] = "ChartOfCharacteristicTypes"
			Or Result[0] = "ChartOfAccounts" Then
				ObjectName.ObjectType = Result[0];
				ObjectName.NameOfObject = Result[1];
		Else
				ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
				ObjectName.NameOfObject = Result[0];
				ObjectName.TabularSectionName = Result[1];
		EndIf;
	ElsIf Result.Count() = 3 Then
		ObjectName.ObjectType = Result[0];
		ObjectName.NameOfObject = Result[1];
		ObjectName.TabularSectionName = Result[2];
	ElsIf Result.Count() = 4 Then 
		ObjectName.ObjectType = Result[0];
		ObjectName.NameOfObject = Result[1];
		ObjectName.TabularSectionName = Result[3];
	ElsIf Result.Count() = 1 Then
		ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
		ObjectName.NameOfObject = Result[0];
	EndIf;

	Return ObjectName;
	
EndFunction

Function GetMetadataObjectTypeByName(Name)
	
	
	For Each Object In Metadata.Catalogs Do 
		If Object.Name = Name Then 
			Return "Catalog";
		EndIf;
	EndDo;
	
	For Each Object In Metadata.Documents Do 
		If Object.Name = Name Then 
			Return "Document";
		EndIf;
	EndDo;
	
	For Each Object In Metadata.DataProcessors Do 
		If Object.Name = Name Then 
			Return "DataProcessor";
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function ObjectManager(MappingObjectName)
	
	ObjectArray = SplitFullObjectName(MappingObjectName);
	If ObjectArray.ObjectType = "Document" Then
		ObjectManager = Documents[ObjectArray.NameOfObject];
	ElsIf ObjectArray.ObjectType = "Catalog" Then
		ObjectManager = Catalogs[ObjectArray.NameOfObject];
	ElsIf ObjectArray.ObjectType = "DataProcessor" Then
		ObjectManager = DataProcessors[ObjectArray.NameOfObject];
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Object ""%1"" is not found.';"), MappingObjectName);
	EndIf;
	
	Return ObjectManager;
	
EndFunction

//Data import //////////////////////////

Procedure InitializeColumns(ColumnsInformation, TemplateWithData, HeaderHeight = 1)
	
	For Each TableRow In ColumnsInformation Do
		TableRow.Position = -1;
	EndDo;
	
	For ColumnNumber = 1 To TemplateWithData.TableWidth Do
		CellHeader = TemplateWithData.GetArea(HeaderHeight, ColumnNumber, HeaderHeight, ColumnNumber).CurrentArea;
		
		If ValueIsFilled(CellHeader.Text) Then
			Filter = New Structure("Synonym", TrimAll(CellHeader.Text));
			FoundColumn1 = ColumnsInformation.FindRows(Filter);
			If FoundColumn1.Count() > 0 Then
				FoundColumn1[0].Position = ColumnNumber;
			Else
				Filter = New Structure("ColumnPresentation",  TrimAll(CellHeader.Text));
				FoundColumn1 = ColumnsInformation.FindRows(Filter);
				If FoundColumn1.Count() > 0 Then
					FoundColumn1[0].Position = ColumnNumber;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ImportFileToTable(ServerCallParameters, StorageAddress) Export
	
	Extension = ServerCallParameters.Extension;
	TemplateWithData = ServerCallParameters.TemplateWithData;
	TempFileName = ServerCallParameters.TempFileName;
	ColumnsInformation = ServerCallParameters.ColumnsInformation;
	
	Try
		
		If Extension = "csv" Then
			ImportCSVFileToTable(TempFileName, TemplateWithData, ColumnsInformation);
		Else
			
			// Check file availability.
			BinaryDataFromFile = New BinaryData(TempFileName);
			BinaryDataFromFile = Undefined;
			
			ImportedTemplateWithData = New SpreadsheetDocument;
			Try
				ImportedTemplateWithData.Read(TempFileName);
			Except
				
				ErrorInfo = ErrorInfo();
				
				If Not ErrorInfo.IsErrorOfCategory(ErrorCategory.LocalFileAccessError, True) Then
					Raise;
				EndIf;
				
				// Replace unexpected error text with text for user message.
				Refinement = CommonClientServer.ExceptionClarification(ErrorInfo);
				ClarifiedText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1
					           |
					           |Make sure the file data is valid.';"), Refinement.Text);
				
				Raise(ClarifiedText,,,, ErrorInfo);
				
			EndTry;
			
			RowNumberWithTableHeader = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation), 2, 1);
			
			Address = "";
			SpreadsheetDocumentIntoValuesTable(ImportedTemplateWithData, ColumnsInformation, Address);
			ImportedData = GetFromTempStorage(Address);
			
			OutputArea2 = TemplateWithData.GetArea(RowNumberWithTableHeader + 1, 1, RowNumberWithTableHeader + 1, ImportedData.Columns.Count());
			
			For Counter = 1 To ImportedData.Columns.Count() Do
				FillingArea = OutputArea2.Area(1, Counter, 1, Counter);
				Column = ColumnsInformation.Find(Counter, "Position");
				If Column <> Undefined And Column.Visible Then
					FillingArea.Parameter = Column.ColumnName;
					FillingArea.FillType = SpreadsheetDocumentAreaFillType.Parameter;
				EndIf;
			EndDo;
			
			TotalRows = ImportedData.Count();
			LineNumber = 1;
			For Each Selection In ImportedData Do
				SetProgressPercent(TotalRows, LineNumber);
				OutputArea2.Parameters.Fill(Selection);
				TemplateWithData.Put(OutputArea2);
				LineNumber = LineNumber + 1;
			EndDo;
			
		EndIf;
		
		StorageAddress = PutToTempStorage(TemplateWithData, StorageAddress);
	Except
		
		DeleteTempFile(TempFileName);
		Raise;
		
	EndTry;
	
	DeleteTempFile(TempFileName);
	
EndProcedure

Procedure DeleteTempFile(TempFileName)
	
	File = New File(TempFileName);
	If File.Exists() Then
		
		Try
			DeleteFiles(TempFileName);
		Except
			
			WarningText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot delete the ""%1"" temporary file due to:
				|%2';"), TempFileName, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
				Metadata.DataProcessors.ImportDataFromFile,, WarningText);
		
		EndTry;
		
	EndIf;
	
EndProcedure

#Region CSVFilesOperations

Procedure ImportCSVFileToTable(FileName, TemplateWithData, ColumnsInformation)
	
	File = New File(FileName);
	If Not File.Exists() Then 
		Return;
	EndIf;
	
	TextReader = New TextReader(FileName);
	String = TextReader.ReadLine();
	If String = Undefined Then 
		MessageText = NStr("en = 'Cannot import data from the file. The data may be corrupt.';");
		Raise MessageText;
	EndIf;
	
	HeaderColumns = StrSplit(String, ";", False);
	Source = New ValueTable;
	ColumnPositionInFile = New Map();
	
	Position = 1;
	For Each Column In HeaderColumns Do
		FoundColumn = FindColumnInfo(ColumnsInformation, "Synonym", Column);
		If FoundColumn = Undefined Then
			FoundColumn = FindColumnInfo(ColumnsInformation, "ColumnPresentation", Column);
		EndIf;
		If FoundColumn <> Undefined Then
			NewColumn = Source.Columns.Add();
			NewColumn.Name = FoundColumn.ColumnName;
			NewColumn.Title = Column;
			ColumnPositionInFile.Insert(Position, NewColumn.Name);
			Position = Position + 1;
		EndIf;
	EndDo;
	
	If Source.Columns.Count() = 0 Then
		Return;
	EndIf;
	
	While String <> Undefined Do
		NewRow = Source.Add();
		Position = StrFind(String, ";");
		IndexOf = 0;
		While Position > 0 Do
			If Source.Columns.Count() < IndexOf + 1 Then
				Break;
			EndIf;
			ColumnName = ColumnPositionInFile.Get(IndexOf + 1);
			If ColumnName <> Undefined Then
				NewRow[ColumnName] = Left(String, Position - 1);
			EndIf;
			String = Mid(String, Position + 1);
			Position = StrFind(String, ";");
			IndexOf = IndexOf + 1;
		EndDo;
		If Source.Columns.Count() = IndexOf + 1  Then
			NewRow[IndexOf] = String;
		EndIf;

		String = TextReader.ReadLine();
	EndDo;
	
	FillTableByDataToImportFromFile(Source, TemplateWithData, ColumnsInformation);
	
EndProcedure

Procedure SaveTableToCSVFile(PathToFile, ColumnsInformation) Export
	
	HeaderFormatForCSV = "";
	
	For Each Column In ColumnsInformation Do 
		HeaderFormatForCSV = HeaderFormatForCSV + Column.ColumnPresentation + ";";
	EndDo;
	
	If StrLen(HeaderFormatForCSV) > 0 Then
		HeaderFormatForCSV = Left(HeaderFormatForCSV, StrLen(HeaderFormatForCSV)-1);
	EndIf;
	
	File = New TextWriter(PathToFile);
	File.WriteLine(HeaderFormatForCSV);
	File.Close();
	
EndProcedure

#EndRegion

#Region TimeConsumingOperations

Procedure WriteMappedData(ExportingParameters, StorageAddress) Export
	
	MappedData = ExportingParameters.MappedData;
	MappingObjectName =ExportingParameters.MappingObjectName;
	ImportParameters = ExportingParameters.ImportParameters;
	ColumnsInformation = ExportingParameters.ColumnsInformation;
	
	CreateIfUnmapped = ImportParameters.CreateIfUnmapped;
	UpdateExistingItems = ImportParameters.UpdateExistingItems;
	
	CatalogName = SplitFullObjectName(MappingObjectName).NameOfObject;
	CatalogManager = Catalogs[CatalogName]; //CatalogManager
	
	AccessManagementUsed = False;
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement       = Common.CommonModule("AccessManagement");
		AccessManagementUsed = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Catalogs[CatalogName].EmptyRef());
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		Properties = New Map;
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		EmptyRefToObject = Catalogs[CatalogName].EmptyRef();
		If ModulePropertyManager.UseAddlAttributes(EmptyRefToObject)
			Or ModulePropertyManager.UseAddlInfo(EmptyRefToObject) Then
			ListOfProperties = ModulePropertyManager.ObjectProperties(EmptyRefToObject);
			For Each Property In ListOfProperties Do
				Properties.Insert(String(Property), Property);
			EndDo;
		EndIf;
	EndIf;
	
	PropertiesTable = New ValueTable;
	PropertiesTable.Columns.Add("Property");
	PropertiesTable.Columns.Add("Value");
	
	LineNumber = 0;
	TotalRows = MappedData.Count();
	For Each TableRow In MappedData Do
		
		ClearContactInformation = False;
		LineNumber = LineNumber + 1;
		
		If (ValueIsFilled(TableRow.MappingObject) And Not UpdateExistingItems) 
			Or (Not ValueIsFilled(TableRow.MappingObject) And Not CreateIfUnmapped) Then
				TableRow.RowMappingResult = "Skipped";
				SetProgressPercent(TotalRows, LineNumber);
				Continue;
		EndIf;
		
		If AccessManagementUsed Then
			ModuleAccessManagement.DisableAccessKeysUpdate(True);
		EndIf;
		BeginTransaction();
		Try
			If ValueIsFilled(TableRow.MappingObject) Then
				Block = New DataLock;
				LockItem = Block.Add("Catalog." + CatalogName);
				LockItem.SetValue("Ref", TableRow.MappingObject);
				Block.Lock();
				
				CatalogItem = TableRow.MappingObject.GetObject();
				TableRow.RowMappingResult = "Updated";
				ClearContactInformation = True;
				If CatalogItem = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Product with product ID %1 does not exist.';"),
					TableRow.SKU);
				EndIf;
			Else
				CatalogItem = CatalogManager.CreateItem();
				TableRow.MappingObject = CatalogItem;
				TableRow.RowMappingResult = "Created";
			EndIf;
			
			For Each Column In ColumnsInformation Do 
				If Column.Visible Then
					If StrStartsWith(Column.ColumnName, "ContactInformation_") Then
						CIKindName = StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(Mid(Column.ColumnName, StrLen("ContactInformation_") + 1));
						ContactInformationKind = ContactInformationKinds.Find(CIKindName, "Description");
						If ClearContactInformation Then
							CatalogItem.ContactInformation.Clear();
							ClearContactInformation = False;
						EndIf;
						If ContactInformationKind <> Undefined Then
							If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
								ModuleContactsManager = Common.CommonModule("ContactsManager");
								ContactInformationValue = ModuleContactsManager.ContactsByPresentation(TableRow[Column.ColumnName], ContactInformationKind.Ref);
								ModuleContactsManager.WriteContactInformation(CatalogItem, ContactInformationValue, ContactInformationKind.Ref, ContactInformationKind.Type);
							EndIf;
						EndIf;
					ElsIf StrStartsWith(Column.ColumnName, "AdditionalAttribute_") Then
						AddPropertyValue(PropertiesTable, Properties, "AdditionalAttribute_", Column.ColumnName,  TableRow[Column.ColumnName]);
					ElsIf StrStartsWith(Column.ColumnName, "Property_") Then
						AddPropertyValue(PropertiesTable, Properties, "Property_", Column.ColumnName,  TableRow[Column.ColumnName]);
					Else
						CatalogItem[Column.ColumnName] = TableRow[Column.ColumnName];
					EndIf;
				EndIf;
			EndDo;
			
			SetProgressPercent(TotalRows, LineNumber);
			If Not CatalogItem.CheckFilling() Then
				UserMessages = GetUserMessages(True);
				MessagesText = "";
				Separator = "";
				For Each UserMessage In UserMessages Do
					If ValueIsFilled(UserMessage.Field) Then
						MessagesText = MessagesText + Separator + UserMessage.Text;
						Separator = Chars.LF;
					EndIf;
				EndDo;
				Raise MessagesText;
			EndIf;
			
			CatalogItem.Write();
			// Write properties when an object already exists.
			If PropertiesTable.Count() > 0 And Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManager = Common.CommonModule("PropertyManager");
				ModulePropertyManager.WriteObjectProperties(CatalogItem.Ref, PropertiesTable);
			EndIf;
			If AccessManagementUsed Then
				ModuleAccessManagement.DisableAccessKeysUpdate(False);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			If AccessManagementUsed Then
				ModuleAccessManagement.DisableAccessKeysUpdate(False, False);
			EndIf;
			ErrorInfo = ErrorInfo();
			TableRow.RowMappingResult = "Skipped";
			TableRow.ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t save the item of the ""%1"" catalog. Reason:
				|%2';"), 
				CatalogName, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
				CatalogManager, CatalogItem.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	StorageAddress = PutToTempStorage(MappedData, StorageAddress);
	
EndProcedure

Procedure SetProgressPercent(Total, LineNumber)
	Percent = LineNumber * 50 / Total;
	ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
	ModuleTimeConsumingOperations.ReportProgress(Percent);
EndProcedure

Procedure GenerateReportOnBackgroundImport(ExportingParameters, StorageAddress) Export
	
	TableReport = ExportingParameters.TableReport; // SpreadsheetDocument
	MappedData  = ExportingParameters.MappedData;
	ColumnsInformation  = ExportingParameters.ColumnsInformation;
	TemplateWithData = ExportingParameters.TemplateWithData;
	ReportType = ExportingParameters.ReportType;
	CalculateProgressPercent = ExportingParameters.CalculateProgressPercent;
	
	If Not ValueIsFilled(ReportType) Then
		ReportType = "AllItems";
	EndIf;
	
	GenerateReportTemplate(TableReport, TemplateWithData);
	
	CreatedItemsCount = 0;
	UpdatedItemsCount = 0;
	SkippedItemsCount = 0;
	ItemsSkippedWithErrorCount = 0;
	For LineNumber = 1 To MappedData.Count() Do
		String = MappedData.Get(LineNumber - 1);
		
		Cell = TableReport.GetArea(LineNumber + 1, 1, LineNumber + 1, 1);
		Cell.CurrentArea.Text = ImportStatusPresentation(String.RowMappingResult);
		Cell.CurrentArea.Details = String.MappingObject;
		Cell.CurrentArea.Comment.Text = String.ErrorDescription;
		If String.RowMappingResult = "Created" Then 
			Cell.CurrentArea.TextColor = StyleColors.SuccessResultColor;
			CreatedItemsCount = CreatedItemsCount + 1;
		ElsIf String.RowMappingResult = "Updated" Then
			Cell.CurrentArea.TextColor = StyleColors.NoteText;
			UpdatedItemsCount = UpdatedItemsCount + 1;
		Else
			Cell.CurrentArea.TextColor = StyleColors.InaccessibleCellTextColor;
			SkippedItemsCount = SkippedItemsCount + 1;
			If ValueIsFilled(String.ErrorDescription) Then
				ItemsSkippedWithErrorCount = ItemsSkippedWithErrorCount + 1;
			EndIf;
		EndIf;
		
		If ReportType = "New_Items" And String.RowMappingResult <> "Created" Then
			Continue;
		EndIf;
		
		If ReportType = "Updated2" And String.RowMappingResult <> "Updated" Then 
			Continue;
		EndIf;
		
		If ReportType = "Skipped2" And String.RowMappingResult <> "Skipped" Then 
			Continue;
		EndIf;
		
		TableReport.Put(Cell);
		For IndexOf = 1 To ColumnsInformation.Count() Do 
			Cell = TableReport.GetArea(LineNumber + 1, IndexOf + 1, LineNumber + 1, IndexOf + 1);
			
			Filter = New Structure("Position", IndexOf);
			FoundColumns = ColumnsInformation.FindRows(Filter);
			If FoundColumns.Count() > 0 Then 
				ColumnName = FoundColumns[0].ColumnName;
				Cell.CurrentArea.Details = String.MappingObject;
				Cell.CurrentArea.Text = String[ColumnName];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			EndIf;
			TableReport.Join(Cell);
			
		EndDo;
		
		If CalculateProgressPercent Then 
			Percent = Round(LineNumber * 50 / MappedData.Count()) + 50;
			ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
			ModuleTimeConsumingOperations.ReportProgress(Percent);
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("ReportType", ReportType);
	Result.Insert("Total", MappedData.Count());
	Result.Insert("CreatedOn", CreatedItemsCount);
	Result.Insert("Updated3", UpdatedItemsCount);
	Result.Insert("Skipped3", SkippedItemsCount);
	Result.Insert("Invalid2", ItemsSkippedWithErrorCount);
	Result.Insert("TableReport", TableReport);
	
	StorageAddress = PutToTempStorage(Result, StorageAddress); 
	
EndProcedure

Procedure GenerateReportTemplate(TableReport, TemplateWithData)
	
	TableReport.Clear();
	Cell = TemplateWithData.GetArea(1, 1, 1, 1);
	
	TableHeader = TemplateWithData.GetArea("R1");
	FillTemplateHeaderCell(Cell, NStr("en = 'Status';"), 12, NStr("en = 'Data import result';"), True);
	TableReport.Join(TableHeader); 
	TableReport.InsertArea(Cell.CurrentArea, TableReport.Area("C1"), SpreadsheetDocumentShiftType.Horizontal);
	
	TableReport.FixedTop = 1;
EndProcedure

Function ImportStatusPresentation(Status)
	
	If Status = "Created" Then
		Return NStr("en = 'Created';");
	ElsIf Status = "Updated" Then
		Return NStr("en = 'Updated';");
	ElsIf Status = "Skipped" Then
		Return NStr("en = 'Skipped';");
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion

//Functional options ///////////////////////////////////////

// Returns attribute columns dependent on functional options.
//
// Parameters:
//  FullObjectName - String - a full object description.
// Returns:
//   -  Map of KeyAndValue:
//       * Key - String - Column name.
//       * Value - Boolean - Availability flag.
//
Function ColumnsDependentOnFunctionalOptions(FullObjectName)
	
	FunctionalOptionsInfo = New Map;
	ObjectNameWithSuffixAttribute = FullObjectName + ".Attribute.";
	
	FunctionalOptions = StandardSubsystemsCached.ObjectsEnabledByOption();
	For Each FunctionalOption In FunctionalOptions Do
		
		If StrStartsWith(FunctionalOption.Key, ObjectNameWithSuffixAttribute) Then
			FunctionalOptionsInfo.Insert(Mid(FunctionalOption.Key, StrLen(ObjectNameWithSuffixAttribute) + 1), FunctionalOption.Value);
		EndIf;
		
	EndDo;
	
	Return FunctionalOptionsInfo;
	
EndFunction

//Service methods ///////////////////////////////////////////

Procedure AddPropertyValue(PropertiesTable, Properties, Prefix, ColumnName, Value)
	PropertyName = TrimAll(StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(Mid(ColumnName, StrLen(Prefix) + 1)));
	Property = Properties.Get(PropertyName); // ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
	If Property <> Undefined Then
		NewPropertiesRow = PropertiesTable.Add();
		NewPropertiesRow.Property = Property.Ref;
		NewPropertiesRow.Value = Value;
	EndIf;
EndProcedure

// Returns a string constant for generating event log messages.
//
// Returns:
//   String
//
Function EventLogEvent() 
	
	Return NStr("en = 'Import data from spreadsheet';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion

#EndIf