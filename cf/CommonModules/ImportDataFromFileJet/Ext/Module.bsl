
#Region Public

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
	
	IsVATRate = (ImportedData.Columns.Find("VATRate") <> Undefined);
	
	Query = New Query;
	If IsVATRate Then
		Query.Text =
		"SELECT
		|	ImportedData.Product AS Product,
		|	ImportedData.VATRate AS VATRate,
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
		|	ImportedData.Id
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MAX(VATRates.Ref) AS Ref,
		|	ImportedData.Id AS Id
		|FROM
		|	ImportedData AS ImportedData
		|		INNER JOIN Catalog.VATRates AS VATRates
		|		ON (VATRates.Description = (CAST(ImportedData.VATRate AS STRING(25))))
		|
		|GROUP BY
		|	ImportedData.Id";
	Else
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
	EndIf;
	
	Query.SetParameter("ImportedData", ImportedData);
	Result = Query.ExecuteBatch();
	
	ProductTable = Result[1].Unload();
	If IsVATRate Then
		VATRateTable = Result[2].Unload();
	EndIf;
	
	For Each ImportedRow In ImportedData Do
		
		NewRow = InventoryTable.Add();
		NewRow.Id = ImportedRow.Id;
		NewRow.Quantity = ImportedRow.Quantity;
		NewRow.Price = ImportedRow.Price;
		
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
		
		If IsVATRate Then
			VATRateRow = VATRateTable.Find(ImportedRow.Id, "Id");
			If VATRateRow <> Undefined Then
				NewRow.VATRate = VATRateRow.Ref;
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

	If ColumnName <> "Product" Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Products.Ref AS Ref
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	&QueryCondition";
	
	If ValueIsFilled(LoadingValuesStructure.Product) Then
		Query.Text = StrReplace(Query.Text, "&QueryCondition", "Products.Description = &Description");
		Query.SetParameter("Description", LoadingValuesStructure.Product);
	Else
		Query.Text = StrReplace(Query.Text, "&QueryCondition", "TRUE");
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		AmbiguityList.Add(Selection.Ref);
	EndDo;
	
EndProcedure

#EndRegion