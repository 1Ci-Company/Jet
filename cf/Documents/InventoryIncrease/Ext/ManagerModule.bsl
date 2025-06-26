#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  InventoryIncreaseRef - DocumentRef.InventoryIncrease - ref to Inventory increase.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(InventoryIncreaseRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryIncrease.Ref AS Ref,
	|	InventoryIncrease.Date AS Date,
	|	InventoryIncrease.Warehouse AS Warehouse
	|INTO DocumentHeader
	|FROM
	|	Document.InventoryIncrease AS InventoryIncrease
	|WHERE
	|	InventoryIncrease.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	InventoryIncreaseInventory.Product AS Product,
	|	InventoryIncreaseInventory.Quantity AS Quantity,
	|	InventoryIncreaseInventory.Amount AS Amount
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|		ON DocumentHeader.Ref = InventoryIncreaseInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Period,
	|	DocumentInventory.Warehouse
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Product AS Product,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	SUM(DocumentInventory.Quantity) AS Quantity,
	|	SUM(DocumentInventory.Amount) AS Amount
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Warehouse,
	|	DocumentInventory.Product,
	|	DocumentInventory.Period";
	
	Query.SetParameter("Ref", InventoryIncreaseRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[2].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[3].Unload());
	
EndProcedure

// StandardSubsystems.Print

// Overrides object's print settings.
//
// Parameters:
//  Settings - See PrintManagement.ObjectPrintingSettings.
//
Procedure OnDefinePrintSettings(Settings) Export
	
	Settings.OnAddPrintCommands = True;
	
EndProcedure

// Populates a list of print commands.
// 
// Parameters:
//  PrintCommands - See PrintManagement.CreatePrintCommandsCollection
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
EndProcedure

// End StandardSubsystems.Print

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
	
	ImportDataFromFileJet.MapDataToImport(ImportedDataAddress, MappingTableAddress, AmbiguityList, TabSectionFullName, AdditionalParameters);
	
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