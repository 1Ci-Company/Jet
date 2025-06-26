#If Server Or ExternalConnection Then

#Region Public

// StandardSubsystems.ImportDataFromFile

// Overrides parameters of data import from a file.
//
// Parameters:
//  Parameters - Structure:
//   * DataStructureTemplateName - String - Template description. For example, "ImportingFromFile".
//   * TabularSectionName - String - Table full name. For example, "Document._DemoCustomerProformaInvoice.TabularSection.Goods".
//   * RequiredColumns2 - Array of String - Descriptions of required columns.
//   * ColumnDataType - Map of KeyAndValue:
//      * Key - String - Column name.
//      * Value - TypeDescription - Column type.
//   * AdditionalParameters - Structure
//
Procedure SetDownloadParametersFromVHFFile(Parameters) Export
	
EndProcedure

// Maps data being imported to the TabSectionFullName table
// with infobase data and populates the AddressOfMappingTable and AmbiguityList parameters.
// AmbiguityList contains a list of infobase objects suggested for an ambiguous cell value.
// 
// Parameters:
//   ImportedDataAddress - String - The address of temporary storage containing a table of data imported from the file.
//     Column list:
//     * Id - Number - Row number.
//       Other columns repeat ImportingFromFile template columns.
//   MappingTableAddress - String - Temporary storage address containing an emptytable, that is a copy of a spreadsheet document.
//                                  The table must be populated with values from the ImportedDataAddress table.
//   AmbiguityList - ValueTable - List of ambiguous values:
//     * Column - String - Name of the column where an ambiguous value was found.
//     * Id - Number - ID of the row where an ambiguous value was found.
//   TabSectionFullName - String - The full name of the recipient table.
//   AdditionalParameters - Arbitrary - Any additional information.
//
Procedure MapDataToImport(ImportedDataAddress, MappingTableAddress, AmbiguityList, TabSectionFullName, AdditionalParameters) Export
	
	InventoryTable = GetFromTempStorage(MappingTableAddress);
	ImportedData = GetFromTempStorage(ImportedDataAddress);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ImportedData.Product AS Product,
	|	ImportedData.Id AS Id
	|INTO ImportedData
	|FROM
	|	&ImportedData AS ImportedData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Products.Ref) AS Ref,
	|	ImportedData.Id AS Id,
	|	COUNT(ImportedData.Id) AS Count
	|FROM
	|	ImportedData AS ImportedData
	|		INNER JOIN Catalog.Products AS Products
	|		ON (Products.Description = (CAST(ImportedData.Product AS STRING(100))))
	|
	|GROUP BY
	|	ImportedData.Id";
	
	Query.SetParameter("ImportedData", ImportedData);
	
	ProductTable = Query.Execute().Unload();
	
	For Each ImportedRow In ImportedData Do
		
		NewRow = InventoryTable.Add();
		NewRow.Id = ImportedRow.Id;
		NewRow.NewPrice = ImportedRow.NewPrice;
		
		ProductRow = ProductTable.Find(ImportedRow.Id, "Id");
		If ProductRow <> Undefined Then
			If ProductRow.Count = 1 Then
				NewRow.Product = ProductRow.Ref; 
			ElsIf ProductRow.Count > 1 Then
				AmbiguityItem = AmbiguityList.Add();
				AmbiguityItem.Id = ImportedRow.Id;
				AmbiguityItem.Column = "Product";
			EndIf;
		EndIf;
		
	EndDo;
	
	PutToTempStorage(InventoryTable, MappingTableAddress);
	
EndProcedure

// Gets a list of infobase objects suggested for an ambiguous cell value.
// 
// Parameters:
//   TabSectionFullName - String - The full name of the recipient table.
//   AmbiguityList - Array of CatalogRef - Array with ambiguous data.
//   ColumnName - String - The name of the column, where the ambiguity is detected.
//   LoadingValuesStructure - Structure - Import data that caused the ambiguity.
//   AdditionalParameters - Arbitrary - Any additional information.
//
Procedure FillInListOfAmbiguities(TabSectionFullName, AmbiguityList, ColumnName, LoadingValuesStructure, AdditionalParameters) Export
	
	ImportDataFromFileJet.FillInListOfAmbiguities(TabSectionFullName, AmbiguityList, ColumnName, LoadingValuesStructure, AdditionalParameters);
	
EndProcedure

// End StandardSubsystems.ImportDataFromFile

#EndRegion

#EndIf