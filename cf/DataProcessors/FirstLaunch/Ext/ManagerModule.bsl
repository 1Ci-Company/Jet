#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Fills in empty infobase.
//
Procedure FirstLaunch() Export
	
	BeginTransaction();
	
	Try
		
		FillInDataByFirstLaunch();
		
		CommitTransaction();
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error first launch : %1'; tr = 'İlk başlatma hatası : %1'", DefaultLanguageCode),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(NStr("en = 'First launch'; tr = 'Ilk başlatma'", DefaultLanguageCode),
			EventLogLevel.Error,,,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

#Region FillIn

Procedure FillInDataByFirstLaunch()
	
	Path = GetTempFileName("") + "\";
	CreateDirectory(Path);
	FileName = "data.xml";
	
	WriteTemplateToDisk(Path, FileName, "DataXML");
	WriteTemplateToDisk(Path, "TaxExemptionReasons.xml", "TaxExemptionReasons");
	WriteTemplateToDisk(Path, "VATWithholdingCodesRates.xml", "VATWithholdingCodesRates");
	
	FillInDataXML(Path, FileName);
	
EndProcedure

Procedure WriteTemplateToDisk(Path, FileName, TemplateName)
	
	Template = DataProcessors.FirstLaunch.GetTemplate(TemplateName);
	Template.Write(Path + FileName);
	
EndProcedure

Procedure FillInDataXML(Path, FileName)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	DOMDocument = DOMDocument(Path + FileName);
	
	CreatedItems = CreatedItems();
	
	LoadDataXML(DOMDocument, Path);
	
	XPathResult = GetXPathResultByTagName(DOMDocument, "item");
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		
		NodeName = DOMElement.Attributes.GetNamedItem("item_type").NodeValue;
		
		If NodeName = "catalog" Then
			LoadCatalogs(DOMElement, CreatedItems);
		ElsIf NodeName = "constant" Then
			LoadConstants(DOMElement, CreatedItems);
		ElsIf NodeName = "information_register" Then
			LoadInformationRegister(DOMElement, CreatedItems);
		ElsIf NodeName = "sl_data_xml" Then
			DOMElement = XPathResult.IterateNext();
			Continue;
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'There is no event handler for the node ""%1""'; tr = '""%1"" ünitesi için olay işleyicisi yoktur'", DefaultLanguageCode),
				NodeName);
			WriteLogException(ErrorDescription);
		EndIf;
		
		DOMElement = XPathResult.IterateNext();
		
	EndDo;
	
EndProcedure

#EndRegion

#Region LoadDataFromXML

Procedure LoadDataXML(DOMDocument, BasePath)
	
	XPathResult = GetXPathResultByTagName(DOMDocument, "item[@item_type=""sl_data_xml""]");
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		DataPath = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
		LocalPath = BasePath + StrReplace(DataPath, "/", "\");
		
		FillBySLDataXML(LocalPath);
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
EndProcedure

Procedure LoadConstants(DOMElement, CreatedItems)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	ConstantName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		ConstantManager = Constants[ConstantName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot find constant ""%1""'; tr = '""%1"" sabiti bulunamadı'", DefaultLanguageCode),
			ConstantName);
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	CurrentConstantValue = ConstantManager.Get();
	ConstantValue = DOMElement.Attributes.GetNamedItem("value").NodeValue;
	
	NewValue = GetReferenceByValue(CurrentConstantValue, ConstantValue, CreatedItems);
	If NewValue = Undefined And ConstantValue <> Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot find value ""%1"" for constant ""%2""'; tr = '""%2"" sabiti için ""%1"" değeri bulunamadı'", DefaultLanguageCode),
			ConstantValue,
			ConstantName);
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	Try
		ConstantManager.Set(NewValue);
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set value ""%1"" for constant ""%2""'; tr = '""%2"" sabiti için ""%1"" değeri ayarlanamadı'", DefaultLanguageCode),
			ConstantValue,
			ConstantName);
		WriteLogException(ErrorDescription);
	EndTry;
	
EndProcedure

Procedure LoadCatalogs(DOMElement, CreatedItems)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	CatalogName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		CatalogManager = Catalogs[CatalogName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot find catalog ""%1""'; tr = '""%1"" kataloğu bulunamadı'", DefaultLanguageCode),
			CatalogName);
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	CommentType = DOMNodeType.Comment;
	ChildNodes = DomElement.ChildNodes;
	For Each Node In ChildNodes Do
		If Node.NodeType = CommentType Then
			Continue;
		EndIf;
		Attributes = New Structure();
		For Each Attribute In Node.ChildNodes Do
			If ValueIsFilled(Attribute.LocalName) Then
				If Metadata.Catalogs[CatalogName].TabularSections.Find(Attribute.LocalName) <> Undefined Then
					Rows = New Array;
					For Each TS_Attribute In Attribute.ChildNodes Do
						TS_Attributes = New Structure();
						For Each Row In TS_Attribute.ChildNodes Do
							If ValueIsFilled(Row.LocalName) Then
								TS_Attributes.Insert(Row.LocalName, Row.TextContent);
							EndIf;
						EndDo;
						Rows.Add(TS_Attributes);
					EndDo;
					
					Attributes.Insert(Attribute.LocalName, Rows);
				Else
					Attributes.Insert(Attribute.LocalName, Attribute.TextContent);
				EndIf;
			EndIf;
		EndDo;
		
		Try
			
			ItemRef = Undefined;
			IsPredefinedElement = False;
			PredefinedKey = Undefined;
			
			Attributes.Property("Predefined", PredefinedKey);
			If ValueIsFilled(PredefinedKey) Then
				IsPredefinedElement = Boolean(PredefinedKey);
			EndIf;
			
			If IsPredefinedElement Then
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["PredefinedDataName"], CreatedItems);
				PredefinedDataName = Attributes["PredefinedDataName"];
			Else
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["Description"], CreatedItems);
			EndIf;
			
			If ItemRef = Undefined Then
				If Attributes.Property("Folder") = True Then
					Item = CatalogManager.CreateFolder();
				Else
					Item = CatalogManager.CreateItem();
					If Attributes.Property("ItemUUID") Then
						New_UID = New UUID(Attributes.ItemUUID);
						NewRef = CatalogManager.GetRef(New_UID);
						Item.SetNewObjectRef(NewRef);
					EndIf;
				EndIf;
			Else
				Item = ItemRef.GetObject();
			EndIf;
			
			DeleteKeyInStructure(Attributes, "Predefined");
			DeleteKeyInStructure(Attributes, "PredefinedDataName");
			DeleteKeyInStructure(Attributes, "Folder");
			DeleteKeyInStructure(Attributes, "Ref");
			
			For Each Attribute In Attributes Do
				If Metadata.Catalogs[CatalogName].TabularSections.Find(Attribute.Key) <> Undefined Then
					Item[Attribute.Key].Clear();
					For Each RowAttributes In Attribute.Value Do
						NewRow = Item[Attribute.Key].Add();
						For Each RowAttribute In RowAttributes Do
							NewRow[RowAttribute.Key] = GetReferenceByValue(NewRow[RowAttribute.Key], RowAttribute.Value, CreatedItems);
						EndDo;
					EndDo;
				Else
					Item[Attribute.Key] = GetReferenceByValue(Item[Attribute.Key], Attribute.Value, CreatedItems);
				EndIf;
			EndDo;
			
			Item.Write();
			
			AddCreatedItem(CreatedItems, Item);
			
		Except
			
			If IsPredefinedElement Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save predefined item ""%1"" to catalog ""%2""'; tr = '""%1"" öntanımlı öğesi ""%2"" kataloğuna kaydedilemiyor'", DefaultLanguageCode),
					PredefinedDataName,
					CatalogName);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save item ""%1"" to catalog ""%2""'; tr = '""%1"" öğesi ""%2"" kataloğuna kaydedilemiyor'", DefaultLanguageCode),
					Attributes["Description"],
					CatalogName);
			EndIf;
			
			WriteLogException(ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure LoadInformationRegister(DOMElement, CreatedItems)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	RegisterName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		RegisterManager = InformationRegisters[RegisterName];
	Except
		ErrorDescription = NStr("en = 'Cannot find information register  ""%1""'; tr = '""%1"" bilgi kaydı bulunamadı'", DefaultLanguageCode);
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, RegisterName);
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	RecorsNodes = DomElement.ChildNodes;
	For Each RecordNode In RecorsNodes Do
		
		NewRecord = RegisterManager.CreateRecordManager();
		For Each Attribute In RecordNode.ChildNodes Do
			
			AttributeName = Attribute.TagName;
			
			Try
				RecordAttribute = NewRecord[Attribute.TagName];
			Except
				ErrorDescription = NStr("en = 'There is no attribute ""%1"" in information register ""%2""'; tr = '""%2"" bilgi kaydında ""%1"" özelliği yok'", DefaultLanguageCode);
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescription,
					AttributeName,
					RegisterName);
				WriteLogException(ErrorDescription);
				Return;
			EndTry;
			
			AttributeValue = Attribute.TextContent;
			
			InfobaseObject = GetReferenceByValue(RecordAttribute, AttributeValue, CreatedItems);
			If InfobaseObject = Undefined And AttributeValue <> Undefined Then
				ErrorDescription =  NStr("en = 'Cannot find value ""%1"" for information register ""%2""'; tr = '""%2"" bilgi kaydı için ""%1"" değeri bulunamadı'", DefaultLanguageCode);
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescription,
					AttributeValue,
					RegisterName);
				WriteLogException(ErrorDescription);
				Return;
			EndIf;
			
			NewRecord[Attribute.TagName] = InfobaseObject;
			
		EndDo;
		
		Try
			NewRecord.Write();
		Except
			WriteLogException();
			Return;
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region DOMDocument

Function DOMDocument(Path)
	
	XMLReader = New XMLReader;
	DOMBuilder = New DOMBuilder;
	XMLReader.OpenFile(Path);
	DOMDocument = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Return DOMDocument;
	
EndFunction

Function GetXPathResultByTagName(DOMDocument, TagName)
	
	Resolver = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression("//xmlns:" + TagName, DOMDocument, Resolver);
	
	Return XPathResult;
	
EndFunction

#EndRegion

#Region CreatedItems

Function CreatedItems()
	
	CreatedItems = New ValueTable;
	CreatedItems.Columns.Add("Type");
	CreatedItems.Columns.Add("Description");
	CreatedItems.Columns.Add("Ref");
	
	Return CreatedItems;
	
EndFunction

Procedure AddCreatedItem(CreatedItems, NewObject)
	
	NewItem = CreatedItems.Add();
	NewItem.Type		= TypeOf(NewObject.Ref);
	NewItem.Description	= NewObject.Description;
	NewItem.Ref			= NewObject.Ref;
	
EndProcedure

#EndRegion

#Region Other

Function GetReferenceByValue(EmptyValue, Val NewValue, CreatedItems, FillingCheck = True)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	InfobaseObject = Undefined;
	
	If EmptyValue = Undefined Then
		
		TypeOfEmptyValue = Undefined;
		
		StringsArray = StrSplit(NewValue, ":");
		If StringsArray.Count() = 2 Then
			TypeOfEmptyValue = Type(StringsArray[0]);
			NewValue = StringsArray[1];
			
			If TypeOfEmptyValue = Type("Number") Then
				InfobaseObject = Number(NewValue);
			ElsIf TypeOfEmptyValue = Type("Boolean") Then
				InfobaseObject = Boolean(NewValue);
			ElsIf TypeOfEmptyValue = Type("UUID") Then
				InfobaseObject = New UUID(NewValue);
			ElsIf Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue) Then
				Try
					InfobaseObject = Eval(NewValue);
				Except
					InfobaseObject = Undefined;
				EndTry;
			EndIf;
		EndIf;
		
		If TypeOfEmptyValue = Undefined Or InfobaseObject <> Undefined Then
			Return InfobaseObject;
		EndIf;
		
	Else
		TypeOfEmptyValue = TypeOf(EmptyValue);
	EndIf;

	If TypeOfEmptyValue = Type("Number")
		Or TypeOfEmptyValue = Type("String")
		Or TypeOfEmptyValue = Type("Date")
		Or TypeOfEmptyValue = Type("Boolean")
		Or TypeOfEmptyValue = Type("UUID") Then
		
		InfobaseObject = NewValue;
		
	ElsIf Enums.AllRefsType().ContainsType(TypeOfEmptyValue) Then
		
		ValueType = EmptyValue.Metadata();
		InfobaseObject = Enums[ValueType.Name][NewValue];
		
	ElsIf TypeOfEmptyValue = Type("ValueStorage") Then
		
		Try
			InfobaseObject = New ValueStorage(Eval(NewValue));
		Except
			If FillingCheck Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot find metadata ""%1"" for type ""%2""'; tr = '""%2"" türü için ""%1"" metaverisi bulunamadı'", DefaultLanguageCode),
					NewValue,
					TypeOfEmptyValue);
				WriteLogException(ErrorDescription)
			EndIf;
		EndTry;
		
	Else
		Filter = New Structure("Type, Description", TypeOfEmptyValue, NewValue);
		FoundedElements = CreatedItems.FindRows(Filter);
		If FoundedElements.Count() > 0 Then
			InfobaseObject = FoundedElements[0].Ref;
		Else
			If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue) Then
				
				MetadataObject = EmptyValue.Metadata();
				PredefinedElements = MetadataObject.GetPredefinedNames();
				
				Index = PredefinedElements.Find(NewValue);
				If Index <> Undefined Then
					ValueType = EmptyValue.Metadata();
					TypeManager = Common.ObjectManagerByFullName(ValueType.FullName());
					InfobaseObject = TypeManager[NewValue];
				EndIf;
				
			EndIf;
				
			If InfobaseObject = Undefined Then
				If Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue)
					Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue) Then
					
					ValueType = EmptyValue.Metadata();
					TypeManager = Common.ObjectManagerByFullName(ValueType.FullName());
					
					FoundedObject = TypeManager.FindByDescription(NewValue, True);
					If Not ValueIsFilled(FoundedObject) Then
						FoundedObject = TypeManager.FindByCode(NewValue);
					EndIf;
					
					If ValueIsFilled(FoundedObject) Then
						InfobaseObject = FoundedObject;
					EndIf;
					
				ElsIf FillingCheck Then
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Can''t find metadata ""%1"" for type ""%2""'; tr = '""%2"" türü için ""%1"" metaverisi bulunamadı'", DefaultLanguageCode),
						NewValue,
						TypeOfEmptyValue);
					WriteLogException(ErrorDescription)
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return InfobaseObject;
	
EndFunction

Procedure WriteLogException(ErrorDescription = Undefined)
	
	If Not ValueIsFilled(ErrorDescription) Then
		ErrorDescription = BriefErrorDescription(ErrorInfo());
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'First launch'; tr = 'Ilk başlatma'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		Metadata.DataProcessors.FirstLaunch,,
		ErrorDescription);
	
	Raise ErrorDescription;
	
EndProcedure

Procedure DeleteKeyInStructure(Structure, KeyName)
	
	If Structure.Property(KeyName) Then
		Structure.Delete(KeyName);
	EndIf;
	
EndProcedure

Function FillBySLDataXML(Val FileName)
	
	File = New File(FileName);
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FileName);
	If Not XMLReader.Read()
		Or XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "_1CV8DtUD"
		Or XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		IncorrectFormatException();
		Return False;
		
	ElsIf Not XMLReader.Read()
		Or XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Data" Then
		
		IncorrectFormatException();
		Return False;
		
	EndIf;
	
	RefReplaceMap = New Map;
	
	LoadPredifinedTable(XMLReader, RefReplaceMap);
	ReplaceRefToPredefined(FileName, RefReplaceMap);
	
	XMLReader.OpenFile(FileName);
	XMLReader.Read();
	XMLReader.Read();
	
	If Not XMLReader.Read() Then 
		IncorrectFormatException();
		Return False;
	EndIf;
	
	Serializer = InitializateSerializatorXDTOWithAnnotationTypes();
	While Serializer.CanReadXML(XMLReader) Do
		
		Try
			WriteValue = Serializer.ReadXML(XMLReader);
		Except
			Raise;
		EndTry;
		
		Try
			WriteValue.DataExchange.Load = True;
		Except
		EndTry;
		
		Try
			WriteValue.Write();
		Except
			
			Try
				MessageText = NStr("en = 'In loading process for Object %1(%2) raised error: %3'; tr = 'Nesne %1(%2) için yükleme işleminde hata oluştu: %3'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
					WriteValue,
					TypeOf(WriteValue),
					ErrorDescription());
			Except
				MessageText = NStr("en = 'In loading data process raised error: %1'; tr = 'Veri yükleme aşamasında hata oluştu: %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription());
			EndTry;
			
			Common.MessageToUser(MessageText);
			
		EndTry;
		
	EndDo;
	
	If XMLReader.NodeType <> XMLNodeType.EndElement Or XMLReader.LocalName <> "Data" Then
		IncorrectFormatException();
		Return False;
	EndIf;
	
	If Not XMLReader.Read()
		Or XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "PredefinedData" Then
		
		IncorrectFormatException();
		Return False;
		
	EndIf;
	
	XMLReader.Skip();
	
	If Not XMLReader.Read()
		Or XMLReader.NodeType <> XMLNodeType.EndElement
		Or XMLReader.LocalName <> "_1CV8DtUD"
		Or XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		IncorrectFormatException();
		Return False;
		
	EndIf;
	
	XMLReader.Close();
	
	Return True;
	
EndFunction

Procedure IncorrectFormatException()
	
	Raise NStr("en = 'Incorrect file format.'; tr = 'Yanlış dosya formatı.'");
	
EndProcedure

Function InitializatePredifinedTable()
	
	PredifinedTable = New ValueTable;
	PredifinedTable.Columns.Add("TableName");
	PredifinedTable.Columns.Add("Ref");
	PredifinedTable.Columns.Add("PredefinedDataName");
	
	Return PredifinedTable;
	
EndFunction

Procedure LoadPredifinedTable(XMLReader, RefReplaceMap)
	
	XMLReader.Skip();
	XMLReader.Read();
	
	PredifinedTable = InitializatePredifinedTable();
	TempRow = PredifinedTable.Add();
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			If XMLReader.LocalName <> "item" Then
				
				TempRow.TableName = XMLReader.LocalName;
				
				TextQuery = 
				"Select
				|	Table.Ref AS Ref
				|From
				|	" + TempRow.TableName + " AS Table
				|Where
				|	Table.PredefinedDataName = &PredefinedDataName";
				Query = New Query(TextQuery);
				
			Else
				
				While XMLReader.ReadAttribute() Do
					TempRow[XMLReader.LocalName] = XMLReader.Value;
				EndDo;
				
				CheckPredefinedValue(TempRow.TableName, TempRow.PredefinedDataName);
				
				Query.SetParameter("PredefinedDataName", TempRow.PredefinedDataName);
				
				QueryResult = Query.Execute();
				If Not QueryResult.IsEmpty() Then
					
					Selection = QueryResult.Select();
					If Selection.Count() = 1 Then
						
						Selection.Next();
						
						RefInIB = XMLString(Selection.Ref);
						RefInFile = TempRow.Ref;
						
						If RefInIB <> RefInFile Then
							
							XMLType = XMLTypeOfRef(Selection.Ref);
							MapType = RefReplaceMap.Get(XMLType);
							If MapType = Undefined Then
								MapType = New Map;
								MapType.Insert(RefInFile, RefInIB);
								RefReplaceMap.Insert(XMLType, MapType);
							Else
								MapType.Insert(RefInFile, RefInIB);
							EndIf;
							
						EndIf;
						
					Else
						
						Raise StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Predefined elements %1 are duplicated in table %2.'; tr = 'Ön tanımlı %1 öğeler tabloda çoğaltıldı %2.'"),
							TempRow.PredefinedDataName, 
							TempRow.TableName);
						
					EndIf;
					
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure CheckPredefinedValue(TableName, PredefinedDataName)
	
	PredefinedItemStr = TableName + "." + PredefinedDataName;
	
	Try
		PredefinedItem = PredefinedValue(PredefinedItemStr);
	Except
		MessageText = NStr("en = 'Predefined object ""%1"" does not exist'; tr = '""%1"" öntanımlı nesnesi mevcut değil'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageText,
			PredefinedItemStr);
		Raise MessageText;
	EndTry;
	
EndProcedure

Function InitializateSerializatorXDTOWithAnnotationTypes()
	
	TypeWithAnotationsRef = PredifinedTypeForUnload();
	
	If TypeWithAnotationsRef.Count() > 0 Then
		Factory = FactoryWithTypes(TypeWithAnotationsRef);
		Serializer = New XDTOSerializer(Factory);
	Else
		Serializer = XDTOSerializer;
	EndIf;
	
	Return Serializer;
	
EndFunction

Function PredifinedTypeForUnload()
	
	Types = New Array;
	
	For Each MetadataObject In Metadata.Catalogs Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfAccounts Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCharacteristicTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCalculationTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	Return Types;
	
EndFunction

Function FactoryWithTypes(Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	SpecifiedTypes = New Map;
	For Each Type In Types Do
		SpecifiedTypes.Insert(XMLTypeOfRef(Type), True);
	EndDo;
	
	NameSpace = New Map;
	NameSpace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(NameSpace);
	TextXPath = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Query = Schema.DOMDocument.CreateXPathExpression(TextXPath, DOMNamespaceResolver);
	Result = Query.Evaluate(Schema.DOMDocument);
	
	While True Do
		
		Node = Result.IterateNext();
		If Node = Undefined Then
			Break;
		EndIf;
		
		TypeAttribute = Node.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SpecifiedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		Node.SetAttribute("nillable", "true");
		Node.RemoveAttribute("type");
		
	EndDo;
	
	XMLWriter = New XMLWriter;
	SchemeFileName = GetTempFileName("xsd");
	XMLWriter.OpenFile(SchemeFileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemeFileName);
	
	Try
		DeleteFiles(SchemeFileName);
	Except
	EndTry;
	
	Return Factory;
	
EndFunction

Function XMLTypeOfRef(Val Value)
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		Ref = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Ref = Value;
	EndIf;
	
	If ObjectFormsReferenceType(MetadataObject) Then
		Return XDTOSerializer.XMLTypeOf(Ref).TypeName;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in definition XMLType reference for object %1: object is not reference.'; tr = '%1 nesne için XMLType referans tanımı hatası: nesne referans nesnesi değil.'"),
			MetadataObject.FullName());
	EndIf;
	
EndFunction

Function ObjectFormsReferenceType(ObjectMD)
	
	If ObjectMD = Undefined Then
		Return False;
	EndIf;
	
	If Metadata.Catalogs.Contains(ObjectMD)
		Or Metadata.Documents.Contains(ObjectMD)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMD)
		Or Metadata.ChartsOfAccounts.Contains(ObjectMD)
		Or Metadata.ChartsOfCalculationTypes.Contains(ObjectMD)
		Or Metadata.ExchangePlans.Contains(ObjectMD)
		Or Metadata.BusinessProcesses.Contains(ObjectMD)
		Or Metadata.Tasks.Contains(ObjectMD) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Procedure ReplaceRefToPredefined(FileName, RefReplaceMap)
	
	ReadFlow = New TextReader(FileName);
	TempFile = GetTempFileName("xml");
	WriteFlow = New TextWriter(TempFile);
	
	StartOfType = "xsi:type=""v8:";
	LengthStartOfType = StrLen(StartOfType);
	EndOfType = """>";
	LengthEndOfType = StrLen(EndOfType);
	
	SourceRow = ReadFlow.ReadLine();
	While SourceRow <> Undefined Do
		
		RemainsOfRow = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceRow, StartOfType);
		While TypePosition > 0 Do
			
			WriteFlow.Write(Mid(SourceRow, CurrentPosition, TypePosition - 1 + LengthStartOfType));
			
			RemainsOfRow = Mid(SourceRow, CurrentPosition + TypePosition + LengthStartOfType - 1);
			CurrentPosition = CurrentPosition + TypePosition + LengthStartOfType - 1;
			
			EndOfTypePosition = Find(RemainsOfRow, EndOfType);
			If EndOfTypePosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainsOfRow, EndOfTypePosition - 1);
			MapReplace = RefReplaceMap.Get(TypeName);
			If MapReplace = Undefined Then
				TypePosition = Find(RemainsOfRow, StartOfType);
				Continue;
			EndIf;
			
			WriteFlow.Write(TypeName);
			WriteFlow.Write(EndOfType);
			
			SourceRowXML = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType, 36);
			
			FindRowXML = MapReplace.Get(SourceRowXML);
			
			If FindRowXML = Undefined Then
				WriteFlow.Write(SourceRowXML);
			Else
				WriteFlow.Write(FindRowXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + EndOfTypePosition - 1 + LengthEndOfType + 36;
			RemainsOfRow = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType + 36);
			TypePosition = Find(RemainsOfRow, StartOfType);
			
		EndDo;
		
		If RemainsOfRow <> Undefined Then
			WriteFlow.WriteLine(RemainsOfRow);
		Else
			WriteFlow.WriteLine(SourceRow);
		EndIf;
		
		SourceRow = ReadFlow.ReadLine();
		
	EndDo;
	
	ReadFlow.Close();
	WriteFlow.Close();
	
	FileName = TempFile;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
