#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  SupplierInvoiceRef - DocumentRef.SupplierInvoice - ref to Supplier invoice.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(SupplierInvoiceRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.Supplier AS Supplier,
	|	SupplierInvoice.Warehouse AS Warehouse,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplier AS Multiplier
	|INTO DocumentHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Supplier AS Counterparty,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	DocumentHeader.Ref AS Document,
	|	SupplierInvoiceInventory.Product AS Product,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.Amount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Amount,
	|	SupplierInvoiceInventory.VATAmount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS VATAmount,
	|	SupplierInvoiceInventory.Total * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Total
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON DocumentHeader.Ref = SupplierInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity,
	|	SUM(DocumentInventory.Amount) AS Amount
	|INTO ProductTable
	|FROM
	|	DocumentInventory AS DocumentInventory
	|		INNER JOIN Catalog.Products AS Products
	|		ON DocumentInventory.Product = Products.Ref
	|			AND (Products.ProductType = VALUE(Enum.ProductTypes.Inventory))
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Period,
	|	DocumentInventory.Warehouse
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Supplier AS Counterparty,
	|	DocumentHeader.Ref AS InvoiceDocument,
	|	AdvanceClearing.Document AS Document,
	|	AdvanceClearing.Amount AS Amount
	|INTO DocumentAdvanceClearing
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.AdvanceClearing AS AdvanceClearing
	|		ON DocumentHeader.Ref = AdvanceClearing.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.Document AS PurchaseDocument,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity,
	|	SUM(DocumentInventory.Amount) AS Amount,
	|	SUM(DocumentInventory.VATAmount) AS VATAmount
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Counterparty,
	|	DocumentInventory.Period,
	|	DocumentInventory.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductTable.Period AS Period,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.Product AS Product,
	|	ProductTable.Quantity AS Quantity
	|FROM
	|	ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentInventory.Period AS Period,
	|	VALUE(Enum.LiabilityTypes.Liability) AS LiabilityType,
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.Document AS Document,
	|	SUM(DocumentInventory.Total) AS Amount
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Document,
	|	DocumentInventory.Period,
	|	DocumentInventory.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentAdvanceClearing.Period,
	|	VALUE(Enum.LiabilityTypes.Advance),
	|	DocumentAdvanceClearing.Counterparty,
	|	DocumentAdvanceClearing.Document,
	|	SUM(DocumentAdvanceClearing.Amount)
	|FROM
	|	DocumentAdvanceClearing AS DocumentAdvanceClearing
	|
	|GROUP BY
	|	DocumentAdvanceClearing.Document,
	|	DocumentAdvanceClearing.Period,
	|	DocumentAdvanceClearing.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentAdvanceClearing.Period,
	|	VALUE(Enum.LiabilityTypes.Liability),
	|	DocumentAdvanceClearing.Counterparty,
	|	DocumentAdvanceClearing.InvoiceDocument,
	|	SUM(DocumentAdvanceClearing.Amount)
	|FROM
	|	DocumentAdvanceClearing AS DocumentAdvanceClearing
	|
	|GROUP BY
	|	DocumentAdvanceClearing.Period,
	|	DocumentAdvanceClearing.InvoiceDocument,
	|	DocumentAdvanceClearing.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductTable.Period AS Period,
	|	ProductTable.Product AS Product,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.Quantity AS Quantity,
	|	ProductTable.Amount AS Amount
	|FROM
	|	ProductTable AS ProductTable";
	
	Query.SetParameter("Ref", SupplierInvoiceRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult[4].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[5].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableSupplierBalance", QueryResult[6].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[7].Unload());
	
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.PrintManager = "PrintManagement";
	PrintCommand.Id = "Document.SupplierInvoice.PF_MXL_GoodsReceivedNote";
	PrintCommand.Presentation = NStr("en = 'Goods received note'");
	
EndProcedure

// End StandardSubsystems.Print

// StandardSubsystems.Interactions

// Gets a counterparty of the document.
//
// Parameters:
//  Ref - DocumentRef.SupplierInvoice - document whose contacts are to be received.
//
// Returns:
//  Array - an array that contains document contacts.
//
Function GetContacts(Ref) Export
	
	Result = New Array;
	
	If Not ValueIsFilled(Ref) Then
		Return Result;
	EndIf;
	
	Query = New Query;
	Query.Text = ContactsQueryText();
	Query.SetParameter("Ref", Ref);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("Contact");
	EndIf;
	
	Return Result;
	
EndFunction

// Gets a text of the query by interaction contacts contained in the document.
//
// Parameters:
//  IsUnion - Boolean - "UNION" using in the query
//
// Returns:
//  String
//
Function ContactsQueryText(IsUnion = False) Export
	
	QueryText =
	"SELECT
	|	SupplierInvoice.Supplier AS Contact
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|	AND SupplierInvoice.Supplier <> VALUE(Catalog.Counterparties.EmptyRef)";
	
	If IsUnion Then
		QueryText = JetServer.GetQueryUnion() + QueryText;
	EndIf;
	
	Return QueryText;
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.MessagesTemplates

// Called when preparing message templates. Overrides the list of attributes and attachments.
//
// Parameters:
//  Attributes - See MessageTemplatesOverridable.OnPrepareMessageTemplate.Attributes
//  Attachments  - See MessageTemplatesOverridable.OnPrepareMessageTemplate.Attachments
//  AdditionalParameters - Structure - Additional information about the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, AdditionalParameters) Export

EndProcedure

// Called when creating a message from a template. Populates values in attributes and attachments.
//
// Parameters:
//  Message - Structure:
//    * AttributesValues - Map of KeyAndValue - List of template's attributes:
//      ** Key     - String - Template's attribute name.
//      ** Value - String - Template's filling value.
//    * CommonAttributesValues - Map of KeyAndValue - List of template's common attributes:
//      ** Key     - String - Template's attribute name.
//      ** Value - String - Template's filling value.
//    * Attachments - Map of KeyAndValue:
//      ** Key     - String - Template's attachment name.
//      ** Value - BinaryData
//                  - String - binary data or an address in a temporary storage of the attachment.
//  MessageSubject - AnyRef - The reference to a data source object.
//  AdditionalParameters - Structure -  Additional information about a message template.
//
Procedure OnCreateMessage(Message, MessageSubject, AdditionalParameters) Export

EndProcedure

// Populates a list of recipients (in case the message is generated from a template).
//
// Parameters:
//   SMSMessageRecipients - ValueTable:
//     * PhoneNumber - String - Recipient's phone number.
//     * Presentation - String - Recipient presentation.
//     * Contact       - Arbitrary - The contact this phone number belongs to.
//  MessageSubject - AnyRef - The reference to a data source object.
//                   - Structure  - Structure that describes template parameters:
//    * SubjectOf               - AnyRef - The reference to a data source object.
//    * MessageKind - String - Message type: Email or SMSMessage.
//    * ArbitraryParameters - Map - List of arbitrary parameters.
//    * SendImmediately - Boolean - Flag indicating whether the message must be sent immediately.
//    * MessageParameters - Structure - Additional message parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, MessageSubject) Export

EndProcedure

// Populates a list of recipients (in case the message is generated from a template).
//
// Parameters:
//   EmailRecipients - ValueTable - List of message recipients:
//     * SendingOption - String - Messaging options: "Whom" (To), "Copy" (CC), "HiddenCopy" (BCC), and "ReplyTo".
//     * Address           - String - Recipient's email address.
//     * Presentation   - String - Recipient presentation.
//     * Contact         - Arbitrary - The contact this email address belongs to.
//  MessageSubject - AnyRef - The reference to a data source object.
//                   - Structure  - Structure that describes template parameters:
//    * SubjectOf               - AnyRef - The reference to a data source object.
//    * MessageKind - String - Message type: Email or SMSMessage.
//    * ArbitraryParameters - Map - List of arbitrary parameters.
//    * SendImmediately - Boolean - Flag indicating whether the message must be sent immediately.
//    * MessageParameters - Structure - Additional message parameters.
//    * ConvertHTMLForFormattedDocument - Boolean - Flag indicating whether the HTML text must be converted.
//             Applicable to messages containing images.
//             Required due to the specifics of image output in formatted documents. 
//    * Account - CatalogRef.EmailAccounts - Sender's email account.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, MessageSubject) Export

EndProcedure

// End StandardSubsystems.MessagesTemplates

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