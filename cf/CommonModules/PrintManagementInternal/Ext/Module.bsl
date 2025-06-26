///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

#Region PrintingInOfficeOpenXMLFormat

Function GeneratePrintForms(TableOfPrintedForms, GenerationParameters, OfficeDocuments, CombinedDocStructure) Export
	
	If GenerationParameters.Count() Then
		
		PrintObjectsTypes = Undefined;
		AdditionalParameters = New Structure("AddExternalPrintFormsToSet", False);
		ContentOfCombinedDoc = New Map();
		
		For Each PrintFormString In TableOfPrintedForms Do
			If PrintFormString.CreateAgain Then
				AdditionalParameters.Insert("SignatureAndSeal", PrintFormString.SignatureAndSeal);
				ArrayOfPrintObjects = CommonClientServer.ValueInArray(PrintFormString.PrintObject);
				PrintForms = PrintManagement.GeneratePrintForms("PrintManagement", PrintFormString.TemplateName,
					ArrayOfPrintObjects, AdditionalParameters, PrintObjectsTypes, PrintFormString.CurrentLanguage);
					
				If PrintForms.PrintFormsCollection.Count() Then
					PrintFormRow = PrintForms.PrintFormsCollection[0];
					For Each OfficeDocItem In PrintFormRow.OfficeDocuments Do
						OfficeDocument = GetFromTempStorage(OfficeDocItem.Key);
						OfficeDocuments.Insert(PrintFormString.PrintFormAddress, OfficeDocument);
						PutToTempStorage(OfficeDocument, PrintFormString.PrintFormAddress);
						Break;
					EndDo;
				Else
					Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error: Cannot generate %1';"), PrintFormString.Presentation);
				EndIf;
			EndIf;
			
			If PrintFormString.Check Then
				PrintFormProperties = New Structure("SignatureAndSeal, CurrentLanguage");
				PrintFormProperties.SignatureAndSeal = PrintFormString.SignatureAndSeal;
				PrintFormProperties.CurrentLanguage = PrintFormString.CurrentLanguage;
				ContentOfCombinedDoc.Insert(PrintFormString.PrintFormAddress, PrintFormProperties);
			EndIf;
		EndDo;
		
		
		If GenerationParameters.Property("RegenerateCombinedDoc") And GenerationParameters.RegenerateCombinedDoc Then
			
			OfficeDocsToMerge = New Map();
			
			For Each PrintForm In ContentOfCombinedDoc Do
				OfficeDocsToMerge.Insert(PrintForm.Key, OfficeDocuments[PrintForm.Key]);
			EndDo;
			
			CombinedDocStructure.Insert("PrintFormAddress", MergeOfficeDocs(OfficeDocsToMerge, CombinedDocStructure.PrintFormAddress));
			
			Presentation = StrConcat(TableOfPrintedForms.UnloadColumn("Presentation"), ", ");
			If StrLen(Presentation) > 50 Then
				Presentation = Left(Presentation, 50)+"...";
			EndIf;
			
			CombinedDocStructure.Insert("PrintFormFileName", Presentation+".docx");
			CombinedDocStructure.Insert("Presentation", Presentation);
			CombinedDocStructure.Insert("ContentOfCombinedDoc", ContentOfCombinedDoc);
			
		EndIf;
	EndIf;
	Return CombinedDocStructure;		
EndFunction

//////////////////////////////////////////////////////////////////////////////////
// 
//
// 
//
// 
//  
//  
//                                     
//
// 
//  
//                           
//  
//                                     
//
// 
//  
//  
//  
//                                 
//  
//  
//  
//  
//                                               
//  
//  
//  
//
// 
//  
//                                 
//  
//  
//
// 
//  
//  
//  
//
// 
//  
//  
//  
//  
//

// Returns the structure of the printed form for generating the final document.
//
// Parameters:
//  Template - Structure -  layout of the printed form.
//
// Returns:
//  Structure:
//   * DirectoryName        - String -  the path where the directory structure of the final document is placed for the subsequent
//                                   build of the DOCX container.
//   * DocumentStructure - See InitializeDocument
//
Function InitializePrintForm(Template) Export
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	TempDirectoryName = FileSystem.CreateTemporaryDirectory();
	
	CopyDirectoryContent(Template.DirectoryName, TempDirectoryName);
	
	DocumentStructure = InitializeDocument();
	
	PrintForm = New Structure;
	PrintForm.Insert("DirectoryName", TempDirectoryName);
	PrintForm.Insert("DocumentStructure", DocumentStructure);
	
	InitializePrintFormStructure(PrintForm, Template);
	
	Return PrintForm;
	
EndFunction

// Returns the layout structure of the printed form.
// The layout file is populated based on the binary data passed in the function parameters.
//
// Parameters:
//  BinaryTemplateData - BinaryData -  binary layout data.
//
// Returns:
//  Structure -  layout of the printed form.
//
Function TemplateFromBinaryData(BinaryTemplateData) Export
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Extension = DefineDataFileExtensionBySignature(BinaryTemplateData);
	If Extension <> "docx" Then
		ErrorText = NStr("en = 'Incorrect layout format for MS Word template.';");
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorText);
		Raise ErrorText;
	EndIf;
	
	TempFileName = GetTempFileName("docx");
	
	TempDirectoryName = FileSystem.CreateTemporaryDirectory();
	
	BinaryTemplateData.Write(TempFileName);
	
	ParseDOCXDocumentContainer(TempFileName, TempDirectoryName);
	
	DeleteFiles(TempFileName);
	
	DocumentStructure = InitializeDocument();
	
	Template = New Structure;
	Template.Insert("DirectoryName",        TempDirectoryName);
	Template.Insert("DocumentStructure", DocumentStructure);
	
	InitializeTemplateStructure(Template);
			
	Return Template;
	
EndFunction

#Region DCS

// Parameters:
//  BinaryTemplateData - BinaryData
// 
// Returns:
//  Structure:
//    * DirectoryName - String - 
//    * DocumentStructure - See InitializeDCSDoc
//
Function TemplateFromDCSBinaryData(BinaryTemplateData) Export
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Extension = DefineDataFileExtensionBySignature(BinaryTemplateData);
	If Extension <> "docx" Then
		ErrorText = NStr("en = 'Incorrect layout format for MS Word template.';");
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorText);
		Raise ErrorText;
	EndIf;
	
	TempFileName = GetTempFileName("docx");	
	TempDirectoryName = FileSystem.CreateTemporaryDirectory();	
	BinaryTemplateData.Write(TempFileName);
	
	ParseDOCXDocumentContainer(TempFileName, TempDirectoryName);
	
	DeleteFiles(TempFileName);
	
	DocumentStructure = InitializeDCSDoc();
	
	Template = New Structure;
	Template.Insert("DirectoryName",        TempDirectoryName);
	Template.Insert("DocumentStructure", DocumentStructure);
	
	InitializeStructureOfDCSTemplate(Template);
			
	Return Template;
	
EndFunction

// Returns:
//  Structure:
//   * HeaderFooter - Map 
//   * ContentTypes1 - See DocumentTree
//   * ContentRelations - See DocumentTree
//   * PicturesDirectory - String
//   * PicturesExtensions - Array
//   * DocumentID - String
//   * DocumentTree - See DocumentTree
//   * TextParameters - Array
//   * Areas - See TableOfTemplateAreas
//
Function InitializeDCSDoc()
	
	Result = New Structure;
	Result.Insert("HeaderFooter",            New Map);
	Result.Insert("ContentTypes1",           New ValueTree);
	Result.Insert("ContentRelations", 		 New ValueTree);
	Result.Insert("LinkMaxID", 		 0);
	Result.Insert("Hyperlinks",            New Map);
	Result.Insert("PicturesDirectory",        "");
	Result.Insert("PicturesExtensions",     New Array);
	Result.Insert("DocumentID", "");
	Result.Insert("DocumentTree", 		 New ValueTree);
	Result.Insert("TextParameters",     	 New Array);
	
	TableOfAreas = TableOfTemplateAreas();
	Result.Insert("Areas",     	 		 TableOfAreas);	
	
	Return Result;
	
EndFunction

// 
// 
// Returns:
//  ValueTable:
//   * DocTreeNode - See DocumentTree
//   * AreaCondition  - String
//   * Collection - String
//   * IndexOf - Number
//   * AreaTree - See DocumentTree
//   * Parameters - Array
//
Function TableOfTemplateAreas()
	Var TableOfAreas;
	TableOfAreas = New ValueTable;
	TableOfAreas.Columns.Add("DocTreeNode");
	TableOfAreas.Columns.Add("AreaCondition");
	TableOfAreas.Columns.Add("Collection");
	TableOfAreas.Columns.Add("IndexOf");
	TableOfAreas.Columns.Add("AreaTree");
	TableOfAreas.Columns.Add("Parameters");
	TableOfAreas.Columns.Add("NestedAreas");
	Return TableOfAreas
EndFunction

// 
// 
// Parameters:
//  DocumentTree - See PrintManagementInternal.ReadXMLIntoTree
//
Procedure ConvertParameters(DocumentTree) Export
			
	ArrayOfParametersNodes = New Array;
	FindNodesByContent(DocumentTree, "w:fldChar", ArrayOfParametersNodes);
	
	If Not ArrayOfParametersNodes.Count() Then
		Return;
	EndIf;
	
	ArrayOfAreas = New Array;
	AreaArray  = New Array;
	
	For Each ParametersNode In ArrayOfParametersNodes Do
		NodeType = ParametersNode.Attributes["w:fldCharType"];
		
		AreaArray.Add(ParametersNode);
				
		If NodeType = "end" Then
			ArrayOfAreas.Add(AreaArray);
			AreaArray  = New Array;
		EndIf;
		
	EndDo;
	
	For Each AreaArray In ArrayOfAreas Do
		StartNode = AreaArray[0];  // ValueTreeRow of See PrintManagementInternal.ReadXMLIntoTree
		If Not StartNode.Rows.Count() Then
			Continue;
		EndIf;	
		TextEntryNode = FindNodeByContent(StartNode, "w:textInput");
		ValNode	= TextEntryNode.Rows[0];
		StartNode.Text = "["+ValNode.Attributes["w:val"]+"]";
		
		StartNode.Rows.Clear();
		StartNode.NameTag = "w:t";
		StartNode.Attributes.Clear();
		
		
		EndNode = AreaArray[AreaArray.UBound()]; // ValueTreeRow of See PrintManagementInternal.ReadXMLIntoTree
		
		RunThroughBegin = StartNode.Parent;
		RunThroughEnd = EndNode.Parent;
		
		RunThroughBeginIndex = RunThroughBegin.Parent.Rows.IndexOf(RunThroughBegin);
		RunThroughEndIndex = RunThroughEnd.Parent.Rows.IndexOf(RunThroughEnd);
		
		NodesToDeleteCount = RunThroughEndIndex - (RunThroughBeginIndex+1);
		
		For K = 0 To NodesToDeleteCount Do
			RunThroughBegin.Parent.Rows.Delete(RunThroughEndIndex-K);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

// Clears all files associated with the print form or layout of the print form.
// Parameters:
//  PrintForm - Structure -  printed form or layout of the printed form.
//
Procedure CloseConnection(PrintForm) Export
	
	Try
		If SafeMode() <> False Then
			SetSafeModeDisabled(True);
		EndIf;
		
		FileSystem.DeleteTemporaryDirectory(PrintForm.DirectoryName);
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(NStr("en = 'Failed to delete temporary directory where print form template is stored. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Collects the final document from the printed form structure and generates a DOCX data file.
// The data file is placed in temporary storage.
//
// Parameters:
//  PrintForm - Structure
//
// Returns:
//  String - 
//
Function GenerateDocument(PrintForm) Export
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	AreasCount = PrintForm.DocumentStructure.AttachedAreas.Count();
	
	If AreasCount = 0 Then
		DeleteFiles(PrintForm.DirectoryName);
		Return Undefined;
	EndIf;
	
	DocumentPath = AssembleDOCXDocumentFile(PrintForm);
	
	BinaryData = New BinaryData(DocumentPath);
	
	PrintFormStorageAddress = PutToTempStorage(BinaryData, New UUID);
	
	DeleteFiles(DocumentPath);
	DeleteFiles(PrintForm.DirectoryName);
	
	Return PrintFormStorageAddress;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

// Gets the area from the layout.
//
// Parameters:
//  Template      - Structure -  layout of the printed form.
//  AreaName - String -  name of the area in the layout.
//
// Returns:
//  Structure - 
//
Function GetTemplateArea(Template, Val AreaName) Export
	
	Return GetDocumentAreaFromDocumentStructure(Template.DocumentStructure, AreaName);
	
EndFunction

// Gets the header area of the first layout area.
//
// Parameters:
//  Template          - Structure -  layout of the printed form;
//  AreaName - String -  name of the area in the layout;
//  SectionNumber   - Number -  number of the section that includes the header.
//
// Returns:
//  Structure - 
//
Function GetHeaderArea(Template, Val AreaName = "Header", Val SectionNumber = 1) Export
	
	Parameters = StrSplit(AreaName, "_");
	If Parameters.Count() = 2 Then
		AreaName = Parameters[0];
		Try
			SectionNumber = Number(Parameters[1]);
		Except
			SectionNumber = 1;
		EndTry;
	EndIf;
	
	Return GetHeaderOrFooterFromDocumentStructure(Template.DocumentStructure, AreaName, SectionNumber);
	
EndFunction

// Gets the footer area of the first layout area.
//
// Parameters:
//  Template          - Structure -  layout of the printed form;
//  AreaName - String -  name of the area in the layout;
//  SectionNumber   - Number -  number of the section that includes the footer.
//
// Returns:
//  Structure -  the footer area.
//
Function GetFooterArea(Template, Val AreaName = "Footer", Val SectionNumber = 1) Export
	
	Parameters = StrSplit(AreaName, "_");
	If Parameters.Count() = 2 Then
		AreaName = Parameters[0];
		Try
			SectionNumber = Number(Parameters[1]);
		Except
			SectionNumber = 1;
		EndTry;
	EndIf;
	
	Return GetHeaderOrFooterFromDocumentStructure(Template.DocumentStructure, AreaName, SectionNumber);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

// Adds a footer to the printed form from the layout.
//
// Parameters:
//  PrintForm - Structure
//  Footer - Structure -  the footer area.
//
// Returns:
//  Structure - 
//
Function AddFooter(PrintForm, Footer) Export
	
	AddHeaderFooterToDocumentStructure(PrintForm.DocumentStructure, Footer);
	HeaderOrFooterStructure = AttachHeaderOrFooterToDocumentStructure(PrintForm.DocumentStructure, Footer);
	
	Return HeaderOrFooterStructure;
	
EndFunction

// Fills in the footer parameters in the printed form from the layout.
//
// Parameters:
//  PrintForm - See InitializePrintForm
//  Footer    - Structure -  the footer area;
//  ObjectData - Structure -  object data to fill in.
//
Procedure FillFooterParameters(PrintForm, Footer, ObjectData = Undefined) Export
	
	If Not TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	FillAreaParameters(PrintForm, Footer, ObjectData);
	PopulateHyperlinkParameters(PrintForm, Footer, ObjectData);
	
EndProcedure

// Adds a header to the printed form from the layout.
//
// Parameters:
//  PrintForm - Structure
//  Header - Structure -  header and footer area.
//
// Returns:
//  Structure - 
//
Function AddHeader(PrintForm, Header) Export
	
	AddHeaderFooterToDocumentStructure(PrintForm.DocumentStructure, Header);
	HeaderOrFooterStructure = AttachHeaderOrFooterToDocumentStructure(PrintForm.DocumentStructure, Header);
	
	Return HeaderOrFooterStructure;
	
EndFunction

// Fills in the header parameters in the printed form from the layout.
//
// Parameters:
//  PrintForm - See InitializePrintForm
//  Header    - Structure -  the header and footer area;
//  ObjectData - Structure -  object data to fill in.
//
Procedure FillHeaderParameters(PrintForm, Header, ObjectData = Undefined) Export
	
	If Not TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	FillAreaParameters(PrintForm, Header, ObjectData);
	PopulateHyperlinkParameters(PrintForm, Header, ObjectData);
	
EndProcedure

// Adds an area to the print form from the layout, while replacing
// the parameters in the area with values from the object data.
// Used for single output of an area.
//
// Parameters:
//  PrintForm       - See InitializePrintForm
//  TemplateArea       - Structure
//  GoToNextRow - Boolean -  determines whether to insert a break after the area is displayed.
//
// Returns:
//  Structure - 
//
Function AttachArea(PrintForm, TemplateArea, Val GoToNextRow = False) Export
	
	AddDocumentAreaToDocumentStructure(PrintForm.DocumentStructure, TemplateArea);
	AreaStructure = AttachDocumentAreaToDocumentStructure(PrintForm.DocumentStructure, TemplateArea);
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return AreaStructure;
	
EndFunction

// Replaces parameters in the scope with values from object data.
//
// Parameters:
//  PrintForm - See InitializePrintForm
//  TemplateArea - Structure
//  ObjectData - Structure -  object data to fill in.
//
Procedure FillParameters_(PrintForm, TemplateArea, ObjectData = Undefined) Export
	
	If Not TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	PopulateHyperlinkParameters(PrintForm, TemplateArea, ObjectData);
	FillAreaParameters(PrintForm, TemplateArea, ObjectData);
	
EndProcedure

// Adds the collection area to the print form from the layout, while replacing
// the parameters in the area with values from the object data.
// Used when displaying data from a list (bulleted or numbered) or a table.
//
// Parameters:
//  PrintForm       - Structure
//  TemplateArea       - Structure
//  ObjectData       - Structure -  object data to fill in.
//  GoToNextRow - Boolean -  determines whether to insert a break after displaying areas of the entire collection.
//
Procedure JoinAndFillSet(PrintForm, TemplateArea, ObjectData = Undefined,
	Val GoToNextRow = False) Export
	
	If Not TypeOf(ObjectData) = Type("Array") Then
		Return;
	EndIf;
	
	If ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	For Each RowData In ObjectData Do
		
		If Not TypeOf(RowData) = Type("Structure") Then
			Continue;
		EndIf;
		
		Area = AttachArea(PrintForm, TemplateArea);
		FillParameters_(PrintForm, Area, RowData);
		
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Inserts a break on the next line.
//
// Parameters:
//  PrintForm - Structure
//
Procedure InsertBreakAtNewLine(PrintForm) Export
	
	Paragraph = PrintForm.DocumentStructure.DocumentAreas.Get("Paragraph");
	
	If Paragraph <> Undefined Then
		
		Paragraph.SectionNumber = 1;
		
		Count = PrintForm.DocumentStructure.AttachedAreas.Count();
		
		If Count <> 0 Then
			Paragraph.SectionNumber = PrintForm.DocumentStructure.AttachedAreas[Count - 1].SectionNumber;
		EndIf;
		
		AttachArea(PrintForm, Paragraph, False);
		
	EndIf;
	
EndProcedure

#Region OperationsWithDocumentStructure

// Returns:
//   Structure:
//   * DocumentID - String
//   * PicturesExtensions - Array
//   * PicturesDirectory - String
//   * ContentLinksTable - ValueTable
//   * ContentRelations - String
//   * ContentTypes1 - String
//   * AttachedAreas - Array
//   * HeaderFooter - Map of KeyAndValue:
//    ** Key - String
//    ** Value - See HeaderOrFooterArea
//   * Sections - Map
//   * DocumentAreas - Map
//
Function InitializeDocument() Export
	
	Result = New Structure;
	Result.Insert("DocumentAreas",       New Map);
	Result.Insert("Sections",                New Map);
	Result.Insert("HeaderFooter",            New Map);
	Result.Insert("AttachedAreas",  New Array);
	Result.Insert("ContentTypes1",           "");
	Result.Insert("ContentRelations",          "");
	Result.Insert("ContentLinksTable",  New ValueTable);
	Result.Insert("PicturesDirectory",        "");
	Result.Insert("PicturesExtensions",     New Array);
	Result.Insert("DocumentID", "");
	
	NumberDetails  = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	
	Result.ContentLinksTable.Columns.Add("ResourceName",   RowDescription);
	Result.ContentLinksTable.Columns.Add("ResourceID",    RowDescription);
	Result.ContentLinksTable.Columns.Add("ResourceNumber", NumberDetails);
	
	Return Result;
	
EndFunction

Function SectionArea()
	
	Result = New Structure;
	Result.Insert("HeaderFooter", New Map);
	Result.Insert("Text",       "");
	Result.Insert("Number",       1);
	
	Return Result;
	
EndFunction

Function DocumentArea()
	
	Result = New Structure;
	Result.Insert("Name",          "");
	Result.Insert("Text",        "");
	Result.Insert("SectionNumber", 1);
	Result.Insert("Hyperlinks",  New Array);
	
	Return Result;
	
EndFunction

// Returns:
//   Structure:
//   * SectionNumber - Number
//   * Text - String
//   * InternalName1 - String
//   * Name - String
//   * Hyperlinks - Array
//
Function HeaderOrFooterArea()
	
	Result = New Structure;
	Result.Insert("Name",          "");
	Result.Insert("InternalName1",     "");
	Result.Insert("Text",        "");
	Result.Insert("SectionNumber", 1);
	Result.Insert("Hyperlinks",  New Array);
	
	Return Result;
	
EndFunction

Function AddSectionToDocumentStructure(DocumentStructure, Section)
	
	SectionStructure = SectionArea();
	FillPropertyValues(SectionStructure, Section);
	DocumentStructure.Sections.Insert(SectionStructure.Number, SectionStructure);
	Return SectionStructure;
	
EndFunction

Function AddDocumentAreaToDocumentStructure(DocumentStructure, Area)
	
	AreaStructure = DocumentArea();
	FillPropertyValues(AreaStructure, Area);
	DocumentStructure.DocumentAreas.Insert(AreaStructure.Name, AreaStructure);
	Return AreaStructure;
	
EndFunction

Function AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooter, Val HeaderOrFooterKey = "")
	
	Section = DocumentStructure.Sections.Get(HeaderOrFooter.SectionNumber);
	
	If Section = Undefined Then
		HeaderOrFooter.Insert("Number", HeaderOrFooter.SectionNumber);
		Section = AddSectionToDocumentStructure(DocumentStructure, HeaderOrFooter);
	EndIf;
	
	HeaderOrFooterStructure = HeaderOrFooterArea();
	FillPropertyValues(HeaderOrFooterStructure, HeaderOrFooter);
	
	If IsBlankString(HeaderOrFooterKey) Then
		HeaderOrFooterKey = HeaderOrFooterStructure.Name + "_" + Format(HeaderOrFooterStructure.SectionNumber, "NG=0");
	EndIf;
	
	DocumentStructure.HeaderFooter.Insert(HeaderOrFooterKey, HeaderOrFooterStructure);
	
	Return HeaderOrFooterStructure;
	
EndFunction

Function AttachDocumentAreaToDocumentStructure(DocumentStructure, Area)
	
	AreaStructure = DocumentArea();
	FillPropertyValues(AreaStructure, Area);
	
	DocumentStructure.AttachedAreas.Add(AreaStructure);
	
	Return AreaStructure;
	
EndFunction

Function AttachHeaderOrFooterToDocumentStructure(DocumentStructure, HeaderOrFooter)
	
	HeaderOrFooterStructure = HeaderOrFooterArea();
	FillPropertyValues(HeaderOrFooterStructure, HeaderOrFooter);
	
	Section = DocumentStructure.Sections.Get(HeaderOrFooterStructure.SectionNumber);
	
	If Section = Undefined Then
		HeaderOrFooterStructure.Insert("SectionNumber", 1);
		Section = DocumentStructure.Sections.Get(1);
	EndIf;
	
	HeaderOrFooterKey = HeaderOrFooterStructure.Name + "_" + Format(HeaderOrFooterStructure.SectionNumber, "NG=0");
	Section.HeaderFooter.Insert(HeaderOrFooterKey, HeaderOrFooterStructure);
	Return HeaderOrFooterStructure;
	
EndFunction

Function GetDocumentAreaFromDocumentStructure(DocumentStructure, AreaName)
	
	Return DocumentStructure.DocumentAreas.Get(AreaName);
	
EndFunction

Function GetHeaderOrFooterFromDocumentStructure(DocumentStructure, HeaderOrFooterName, SectionNumber = 1)
	
	HeaderOrFooterKey = HeaderOrFooterName + "_" + Format(SectionNumber, "NG=0");
	Return DocumentStructure.HeaderFooter.Get(HeaderOrFooterKey);
	
EndFunction

Procedure AddRowToContentLinksTable(DocumentStructure, ResourceName, ResourceID, ResourceNumber)
	
	NewRow = DocumentStructure.ContentLinksTable.Add();
	NewRow.ResourceName   = ResourceName;
	NewRow.ResourceID    = ResourceID;
	NewRow.ResourceNumber = ResourceNumber;
	
EndProcedure

#EndRegion

#Region WorkWithOfficeOpenXML

#Region DCS

#Region DocsMerge

Function MergeOfficeDocs(OfficeDocuments, AddressOfCombinedDoc)
	
	FinalPrintForm = Undefined;
	
	For Each OfficeDocument In OfficeDocuments Do
		TreeOfTemplate = PrintManagement.InitializeTemplateOfDCSOfficeDoc(OfficeDocument.Value);
		DocumentStructure = TreeOfTemplate.DocumentStructure;
		RefsMap = New Map;

		RefsForSearching = GetRefsForContentSearch(DocumentStructure, FinalPrintForm = Undefined);
		
		RefsForSearching = ArrayIntoMap(RefsForSearching);
		
		ExtractRefs(DocumentStructure.DocumentTree, RefsMap, RefsForSearching);
		
		If FinalPrintForm = Undefined Then
			For K = 1 To RefsForSearching.Count() Do
				PropertyName = "rId"+ Format(K, "NG=");
				If RefsMap.Get(PropertyName) = Undefined Then
					RefsMap.Insert(PropertyName, New Map);
				EndIf;
			EndDo;
		EndIf;
		
		If FinalPrintForm = Undefined Then
			FinalDocStructureOfRefs = Common.CopyRecursive(RefsMap);
			FinalPrintForm = Common.CopyRecursive(TreeOfTemplate);
			FinalDocStructure = FinalPrintForm.DocumentStructure;
		Else                           
			For Each RefsInDoc In RefsMap Do
				NewKey = PickUniqueKey(RefsInDoc.Key, FinalDocStructureOfRefs);
				If NewKey <> RefsInDoc.Key Then
					ReplaceMentions(RefsInDoc, NewKey);
				EndIf;
				ProcessStructure(RefsInDoc.Key, NewKey, FinalPrintForm, TreeOfTemplate);
				FinalDocStructureOfRefs.Insert(NewKey, Common.CopyRecursive(RefsInDoc.Value));
			EndDo;
			
			DocumentNodeOfNewDoc = DocumentStructure.DocumentTree.Rows[0]; // ValueTableRow of See PrintManagementInternal.ReadXMLIntoTree
			FinalDocDocumentNode = FinalDocStructure.DocumentTree.Rows[0]; 
			
			BodyNodeOfNewDoc 	= DocumentNodeOfNewDoc.Rows[0]; 
			FinalDocBodyNode 	= FinalDocDocumentNode.Rows[0]; 

			SectionEndNode = FindNode(FinalDocBodyNode, -1, "w:sectPr");    
			
			IndexOfAdditingSection = FinalDocBodyNode.Rows.IndexOf(SectionEndNode);
			
			AddSectionDetailsNode(FinalDocBodyNode, IndexOfAdditingSection, SectionEndNode);
			FinalDocBodyNode.Rows.Delete(SectionEndNode);
			
			For Each AdditionNode In BodyNodeOfNewDoc.Rows Do
				IndexOfAdditingSection = IndexOfAdditingSection + 1;
				NodeToAdd = MakeCopyNode(FinalDocBodyNode, IndexOfAdditingSection, AdditionNode);
				CreateLowerLevelNodes(NodeToAdd, AdditionNode);
			EndDo;
			DeleteFiles(TreeOfTemplate.DirectoryName);
		EndIf;
	EndDo;
	
	Return GetPrintForm(FinalPrintForm, AddressOfCombinedDoc);

EndFunction  

Function GetRefsForContentSearch(DocumentStructure, AllLinks = False)
	ArrayOfRefsForSearching = New Array;
	ArrayOfFoundNodes = New Array;

	ArrayOfSearchedFor = New Array;
	ArrayOfSearchedFor.Add("http://schemas.openxmlformats.org/officeDocument/2006/relationships/header");
	ArrayOfSearchedFor.Add("http://schemas.openxmlformats.org/officeDocument/2006/relationships/image");
	ArrayOfSearchedFor.Add("http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer");
	ArrayOfSearchedFor.Add("http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" );
	
	LinkTree = DocumentStructure.ContentRelations;
	
	If AllLinks Then
		FindNodesByContent(LinkTree, "Relationship", ArrayOfFoundNodes);
	Else
		NodesSearchParameters = NodesSearchParameters();
		NodesSearchParameters.AttributeName = "Type";
		NodesSearchParameters.ValuesOfAttribute = ArrayOfSearchedFor;
		FindNodesByContent(LinkTree, "Relationship", ArrayOfFoundNodes, NodesSearchParameters);
	EndIf; 
	
	For Each FoundNode In ArrayOfFoundNodes Do
		ArrayOfRefsForSearching.Add(FoundNode.Attributes["Id"]);
	EndDo; 
	
	ArrayOfRefsForSearching = CommonClientServer.CollapseArray(ArrayOfRefsForSearching);

	Return ArrayOfRefsForSearching;
EndFunction

Procedure ReplaceMentions(RefsInDoc, NewKey)
	For Each RefInDoc In RefsInDoc.Value Do
		NodeToEdit = RefInDoc.Key;
		For Each Attribute In RefInDoc.Value Do
			NodeToEdit.Attributes.Insert(Attribute.Key, NewKey);
		EndDo;
	EndDo;
EndProcedure
	
Procedure ProcessStructure(InitialKey, NewKey, Receiver, Source, Encoding = "UTF-8")
	
	StructureOfDestinationDoc = Receiver.DocumentStructure;
	DocStructureOfSource = Source.DocumentStructure; 
	
	LinksTreeOfSource = DocStructureOfSource.ContentRelations;
	TreeOfDestinationLinks = StructureOfDestinationDoc.ContentRelations;
	
	SourceNode_ = FindNodeByContent(LinksTreeOfSource, "Relationship", "Id", InitialKey);
	ResourceSourceName = SourceNode_.Attributes["Target"];
	NameOfResourceForReceipt = ResourceSourceName;
	
	If SourceNode_.Attributes["Type"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Then
		
	Else
		While True Do
			FoundNode = FindNodeByContent(TreeOfDestinationLinks, "Relationship", "Target", NameOfResourceForReceipt); 
			If FoundNode = Undefined Then
				Break;
			EndIf;
		
			SourceNameArray = StrSplit(NameOfResourceForReceipt, "/\.");
		    ResourceShortName = SourceNameArray[SourceNameArray.UBound()-1];
		    
		    KeyStructure1 = GetNameWithoutDigits(ResourceShortName); 
			NameTemplate 	= KeyStructure1.NameTemplate;
			ResourceNumber 	= KeyStructure1.Number;
			ResourceNumber 	= ResourceNumber + 1;
			ResourceName		= StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, Format(ResourceNumber, "NG="));
			
			PathToResource = "";
			For K = 0 To SourceNameArray.UBound() - 2 Do
				PathToResource = PathToResource + SourceNameArray[K]+"/";
			EndDo;
			NameOfResourceForReceipt = PathToResource + ResourceName +"."+SourceNameArray[SourceNameArray.UBound()];
		EndDo;
		
		SourceFileName = Source.DirectoryName + "word" + SetPathSeparator("\"+ResourceSourceName);
		ReceiverFileName = Receiver.DirectoryName + "word" + SetPathSeparator("\"+NameOfResourceForReceipt);
		
		FileDestination = New File(ReceiverFileName);
		DestinationFileDir = New File(FileDestination.Path);
		
		If Not DestinationFileDir.Exists() Then   
			CreateDirectory(FileDestination.Path);
		EndIf;
	
		FileCopy(SourceFileName, ReceiverFileName);
	EndIf;
	
	DestinationLinksRoot = TreeOfDestinationLinks.Rows[0];
	NewLink = MakeCopyNode(DestinationLinksRoot, DestinationLinksRoot.Rows.Count(), SourceNode_);
	NewLink.Attributes.Insert("Target", NameOfResourceForReceipt);
	NewLink.Attributes.Insert("Id", NewKey);
	
	TreeOfDestinationContentTypes = StructureOfDestinationDoc.ContentTypes1;
	TreeOfSourceContentTypes = DocStructureOfSource.ContentTypes1;
	
	DestinationRoot = FindNodeByContent(TreeOfDestinationContentTypes, "Types");

	If StrFind(NewLink.Attributes["Type"], "header") Or StrFind(NewLink.Attributes["Type"], "footer") Then
		NameOfHeaderFooterFileSource = "/word/"+ResourceSourceName;
		HeaderFooterFileNamDestination = "/word/"+NameOfResourceForReceipt;
		
		OverridingNode = FindNodeByContent(TreeOfSourceContentTypes, "Override", "PartName", NameOfHeaderFooterFileSource);
		
		If OverridingNode <> Undefined Then
			NewContentType = MakeCopyNode(DestinationRoot, DestinationRoot.Rows.Count(), OverridingNode);
			NewContentType.Attributes.Insert("PartName", HeaderFooterFileNamDestination);
		EndIf;
	ElsIf NewLink.Attributes["Type"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Then
		
		ArrayOfNameWords = StrSplit(NameOfResourceForReceipt, ".", True);
		SourceSourceExtension  = ArrayOfNameWords[ArrayOfNameWords.UBound()];
		
		NodeDefineSource = FindNodeByContent(TreeOfSourceContentTypes, "Default", "Extension", SourceSourceExtension);
		NodeDefineDestination = FindNodeByContent(TreeOfDestinationContentTypes, "Default", "Extension", SourceSourceExtension);
		
		If NodeDefineSource <> Undefined And NodeDefineDestination = Undefined Then
			NewContentType = MakeCopyNode(DestinationRoot, DestinationRoot.Rows.Count(), NodeDefineSource);
		EndIf;
	EndIf;	

EndProcedure  

Function ReadXMLStringToTree(XMLLine)
	XMLReader = InitializeXMLReader(XMLLine);
	Return ReadXMLIntoTree(XMLReader);
EndFunction

// 
// 
// Parameters:
//  XMLWriter - XMLWriter - 
//  Tree - ValueTree:
//   * NameTag - String
//   * Text - String
//   * WholeText - String
//   * Attributes - Map
//
Procedure PutTreeToXMLEntry(XMLWriter, Tree)
	For Each Substring In Tree.Rows Do
		WriteElement(XMLWriter, Substring);	
	EndDo;
EndProcedure

Function PutTreeToXMLString(Tree)
	XMLWriter = InitializeXMLRecord("");
	For Each Substring In Tree.Rows Do
		WriteElement(XMLWriter, Substring);	
	EndDo;
	Return XMLWriter.Close();
EndFunction

Function PickUniqueKey(Val Var_Key, Structure)
	KeyStructure1 = GetNameWithoutDigits(Var_Key); 
	NameTemplate = KeyStructure1.NameTemplate;
	NumOfKey 	= KeyStructure1.Number;
	
	While Structure.Get(Var_Key) <> Undefined Do
		NumOfKey = NumOfKey + 1;
    	Var_Key = StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, Format(NumOfKey, "NG="));
	EndDo;
	Return Var_Key;	
EndFunction 

Function GetNameWithoutDigits(Val Name)
	ArrayOfKey = StrSplit(Name, "0123456789", False);
	If ArrayOfKey.Count() > 1 Then
		Raise NStr("en = 'Unexpected key';");
	EndIf;
	Result = New Structure ("NameTemplate, Number");
	Result.NameTemplate 	= ArrayOfKey[0]+"%1";
	UnwantedChars = StrConcat(ArrayOfKey,"");
	NumbersArray = StrSplit(Name, UnwantedChars, False);
	If NumbersArray.Count() > 1 Then
		Raise NStr("en = 'Unexpected key, several numbers';");
	EndIf;
	Result.Number	= Number(NumbersArray[0]);
	Return Result;
EndFunction

Procedure ExtractRefs(TreeOfTemplate, RefsMap, RefsForSearching)
	
	For Each TreeRow In TreeOfTemplate.Rows Do
		
		For Each Attribute In TreeRow.Attributes Do
			If RefsForSearching.Get(Attribute.Value) <> Undefined Then 
				Mentions = RefsMap.Get(Attribute.Value);
				If Mentions = Undefined Then
					Mentions = New Map;
				EndIf;
									
				Attributes = Mentions.Get(TreeRow);
				If Attributes = Undefined Then
					Attributes = New Map;
				EndIf;
				Attributes.Insert(Attribute.Key, Attribute.Value);
				
				Mentions.Insert(TreeRow, Attributes);
		
				RefsMap.Insert(Attribute.Value, Mentions);
			EndIf;
		EndDo;
				
		ExtractRefs(TreeRow, RefsMap, RefsForSearching);
	EndDo;
EndProcedure



// Parameters:
//  NodeOfParent - See DocumentTree
//  IndexOf - Number 
//  Node - See DocumentTree
//
Procedure AddSectionDetailsNode(NodeOfParent, IndexOf, Node)
	If NodeOfParent.Rows.Count() <= IndexOf Then
		NewPara = NodeOfParent.Rows.Add();
	Else
		NewPara = NodeOfParent.Rows.Insert(IndexOf);
	EndIf; 
	NewPara.NameTag = "w:p";
	NewFormattingProperties = NewPara.Rows.Add();
	NewFormattingProperties.NameTag = "w:pPr";
	
	NewSection = NewFormattingProperties.Rows.Add();
	
	FillPropertyValues(NewSection, Node, "NameTag,Text,WholeText");
	NewSection.Attributes = Common.CopyRecursive(Node.Attributes); 
	CreateLowerLevelNodes(NewSection, Node);

EndProcedure

#EndRegion

// 
// 
// Parameters:
//  XMLReader - XMLReader
// 
// Returns:
//  ValueTree:
//   * NameTag - String - 
//   * Text - String - 
//   * WholeText - String - 
//   * Attributes - Map - 
//  
//
Function ReadXMLIntoTree(XMLReader, Hyperlinks = Undefined) Export
	XMLReader.IgnoreWhitespace = False;
	Tree = DocumentTree();
	If Hyperlinks <> Undefined And Hyperlinks.Count() = 0 Then
		Hyperlinks = Undefined;
	EndIf;
	ReadRecord(XMLReader, Tree, Hyperlinks);
	Return Tree;
EndFunction

// Returns:
//  ValueTree:
//   * NameTag - String - 
//   * Text - String - 
//   * WholeText - String - 
//   * Attributes - Map - 
//   * IndexOf - Number -  
//
Function DocumentTree()
	Var Tree;
	Tree = New ValueTree;
	Tree.Columns.Add("NameTag",  New TypeDescription("String"));
	Tree.Columns.Add("Text",  New TypeDescription("String"));
	Tree.Columns.Add("WholeText",  New TypeDescription("String"));
	Tree.Columns.Add("Attributes",  New TypeDescription("Map"));
	Tree.Columns.Add("IndexOf",  New TypeDescription("Number"));
	Return Tree
EndFunction

Function ReadRecord(XMLReader, TreeRow, Hyperlinks)
	WholeText = "";
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			NewRow = TreeRow.Rows.Add();
			NewRow.NameTag = XMLReader.Name;
			NewRow.Attributes = ObtainAttributes(XMLReader);
			NewRow.Text = "";
			NewRow.WholeText = ReadRecord(XMLReader, NewRow, Hyperlinks);
			
			If Hyperlinks <> Undefined And NewRow.NameTag = "w:hyperlink" Then
				HyperlinkAnchorText = Hyperlinks[NewRow.Attributes["r:id"]];
				If HyperlinkAnchorText <> Undefined Then
					NewRow.WholeText = HyperlinkAnchorText + NewRow.WholeText;
				EndIf;
			EndIf;
			WholeText = WholeText + NewRow.WholeText;
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			Return WholeText;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If TypeOf(TreeRow) <> Type("ValueTreeRow")
			    Or (StrStartsWith(XMLReader.Value, Char(10))) Then 
				Continue;
			EndIf;
			
			TreeRow.Text = StrReplace(XMLReader.Value, Char(160), " ");
			If StrStartsWith(TreeRow.Text, "HYPERLINK ") Then           
				TreeRow.Text = DecodeString(XMLReader.Value, StringEncodingMethod.URLEncoding);
			EndIf;
				
			TreeRow.WholeText = TreeRow.Text;
			WholeText = WholeText + TreeRow.WholeText;
		Else
			Raise (NStr("en = 'Unknown:';") + " " + XMLReader.NodeType);
		EndIf;
	EndDo;
	Return WholeText;
EndFunction  

Function ObtainAttributes(XMLReader)
	AttributesMap = New Map;
	While XMLReader.ReadAttribute() Do
		AttributesMap.Insert(XMLReader.Name, XMLReader.Value);
	EndDo;
	Return AttributesMap;
EndFunction

Procedure InitializeStructureOfDCSTemplate(Template)
	
	DirectoryName = Template.DirectoryName;
	DocumentStructure = Template.DocumentStructure;
	DocumentStructure.PicturesDirectory        = DirectoryName + SetPathSeparator("\word\media\");
	
	FilesToChange = New Map;
	FilesToChange.Insert("ContentRelations", DirectoryName + SetPathSeparator("\word\_rels\document.xml.rels"));
	FilesToChange.Insert("ContentTypes1",  DirectoryName + SetPathSeparator("\[Content_Types].xml"));
	FilesToChange.Insert("Document",      DirectoryName + SetPathSeparator("\word\document.xml"));
	
	DirectoryWithFileStructure = DirectoryName + "word" + GetPathSeparator(); 
	
	File = New File(FilesToChange.Get("ContentRelations"));
	If File.Exists() Then
		XMLReader = InitializeXMLReader(File.FullName, 1);
		XMLTree = ReadXMLIntoTree(XMLReader);
		ArrayOfHiperlinksNodes = New Array;
		NodesSearchParameters = NodesSearchParameters();
		NodesSearchParameters.AttributeName = "Type";
		NodesSearchParameters.ValuesOfAttribute = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink";
		FindNodesByContent(XMLTree, "Relationship", ArrayOfHiperlinksNodes, NodesSearchParameters);
		HyperlinksMapping = DocumentStructure.Hyperlinks;
		
		For Each HyperlinkNode In ArrayOfHiperlinksNodes Do
			HyperlinkAnchorText = DecodeString(HyperlinkNode.Attributes["Target"], StringEncodingMethod.URLEncoding);
			LinkParameters_ = PrintManagement.FindParametersInText(HyperlinkAnchorText);
			CommonClientServer.SupplementArray(DocumentStructure.TextParameters, LinkParameters_, True);
			LinkID = HyperlinkNode.Attributes["Id"];
			HyperlinksMapping.Insert(LinkID, HyperlinkAnchorText);
		EndDo;         
		MaxID = 0;
		NodesArray = New Array;
		FindNodesByContent(XMLTree, "Relationship", NodesArray);
		For Each Node In NodesArray Do
			Id = Node.Attributes["Id"];
			ArrayOfIDParts = StrSplit(Id, "0123456789", False);
			Id = Number(StrReplace(Id, ArrayOfIDParts[0], ""));
			MaxID = Max(Id, MaxID);
		EndDo;
		DocumentStructure.LinkMaxID = MaxID; 
		DocumentStructure.ContentRelations = XMLTree;
	EndIf;

	
	File = New File(DirectoryWithFileStructure + "document.xml"); //@Non-NLS
	If File.Exists() Then
		XMLReader = InitializeXMLReader(File.FullName, 1);
		DocumentStructure.DocumentTree = ReadXMLIntoTree(XMLReader, DocumentStructure.Hyperlinks);
	
		XMLText = DocumentStructure.DocumentTree.Rows[0].WholeText;
		DocumentStructure.TextParameters = PrintManagement.FindParametersInText(XMLText);
		
	EndIf;
	
	StructureFiles = FindFiles(DirectoryWithFileStructure, "*.xml");
	For Each File In StructureFiles Do
		If Not (Left(File.BaseName, 6) = "header") And Not (Left(File.BaseName, 6) = "footer") Then
			Continue;
		EndIf;
		
		XMLReader = InitializeXMLReader(File.FullName, 1);
		
		XMLTree = ReadXMLIntoTree(XMLReader, DocumentStructure.Hyperlinks);
		
		DocumentStructure.HeaderFooter.Insert(File.BaseName, XMLTree);
		
		XMLText = XMLTree.Rows[0].WholeText;
		CommonClientServer.SupplementArray(DocumentStructure.TextParameters, PrintManagement.FindParametersInText(XMLText), True);
		
	EndDo;
		
	File = New File(FilesToChange.Get("ContentTypes1"));
	If File.Exists() Then
		XMLReader = InitializeXMLReader(File.FullName, 1);
		XMLTree = ReadXMLIntoTree(XMLReader);
		DocumentStructure.ContentTypes1 = XMLTree;
	EndIf;
	
EndProcedure

Function GetNode(Tree, Val Path) Export
	PathArray = StrSplit(Path, "/", False);
	ArrayOfFoundStrings = Tree.Rows.FindRows(New Structure("NameTag", PathArray[0]), False);
	If ArrayOfFoundStrings.Count() Then
		If PathArray.Count() = 1 Then
			Return ArrayOfFoundStrings[0];
		ElsIf PathArray.Count() Then
			PathArray.Delete(0);
			Return GetNode(ArrayOfFoundStrings[0], StrConcat(PathArray, "/"));
		EndIf;
	EndIf;
	Return Undefined;
EndFunction    

Function GetTextsNodes(DocNode, MapOfNodes = Undefined) Export
	If MapOfNodes = Undefined Then
		MapOfNodes = New Map();
	EndIf;
	
	If DocNode.NameTag = "w:t" Then
		MapOfNodes.Insert(DocNode, DocNode.Text);
	EndIf;
	
	For Each ChildNode In DocNode.Rows Do
		GetTextsNodes(ChildNode, MapOfNodes);		
	EndDo;
	
	Return MapOfNodes;
EndFunction

Procedure RunIndexNodes(DocumentTree, Counter = 0) Export
	For Each TreeItem In DocumentTree.Rows Do
		TreeItem.IndexOf = Counter;
		Counter = Counter + 1;
		RunIndexNodes(TreeItem, Counter);
	EndDo;
EndProcedure

Procedure FindAreas(DocumentStructure, ObjectTablePartNames) Export
	
	Areas = DocumentStructure.Areas;
	DocumentTree = DocumentStructure.DocumentTree;
	
	ConditionalAreasStarts = New Array;
	ConditionalAreasEnds = New Array;
	FindNodes(DocumentTree, "{"+TagNameCondition(), ConditionalAreasStarts);
	FindNodes(DocumentTree, "{/"+TagNameCondition(), ConditionalAreasEnds);
	
	For Each TabularSectionName In ObjectTablePartNames Do
		FoundAreas = New Array;
		FindNodes(DocumentTree, "["+TabularSectionName+".", FoundAreas);
		For Each Area In FoundAreas Do
			If ConditionalAreasStarts.Find(Area) <> Undefined Then
				Continue;
			EndIf;
			TableAreaStartNode = FindTableAreaRoot(Area);
			AddedTabularSectionBeginningNode = Areas.Find(TableAreaStartNode, "DocTreeNode");
			If AddedTabularSectionBeginningNode = Undefined Then
				NewArea = Areas.Add();
				NewArea.DocTreeNode = TableAreaStartNode;
				NewArea.Collection = TabularSectionName;
				NewArea.IndexOf = NewArea.DocTreeNode.IndexOf;
			Else
				AddedTabularSectionBeginningNode.Collection = TabularSectionName;
			EndIf;
			
			TableAreaEndNode = GetNextNode(TableAreaStartNode);
			If Areas.Find(TableAreaEndNode, "DocTreeNode") = Undefined Then
				NewArea = Areas.Add();
				NewArea.DocTreeNode = TableAreaEndNode;
				NewArea.IndexOf = NewArea.DocTreeNode.IndexOf;
			EndIf;
		EndDo;
	EndDo;
	
	ConditionalAreasStartIndexes = GetIndexesOfNodesArray(ConditionalAreasStarts);
	ConditionalAreasEndIndexes = GetIndexesOfNodesArray(ConditionalAreasEnds);
	
	For Each ConditionalAreaStartIndex In ConditionalAreasStartIndexes Do
		ConditionalAreaStart = DocumentTree.Rows.Find(ConditionalAreaStartIndex, "IndexOf", True);
		For Each ConditionalAreaEndIndex In ConditionalAreasEndIndexes Do
			ConditionalAreaEnd = DocumentTree.Rows.Find(ConditionalAreaEndIndex, "IndexOf", True);
			If ConditionalAreaStartIndex < ConditionalAreaEndIndex Then
				Break;
			EndIf;
		EndDo;
		
		AreaCondition = AreaCondition(ConditionalAreaStart);
		If ConditionalAreaEnd = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In the document template, the end of the %1 conditional area is not specified.';"), AreaCondition);
		EndIf;
		ShouldAddConditionalAreas = True;
		CollectionArea = Undefined;
		ConditionalAreasEnds = New Array;
		AreasToRemove = New Array;
		If Areas.Count() > 0 Then
			For AreaIndex = 0 To Areas.Count() - 1 Do
				Area = Areas[AreaIndex];
				NextArea = ?(AreaIndex+1 < Areas.Count(), Areas[AreaIndex+1], Undefined);
				
				If ConditionalAreaStartIndex >= Area.IndexOf And Area.IndexOf >= ConditionalAreaEndIndex Then
					If ValueIsFilled(Area.Collection) Then
						CollectionArea = Area;
					EndIf;
					IsConditionEndParent = 
						Area.DocTreeNode.Rows.Find(ConditionalAreaEndIndex, "IndexOf", True) <> Undefined;
					If Not IsConditionEndParent Then
						Area.AreaCondition = AreaCondition;
						Continue;
					EndIf;
						
					If CollectionArea <> Undefined Then
						NextAreaNode = NextAreaBorder(CollectionArea.DocTreeNode, Areas);
						If NextAreaNode <> Undefined And NextAreaNode.IndexOf < ConditionalAreaEndIndex Then
							AreaProperties = New Structure("DocTreeNode, AreaCondition");
							AreaProperties.DocTreeNode = NextAreaNode;
							AreaProperties.AreaCondition = AreaCondition;
							ConditionalAreasEnds.Add(AreaProperties);
						EndIf;
					EndIf;
					
					NextAreaNode = NextAreaBorder(ConditionalAreaEnd, Areas);
					If NextAreaNode = Undefined Then
						AreasToRemove.Add(Area);
						Continue;
					EndIf;
					Area.DocTreeNode = NextAreaNode;
					Area.IndexOf = Area.DocTreeNode.IndexOf;
				ElsIf NextArea <> Undefined And ConditionalAreaStartIndex >= Area.IndexOf
					And NextArea.IndexOf >= ConditionalAreaEndIndex Then
					If Area.NestedAreas = Undefined Then
						Area.NestedAreas = TableOfTemplateAreas();
					EndIf;
					For IndexOfNode = ConditionalAreaStartIndex + 1 To ConditionalAreaEndIndex - 1 Do
						NodeWithCondition = Area.DocTreeNode.Rows.Find(IndexOfNode, "IndexOf", True);
						If NodeWithCondition <> Undefined Then
							NestedCondition = Area.NestedAreas.Add();
							NestedCondition.DocTreeNode = NodeWithCondition;
							NestedCondition.AreaCondition = AreaCondition;
							NestedCondition.IndexOf = IndexOfNode;
							ShouldAddConditionalAreas = False;
						EndIf;
					EndDo;
				EndIf;
			EndDo;
		
			For Each Area In AreasToRemove Do
				Areas.Delete(Area);
			EndDo;
		
			For Each AreaProperties In ConditionalAreasEnds Do
				NewArea = Areas.Add();
				FillPropertyValues(NewArea, AreaProperties);
				NewArea.IndexOf = NewArea.DocTreeNode.IndexOf;
			EndDo;
		EndIf;
		
		If ShouldAddConditionalAreas Then
			AddAreaWithCondition(Areas, ConditionalAreaStart);
			ConditionalAreaEnd = DocumentTree.Rows.Find(ConditionalAreaEndIndex, "IndexOf", True);
			AddAreaWithCondition(Areas, ConditionalAreaEnd);
		EndIf;
	EndDo;
	
	DeleteConditionalAreasTags(ConditionalAreasStartIndexes, DocumentTree);
	DeleteConditionalAreasTags(ConditionalAreasEndIndexes, DocumentTree);
	
	StartNode = DocumentTree.Rows[0];
	If Areas.Find(StartNode, "DocTreeNode") = Undefined Then
		NewArea = Areas.Add();
		NewArea.DocTreeNode = StartNode;
		NewArea.AreaCondition = Undefined;
		NewArea.Collection = "";
		NewArea.IndexOf = NewArea.DocTreeNode.IndexOf;
	EndIf;
		
	AddTransitionLevelAreas(Areas, DocumentTree);
	
	For AreaIndex = 0 To Areas.Count()-1 Do
		CurrentArea = DocumentStructure.Areas[AreaIndex];
		AreaStructure = StructureOfAreaFromTemplate(DocumentTree, Areas, AreaIndex, DocumentStructure.Hyperlinks);
		FillPropertyValues(CurrentArea, AreaStructure);
	EndDo;
	
EndProcedure

Function GetIndexesOfNodesArray(NodesArray)
	Result = New Array;
	
	For Each Node In NodesArray Do
		Result.Add(Node.IndexOf);
	EndDo;
	
	Return Result;
EndFunction

Function StructureOfAreaFromTemplate(TreeOfTemplate, Areas, AreaIndex, Hyperlinks)
	CurrentArea = Areas[AreaIndex];
	IndexOfCurrentAreaNode = CurrentArea.IndexOf;
	AreaStartNode = CurrentArea.DocTreeNode;
	AreaStartParent = AreaStartNode.Parent; 
	If AreaStartParent = Undefined Then
		RunThroughCollection = TreeOfTemplate.Rows;
	Else
		RunThroughCollection = AreaStartParent.Rows;
	EndIf;
	If Areas.Count() = AreaIndex + 1 Then
		IndexOfNextArea = Undefined;
		IndexOfNextAreaNode = Undefined;
	Else
		IndexOfNextArea = AreaIndex + 1;
		IndexOfNextAreaNode = Areas[IndexOfNextArea].IndexOf;
	EndIf;
	
	
	AreaTree = DocumentTree();
	For Each Node In RunThroughCollection Do
		If Node.IndexOf < IndexOfCurrentAreaNode Then
			Continue;
		EndIf;
		 
		If IndexOfNextAreaNode <> Undefined And Node.IndexOf >= IndexOfNextAreaNode Then
			Break;
		EndIf;
		
		NewNode = MakeCopyNode(AreaTree, AreaTree.Rows.Count(), Node);
		CreateLowerLevelNodes(NewNode, Node, IndexOfNextAreaNode);
	EndDo;
	
	RestoreFullText(AreaTree, Hyperlinks);
	
	ParametersArray = New Array;
	For Each TreeRow In AreaTree.Rows Do
		CommonClientServer.SupplementArray(ParametersArray, PrintManagement.FindParametersInText(TreeRow.WholeText));
	EndDo;
	
	ArrayOfHiperlinksNodes = New Array;
	FindNodesByContent(AreaTree, "w:hyperlink", ArrayOfHiperlinksNodes);
	
	For Each HyperlinkNode In ArrayOfHiperlinksNodes Do 
		HyperlinkText = Hyperlinks[HyperlinkNode.Attributes["r:id"]];
		CommonClientServer.SupplementArray(ParametersArray, PrintManagement.FindParametersInText(HyperlinkText));
	EndDo;
	
	Result = New Structure("AreaTree, Parameters");
	Result.AreaTree = AreaTree;
	Result.Parameters = ParametersArray;
	
	Return Result;
EndFunction

// Parameters:
//  Parent - ValueTreeRow of See DocumentTree
//  Var_Key - String
//  NodesArray - Array of See DocumentTree
//
Function FindNodes(Parent, Var_Key, NodesArray) Export
	AreNodesFound = False;
	For Each TreeItem In Parent.Rows Do
		FoundNodeCount = NodesArray.UBound();
		
		OccurrencesCount = StrOccurrenceCount(TreeItem.WholeText, Var_Key);
		
		If OccurrencesCount And Not FindNodes(TreeItem, Var_Key, NodesArray) Then
			If FoundNodeCount = NodesArray.UBound() Then
				OccurrencesCount = OccurrencesCount - 1;
				NodesArray.Add(TreeItem);
				AreNodesFound = True;
			EndIf;
		EndIf;
		
	EndDo;
	Return AreNodesFound;
EndFunction

Function ArrayIntoMap(Array)
	Map = New Map();
	For Each Item In Array Do
		Map.Insert(Item, True);
	EndDo; 
	Return Map;
EndFunction 

// 
// 
// Parameters:
//  TreeRow - See DocumentTree
//  NameTag - String - 
//   See DocumentTree
//  AttributeName - Undefined, String - 
//  ValuesOfAttribute - Undefined, String, Array, Arbitrary - 
// 
// Returns:
//   See DocumentTree
//  
Function FindNodeByContent(TreeRow, NameTag, AttributeName = Undefined, Val ValuesOfAttribute = Undefined) Export
	NodesArray = New Array;
	NodesSearchParameters = NodesSearchParameters();
	NodesSearchParameters.AttributeName = AttributeName;
	NodesSearchParameters.ValuesOfAttribute = ValuesOfAttribute;
	NodesSearchParameters.FirstValue = True;	
	FindNodesByContent(TreeRow, NameTag, NodesArray, NodesSearchParameters);
	If NodesArray.Count() = 1 Then
		Return NodesArray[0];
	Else
		Return Undefined;
	EndIf;	
EndFunction

// 
// 
// Returns:
//  Structure:
//   * AttributeName - Undefined
//   * ValuesOfAttribute - Undefined
//   * FirstValue - Boolean
//   * OnlySubordinateOnes - Boolean
//
Function NodesSearchParameters() Export
	ParametersStructure = New Structure;
	ParametersStructure.Insert("AttributeName", Undefined);
	ParametersStructure.Insert("ValuesOfAttribute", Undefined);
	ParametersStructure.Insert("FirstValue", False);
	ParametersStructure.Insert("IncludeSubordinates", True);
	Return ParametersStructure;
EndFunction

// 
// 
// Parameters:
//  TreeRow - See DocumentTree
//  NameTag - String - 
//  NodesArray - See DocumentTree
//  SearchParameters - See NodesSearchParameters
//
Procedure FindNodesByContent(TreeRow, NameTag, NodesArray, SearchParameters = Undefined) Export
	If SearchParameters = Undefined Then
		SearchParameters = NodesSearchParameters();
	EndIf;
	AttributeName = SearchParameters.AttributeName;
	ValuesOfAttribute = SearchParameters.ValuesOfAttribute;
	FirstValue = SearchParameters.FirstValue;
	IncludeSubordinates = SearchParameters.IncludeSubordinates;
	
	If TypeOf(ValuesOfAttribute) = Type("String") Then
		ValuesOfAttribute = StrSplit(ValuesOfAttribute, ",", False);
		ValuesOfAttribute = ArrayIntoMap(ValuesOfAttribute);
	ElsIf TypeOf(ValuesOfAttribute) = Type("Array") Then
		ValuesOfAttribute = ArrayIntoMap(ValuesOfAttribute);
	EndIf;
	
	FilterByTag = New Structure("NameTag", NameTag);
	TreeItems = TreeRow.Rows.FindRows(FilterByTag, IncludeSubordinates);
	
	For Each TreeItem In TreeItems Do
		If AttributeName <> Undefined Then
			CurrentAttributes = TreeItem.Attributes;
			AttributeCurrentVal = CurrentAttributes.Get(AttributeName);
			If AttributeCurrentVal = Undefined Then
				Continue;
			EndIf;
				
			If ValuesOfAttribute <> Undefined Then
				If ValuesOfAttribute.Get(AttributeCurrentVal) = Undefined Then
					Continue;
				EndIf;
			EndIf;
		EndIf;
		NodesArray.Add(TreeItem);
		If FirstValue Then
			Return;
		EndIf;
	EndDo;
	
EndProcedure

Procedure RestoreFullText(XMLTree, Hyperlinks) Export
	For Each TreeRow In XMLTree.Rows Do
		RestoreEntireTextRecursively(TreeRow, Hyperlinks);
	EndDo;
EndProcedure

Procedure RestoreEntireTextRecursively(TreeRow, Hyperlinks)
	
	TreeRow.WholeText = "";
	
	If Not TreeRow.Rows.Count() Then
		TreeRow.WholeText = TreeRow.Text;
		If Hyperlinks <> Undefined And TreeRow.NameTag = "w:hyperlink" Then
			HyperlinkAnchorText = Hyperlinks[TreeRow.Attributes["r:id"]];
			If HyperlinkAnchorText <> Undefined Then
				TreeRow.WholeText = HyperlinkAnchorText + TreeRow.WholeText;
			EndIf;
		EndIf;
	Else
		For Each Substring In TreeRow.Rows Do
			RestoreEntireTextRecursively(Substring, Hyperlinks);
			TreeRow.WholeText = TreeRow.WholeText + Substring.WholeText;
			If Hyperlinks <> Undefined And TreeRow.NameTag = "w:hyperlink" Then
				HyperlinkAnchorText = Hyperlinks[TreeRow.Attributes["r:id"]];
				If HyperlinkAnchorText <> Undefined Then
					TreeRow.WholeText = HyperlinkAnchorText + TreeRow.WholeText;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

// Returns:
// - ValueTreeRow of See DocumentTree
// - Undefined
//
Function FindNode(Node, Direction, Name)
	
	CollectionOfNodeRows = Node.Rows;
		
	RowsCount = CollectionOfNodeRows.Count() - 1;
	
	If Direction < 0 Then
		For K = 0 To RowsCount Do
			SearchString = CollectionOfNodeRows.Get(RowsCount-K);
			If SearchString.NameTag = Name Then
				Return SearchString;
			EndIf;
		EndDo;
	Else
		For K = 0 To RowsCount Do
			SearchString = CollectionOfNodeRows.Get(K);
			If SearchString.NameTag = Name Then
				Return SearchString;
			EndIf;
		EndDo;
	EndIf;
	
	Return Undefined;
EndFunction

Function FindParentNode(Node, Name)
	Parent = Node.Parent;
	If Parent = Undefined Then
		Return Undefined;
	ElsIf Parent.NameTag = Name Then
		Return Parent;
	Else
		Return FindParentNode(Parent, Name);
	EndIf;
EndFunction

// 
// 
// Parameters:
//  NodeOfParent - ValueTreeRow:
//   * NameTag - String
//   * Text - String
//   * WholeText - String
//   * Attributes - Map
//  IndexOf - Number - IndexOf
//  Node - 
//   
//   
//   
//   
// 
// Returns:
//  ValueTreeRow:
//   * NameTag - String
//   * Text - String
//   * WholeText - String
//   * Attributes - Map
//
Function MakeCopyNode(NodeOfParent, IndexOf, Node) Export
	If NodeOfParent.Rows.Count() <= IndexOf Then
		NodeOfClone = NodeOfParent.Rows.Add();
	Else
		NodeOfClone = NodeOfParent.Rows.Insert(IndexOf);
	EndIf;
	FillPropertyValues(NodeOfClone, Node, "NameTag,Text,WholeText,IndexOf");
	NodeOfClone.Attributes = New Map;
	CommonClientServer.SupplementMap(NodeOfClone.Attributes, Node.Attributes);
		
	Return NodeOfClone;
EndFunction

//  
// 
// Parameters:
//   See PrintManagementInternal.ReadXMLIntoTree
//   See PrintManagementInternal.ReadXMLIntoTree
//
Procedure CreateLowerLevelNodes(NewRow, CurrentRow, LowerIndex = Undefined) Export
	
	For Each CrRow In CurrentRow.Rows Do
		If LowerIndex <> Undefined And LowerIndex <= CrRow.IndexOf Then
			Break;
		EndIf;
		NString = MakeCopyNode(NewRow, NewRow.Rows.Count(), CrRow);
		CreateLowerLevelNodes(NString, CrRow, LowerIndex);						
	EndDo;	
	
EndProcedure

Procedure GetAreasFromTree(TreePointer, Areas, TabularSectionNames, EndRegion = False)
	For Each TreeRow In TreePointer.Rows Do
		If HasStringContainsAreaStart(TreeRow.WholeText, TabularSectionNames) Then
			
			IsAreaEnd = StrFind(TreeRow.WholeText, "{/"+TagNameCondition()) <> 0;
			If Not TreeRow.Rows.Count() Then
				AddAreaNode(Areas, TreeRow, IsAreaEnd, TabularSectionNames); 
			Else			
				GetAreasFromTree(TreeRow, Areas, TabularSectionNames, IsAreaEnd);
			EndIf;
			
			// 
			EdgeArea = Areas[Areas.Count()-1];
			If EdgeArea <> Undefined And StrFind(TreeRow.WholeText, "{" + TagNameCondition()) 
				And StrFind(TreeRow.WholeText, "}") And EdgeArea.AreaCondition = Undefined Then
				ConditionArrayStart = StrSplit(TreeRow.WholeText, "{", False);
				For K=0 To ConditionArrayStart.UBound() Do
					If StrFind(ConditionArrayStart[K], TagNameCondition()+" ") Then
						ArrayOfEndCondition = StrSplit(ConditionArrayStart[K], "}", False);
						EdgeArea.AreaCondition = TrimAll(StrReplace(ArrayOfEndCondition[0], TagNameCondition()+" ", ""));
						Break;
					EndIf;
				EndDo;
			EndIf;
		ElsIf StrFind(TreeRow.WholeText, "{") And Not TreeRow.Rows.Count() Then
			AddAreaNode(Areas, TreeRow, EndRegion, TabularSectionNames); 
		ElsIf StrFind(TreeRow.WholeText, "{") Then
			GetAreasFromTree(TreeRow, Areas, TabularSectionNames, IsAreaEnd);
		EndIf;			 		
	EndDo;
	
EndProcedure

Procedure AddAreaNode(Areas, String, IsAreaEnd, TabularSectionNames)
	
	If HasStringContainsTableStart(String.WholeText, TabularSectionNames, False) Then
		DocTreeNode = FindTableAreaRoot(String);
		If Areas.Find(DocTreeNode, "DocTreeNode") = Undefined Then
			NewArea = Areas.Add();
			NewArea.DocTreeNode = DocTreeNode;
			NewArea.AreaCondition = Undefined;
			
			For Each TabularSectionName In TabularSectionNames Do
				If StrFind(String.WholeText, "["+TabularSectionName+".") Then
					Break;
				EndIf;  			
			EndDo;
			NewArea.Collection = TabularSectionName;
			
		EndIf;
	Else
		NewArea = Areas.Add();
		NewArea.DocTreeNode = String;
		NewArea.AreaCondition = Undefined;
	EndIf;
EndProcedure

Function FindTableAreaRoot(String)
	Pointer = String;
	
	ParentsStructure = New Structure("Paragraph, TableRow");
	
	While ValueIsFilled(Pointer.Parent) Do
		Pointer = Pointer.Parent;
		If Pointer.NameTag = "w:tr" And Not ValueIsFilled(ParentsStructure.TableRow) Then
			ParentsStructure.TableRow = Pointer;
		ElsIf Pointer.NameTag = "w:p" And Not ValueIsFilled(ParentsStructure.Paragraph) Then
			ParentsStructure.Paragraph = Pointer;
		EndIf; 
	EndDo;
	
	Return ?(ValueIsFilled(ParentsStructure.TableRow), ParentsStructure.TableRow, ParentsStructure.Paragraph);
	 
EndFunction

Function GetNextNode(Node)
	ParentNode1 = Node.Parent;
	IndexOf = ParentNode1.Rows.IndexOf(Node);
	If IndexOf + 1 = ParentNode1.Rows.Count() Then
		Return GetNextNode(ParentNode1);
	Else 
		Return ParentNode1.Rows[IndexOf+1];
	EndIf;
EndFunction

Function NextAreaBorder(String, Areas)
	Parent = String.Parent;
	If Parent = Undefined Then
		Return Undefined;
	EndIf;
	
	IndexOfNextNode = Parent.Rows.IndexOf(String)+1;
	NavigateToParent = False;
	If IndexOfNextNode = Parent.Rows.Count() Then
		NavigateToParent = True;
	Else
		For RowIndex = Parent.Rows.IndexOf(String)+1 To Parent.Rows.Count()-1 Do
			NavigateToParent = Parent.Rows[RowIndex].WholeText = "";
			If Not NavigateToParent Then
				Break;
			EndIf;
		EndDo;
	EndIf;
		
	If NavigateToParent Then
		
		Return NextAreaBorder(Parent, Areas);
		
	Else
		
		AreaStartNode = Parent.Rows[IndexOfNextNode];
		
		IsTableBeginning = AreaStartNode.NameTag = "w:tbl";
		If IsTableBeginning Then
			HasPredecessorNodes = Parent.Rows.Count() > 2;
			If HasPredecessorNodes Then
				NodeOfPredecessor = TablePredecessor(Parent, IndexOfNextNode-1);
				If NodeOfPredecessor <> Undefined Then
					AlignColumnsGrid(AreaStartNode, NodeOfPredecessor);
					
					While True Do
						AlignmentNode = TablePredecessor(Parent, Parent.Rows.IndexOf(NodeOfPredecessor)-1);
						If AlignmentNode <> Undefined Then
							AlignColumnsGrid(AreaStartNode, AlignmentNode);
						Else
							Break;
						EndIf;
					EndDo;
					
					TableRows = New Array();
					FindNodesByContent(AreaStartNode, "w:tr", TableRows);
					FirstAddedNode = Undefined;
					For Each TableRow In TableRows Do
						NewNode = MakeCopyNode(NodeOfPredecessor, NodeOfPredecessor.Rows.Count(), TableRow);
						CreateLowerLevelNodes(NewNode, TableRow);
						FirstAddedNode = ?(FirstAddedNode = Undefined, NewNode, FirstAddedNode);
						
						AreaForSubstitute = Areas.Find(NewNode.IndexOf, "IndexOf");
						If AreaForSubstitute <> Undefined Then 
							AreaForSubstitute.DocTreeNode = NewNode;
						EndIf;
					EndDo;
					
					Parent.Rows.Delete(AreaStartNode);
					Return FirstAddedNode;					
				EndIf;
			EndIf;
		EndIf;
		
		Return Parent.Rows[IndexOfNextNode];
	EndIf;
EndFunction

Function TablePredecessor(Parent, CurrentNodeIndex)
	
	For SearchIndex = 1 To CurrentNodeIndex Do
		NodeOfPredecessor = Parent.Rows[CurrentNodeIndex-SearchIndex];
		If NodeOfPredecessor.NameTag = "w:tbl" Then
			Return NodeOfPredecessor;
		ElsIf NodeOfPredecessor.NameTag = "w:p" And StrStartsWith(NodeOfPredecessor.WholeText, "{"+TagNameCondition())
			And StrEndsWith(NodeOfPredecessor.WholeText, "}") Then
			Continue;
		EndIf;
		Return Undefined;
	EndDo;
	Return Undefined;

EndFunction

Procedure AlignColumnsGrid(AreaStartNode, NodeOfPredecessor)
	
	PredecessorColumnsGridNode = FindNodeByContent(NodeOfPredecessor, "w:tblGrid");
	AdditionColumnsGripNode = FindNodeByContent(AreaStartNode, "w:tblGrid");
	GridArray = New Array;
	PredecessorGridArray = New Array;
	CurrentWidth = 0;
	For Each GripNode In PredecessorColumnsGridNode.Rows Do
		CurrentWidth = CurrentWidth + Number(GripNode.Attributes["w:w"]);
		GridArray.Add(CurrentWidth);
		PredecessorGridArray.Add(CurrentWidth);
	EndDo;
	
	ArrayOfAdditionGrid = New Array;
	CurrentWidth = 0;
	For Each GripNode In AdditionColumnsGripNode.Rows Do
		CurrentWidth = CurrentWidth + Number(GripNode.Attributes["w:w"]);
		ArrayOfAdditionGrid.Add(CurrentWidth);
		ArrayCellsWidth = 0;
		For GridIndex = 0 To GridArray.UBound() Do
			If CurrentWidth = GridArray[GridIndex] Then
				Break;
			ElsIf CurrentWidth > GridArray[GridIndex]
				And GridArray.UBound() = GridIndex Then
				GridArray.Add(CurrentWidth);
			ElsIf (CurrentWidth > GridArray[GridIndex]
				And CurrentWidth < GridArray[GridIndex+1]) Then
				GridArray.Insert(GridIndex+1, CurrentWidth);
				Break;
			EndIf;
			ArrayCellsWidth = ArrayCellsWidth + GridArray[GridIndex];
		EndDo;
	EndDo;															
	
	ArrayOfPredecessorColumnCount = ColumnsUsage(PredecessorColumnsGridNode, GridArray);
	ArrayOfAdditionalColumnCount = ColumnsUsage(AdditionColumnsGripNode, GridArray);
	
	SetGrid(NodeOfPredecessor, GridArray);
	SetGrid(AreaStartNode, GridArray);
	
	SetGridUsage(NodeOfPredecessor, ArrayOfPredecessorColumnCount);
	SetGridUsage(AreaStartNode, ArrayOfAdditionalColumnCount);

EndProcedure

Function ColumnsUsage(PredecessorColumnsGridNode, GridArray)
	
	ColumnsUsage = New Array;
	CurrentWidth = 0;
	GridColumnsUsedCount = 0;
	PreviousColumnNumber = 0;	
	For Each GripNode In PredecessorColumnsGridNode.Rows Do
		CurrentWidth = CurrentWidth + Number(GripNode.Attributes["w:w"]);
		ColumnsCount = GridArray.Find(CurrentWidth) - PreviousColumnNumber + 1;
		PreviousColumnNumber = GridArray.Find(CurrentWidth)+1;
		ColumnsUsage.Add(ColumnsCount);
		GridColumnsUsedCount = GridColumnsUsedCount + ColumnsCount;
	EndDo;
	
	If GridColumnsUsedCount < GridArray.Count() Then
		ColumnsUsage[ColumnsUsage.UBound()] = ColumnsUsage[ColumnsUsage.UBound()]
			+ GridArray.Count() - GridColumnsUsedCount;
	EndIf;
	
	Return ColumnsUsage;

EndFunction

Procedure SetGrid(NodeOfPredecessor, GridArray)
	
	GridDefiningNode = FindNodeByContent(NodeOfPredecessor, "w:tblGrid");
	GridDefiningNode.Rows.Clear();
	CurrentWidth = 0;
	For Each GridItem In GridArray Do
		ColumnGridDefiningNode = GridDefiningNode.Rows.Add();
		ColumnGridDefiningNode.NameTag = "w:gridCol";
		ColumnGridDefiningNode.Attributes.Insert("w:w", Format(GridItem-CurrentWidth, "NG=;"));
		CurrentWidth = GridItem;
	EndDo;

EndProcedure

Procedure SetGridUsage(Node, Val ArrayOfColumnCount)
	ArrayOfRowsNodes = New Array;
	SearchParameters = NodesSearchParameters();
	SearchParameters.IncludeSubordinates = False;
	FindNodesByContent(Node, "w:tr", ArrayOfRowsNodes, SearchParameters);
	
	For Each NodeOfRow In ArrayOfRowsNodes Do
		SearchParameters = NodesSearchParameters();
		SearchParameters.IncludeSubordinates = False;
		ArrayOfColumnsNodes = New Array;
		FindNodesByContent(NodeOfRow, "w:tc", ArrayOfColumnsNodes, SearchParameters);
		IndexOfUsed = 0;
		For ColumnIndex = 0 To ArrayOfColumnsNodes.UBound() Do
			ColumnNode = ArrayOfColumnsNodes[ColumnIndex];
			NodeOfColumnProperties = FindNodeByContent(ColumnNode, "w:tcPr");
			GridDefiningNode = FindNodeByContent(NodeOfColumnProperties, "w:gridSpan");
			If GridDefiningNode = Undefined Then
				GridDefiningNode = NodeOfColumnProperties.Rows.Add();
				GridDefiningNode.NameTag = "w:gridSpan";
				GridColumnCount = ArrayOfColumnCount[ColumnIndex];
			Else
				GridColumnCount = 0;
				GridColumnsCountBefore = Number("0"+GridDefiningNode.Attributes["w:val"]);
				For IndexOfUsedInOldGrid = IndexOfUsed To IndexOfUsed + GridColumnsCountBefore - 1 Do
					GridColumnCount = GridColumnCount + ArrayOfColumnCount[IndexOfUsedInOldGrid];
				EndDo;
				IndexOfUsed = IndexOfUsedInOldGrid;
			EndIf;
			GridDefiningNode.Attributes.Insert("w:val", Format(GridColumnCount, "NG=;"));
		EndDo;
	EndDo;
EndProcedure

Function TagNameCondition()
	Return PrintManagementClientServer.TagNameCondition();
EndFunction

Function AreaCondition(Area)
	ConditionArrayStart = StrSplit(Area.WholeText, "{", False);
	For IndexOf = 0 To ConditionArrayStart.UBound() Do
		If StrFind(ConditionArrayStart[IndexOf], TagNameCondition()+" ") Then
			ArrayOfEndCondition = StrSplit(ConditionArrayStart[IndexOf], "}", False);
			Return TrimAll(StrReplace(ArrayOfEndCondition[0], TagNameCondition()+" ", ""));
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

Function HasStringContainsAreaStart(Val Text, TabularSectionNames)
	
	Result = StrFind(Text, "{"+TagNameCondition()+" ") Or StrFind(Text, "{/"+TagNameCondition());
	HasStringContainsTableStart(Text, TabularSectionNames, Result);
	Return Result;
	
EndFunction

Function HasStringContainsTableStart(Text, TabularSectionNames, Result)

	If Not Result Then
		For Each TabularSectionName In TabularSectionNames Do
			Result = Result Or StrFind(Text, "["+TabularSectionName+".");
			If Result Then
				Break;
			EndIf;  			
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

Function GetPrintForm(TreeOfTemplate, StorageAddress = Undefined) Export
	
	DocumentPath = CollectOfficeDocumentFile(TreeOfTemplate);
	BinaryData = New BinaryData(DocumentPath);
	PrintFormStorageAddress = PutToTempStorage(BinaryData, 
		?(StorageAddress = Undefined, New UUID, StorageAddress));
	
	DeleteFiles(DocumentPath);
	DeleteFiles(TreeOfTemplate.DirectoryName);
	
	Return PrintFormStorageAddress;
EndFunction

// 
// 
// Parameters:
//  TreeOfTemplate - 
//  Encoding - String - Encoding
// 
// Returns:
//  String - 
//
Function CollectOfficeDocumentFile(TreeOfTemplate, Encoding = "UTF-8") Export
	DocumentStructure = TreeOfTemplate.DocumentStructure;
	Tree = DocumentStructure.DocumentTree;
	
	FilesToChange = New Map;
	FilesToChange.Insert("ContentRelations", TreeOfTemplate.DirectoryName + SetPathSeparator("\word\_rels\document.xml.rels"));
	FilesToChange.Insert("ContentTypes1",  TreeOfTemplate.DirectoryName + SetPathSeparator("\[Content_Types].xml"));
	FilesToChange.Insert("Document",      TreeOfTemplate.DirectoryName + SetPathSeparator("\word\document.xml"));
	
	
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("Document"));
	PutTreeToXMLEntry(XMLWriter, Tree);
	XMLWriter.Close();
	
	HeadersOrFootersFilesArray = New Array;
	
	For Each HeaderOrFooter In DocumentStructure.HeaderFooter Do
		FileName = TreeOfTemplate.DirectoryName + SetPathSeparator("\word\") + HeaderOrFooter.Key + ".xml";
		If Not HeaderOrFooter.Value.Rows.Count() Then
			Continue;
		EndIf;

		XMLWriter = New XMLWriter;
		XMLWriter = InitializeXMLRecord("", FileName);
		For Each Substring In HeaderOrFooter.Value.Rows Do
			WriteElement(XMLWriter, Substring);	
		EndDo;
		XMLWriter.Close();
		
		HeadersOrFootersFilesArray.Add(HeaderOrFooter.Key);
	EndDo;
	
	// 
	
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentRelations"));
	PutTreeToXMLEntry(XMLWriter, DocumentStructure.ContentRelations);
	XMLWriter.Close();
	
	// 
	
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentTypes1"));
	PutTreeToXMLEntry(XMLWriter, DocumentStructure.ContentTypes1);
	XMLWriter.Close();
	
	DocumentPath = GetTempFileName("DOCX");
	AssembleDOCXDocumentContainer(DocumentPath, TreeOfTemplate.DirectoryName);
	Return DocumentPath;
	
EndFunction

Procedure WriteElement(XMLWriter, TreeRow)
	If TreeRow.Attributes["o:gfxdata"] <> Undefined Then
		TagBuilder = InitializeXMLRecord("",,, False);
		TagBuilder.WriteStartElement(TreeRow.NameTag);
		For Each Attribute In TreeRow.Attributes Do
			TagBuilder.WriteStartAttribute(Attribute.Key);
			If Attribute.Key = "o:gfxdata" Then
				TagBuilder.WriteText("");
			Else
				TagBuilder.WriteText(Attribute.Value);
			EndIf;			
			TagBuilder.WriteEndAttribute();	
		EndDo;
		TagBuilder.WriteEndElement();
		TagPresentation = TagBuilder.Close();
		AttributePresentation_1 = "o:gfxdata="""+StrReplace(TreeRow.Attributes["o:gfxdata"], Char(10), "&#xA;")+"""";
		TagPresentation = StrReplace(TagPresentation, "o:gfxdata=""""", AttributePresentation_1);
		XMLWriter.WriteRaw(TagPresentation);
	Else
		XMLWriter.WriteStartElement(TreeRow.NameTag);
		For Each Attribute In TreeRow.Attributes Do
			XMLWriter.WriteAttribute(Attribute.Key, Attribute.Value);
		EndDo;
		
		If TreeRow.Text <> "" Then
			RecordText = TreeRow.Text;
			If StrStartsWith(RecordText, " HYPERLINK ") Then           
				ArrayOfField = StrSplit(RecordText, """");
				ArrayOfField[1] = EncodeString(ArrayOfField[1], StringEncodingMethod.URLEncoding);
				RecordText = StrConcat(ArrayOfField,"""");
			EndIf;
			XMLWriter.WriteText(RecordText);
		EndIf;
		
		For Each Substring In TreeRow.Rows Do
			WriteElement(XMLWriter, Substring);	
		EndDo;
	
		XMLWriter.WriteEndElement();
	EndIf;
	
EndProcedure

Procedure AssignValToDoc(Node, ReplacementCompliance, TreeOfTemplate, ShouldAddLinks) Export
	DocumentStructure = TreeOfTemplate.DocumentStructure;
	If Node.NameTag = "w:hyperlink" Then
		Hyperlinks = DocumentStructure.Hyperlinks;
		HyperlinkText = Hyperlinks[Node.Attributes["r:id"]];
		If StrFind(HyperlinkText, ReplacementCompliance.Key) = 0 Then
			Return;
		EndIf;
		HyperlinkText = StrReplace(HyperlinkText, ReplacementCompliance.Key, ReplacementCompliance.Value);
		If ShouldAddLinks Then
			ResourceID = TreeOfTemplate.DocumentStructure.LinkMaxID + 1;
			TreeOfTemplate.DocumentStructure.LinkMaxID = ResourceID;
			FullID = "rId" + Format(ResourceID, "NG=0");
			Node.Attributes["r:id"] = FullID;
			
	        Hyperlinks.Insert(FullID, HyperlinkText);
			NodeOfLinks = TreeOfTemplate.DocumentStructure.ContentRelations.Rows[0];
			HyperlinkLinksNode = NodeOfLinks.Rows.Add();
			HyperlinkLinksNode.NameTag = "Relationship";
			HyperlinkLinksNode.Attributes.Insert("Id", FullID); 
			HyperlinkLinksNode.Attributes.Insert("Target", HyperlinkText);
			HyperlinkLinksNode.Attributes.Insert("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink");
			HyperlinkLinksNode.Attributes.Insert("TargetMode", "External");
		Else
			FullID = Node.Attributes["r:id"];
			ArrayOfFoundNodes = New Array;
			SearchParameters = NodesSearchParameters();
			SearchParameters.AttributeName = "Id";
			SearchParameters.ValuesOfAttribute = FullID;
			FindNodesByContent(TreeOfTemplate.DocumentStructure.ContentRelations, "Relationship", ArrayOfFoundNodes, SearchParameters); 
			If ArrayOfFoundNodes.Count() <> 0 Then
				ArrayOfFoundNodes[0].Attributes.Insert("Target", HyperlinkText);	
				Hyperlinks.Insert(FullID, HyperlinkText);
			EndIf;
		EndIf;

	ElsIf TreeOfTemplate = Undefined Or TypeOf(ReplacementCompliance.Value) <> Type("Structure") Then
		If StrFind(ReplacementCompliance.Key, ".DSStamp") Then
			Node.NameTag = "w:bookmarkStart";
			Node.Text = "";
			Node.WholeText = "";
			Node.Attributes.Clear();
			Node.Attributes.Insert("w:id", "1");
			Node.Attributes.Insert("w:name", "V8DSStamp");
			Node.Rows.Clear();
				
			BookmarkEndNode = MakeCopyNode(Node.Parent, Node.Parent.Rows.IndexOf(Node)+1, Node);
			BookmarkEndNode.NameTag = "w:bookmarkEnd";
			BookmarkEndNode.Attributes.Delete("w:name");
		Else
			ValueStrings_ = StrSplit(ReplacementCompliance.Value, Chars.LF, True);
			LinesOfText = New Array;
			NodeText = Node.Text;
			KeyLngth = StrLen(ReplacementCompliance.Key);
			OccurrencePosition = StrFind(NodeText, ReplacementCompliance.Key);
			While OccurrencePosition <> 0 Do
				If OccurrencePosition > 1 Then
					LinesOfText.Add(Left(NodeText, OccurrencePosition-1));
				EndIf;
				
				LinesOfText.Add(ReplacementCompliance.Key);
				NodeText = Mid(NodeText, OccurrencePosition + KeyLngth);
				OccurrencePosition = StrFind(NodeText, ReplacementCompliance.Key);
			EndDo;
			
			If StrLen(NodeText) > 0 Then
				LinesOfText.Add(NodeText);
			EndIf;
			Node.Text = "";
			ParentOfNode = Node.Parent;
			
			For Each TextString In LinesOfText Do
				If TextString = ReplacementCompliance.Key Then
					For ValueRowIndex = 0 To ValueStrings_.UBound() Do
						ValueRow = ValueStrings_[ValueRowIndex];
						If ValueRowIndex = 0 Then
							Node.Text = Node.Text + ValueRow;
						Else
							NewLineNode = ParentOfNode.Rows.Insert(ParentOfNode.Rows.IndexOf(Node)+1);
							NewLineNode.IndexOf = Node.IndexOf + (1 - Node.IndexOf + Int(Node.IndexOf))/2; 
							NewLineNode.NameTag = "w:br";
							
							Node = MakeCopyNode(ParentOfNode, ParentOfNode.Rows.IndexOf(Node)+2, Node);
							Node.IndexOf = NewLineNode.IndexOf + (1 - NewLineNode.IndexOf + Int(NewLineNode.IndexOf))/2;
							Node.Text = ValueRow;
						EndIf;
					EndDo;
				Else
					Node.Text = Node.Text + TextString;
				EndIf;
			EndDo;
			
		EndIf;
		
	Else
		ValueStructure = ReplacementCompliance.Value;
		
		If Not IsTempStorageURL(ValueStructure.PictureAddress) Then
			Node.Text = "";
			Return;
		EndIf;
			
		BinaryData = GetFromTempStorage(ValueStructure.PictureAddress); // BinaryData - 
				
		StructurePicture = New Structure;
		StructurePicture.Insert("BinaryData",     BinaryData);
		StructurePicture.Insert("IconName",        "image");
				
		PictureParameters = GetImageAttributes(BinaryData);
				
		If PictureParameters.Count() = 0 Or PictureParameters.ImageType = Null Then
			Node.Text = "";
			Return;
		EndIf;
		
		PictureDimensions = New Structure("Width,Height",0,0);
		FillPropertyValues(PictureDimensions, ValueStructure);
		
		MainDisplayResolotion = StandardSubsystemsServer.ClientParametersAtServer().Get("MainDisplayResolotion");
		MainDisplayResolotion = ?(MainDisplayResolotion = Undefined, 72, MainDisplayResolotion);

		NodeForSearching = TreeOfTemplate.DocumentStructure.DocumentTree.Rows.Find(Node.IndexOf, "IndexOf", True);
		TableNode = FindParentNode(NodeForSearching, "w:tbl");
		If TableNode = Undefined Then
			TableCellWidth = 0;
		Else
			
			TableWidthDetailsNode = FindNodeByContent(TableNode, "w:tblW");
			
			DXAType = False;
			PCTType = False;
			
			TableWidth    = TableWidthDetailsNode.Attributes["w:w"];
			WidthType = TableWidthDetailsNode.Attributes["w:type"];   
			
			CellNode = FindParentNode(NodeForSearching, "w:tc");
			CellWidthDetailsNode = FindNodeByContent(CellNode, "w:tcW");
			TableCellWidth = CellWidthDetailsNode.Attributes["w:w"];
			
			If WidthType = "auto" Then
				DXAType = False;
			ElsIf WidthType = "dxa" Then
				DXAType = True;
			ElsIf WidthType = "pct" Then
				PCTType = True;
			EndIf;
			
			If Not DXAType Or (PCTType And TableWidth = 0) Then
				TableCellWidth = 0;
			ElsIf PCTType And Not TableWidth = 0 Then
				
				// 
				// 
				
				TableCellWidth = TableWidth * TableCellWidth / 50 / 100;
				
			EndIf;
		EndIf;
					
		If Not TableCellWidth = 0 Then
			
			HeightToWidthRatio = PictureParameters.Height / PictureParameters.Width;
			
			PictureWidth = TableCellWidth * 914400 / MainDisplayResolotion / 20;
			PictureHeight = HeightToWidthRatio * TableCellWidth * 914400 / MainDisplayResolotion / 20;
			
		Else
			
			If ValueIsFilled(PictureDimensions.Height) Or ValueIsFilled(PictureDimensions.Width) Then
				
				ConversionFactor_ = 914400/2.54/10;
				If PictureDimensions.Width <> 0 Then 
					PictureWidth = ConversionFactor_ * PictureDimensions.Width;
					ScalingCoeff = PictureWidth/PictureParameters.Width;
				EndIf;
				
				If PictureDimensions.Height <> 0 Then 
					PictureHeight = ConversionFactor_ * PictureDimensions.Height;
					ScalingCoeff = PictureHeight/PictureParameters.Height;
				EndIf;
				
				If PictureDimensions.Width = 0 Then
					PictureWidth = ScalingCoeff*PictureParameters.Width;
				EndIf;
				
				If PictureDimensions.Height = 0 Then
					PictureHeight = ScalingCoeff*PictureParameters.Height;
				EndIf;
				
			Else
				ScaleRatio = 2;
				ProportionsRatio = 914400 / (MainDisplayResolotion * ScaleRatio);
				
				PictureWidth = ProportionsRatio * PictureParameters.Width;
				PictureHeight = ProportionsRatio * PictureParameters.Height;
			EndIf;
		EndIf;
		
		PictureWidth = Round(PictureWidth, 0);
		PictureHeight = Round(PictureHeight, 0);
		
		StructurePicture.Insert("PictureExtension", StrReplace(PictureParameters.ImageType, "image/", ""));
		StructurePicture.Insert("PictureWidth",     PictureWidth);
		StructurePicture.Insert("PictureHeight",     PictureHeight);
		
		
		PutPictureInDCSDocLibrary(TreeOfTemplate, StructurePicture);
		PictureXMLTemplate = GetPictureTemplate();
		PrepareTemplateToXMLReading(PictureXMLTemplate);
		PreparePictureTemplate(PictureXMLTemplate, StructurePicture);
		PictureTree = ReadXMLStringToTree(StructurePicture.PictureText);
		
		PictureDocNode = PictureTree.Rows[0];
		PuttingIndex = Node.Parent.Rows.IndexOf(Node);
		
		ArrayOfTextParts = StrSplit(StrReplace(Node.Text, ReplacementCompliance.Key, Chars.LF), Chars.LF);
		For PartCounter = 0 To ArrayOfTextParts.UBound() Do
			TextPart = ArrayOfTextParts[PartCounter];
			If TextPart <> "" Then
				NodeToAdd = MakeCopyNode(Node.Parent, PuttingIndex, Node);
				NodeToAdd.Text = TextPart;
				PuttingIndex = PuttingIndex + 1;
			EndIf;
			
			If PartCounter < ArrayOfTextParts.UBound() Then
				For Each PictureNode In PictureDocNode.Rows Do
			   		NodeToAdd = MakeCopyNode(Node.Parent, PuttingIndex+1, PictureNode);
					CreateLowerLevelNodes(NodeToAdd, PictureNode);
					PuttingIndex = PuttingIndex + 1;
				EndDo;
			EndIf;
		EndDo;
		Node.Parent.Rows.Delete(Node);
		
	EndIf;

EndProcedure

Procedure PrepareTemplateToXMLReading(PictureXMLTemplate)
	PictureXMLTemplate = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>
		|<w:document xmlns:wpc=""http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"" xmlns:cx=""http://schemas.microsoft.com/office/drawing/2014/chartex"" xmlns:cx1=""http://schemas.microsoft.com/office/drawing/2015/9/8/chartex"" xmlns:cx2=""http://schemas.microsoft.com/office/drawing/2015/10/21/chartex"" xmlns:cx3=""http://schemas.microsoft.com/office/drawing/2016/5/9/chartex"" xmlns:cx4=""http://schemas.microsoft.com/office/drawing/2016/5/10/chartex"" xmlns:cx5=""http://schemas.microsoft.com/office/drawing/2016/5/11/chartex"" xmlns:cx6=""http://schemas.microsoft.com/office/drawing/2016/5/12/chartex"" xmlns:cx7=""http://schemas.microsoft.com/office/drawing/2016/5/13/chartex"" xmlns:cx8=""http://schemas.microsoft.com/office/drawing/2016/5/14/chartex"" xmlns:mc=""http://schemas.openxmlformats.org/markup-compatibility/2006"" xmlns:aink=""http://schemas.microsoft.com/office/drawing/2016/ink"" xmlns:am3d=""http://schemas.microsoft.com/office/drawing/2017/model3d"" xmlns:o=""urn:schemas-microsoft-com:office:office"" xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships"" xmlns:m=""http://schemas.openxmlformats.org/officeDocument/2006/math"" xmlns:v=""urn:schemas-microsoft-com:vml"" xmlns:wp14=""http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"" xmlns:wp=""http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"" xmlns:w10=""urn:schemas-microsoft-com:office:word"" xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"" xmlns:w14=""http://schemas.microsoft.com/office/word/2010/wordml"" xmlns:w15=""http://schemas.microsoft.com/office/word/2012/wordml"" xmlns:w16cid=""http://schemas.microsoft.com/office/word/2016/wordml/cid"" xmlns:w16se=""http://schemas.microsoft.com/office/word/2015/wordml/symex"" xmlns:wpg=""http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"" xmlns:wpi=""http://schemas.microsoft.com/office/word/2010/wordprocessingInk"" xmlns:wne=""http://schemas.microsoft.com/office/word/2006/wordml"" xmlns:wps=""http://schemas.microsoft.com/office/word/2010/wordprocessingShape"" mc:Ignorable=""w14 w15 w16se w16cid wp14"">"
		+ PictureXMLTemplate 
		+"</w:document>";
EndProcedure

Procedure PutPictureInDCSDocLibrary(TreeOfTemplate, StructurePicture)
	
	PicturesDirectory = TreeOfTemplate.DocumentStructure.PicturesDirectory;
	
	MediaDirectory = New File(PicturesDirectory);
	TypePicture = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image";
	
	If Not MediaDirectory.Exists() Then
		CreateDirectory(PicturesDirectory);
	EndIf;
	
	NodeOfLinks = TreeOfTemplate.DocumentStructure.ContentRelations.Rows[0];
	PictureExtension = StructurePicture.PictureExtension;
	
	ResourceID = TreeOfTemplate.DocumentStructure.LinkMaxID + 1;
	PictureLinksNode = NodeOfLinks.Rows.Add();
	PictureLinksNode.NameTag = "Relationship";
	PictureLinksNode.Attributes.Insert("Id", "rId" + Format(ResourceID, "NG=0"));
	TreeOfTemplate.DocumentStructure.LinkMaxID = ResourceID;
	PictureLinksNode.Attributes.Insert("Type", TypePicture);

	IconName  = StructurePicture.IconName + Format(ResourceID, "NG=0");
	ResourceName   = "media/" + IconName + "." + PictureExtension;
	PictureLinksNode.Attributes.Insert("Target", ResourceName);
	
	StructurePicture.Insert("rId", "rId" + Format(ResourceID, "NG=0"));
	StructurePicture.IconName = IconName;
	
	ContentTypes1 = TreeOfTemplate.DocumentStructure.ContentTypes1;
	PictureExtensionsNodes = New Array;
	NodesSearchParameters = NodesSearchParameters();
	NodesSearchParameters.AttributeName = "Extension";
	NodesSearchParameters.ValuesOfAttribute = PictureExtension;
	FindNodesByContent(ContentTypes1, "Default", PictureExtensionsNodes, NodesSearchParameters);
	If PictureExtensionsNodes.Count() = 0 Then
		TypesNode = ContentTypes1.Rows[0];
		NodeOfType = TypesNode.Rows.Add();
		NodeOfType.NameTag = "Default";  
		NodeOfType.Attributes.Insert("ContentType", "image/" + PictureExtension);
		NodeOfType.Attributes.Insert("Extension", PictureExtension);
	EndIf;
	
	BinaryData = StructurePicture.BinaryData;
	BinaryData.Write(PicturesDirectory + StructurePicture.IconName + "." + StructurePicture.PictureExtension);
	
EndProcedure

Procedure AddTransitionLevelAreas(Areas, DocumentTree)

	Areas.Sort("IndexOf");
	
	AreasToAdd = New Array;
	
	For AreaIndex = 0 To Areas.Count()-1 Do
		Area = Areas[AreaIndex];
		If AreaIndex = Areas.Count()-1 Then
			NextAreaStartIndex = AreaEndIndex(DocumentTree);
		Else
			NextAreaStartIndex = Areas[AreaIndex+1].IndexOf;
		EndIf;
		
		AddAreasUntilIndexIsReached(Area.DocTreeNode, Area.IndexOf, Area.AreaCondition, NextAreaStartIndex, AreasToAdd);					
		  
	EndDo;
	
	For Each AreaStructure In AreasToAdd Do
		NewArea = Areas.Add();
		FillPropertyValues(NewArea, AreaStructure);
		NewArea.IndexOf = NewArea.DocTreeNode.IndexOf;
	EndDo;
	
	Areas.Sort("IndexOf");
	
EndProcedure

Procedure AddAreasUntilIndexIsReached(DocTreeNode, CurrentAreaStartIndex, AreaCondition, NextAreaStartIndex, AreasToAdd)
	CurrentAreaEndIndex = AreaEndIndex(DocTreeNode);					
	If CurrentAreaEndIndex + 1 < NextAreaStartIndex Then
		AreaParent = DocTreeNode.Parent;
		CurrentAreaIndex = AreaParent.Rows.IndexOf(DocTreeNode);
		If CurrentAreaIndex = AreaParent.Rows.Count() - 1 Then
			AddAreasUntilIndexIsReached(AreaParent, CurrentAreaStartIndex, AreaCondition, NextAreaStartIndex, AreasToAdd)
		Else
			NodeToAdd = AreaParent.Rows[CurrentAreaIndex+1];
			If NodeToAdd.IndexOf + 1 < NextAreaStartIndex And NodeToAdd.IndexOf > CurrentAreaStartIndex Then
				AreaStructure = New Structure("DocTreeNode, AreaCondition");
				AreaStructure.DocTreeNode = NodeToAdd;
				AreaStructure.AreaCondition = AreaCondition;
				AreasToAdd.Add(AreaStructure);
				AddAreasUntilIndexIsReached(AreaParent, CurrentAreaStartIndex, AreaCondition, NextAreaStartIndex, AreasToAdd);
			EndIf;
		EndIf;
	EndIf;
EndProcedure

Function AreaEndIndex(DocTreeNode)
	RowsCount = DocTreeNode.Rows.Count();
	If RowsCount > 0 Then
		Return AreaEndIndex(DocTreeNode.Rows[RowsCount-1]);
	Else
		Return DocTreeNode.IndexOf;
	EndIf;
EndFunction

Procedure DeleteConditionalAreasTags(Indexes, DocumentTree)
	For Each IndexOf In Indexes Do
		Area = DocumentTree.Rows.Find(IndexOf, "IndexOf", True);
		Area.Parent.Rows.Delete(Area);
	EndDo;
EndProcedure

Procedure AddAreaWithCondition(Areas, Area)
	NextAreaNode = NextAreaBorder(Area, Areas);
	
	If NextAreaNode = Undefined Then
		Return;
	EndIf;
	
	FoundArea = Areas.Find(NextAreaNode, "DocTreeNode");
	
	If FoundArea = Undefined Then
		FoundArea = Areas.Add();
		FoundArea.DocTreeNode = NextAreaNode;
		FoundArea.IndexOf = FoundArea.DocTreeNode.IndexOf;
	EndIf;
	
	FoundArea.AreaCondition = AreaCondition(Area);
EndProcedure

Procedure ExcludeNestedTables(ObjectTablePartNames) Export
	For NameIndex = 0 To ObjectTablePartNames.UBound() Do
		IndexOfSearchName = ObjectTablePartNames.UBound();
		If NameIndex = IndexOfSearchName Then
			Break;
		EndIf;
		While True Do
			If StrStartsWith(ObjectTablePartNames[IndexOfSearchName], 
				ObjectTablePartNames[NameIndex]) Then
				
				ObjectTablePartNames.Delete(IndexOfSearchName);
				IndexOfSearchName = ObjectTablePartNames.UBound();
			Else
				IndexOfSearchName = IndexOfSearchName - 1;
			EndIf;    
			
			If NameIndex = IndexOfSearchName Then
				Break;
			EndIf;
		EndDo;
		If NameIndex = ObjectTablePartNames.UBound() Then
			Return;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

Procedure ParseDOCXDocumentContainer(Val FullFileName, Val FileStructurePath)
	
	Try
		Archiver = New ZipFileReader(FullFileName);
	Except
		DeleteFiles(FullFileName);
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(NStr("en = 'Cannot open template file. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Try
		Archiver.ExtractAll(FileStructurePath, ZIPRestoreFilePathsMode.Restore);
	Except
		Archiver.Close();
		DeleteFiles(FullFileName);
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(NStr("en = 'Cannot parse template file. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Archiver.Close();
	
EndProcedure

Procedure AssembleDOCXDocumentContainer(Val FullFileName, Val FileStructurePath)
	
	Try
		Archiver = New ZipFileWriter(FullFileName);
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(NStr("en = 'Cannot create MS Word document. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	FilesPackingMask = CommonClientServer.AddLastPathSeparator(FileStructurePath) + "*";
	
	Try
		Archiver.Add(FilesPackingMask, ZIPStorePathMode.StoreRelativePath, ZIPSubDirProcessingMode.ProcessRecursively);
		Archiver.Write();
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(NStr("en = 'Cannot generate MS Word document. Reason:';") + Chars.LF 
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Function AssembleDOCXDocumentFile(PrintForm)
	
	FilesToChange = New Map;
	FilesToChange.Insert("ContentRelations", PrintForm.DirectoryName + SetPathSeparator("\word\_rels\document.xml.rels"));
	FilesToChange.Insert("ContentTypes1",  PrintForm.DirectoryName + SetPathSeparator("\[Content_Types].xml"));
	FilesToChange.Insert("Document",      PrintForm.DirectoryName + SetPathSeparator("\word\document.xml"));
	
	// 
	HeaderOrFooterOutput = New Map;
	
	For Each Section In PrintForm.DocumentStructure.Sections Do
		
		For Each HeaderOrFooterItem In Section.Value.HeaderFooter Do
			
			HeaderOrFooter = HeaderOrFooterItem.Value;
			
			FileName = PrintForm.DirectoryName + SetPathSeparator("\word\") + HeaderOrFooter.InternalName1 + ".xml";
			If IsBlankString(HeaderOrFooter.Text) Then
				Continue;
			EndIf;
			
			XMLWriter = New TextWriter(FileName, TextEncoding.UTF8);
			XMLWriter.Write(HeaderOrFooter.Text);
			XMLWriter.Close();
			
			HeaderOrFooterOutput.Insert(HeaderOrFooterItem.Key, True);
			
		EndDo;
		
	EndDo;
	
	HeadersOrFootersFilesArray = New Array;
	
	For Each HeaderOrFooterItem In PrintForm.DocumentStructure.HeaderFooter Do
		
		If HeaderOrFooterOutput.Get(HeaderOrFooterItem.Key) = True Then
			Continue;
		EndIf;
		
		HeaderOrFooter = HeaderOrFooterItem.Value;
		HeaderOrFooter.Text = "";
		
		FileName = PrintForm.DirectoryName + SetPathSeparator("\word\") + HeaderOrFooter.InternalName1 + ".xml";
		DeleteFiles(FileName);
		HeadersOrFootersFilesArray.Add(HeaderOrFooter.InternalName1);
		
	EndDo;
	
	// 
	
	XMLReader = InitializeXMLReader(PrintForm.DocumentStructure.ContentRelations);
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentRelations"));
	
	SkipTag    = False;
	ContinueReading = True;
	
	While True Do
		
		If SkipTag Then
			XMLReader.Skip();
			ContinueReading = XMLReader.Read();
			SkipTag = False;
		Else
			ContinueReading = XMLReader.Read();
		EndIf;
		
		If Not ContinueReading Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "Relationship" Then
			
			AttributeValue = XMLReader.GetAttribute("Target");
			
			For Each HeaderOrFooterFileName In HeadersOrFootersFilesArray Do
				
				If StrFind(AttributeValue, HeaderOrFooterFileName) > 0 Then
					SkipTag = True;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If Not SkipTag Then
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	PrintForm.DocumentStructure.ContentRelations = XMLWriter.Close(); 
	
	// 
	
	XMLReader = InitializeXMLReader(PrintForm.DocumentStructure.ContentTypes1);
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentTypes1"));
	
	SkipTag    = False;
	ContinueReading = True;
	
	While True Do
		
		If SkipTag Then
			XMLReader.Skip();
			ContinueReading = XMLReader.Read();
			SkipTag = False;
		Else
			ContinueReading = XMLReader.Read();
		EndIf;
		
		If Not ContinueReading Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "Override" Then
			
			AttributeValue = XMLReader.GetAttribute("PartName");
			
			For Each HeaderOrFooterFileName In HeadersOrFootersFilesArray Do
				
				If StrFind(AttributeValue, HeaderOrFooterFileName) > 0 Then
					SkipTag = True;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If Not SkipTag Then
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	PrintForm.DocumentStructure.ContentTypes1 = XMLWriter.Close(); 
	
	// 
	
	SequenceNumber = 1;
	
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("Document"));
	
	SectionNumber           = Undefined;
	AreasCount     = PrintForm.DocumentStructure.AttachedAreas.Count();
	DocumentID = PrintForm.DocumentStructure.DocumentID;
	
	For Each Area In PrintForm.DocumentStructure.AttachedAreas Do
		
		If Area.SectionNumber = 0 Then
			Area.SectionNumber = ?(SectionNumber = Undefined, 1, SectionNumber);
		EndIf;
		
		OutputIntermediateSection = ?(SectionNumber <> Undefined And SectionNumber <> Area.SectionNumber, True, False);
		
		IsLastArea = ?(SequenceNumber = AreasCount, True, False);
		
		// 
		
		If OutputIntermediateSection = True And IsLastArea = False Then
			
			SectionToOutput = PrintForm.DocumentStructure.Sections.Get(SectionNumber);
			
			If SectionToOutput <> Undefined Then
				
				SectionText = ProcessDocumentSection(PrintForm.DocumentStructure, SectionToOutput);
				
				SectionOpeningTag = "<w:p w:rsidR=""" + DocumentID + """ w:rsidRDefault=""" + DocumentID + """><w:pPr>";
				SectionClosingTag = "</w:pPr></w:p>";
				SectionText = SectionOpeningTag + SectionText + SectionClosingTag;
				XMLWriter.WriteRaw(SectionText);
				
			EndIf;
			
		EndIf;
		
		// 
		
		XMLReader = InitializeXMLReader(Area.Text);
		
		While XMLReader.Read() Do
			
			If XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:body" Then
				Break;
			EndIf;
			
			If SequenceNumber > 1 Then
				
				If XMLReader.NodeType = XMLNodeType.StartElement And (XMLReader.Name = "w:document" Or XMLReader.Name = "w:body") Then
					Continue;
				EndIf;
				
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		EndDo;
		
		// 
		
		If IsLastArea Then
			
			SectionToOutput = PrintForm.DocumentStructure.Sections.Get(Area.SectionNumber);
			If SectionToOutput <> Undefined Then
				SectionText = ProcessDocumentSection(PrintForm.DocumentStructure, SectionToOutput);
				XMLWriter.WriteRaw(SectionText);
			EndIf;
			
		EndIf;
		
		SequenceNumber = SequenceNumber + 1;
		SectionNumber = Area.SectionNumber;
		
	EndDo;
	
	XMLWriter.WriteEndElement(); // 
	XMLWriter.WriteEndElement(); // 
	
	XMLWriter.Close();
	
	DocumentPath = GetTempFileName("DOCX");
	
	AssembleDOCXDocumentContainer(DocumentPath, PrintForm.DirectoryName);
	
	Return DocumentPath;
	
EndFunction


// Parameters:
//  SearchNode - ValueTreeRow of See DocumentTree
//  PuttingIndex - Number
//
Procedure FindStampLocationNode(SearchNode, PuttingIndex) Export
	If SearchNode.Parent.NameTag <> "w:body" And SearchNode.Parent.NameTag <> "w:tc" Then
		SearchNode = SearchNode.Parent;
		FindStampLocationNode(SearchNode, PuttingIndex);
	Else
		SearchNodeParent = SearchNode.Parent;
		PuttingIndex = SearchNodeParent.Rows.IndexOf(SearchNode);
		SearchNode = SearchNodeParent;
	EndIf;	
EndProcedure

// Parameters:
//  TableNode - ValueTreeRow of See DocumentTree
//  NodeOfText - ValueTreeRow of See DocumentTree
//
Procedure MoveFormattingParameters(TableNode, NodeOfText) Export
	
	RunThrough = NodeOfText.Parent;
	Paragraph = RunThrough.Parent;
	
	CharacteristicsOfText = FindNode(Paragraph, 1, "w:pPr");
	If CharacteristicsOfText = Undefined Then
		Return;
	EndIf;
	
	TextLayoutCharacteristic = FindNode(CharacteristicsOfText, 1, "w:jc");
	If TextLayoutCharacteristic = Undefined Then
		Return;
	EndIf;
	
	TableCharacteristics = FindNode(TableNode, 1, "w:tblPr");
	
	TableLayoutCharacteristic = TableCharacteristics.Rows.Add();
	FillPropertyValues(TableLayoutCharacteristic, TextLayoutCharacteristic);
	TableLayoutCharacteristic.Attributes = Common.CopyRecursive(TextLayoutCharacteristic.Attributes);
	
EndProcedure

Procedure DeleteInsignificantAttributes(Tree, InsignificantAttributes) Export
	For Each TreeRow In Tree.Rows Do
		
		For Each Attribute In InsignificantAttributes Do
			If TreeRow.Attributes.Get(Attribute) <> Undefined Then
				TreeRow.Attributes.Delete(Attribute);
			EndIf;
		EndDo;
				
		DeleteInsignificantAttributes(TreeRow, InsignificantAttributes);
	EndDo;
EndProcedure

Procedure InitializeTemplateStructure(Template)
	
	DirectoryName            = Template.DirectoryName;
	DocumentStructure     = Template.DocumentStructure;
	ContentLinksTable  = DocumentStructure.ContentLinksTable;
	
	File = New File(DirectoryName + "[Content_Types].xml");
	If File.Exists() Then
		Read = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = Read.Read();
		DocumentStructure.ContentTypes1 = FileText;
	EndIf;
	
	LinksFileDirectory = DirectoryName + SetPathSeparator("\word\_rels\");
	
	File = New File(LinksFileDirectory + "document.xml.rels");
	If File.Exists() Then
		XMLReader = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentRelations = FileText;
	
		XMLReader = InitializeXMLReader(FileText);
		While XMLReader.Read() Do
			If Not (XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "Relationship") Then
				Continue;
			EndIf;
			
			ResourceID    = XMLReader.GetAttribute("Id");
			
			StringOfExtraCharacters = StrConcat(StrSplit(ResourceID, "0123456789"));
			ResourceNumberAsString = StrConcat(StrSplit(ResourceID, StringOfExtraCharacters));
			
			ResourceNumber = Number(ResourceNumberAsString);
			
			NewRow = ContentLinksTable.Add();
			NewRow.ResourceName   = XMLReader.GetAttribute("Target");
			NewRow.ResourceID    = ResourceID;
			NewRow.ResourceNumber = ResourceNumber;
		EndDo;
	EndIf;
	
	// 
	
	DirectoryWithFileStructure = DirectoryName + "word" + GetPathSeparator();
	
	File = New File(DirectoryWithFileStructure + "document.xml"); //@Non-NLS
	If File.Exists() Then
		XMLReader = InitializeXMLReader(File.FullName, 1);
		AnalysisParameters = New Structure("AnalysisType", 1);
		SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters);
	EndIf;
	
	For Each Section In DocumentStructure.Sections Do
		XMLReader = InitializeXMLReader(Section.Value.Text);
		SelectHeadersFootersFormSection(XMLReader, DocumentStructure, Section.Value);
	EndDo;
	
	StructureFiles = FindFiles(DirectoryWithFileStructure, "*.xml");
	For Each File In StructureFiles Do
		If Not (Left(File.BaseName, 6) = "header") And Not (Left(File.BaseName, 6) = "footer") Then
			Continue;
		EndIf;
		
		HeaderOrFooter = DocumentStructure.HeaderFooter.Get(File.Name); // See HeaderOrFooterArea
		If HeaderOrFooter = Undefined Then
			Continue;
		EndIf;
		
		DocumentStructure.HeaderFooter.Delete(File.Name);
		DocumentStructure.HeaderFooter.Insert(HeaderOrFooter.Name + "_" + Format(HeaderOrFooter.SectionNumber, "NG=0"), HeaderOrFooter);
		
		XMLReader = InitializeXMLReader(File.FullName, 1);
		AnalysisParameters = New Structure("AnalysisType, AnalysisStructure", 2, HeaderOrFooter);
		SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters);
	EndDo;
	
EndProcedure

Procedure InitializePrintFormStructure(PrintForm, Template)
	
	DirectoryName        = PrintForm.DirectoryName;
	DocumentStructure = PrintForm.DocumentStructure;
	
	DocumentStructure.DocumentID = Template.DocumentStructure.DocumentID;
	DocumentStructure.PicturesDirectory        = DirectoryName + SetPathSeparator("\word\media\");
	DocumentStructure.ContentLinksTable = Template.DocumentStructure.ContentLinksTable.Copy();
	
	File = New File(DirectoryName + "[Content_Types].xml");
	If File.Exists() Then
		XMLReader = New TextReader(File.FullName,TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentTypes1 = FileText;
	EndIf;
	
	LinksFileDirectory = DirectoryName + SetPathSeparator("\word\_rels\");
	
	File = New File(LinksFileDirectory + "document.xml.rels");
	If File.Exists() Then
		XMLReader = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentRelations = FileText;
	EndIf;
	
	DirectoryWithFileStructure = DirectoryName + "word" + GetPathSeparator();
	FilesMask ="*.xml";
	StructureFiles = FindFiles(DirectoryWithFileStructure, FilesMask);
	
	For Each File In StructureFiles Do
		If File.BaseName = "document" Then
			XMLWriter = New TextWriter(File.FullName, TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
		
		If Left(File.BaseName, 6) = "header" Then
			XMLWriter = New TextWriter(File.FullName,TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
		
		If Left(File.BaseName, 6) = "footer" Then
			XMLWriter = New TextWriter(File.FullName, TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
	EndDo;
	
	// 
	For Each Section In Template.DocumentStructure.Sections Do
		AddSectionToDocumentStructure(DocumentStructure, Section.Value);
	EndDo;
	
	For Each HeaderOrFooter In Template.DocumentStructure.HeaderFooter Do
		
		AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooter.Value);
		HeaderOrFooterStructure = DocumentStructure.HeaderFooter.Get(HeaderOrFooter.Key);
		If HeaderOrFooterStructure <> Undefined Then
			HeaderOrFooterStructure.Text = "";
		EndIf;
		
	EndDo;
	
	Paragraph = Template.DocumentStructure.DocumentAreas.Get("Paragraph");
	
	If Paragraph <> Undefined Then
		AddDocumentAreaToDocumentStructure(DocumentStructure, Paragraph);
	EndIf;
	
EndProcedure

Procedure FillAreaParameters(PrintForm, Area, ObjectData)
	
	ProcessText = False;
	XMLParseStructure = InitializeMXLParsing();
	
	TableOpen       = False; 
	TableCellOpen = False;
	IsPreserveSpaceAttributeSpecified = False;
	
	TableWidth         = 0;
	TableCellWidth   = 0;
	
	MainDisplayResolotion = StandardSubsystemsServer.ClientParametersAtServer().Get("MainDisplayResolotion");
	MainDisplayResolotion = ?(MainDisplayResolotion = Undefined, 72, MainDisplayResolotion);
	
	XMLReader = InitializeXMLReader(Area.Text);
	InitializeWriteToStream(XMLParseStructure, "Area", "");
	
	While XMLReader.Read() Do
		
		If ReadStringTextStart(XMLParseStructure, XMLReader) Then
			ProcessText = True;
			IsPreserveSpaceAttributeSpecified = False;
		EndIf;
		
		If ReadStringTextEnd(XMLParseStructure, XMLReader) Then
			ProcessText = False;
		EndIf;
		
		If ReadTableStart(XMLParseStructure, XMLReader) Then
			TableOpen = True;
		EndIf;
		
		If TableOpen And ReadTableWidthStart(XMLParseStructure, XMLReader) Then
			SetFieldWidth(XMLReader, TableWidth);
		EndIf;
		
		If TableOpen And ReadTableCellStart(XMLParseStructure, XMLReader) Then
			TableCellOpen = True;
		EndIf;
		
		If TableCellOpen And ReadTableCellWidthStart(XMLParseStructure, XMLReader) Then
			SetFieldWidth(XMLReader, TableCellWidth, TableWidth);
		EndIf;
		
		If ReadTableCellEnd(XMLParseStructure, XMLReader) Then
			TableCellOpen = False;
			TableCellWidth  = 0;
		EndIf;
		
		If ReadTableEnd(XMLParseStructure, XMLReader) Then
			TableOpen = False;
			TableWidth  = 0;
		EndIf;
			
		If ProcessText And XMLReader.NodeType = XMLNodeType.Text Then
			
			NodeText = XMLReader.Value;
			
			ParametersFromText = New Array;
			
			SelectParameters(ParametersFromText, NodeText);
			
			TextOutput = True;
			PictureOutput = False;
			ParameterValue = Undefined;
			PictureDimensions = New Structure("Width,Height",0,0);
			
			For Each ParameterText In ParametersFromText Do
				
				If ObjectData.Property(ParameterText, ParameterValue) Then
					If TypeOf(ParameterValue) = Type("Structure") Then
						FillPropertyValues(PictureDimensions, ParameterValue);
						ParameterValue = TrimAll(ParameterValue.PictureAddress);
					Else
						ParameterValue = String(ParameterValue);
					EndIf;
				EndIf;
				
				If TypeOf(ParameterValue) = Type("String") And Not StrStartsWith(ParameterValue, "e1cib/tempstorage") Then
					NodeText = StrReplace(NodeText, "{v8 " + ParameterText + "}", ParameterValue);
				ElsIf TypeOf(ParameterValue) = Type("String") And StrStartsWith(ParameterValue, "e1cib/tempstorage") Then
					NodeText = ParameterValue;
					TextOutput = False;
					PictureOutput = True;
					Break;
				EndIf;
				
			EndDo;
			
			If TextOutput Then
				
				WriteTextToStreams(XMLParseStructure, XMLReader, "Area", NodeText, IsPreserveSpaceAttributeSpecified);
				
			ElsIf PictureOutput Then
				
				BinaryData = GetFromTempStorage(NodeText); // BinaryData - 
				
				StructurePicture = New Structure;
				StructurePicture.Insert("BinaryData",     BinaryData);
				StructurePicture.Insert("IconName",        "image");
				StructurePicture.Insert("PicturesDirectory",    PrintForm.DocumentStructure.PicturesDirectory);
				
				PictureParameters = GetImageAttributes(BinaryData);
				
				If PictureParameters.Count() = 0 Or PictureParameters.ImageType = Null Then
					WriteTextToStreams(XMLParseStructure, XMLReader, "Area", NodeText);
					Continue;
				EndIf;
				
				If Not TableCellWidth = 0 Then
					
					HeightToWidthRatio = PictureParameters.Height / PictureParameters.Width;
					
					PictureWidth = TableCellWidth * 914400 / MainDisplayResolotion / 20;
					PictureHeight = HeightToWidthRatio * TableCellWidth * 914400 / MainDisplayResolotion / 20;
					
				Else
					
					If PictureDimensions.Height <> 0 Or PictureDimensions.Width <> 0 Then
						
						ConversionFactor_ = 914400/2.54/10;
						If PictureDimensions.Width <> 0 Then 
							PictureWidth = ConversionFactor_ * PictureDimensions.Width;
							ScalingCoeff = PictureWidth/PictureParameters.Width;
						EndIf;
						
						If PictureDimensions.Height <> 0 Then 
							PictureHeight = ConversionFactor_ * PictureDimensions.Height;
							ScalingCoeff = PictureHeight/PictureParameters.Height;
						EndIf;
						
						If PictureDimensions.Width = 0 Then
							PictureWidth = ScalingCoeff*PictureParameters.Width;
						EndIf;
						
						If PictureDimensions.Height = 0 Then
							PictureHeight = ScalingCoeff*PictureParameters.Height;
						EndIf;
						
					Else
						ScaleRatio = 2;
						ProportionsRatio = 914400 / (MainDisplayResolotion * ScaleRatio);
						
						PictureWidth = ProportionsRatio * PictureParameters.Width;
						PictureHeight = ProportionsRatio * PictureParameters.Height;
					EndIf;
				EndIf;
				
				PictureWidth = Round(PictureWidth, 0);
				PictureHeight = Round(PictureHeight, 0);
				
				StructurePicture.Insert("PictureExtension", StrReplace(PictureParameters.ImageType, "image/", ""));
				StructurePicture.Insert("PictureWidth",     PictureWidth);
				StructurePicture.Insert("PictureHeight",     PictureHeight);
				
				
				IncludePictureToDocumentLibrary(PrintForm.DocumentStructure, StructurePicture);
				PictureXMLTemplate = GetPictureTemplate();
				PreparePictureTemplate(PictureXMLTemplate, StructurePicture);
				IncludePictureTextToDocument(XMLParseStructure.WriteStreams.Area.Stream, StructurePicture);
				
			EndIf
			
		Else
			WriteXMLItemToStream(XMLParseStructure, XMLReader, PrintForm.DocumentStructure, IsPreserveSpaceAttributeSpecified);
		EndIf;
		
	EndDo;
	
	Area.Text = CompleteWriteToStream(XMLParseStructure, "Area");
	
EndProcedure

// Parameters:
//  PrintForm - See InitializePrintForm
//  Area - Structure:
//   * Name - String
//   * Text - String
//   * SectionNumber - Number
//   * Hyperlinks - Array of See HyperlinkStructure
//  ObjectData - 
//
Procedure PopulateHyperlinkParameters(PrintForm, Area, ObjectData)
	
	If Area.Hyperlinks.Count() = 0 Then
		Return;
	EndIf;
	
	DocumentStructure = PrintForm.DocumentStructure;
	ContentLinksTable = DocumentStructure.ContentLinksTable;
	
	LinkTree = ReadXMLStringToTree(DocumentStructure.ContentRelations);
	RelationsNode = LinkTree.Rows[0];
	ArrayOfFoundNodes = New Array;
	NodesSearchParameters = NodesSearchParameters();
	NodesSearchParameters.AttributeName = "Type";
	NodesSearchParameters.ValuesOfAttribute = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink";
	FindNodesByContent(LinkTree, "Relationship", ArrayOfFoundNodes, NodesSearchParameters);
	
	For ArrayIndex = 0 To Area.Hyperlinks.UBound() Do
		
		Hyperlink 	= Area.Hyperlinks[ArrayIndex];
		ResourceID		= Hyperlink.ResourceID;
		ParameterName	= Hyperlink.ParameterName;
		
		If Not IsBlankString(ParameterName) Then
			LinkString_      = Hyperlink.Ref;
			ParameterValue = "";
			
			If ObjectData.Property(ParameterName, ParameterValue) Then
				ParameterValue = EncodeString(TrimAll(ParameterValue), StringEncodingMethod.URLEncoding);
			EndIf;
			ValueToSet = StrReplace(LinkString_, "{v8 " + ParameterName +"}" , ParameterValue);
			
			StringOfContentLinks = ContentLinksTable.Find(ResourceID, "ResourceID");
			
			If DecodeString(StringOfContentLinks.ResourceName, StringEncodingMethod.URLEncoding) = LinkString_ Then
				StringOfContentLinks.ResourceName 	= ValueToSet;
				
				For Each HyperlinkNode In ArrayOfFoundNodes Do
					If HyperlinkNode.Attributes["Id"] = ResourceID Then
						HyperlinkNode.Attributes.Insert("Target", ValueToSet);
						Break;
					EndIf;
				EndDo;
				
			Else
				ContentLinksTable.Sort("ResourceNumber Asc");
				ResourceNewNumber = ContentLinksTable[ContentLinksTable.Count() - 1].ResourceNumber + 1;
				
				ResourceNewID = "rId" + Format(ResourceNewNumber, "NG=0");
				
				NewRowRefs 				= ContentLinksTable.Add();
				NewRowRefs.ResourceNumber	= ResourceNewNumber;
				NewRowRefs.ResourceID		= ResourceNewID;
				NewRowRefs.ResourceName 	= ValueToSet;
				
				NewLink = RelationsNode.Rows.Add();
				NewLink.NameTag = "Relationship";
				NewLink.Attributes = New Map;
				NewLink.Attributes.Insert("Target", ValueToSet);
				NewLink.Attributes.Insert("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink");
				NewLink.Attributes.Insert("Id", ResourceNewID);
				NewLink.Attributes.Insert("TargetMode", "External");
				
				Area.Text = StrReplace(Area.Text, "r:id="""+ResourceID+"""", "r:id="""+ResourceNewID+"""");
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DocumentStructure.ContentRelations = PutTreeToXMLString(LinkTree);
	
	
EndProcedure

Procedure SelectParameters(ParametersArray, Val Text)

	ParameterStart = StrFind(Text, "{v8 ");
	
	If ParameterStart > 0 Then
		
		Text = Right(Text, StrLen(Text) - (ParameterStart+3));
		ParameterEnd = StrFind(Text, "}");
		If ParameterEnd > 0 Then
			ParameterText1 = TrimAll(Left(Text, ParameterEnd-1));
			ParametersArray.Add(ParameterText1);
			Text = Right(Text, StrLen(Text) - (StrLen(ParameterText1) + 1));
		EndIf;
		
		ParameterStart = StrFind(Text, "{v8 ");
		If ParameterStart > 0 Then
			SelectParameters(ParametersArray, Text);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SetFieldWidth(XMLReader, Width, Val TableWidth = 0)
	
	DXAType = False;
	PCTType = False;
	
	Width    = XMLReader.GetAttribute("w:w");
	WidthType = XMLReader.GetAttribute("w:type");
	
	If WidthType = "auto" Then
		DXAType = False;
	ElsIf WidthType = "dxa" Then
		DXAType = True;
	ElsIf WidthType = "pct" Then
		PCTType = True;
	EndIf;
	
	If Not DXAType Or (PCTType And TableWidth = 0) Then
		Width = 0;
	ElsIf PCTType And Not TableWidth = 0 Then
		
		// 
		// 
		
		Width = TableWidth * Width / 50 / 100;
		
	EndIf;
	
EndProcedure

Function GetPictureTemplate()
	
	PictureXMLTemplate =
	"<w:drawing>
	|	<wp:inline distT=""0"" distB=""0"" distL=""0"" distR=""0"">
	|		<wp:extent cx=""%6"" cy=""%7""/>
	|		<wp:effectExtent l=""0"" t=""0"" r=""0"" b=""0""/>
	|		<wp:docPr id=""%1"" name=""%2""/>
	|		<wp:cNvGraphicFramePr>
	|			<a:graphicFrameLocks xmlns:a=""http://schemas.openxmlformats.org/drawingml/2006/main"" noChangeAspect=""1""/>
	|		</wp:cNvGraphicFramePr>
	|		<a:graphic xmlns:a=""http://schemas.openxmlformats.org/drawingml/2006/main"">
	|			<a:graphicData uri=""http://schemas.openxmlformats.org/drawingml/2006/picture"">
	|				<pic:pic xmlns:pic=""http://schemas.openxmlformats.org/drawingml/2006/picture"">
	|					<pic:nvPicPr>
	|						<pic:cNvPr id=""%1"" name=""%2"" descr=""%3""/>
	|						<pic:cNvPicPr>
	|							<a:picLocks noChangeAspect=""1"" noChangeArrowheads=""1""/>
	|						</pic:cNvPicPr>
	|					</pic:nvPicPr>
	|					<pic:blipFill>
	|						<a:blip r:embed=""%4"">
	|							<a:extLst>
	|								<a:ext uri=""%5"">
	|									<a14:useLocalDpi xmlns:a14=""http://schemas.microsoft.com/office/drawing/2010/main"" val=""0""/>
	|								</a:ext>
	|							</a:extLst>
	|						</a:blip>
	|						<a:srcRect/>
	|						<a:stretch>
	|							<a:fillRect/>
	|						</a:stretch>
	|					</pic:blipFill>
	|					<pic:spPr bwMode=""auto"">
	|						<a:xfrm>
	|							<a:off x=""0"" y=""0""/>
	|							<a:ext cx=""%6"" cy=""%7""/>
	|						</a:xfrm>
	|						<a:prstGeom prst=""rect"">
	|							<a:avLst/>
	|						</a:prstGeom>
	|						<a:noFill/>
	|						<a:ln>
	|							<a:noFill/>
	|						</a:ln>
	|					</pic:spPr>
	|				</pic:pic>
	|			</a:graphicData>
	|		</a:graphic>
	|	</wp:inline>
	|</w:drawing>";
	
	Return PictureXMLTemplate;
	
EndFunction

Procedure PreparePictureTemplate(TemplatePicture, StructurePicture)
	
	// 
	// 
	// 
	// 
	// 
	// 
	// 
	// 
	ProcessedPictureTemplate = StringFunctionsClientServer.SubstituteParametersToString(TemplatePicture, 
		"0",
		StructurePicture.IconName,
		StructurePicture.IconName,
		StructurePicture.rId,
		"{28A0092B-C50C-407E-A947-70E740481C1C}", 
		Format(StructurePicture.PictureWidth, "NG=0"),
		Format(StructurePicture.PictureHeight, "NG=0"));
										   
	StructurePicture.Insert("PictureText", ProcessedPictureTemplate);
	
EndProcedure

Procedure IncludePictureToDocumentLibrary(DocumentStructure, StructurePicture)
	
	MediaDirectory = New File(StructurePicture.PicturesDirectory);
	TypePicture = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image";
	
	If Not MediaDirectory.Exists() Then
		CreateDirectory(StructurePicture.PicturesDirectory);
	EndIf;
	
	// 
	XMLReader = InitializeXMLReader(DocumentStructure.ContentRelations);
	XMLWriter = InitializeXMLRecord("");
	
	DocumentStructure.ContentLinksTable.Sort("ResourceNumber Asc");
	MaxResourceNumber = DocumentStructure.ContentLinksTable[DocumentStructure.ContentLinksTable.Count() - 1].ResourceNumber;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "Relationships" Then
			
			ResourceNumber = MaxResourceNumber + 1;
			ResourceID    = "rId" + Format(MaxResourceNumber + 1, "NG=0");
			IconName  = StructurePicture.IconName + ResourceID;
			ResourceName   = "media/" + IconName + "." + StructurePicture.PictureExtension;
			
			AddRowToContentLinksTable(DocumentStructure, ResourceName, ResourceID, ResourceNumber);
			
			StructurePicture.Insert("rId", ResourceID);
			StructurePicture.IconName = IconName;
			
			XMLWriter.WriteStartElement("Relationship");
			XMLWriter.WriteAttribute("Target", ResourceName);
			XMLWriter.WriteAttribute("Type",   TypePicture);
			XMLWriter.WriteAttribute("Id",     ResourceID);
			XMLWriter.WriteEndElement();
			
			WriteXMLItem(XMLReader, XMLWriter);
			
			AddPictureExtensionToContentTypes(DocumentStructure, StructurePicture);
			
		Else
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	DocumentStructure.ContentRelations = XMLWriter.Close();
	
	// 
	BinaryData = StructurePicture.BinaryData;
	BinaryData.Write(StructurePicture.PicturesDirectory + StructurePicture.IconName + "." + StructurePicture.PictureExtension);
	
EndProcedure

Procedure IncludePictureTextToDocument(XMLWriter, StructurePicture)
	
	XMLWriter.WriteEndElement(); // 
	XMLWriter.WriteRaw(StructurePicture.PictureText);
	XMLWriter.WriteStartElement("w:t");
	
EndProcedure

Procedure AddPictureExtensionToContentTypes(DocumentStructure, StructurePicture)
	
	AddedExtensions = DocumentStructure.PicturesExtensions;
	PictureExtension    = StructurePicture.PictureExtension; 
	
	If Not AddedExtensions.Find(PictureExtension) = Undefined Then
		Return;
	EndIf;
	
	XMLReader = InitializeXMLReader(DocumentStructure.ContentTypes1);
	
	XMLWriter = InitializeXMLRecord("");
	
	HasExtension = False;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "Default" Then
			
			ExtensionValue = XMLReader.AttributeValue("Extension");
			
			If ExtensionValue = PictureExtension Then
				HasExtension = True;
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "Types" Then
			
			If Not HasExtension Then
			
				XMLWriter.WriteStartElement("Default");
				XMLWriter.WriteAttribute("ContentType", "image/" + PictureExtension);
				XMLWriter.WriteAttribute("Extension", PictureExtension);
				XMLWriter.WriteEndElement();
				
				AddedExtensions.Add(PictureExtension);
			
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		Else
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	DocumentStructure.ContentTypes1 = XMLWriter.Close();
	
EndProcedure

#Region SimpleOperationsWithXMLData

Function InitializeXMLRecord(RootTag, PathToFile = "", Encoding = "UTF-8", WriteDeclaration = True)
	
	XMLWriter = New XMLWriter;
	XMLWriter.Indent = False;
	If IsBlankString(PathToFile) Then
		XMLWriter.SetString();
	Else
		XMLWriter.OpenFile(PathToFile)
	EndIf;
	
	If WriteDeclaration Then
		XMLWriter.WriteRaw("<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>");
	EndIf;
	
	If Not IsBlankString(RootTag) Then
		XMLWriter.WriteStartElement(RootTag);
	EndIf;
	
	Return XMLWriter;
	
EndFunction

Function InitializeXMLReader(ReadingData, DataType = 0)
	
	XMLReader = New XMLReader;
	If DataType = 0 Then
		XMLReader.SetString(ReadingData);
	Else
		XMLReader.OpenFile(ReadingData);
	EndIf;
	
	XMLReader.IgnoreWhitespace = False;
	
	Return XMLReader;
	
EndFunction

Procedure WriteXMLItem(XMLReader, XMLWriter, Text = Undefined)
	
	If XMLReader.NodeType = XMLNodeType.ProcessingInstruction Then
		
		XMLWriter.WriteProcessingInstruction(XMLReader.Name, XMLReader.Value);
		
	ElsIf XMLReader.NodeType = XMLNodeType.StartElement Then
		
		XMLWriter.WriteStartElement(XMLReader.Name);
		
		While XMLReader.ReadAttribute() Do
			
			XMLWriter.WriteStartAttribute(XMLReader.Name);
			XMLWriter.WriteText(XMLReader.Value);
			XMLWriter.WriteEndAttribute();
			
		EndDo;
		
	ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
		
		XMLWriter.WriteEndElement();
		
	ElsIf XMLReader.NodeType = XMLNodeType.Text Then
		
		If Text = Undefined Then
			XMLWriter.WriteText(XMLReader.Value);
		Else
			XMLWriter.WriteText(Text);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ParseXMLDocumentToAreas

Procedure InitializeWriteToStream(XMLParseStructure, StreamName, RootTag = "w:next", WriteDeclaration = True)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		XMLParseStructure.WriteStreams.Insert(StreamName, New Structure("Stream, WritingAllowed, Level, ThreadTerminated, StreamText, ParagraphLevel"));
	EndIf;
	
	If Not XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		ContinueWriteToStream(XMLParseStructure, StreamName);
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed  = True;
	XMLParseStructure.WriteStreams[StreamName].Stream            = InitializeXMLRecord(RootTag, , , WriteDeclaration);
	XMLParseStructure.WriteStreams[StreamName].Level          = ?(IsBlankString(RootTag), 0, 1);
	XMLParseStructure.WriteStreams[StreamName].ThreadTerminated      = False;
	XMLParseStructure.WriteStreams[StreamName].StreamText      = "";
	XMLParseStructure.WriteStreams[StreamName].ParagraphLevel    = XMLParseStructure.CurrentParagraphLevel;
	
EndProcedure

Procedure StopWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = False;
	
EndProcedure

Procedure ContinueWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = True;
	
EndProcedure

Procedure ResetWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined;
	
EndProcedure

Function CompleteWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return "";
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return "";
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return "";
	EndIf;
	
	While XMLParseStructure.WriteStreams[StreamName].Level > 0 Do
		XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[StreamName].Level = XMLParseStructure.WriteStreams[StreamName].Level - 1;
	EndDo;
	
	XMLParseStructure.WriteStreams[StreamName].StreamText = XMLParseStructure.WriteStreams[StreamName].Stream.Close();
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined;
	XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True;
	
	Return XMLParseStructure.WriteStreams[StreamName].StreamText;
	
EndFunction

Procedure TransferWriteToStream(XMLParseStructure, SourceStreamName, RecipientStreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = RecipientStreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(SourceStreamName)
		 Or Not XMLParseStructure.WriteStreams.Property(RecipientStreamName) Then
		Return;
	EndIf;
	
	CompleteWriteToStream(XMLParseStructure, SourceStreamName);
	
	StreamText = XMLParseStructure.WriteStreams[SourceStreamName].StreamText;
	StreamText = StrReplace(StreamText, "<w:next>", "<w:next " + XMLParseStructure.XMLAttributes + ">");
	
	XMLReader = InitializeXMLReader(StreamText);
	
	While XMLReader.Read() Do
		
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLParseStructure.WriteStreams[RecipientStreamName].Stream);
		
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure TransferOpeningTagsOfWriteToStream(XMLParseStructure, SourceStreamName, RecipientStreamName, StopTag)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = RecipientStreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(SourceStreamName)
		 Or Not XMLParseStructure.WriteStreams.Property(RecipientStreamName) Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams[SourceStreamName].ThreadTerminated Then
		XMLParseStructure.WriteStreams[SourceStreamName].WritingAllowed = False;
		XMLParseStructure.WriteStreams[SourceStreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[SourceStreamName].StreamText = XMLParseStructure.WriteStreams[SourceStreamName].Stream.Close();
		XMLParseStructure.WriteStreams[SourceStreamName].ThreadTerminated = True;
	EndIf;
	
	StreamText = XMLParseStructure.WriteStreams[SourceStreamName].StreamText;
	StreamText = StrReplace(StreamText, "<w:next>", "<w:next " + XMLParseStructure.XMLAttributes + ">");
	
	XMLReader = InitializeXMLReader(StreamText);
	
	While XMLReader.Read() Do
		
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = StopTag Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			XMLParseStructure.WriteStreams[RecipientStreamName].Level = XMLParseStructure.WriteStreams[RecipientStreamName].Level + 1;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement Then
			XMLParseStructure.WriteStreams[RecipientStreamName].Level = XMLParseStructure.WriteStreams[RecipientStreamName].Level - 1;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLParseStructure.WriteStreams[RecipientStreamName].Stream);
		
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure AddAttributeToStream(XMLParseStructure, StreamName, AttributeName, AttributeValue)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteStartAttribute(AttributeName);
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteText(AttributeValue);
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndAttribute();
	
EndProcedure

Procedure AddTextToStream(XMLParseStructure, StreamName, Text)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteText(Text);
	
EndProcedure

Procedure CloseItemsInStream(XMLParseStructure, StreamName, ItemCount)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	For IndexOf = 1 To ItemCount Do
		XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[StreamName].Level = XMLParseStructure.WriteStreams.ParamStrings.Level - 1;
	EndDo;
	
EndProcedure

Function StreamActive(XMLParseStructure, StreamName)
	
	If Not XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return False;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure WriteProcessingInstructionToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If XMLParseStructure.CurrentParagraphLevel <> StreamItem.Value.ParagraphLevel Then
			Continue;
		EndIf;
		
		If Not IsBlankString(XMLParseStructure.LockingStream) And Not StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If Not IsBlankString(StreamName) And Not StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If Not StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteProcessingInstruction(XMLReader.Name, XMLReader.Value);
		
	EndDo;
	
EndProcedure

Procedure WriteStreamStartToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If XMLParseStructure.CurrentParagraphLevel <> StreamItem.Value.ParagraphLevel Then
			Continue;
		EndIf;
		
		If Not IsBlankString(XMLParseStructure.LockingStream) And Not StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If Not IsBlankString(StreamName) And Not StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If Not StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteStartElement(XMLReader.Name);
		StreamItem.Value.Level = StreamItem.Value.Level + 1;
		
	EndDo;
	
EndProcedure

Procedure WriteAttributeToStreams(XMLParseStructure, XMLReader, StreamName = "", Val Text = Undefined)
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If XMLParseStructure.CurrentParagraphLevel <> StreamItem.Value.ParagraphLevel Then
			Continue;
		EndIf;
		
		If Not IsBlankString(XMLParseStructure.LockingStream) And Not StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If Not IsBlankString(StreamName) And Not StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If Not StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		If Text = Undefined Then
			Text = XMLReader.Value;
		EndIf;
		
		StreamItem.Value.Stream.WriteStartAttribute(XMLReader.Name);
		StreamItem.Value.Stream.WriteText(Text);
		StreamItem.Value.Stream.WriteEndAttribute();
		
	EndDo;
	
EndProcedure

Procedure WriteItemEndToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If XMLParseStructure.CurrentParagraphLevel <> StreamItem.Value.ParagraphLevel Then
			Continue;
		EndIf;
		
		If Not IsBlankString(XMLParseStructure.LockingStream) And Not StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If Not IsBlankString(StreamName) And Not StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If Not StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteEndElement();
		StreamItem.Value.Level = StreamItem.Value.Level - 1;
		
	EndDo;
	
EndProcedure

Procedure WriteTextToStreams(XMLParseStructure, XMLReader, StreamName = "", Val Text = Undefined, IsPreserveSpaceAttributeSpecified = Undefined)
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If XMLParseStructure.CurrentParagraphLevel <> StreamItem.Value.ParagraphLevel Then
			Continue;
		EndIf;
		
		If Not IsBlankString(XMLParseStructure.LockingStream) And Not StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If Not IsBlankString(StreamName) And Not StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If Not StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		If Text = Undefined Then
			Text = XMLReader.Value;
		EndIf;
		
		CountOfRows = ?(IsBlankString(Text), 1, StrLineCount(Text));
		
		If CountOfRows > 1 Then
			
			For Indus = 1 To CountOfRows Do
				
				TextString = StrGetLine(Text, Indus);
				If IsPreserveSpaceAttributeSpecified = False Then
					StreamItem.Value.Stream.WriteAttribute("xml:space", "preserve");
				EndIf;
				StreamItem.Value.Stream.WriteText(TextString);
				
				If Indus < CountOfRows Then
					StreamItem.Value.Stream.WriteEndElement();
					StreamItem.Value.Stream.WriteStartElement("w:br");
					StreamItem.Value.Stream.WriteEndElement();
					StreamItem.Value.Stream.WriteStartElement("w:t");
				EndIf;
				
			EndDo;
			
		Else
			If IsPreserveSpaceAttributeSpecified = False Then
				StreamItem.Value.Stream.WriteAttribute("xml:space", "preserve");
			EndIf;
			StreamItem.Value.Stream.WriteText(Text);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteXMLItemToStream(XMLParseStructure, XMLReader, DocumentStructure, IsPreserveSpaceAttributeSpecified = Undefined)
	
	If XMLReader.NodeType = XMLNodeType.ProcessingInstruction Then
		
		WriteProcessingInstructionToStreams(XMLParseStructure, XMLReader);
		
	ElsIf XMLReader.NodeType = XMLNodeType.StartElement Then
		
		NodeName = XMLReader.Name;
		
		WriteStreamStartToStreams(XMLParseStructure, XMLReader);
		
		While XMLReader.ReadAttribute() Do
			
			If IsBlankString(DocumentStructure.DocumentID) And (Left(XMLReader.Name, 6) = "w:rsid") Then
				DocumentStructure.DocumentID = XMLReader.Value;
			EndIf;
			
			AttributeValue = XMLReader.Value;
			
			If Left(XMLReader.Name, 4) = "r:id" And (NodeName = "w:hyperlink") Then
				AddParsedStringHyperlink(XMLParseStructure, DocumentStructure.ContentLinksTable.Find(AttributeValue, "ResourceID"));
			EndIf;
			
			If Left(XMLReader.Name, 6) = "w:rsid" Then
				AttributeValue = DocumentStructure.DocumentID;
			EndIf;
			
			IsPreserveSpaceAttributeSpecified = XMLReader.Name = "xml:space";
			
			WriteAttributeToStreams(XMLParseStructure, XMLReader,, AttributeValue);
			
			If NodeName = "w:document" Or NodeName = "w:ftr" Or NodeName = "w:hdr" Then
				XMLParseStructure.XMLAttributes = XMLParseStructure.XMLAttributes + " " + XMLReader.Name + "=""" + XMLReader.Value + """";
			EndIf;
			
		EndDo;
		
	ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
		
		WriteItemEndToStreams(XMLParseStructure, XMLReader);
		
	ElsIf XMLReader.NodeType = XMLNodeType.Text Then
		
		If XMLParseStructure.Property("OneCTagStatus") Then
			AnalyzeParametersInString(XMLReader.Value, XMLParseStructure);
		EndIf;
		
		WriteTextToStreams(XMLParseStructure, XMLReader);
		
	EndIf;
	
EndProcedure



Function ReadAnyBlockStartExceptForParagraph(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And Not XMLReader.Name = "w:p";
	
EndFunction

Function ReadAnyBlockEndButParagraph(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And Not XMLReader.Name = "w:p";
	
EndFunction

Function ReadDocumentBodyStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:body";
	
EndFunction

Function ReadHeaderOrFooterBodyStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And (XMLReader.Name = "w:ftr" Or XMLReader.Name = "w:hdr");
	
EndFunction

Function ReadParagraphStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:p";
	
EndFunction

Function ReadParagraphEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:p";
	
EndFunction

Function ReadStringStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:r";
	
EndFunction

Function ReadStringEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:r";
	
EndFunction

Function ReadStringTextStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:t";
	
EndFunction

Function ReadStringTextEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:t";
	
EndFunction

Function ReadTableStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:tbl";
	
EndFunction

Function ReadTableEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:tbl";
	
EndFunction

Function ReadTableWidthStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:tblW";
	
EndFunction

Function ReadTableCellWidthStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:tcW";
	
EndFunction

Function ReadTableCellStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:tc";
	
EndFunction

Function ReadTableCellEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:tc";
	
EndFunction

Function ReadSectionStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = "Section" Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.Name = "w:sectPr";
	
EndFunction

Function ReadSectionEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) And Not XMLParseStructure.LockingStream = "Section" Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement And XMLReader.Name = "w:sectPr";
	
EndFunction

Function InitializeMXLParsing()
	
	Result = New Structure;
	Result.Insert("WriteStreams",      New Structure);
	Result.Insert("XMLAttributes",       "");
	Result.Insert("AreaName",        "");
	Result.Insert("AreaStatus",     0);
	Result.Insert("SectionNumber",      1);
	Result.Insert("LockingStream",  "");
	Result.Insert("ParsedStrings1", New Array);
	Result.Insert("FormatStreamName",  "");
	Result.Insert("CurrentParagraphLevel", "0");
	Result.Insert("Hyperlinks",       New Array);
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//   * ResourceID 
//   * ParameterName 
//   * Ref 
//
Function HyperlinkStructure()
	Structure = New Structure("ResourceID,ParameterName,Ref");
	Return Structure;
EndFunction

Function HeadersFootersTypes()
	
	Result = New Map;
	Result.Insert("w:headerReference_even",    "EvenHeader");
	Result.Insert("w:footerReference_even",    "EvenFooter");
	Result.Insert("w:headerReference_first",   "FirstHeader");
	Result.Insert("w:footerReference_first",   "FirstFooter");
	Result.Insert("w:headerReference_default", "Header");
	Result.Insert("w:footerReference_default", "Footer");
	
	Return Result;
	
EndFunction

Procedure Reset1CTagsStatuses(XMLParseStructure, ResetTemplateStringStreams = False)
	
	XMLParseStructure.Insert("OneCTagStatus",     0);
	XMLParseStructure.Insert("OneCTagType",        0);
	XMLParseStructure.Insert("OneCTagName",        "");
	XMLParseStructure.Insert("FullOneCTagName",  "");
	XMLParseStructure.Insert("TextBefore1CTag",    "");
	XMLParseStructure.Insert("TextAfter1CTag", "");
	
	If ResetTemplateStringStreams Then
		ResetTemplateStringStreams(XMLParseStructure)
	EndIf;
	
EndProcedure

Procedure AddParsedString(XMLParseStructure, String, OneCTagStatus = 0, AreaName = "", FormatStream = "")
	
	StringStructure = New Structure;
	StringStructure.Insert("OneCTagStatus", OneCTagStatus);
	StringStructure.Insert("AreaName",   AreaName);
	StringStructure.Insert("Text",        String);
	StringStructure.Insert("FormatStream", FormatStream);
	
	XMLParseStructure.ParsedStrings1.Add(StringStructure);
	
EndProcedure

Procedure AddParsedStringHyperlink(XMLParseStructure, ResourceString)
	
	LinkString_ = DecodeString(ResourceString.ResourceName, StringEncodingMethod.URLEncoding);
	
	ParametersFromText = New Array;
	SelectParameters(ParametersFromText, LinkString_);
	
	For Each ParameterText In ParametersFromText Do
		HyperlinkStructure = HyperlinkStructure();
		HyperlinkStructure.ResourceID = ResourceString.ResourceID;
		HyperlinkStructure.ParameterName = ParameterText;
		HyperlinkStructure.Ref = LinkString_;
		XMLParseStructure.Hyperlinks.Add(HyperlinkStructure);
	EndDo;
	
EndProcedure

Procedure GenerateParsedStrings(XMLParseStructure)
	
	If XMLParseStructure.OneCTagStatus = 7 And XMLParseStructure.OneCTagType = 0
		 Or XMLParseStructure.OneCTagStatus = 3 And XMLParseStructure.OneCTagType = 1 And Not IsBlankString(XMLParseStructure.AreaName)
		 Or XMLParseStructure.OneCTagStatus = 7 And XMLParseStructure.OneCTagType = 1 And Not XMLParseStructure.OneCTagName = XMLParseStructure.AreaName Then
		
		Reset1CTagsStatuses(XMLParseStructure, True);
		Return;
	EndIf;
	
	If Not XMLParseStructure.TextBefore1CTag = "" Then
		AddParsedString(XMLParseStructure, XMLParseStructure.TextBefore1CTag,,,"TextFormatBefore");
	EndIf;
	
	If Not XMLParseStructure.FullOneCTagName = "" Then
		If XMLParseStructure.OneCTagStatus = 3 Or XMLParseStructure.OneCTagStatus = 7 Then
			XMLParseStructure.FullOneCTagName = StrReplace(XMLParseStructure.FullOneCTagName, " ", "");
			XMLParseStructure.FullOneCTagName = StrReplace(XMLParseStructure.FullOneCTagName, "{v8", "{v8 ");
			XMLParseStructure.FullOneCTagName = StrReplace(XMLParseStructure.FullOneCTagName, "{/v8", "{/v8 ");
		EndIf;
		AddParsedString(XMLParseStructure, XMLParseStructure.FullOneCTagName, ?(XMLParseStructure.OneCTagType = 1, XMLParseStructure.OneCTagStatus, 0), ?(XMLParseStructure.OneCTagType = 1, XMLParseStructure.OneCTagName, ""),"TagFormat1C");
	EndIf;
	
	If Not XMLParseStructure.TextAfter1CTag = "" Then
		AddParsedString(XMLParseStructure, XMLParseStructure.TextAfter1CTag,,,"TextFormatAfter");
	EndIf;
	
	Reset1CTagsStatuses(XMLParseStructure);
	
EndProcedure

Procedure ClearParsedStrings(XMLParseStructure)
	
	XMLParseStructure.ParsedStrings1.Clear();
	
EndProcedure

Procedure ClearUpHyperlinks(XMLParseStructure)
	
	XMLParseStructure.Hyperlinks.Clear();
	
EndProcedure

Procedure InitializeTemplateStringStreams(XMLParseStructure)
	
	If XMLParseStructure.OneCTagStatus = 1 Or XMLParseStructure.OneCTagStatus = 5 Then
		
		If Not StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 2 Or XMLParseStructure.OneCTagStatus = 6 Then
		
		If Not StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
		If Not StreamActive(XMLParseStructure, "TagFormat1C") Then
			InitializeWriteToStream(XMLParseStructure, "TagFormat1C");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TagFormat1C");
			StopWriteToStream(XMLParseStructure, "TagFormat1C");
		EndIf;
		
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 3 Or XMLParseStructure.OneCTagStatus = 7 Then
		
		If Not StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
		If Not StreamActive(XMLParseStructure, "TagFormat1C") Then
			InitializeWriteToStream(XMLParseStructure, "TagFormat1C");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TagFormat1C");
			StopWriteToStream(XMLParseStructure, "TagFormat1C");
		EndIf;
		
		If Not StreamActive(XMLParseStructure, "TextFormatAfter") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatAfter");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatAfter");
			StopWriteToStream(XMLParseStructure, "TextFormatAfter");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ResetTemplateStringStreams(XMLParseStructure)
	
	ResetWriteToStream(XMLParseStructure, "TextFormatBefore");
	ResetWriteToStream(XMLParseStructure, "TagFormat1C");
	ResetWriteToStream(XMLParseStructure, "TextFormatAfter");
	
EndProcedure

Procedure SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters)
	
	TagLevelLock       = -1;
	TagLevelArea    = -1;
	ParagraphLevel         = "0";
	CurrentLevel        = 0;
	SkipTag         = False;
	SectionText          = "";
	
	DigitalSignatureBookmarkID 		= "";
	BookmarkBufferText				= "";
	MapOfBookmarksAttributes 	= New Map();
		
	XMLParseStructure = InitializeMXLParsing();
	
	Reset1CTagsStatuses(XMLParseStructure);
	
	InitializeWriteToStream(XMLParseStructure, "Title", "");
	
	If AnalysisParameters.AnalysisType <> 1 Then
		InitializeWriteToStream(XMLParseStructure, "Block", "");
		TagLevelLock = 0;
	EndIf;
	
	While XMLReader.Read() Do
		
		// 
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		If (XMLReader.Name = "w:bookmarkStart" Or XMLReader.Name = "w:bookmarkEnd") Then
			
			If XMLReader.NodeType = XMLNodeType.StartElement Then
				BookmarksBuffer 			 = InitializeXMLRecord("");
				BookmarksBuffer.WriteCurrent(XMLReader);
			
				BookmarkBufferText = BookmarksBuffer.Close();
				
				ReadXMLBookmarks = InitializeXMLReader(BookmarkBufferText);
				ReadXMLBookmarks.Read();
				
				MapOfBookmarksAttributes = ObtainAttributes(ReadXMLBookmarks);
			EndIf;
			
			If MapOfBookmarksAttributes.Get("w:name") <> "V8DSStamp" And DigitalSignatureBookmarkID <> MapOfBookmarksAttributes.Get("w:id") Then
			
				If XMLReader.NodeType = XMLNodeType.StartElement Then
					SkipTag = True;
				ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
					SkipTag = False;
				EndIf;
				
				Continue;
				
			Else
							
				DigitalSignatureBookmarkID = MapOfBookmarksAttributes.Get("w:id");
			EndIf;
			
		EndIf;
		
		If SkipTag Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			CurrentLevel = CurrentLevel + 1;
		EndIf;
		
		If ReadSectionStart(XMLParseStructure, XMLReader) Then
			XMLParseStructure.LockingStream = "Section";
			InitializeWriteToStream(XMLParseStructure, "Section", "", False);
			TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Section", "w:body");
		EndIf;
		
		If ReadAnyBlockStartExceptForParagraph(XMLParseStructure, XMLReader) And CurrentLevel = TagLevelLock Then
			InitializeWriteToStream(XMLParseStructure, "Block");
		EndIf;
		
		If ReadParagraphStart(XMLParseStructure, XMLReader) Then
			ParagraphLevel = Format(Number(ParagraphLevel) + 1, "NZ=0; NG=0");
			XMLParseStructure.CurrentParagraphLevel = ParagraphLevel;
			
			Reset1CTagsStatuses(XMLParseStructure, True);
			InitializeWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			InitializeWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			StopWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
		EndIf;
		
		If ReadParagraphEnd(XMLParseStructure, XMLReader) Then
			ContinueWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
		EndIf;
		
		If ReadStringStart(XMLParseStructure, XMLReader) Then
			ContinueWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			InitializeWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
			StopWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			XMLParseStructure.FormatStreamName = "ParamString" + ParagraphLevel;
		EndIf;
		
		ReadStringTextStart = ReadStringTextStart(XMLParseStructure, XMLReader);
		
		CompleteWriteToTitle = ReadDocumentBodyStart(XMLParseStructure, XMLReader) Or ReadHeaderOrFooterBodyStart(XMLParseStructure, XMLReader);
		
		WriteXMLItemToStream(XMLParseStructure, XMLReader, DocumentStructure);
		
		If ReadStringTextStart Then
			CompleteWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
		EndIf;
		
		If CompleteWriteToTitle Then
			TagLevelLock    = XMLParseStructure.WriteStreams.Title.Level + 1;
			TagLevelArea = XMLParseStructure.WriteStreams.Title.Level + 2;
			
			CompleteWriteToStream(XMLParseStructure, "Title");
		EndIf;
		
		If ReadStringEnd(XMLParseStructure, XMLReader) Then
			If XMLParseStructure.OneCTagStatus = 0 And XMLParseStructure.ParsedStrings1.Count() = 0 Then
				TransferWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel, "Paragraph" + ParagraphLevel);
			ElsIf XMLParseStructure.ParsedStrings1.Count() > 0 Then
				InitializeWriteToStream(XMLParseStructure, "ParamStrings");
				
				RowsCount = 0;
				
				For Each StringItem In XMLParseStructure.ParsedStrings1 Do
					
					If AnalysisParameters.AnalysisType = 1 And CurrentLevel = TagLevelArea And StringItem.OneCTagStatus = 3 And IsBlankString(XMLParseStructure.AreaName) Then
						
						XMLParseStructure.AreaName = StringItem.AreaName;
						XMLParseStructure.AreaStatus = 0;
						RowsCount = 0;
						
						InitializeWriteToStream(XMLParseStructure, "Area", "");
						TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Area", "w:body");
						StopWriteToStream(XMLParseStructure, "Area");
						ResetWriteToStream(XMLParseStructure, "ParamStrings");
						InitializeWriteToStream(XMLParseStructure, "ParamStrings");
						
						Break;
						
					ElsIf AnalysisParameters.AnalysisType = 1 And CurrentLevel = TagLevelArea And StringItem.OneCTagStatus = 7 And XMLParseStructure.AreaName = StringItem.AreaName Then
						
						AreaText = CompleteWriteToStream(XMLParseStructure, "Area");
						
						AreaStructure = DocumentArea();
						AreaStructure.Name          = XMLParseStructure.AreaName;
						AreaStructure.Text        = AreaText;
						AreaStructure.SectionNumber = XMLParseStructure.SectionNumber;
						AreaStructure.Hyperlinks  = Common.CopyRecursive(XMLParseStructure.Hyperlinks);
						
						ClearUpHyperlinks(XMLParseStructure);
						
						AddDocumentAreaToDocumentStructure(DocumentStructure, AreaStructure);
						
						XMLParseStructure.AreaName = "";
						XMLParseStructure.AreaStatus = 0;
						
						Break;
						
					EndIf;
					
					RowsCount = RowsCount + 1;
					
					CompleteWriteToStream(XMLParseStructure, StringItem.FormatStream);
					
					HasSpaceAttribute = StrFind(XMLParseStructure.WriteStreams[StringItem.FormatStream].StreamText, "w:t xml:space", SearchDirection.FromEnd) > 0;
					
					TransferOpeningTagsOfWriteToStream(XMLParseStructure, StringItem.FormatStream, "ParamStrings", "w:t");
					
					If Not HasSpaceAttribute And (IsBlankString(Left(StringItem.Text, 1)) Or IsBlankString(Right(StringItem.Text, 1))) Then
						AddAttributeToStream(XMLParseStructure, "ParamStrings", "xml:space", "preserve");
					EndIf;
					AddTextToStream(XMLParseStructure, "ParamStrings", StringItem.Text);
					CloseItemsInStream(XMLParseStructure, "ParamStrings", 2);
					
				EndDo;
				
				If RowsCount > 0 Then
					TransferWriteToStream(XMLParseStructure, "ParamStrings", "Paragraph" + ParagraphLevel);
				EndIf;
				
				ResetWriteToStream(XMLParseStructure, "ParamStrings");
				ResetTemplateStringStreams(XMLParseStructure);
				ClearParsedStrings(XMLParseStructure);
			EndIf;
			
			ResetWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
			
			If XMLParseStructure.OneCTagStatus = 0 And XMLParseStructure.ParsedStrings1.Count() = 0 Or XMLParseStructure.ParsedStrings1.Count() > 0 Then
				ResetWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				InitializeWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				StopWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			EndIf;
		EndIf;
		
		If ReadParagraphEnd(XMLParseStructure, XMLReader) Then
			If Not XMLParseStructure.OneCTagStatus = 0 Then
				Reset1CTagsStatuses(XMLParseStructure, True);
			EndIf;
			
			If Number(ParagraphLevel) > 1 Then
				WrapStream = "Rows" + Format(Number(ParagraphLevel) - 1, "NZ=0; NG=0");
			ElsIf CurrentLevel = TagLevelLock And AnalysisParameters.AnalysisType = 1 Then
				WrapStream = "Area";
			Else
				WrapStream = "Block";
			EndIf;
			
			If AnalysisParameters.AnalysisType <> 1
				 Or Not IsBlankString(XMLParseStructure.AreaName) And XMLParseStructure.AreaStatus = 1 Then
				TransferWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel, WrapStream);
			EndIf;
			
			ResetWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			ResetWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			
			If Not IsBlankString(XMLParseStructure.AreaName) And XMLParseStructure.AreaStatus = 0 Then
				XMLParseStructure.AreaStatus = 1;
			EndIf;
			
			ParagraphLevel = Format(Number(ParagraphLevel) - 1, "NZ=0; NG=0");
			XMLParseStructure.CurrentParagraphLevel = ParagraphLevel;
			XMLParseStructure.FormatStreamName = "ParamString" + ParagraphLevel;
		EndIf;
		
		If ReadAnyBlockEndButParagraph(XMLParseStructure, XMLReader) And CurrentLevel = TagLevelLock Then
			If Not IsBlankString(XMLParseStructure.AreaName) And XMLParseStructure.AreaStatus = 1 Then
				TransferWriteToStream(XMLParseStructure, "Block", "Area");
			EndIf;
			ResetWriteToStream(XMLParseStructure, "Block");
		EndIf;
		
		If ReadSectionEnd(XMLParseStructure, XMLReader) Then
			SectionText = CompleteWriteToStream(XMLParseStructure, "Section");
			XMLParseStructure.LockingStream = "";
		EndIf;
		
		If Not IsBlankString(SectionText) And CurrentLevel = TagLevelLock Then
			If XMLParseStructure.AreaStatus = 0 Then
				SectionStructure = SectionArea();
				SectionStructure.Text = SectionText;
				SectionStructure.Number = XMLParseStructure.SectionNumber;
				AddSectionToDocumentStructure(DocumentStructure, SectionStructure);
				XMLParseStructure.SectionNumber = XMLParseStructure.SectionNumber + 1;
			EndIf;
			SectionText = "";
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement Then
			CurrentLevel = CurrentLevel - 1;
		EndIf;
		
	EndDo;
	
	If AnalysisParameters.AnalysisType = 2 Or AnalysisParameters.AnalysisType = 3 Then
		AreaText = CompleteWriteToStream(XMLParseStructure, "Block");
		AnalysisParameters.AnalysisStructure.Text  = AreaText;
	EndIf;
	
	If AnalysisParameters.AnalysisType = 1  Then
		InitializeWriteToStream(XMLParseStructure, "Paragraph", "");
		TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Paragraph", "w:body");
		
		BreakText = "<w:p w:rsidRDefault=""" + DocumentStructure.DocumentID + """ w:rsidR=""" + DocumentStructure.DocumentID + """></w:p>";
		XMLParseStructure.WriteStreams.Paragraph.Stream.WriteRaw(BreakText);
		
		AreaText = CompleteWriteToStream(XMLParseStructure, "Paragraph");
		
		AreaStructure = DocumentArea();
		AreaStructure.Name          = "Paragraph";
		AreaStructure.Text        = AreaText;
		AreaStructure.SectionNumber = 0;
		AddDocumentAreaToDocumentStructure(DocumentStructure, AreaStructure);
	EndIf;
	
EndProcedure

Procedure AnalyzeParametersInString(Val String, XMLParseStructure)
	
	// 
	// 
	// 
	
	// 
	// 
	// 
	
	FlagOf1CTagStart = "{v8 ";
	FlagOf1CTagEnd  = "{/v8 ";
	
	StringLengthOf1CTag       = StrLen(XMLParseStructure.FullOneCTagName);
	StringLength             = StrLen(String);
	
	For f = 1 To StringLength Do
		
		Char      = Mid(String, f, 1);
		CharCode  = CharCode(Char);
		
		If Char = "{" And (XMLParseStructure.OneCTagStatus = 3 Or XMLParseStructure.OneCTagStatus = 7) Then
			InitializeTemplateStringStreams(XMLParseStructure);
			GenerateParsedStrings(XMLParseStructure);
			StringLengthOf1CTag = 0;
		EndIf;
		
		If StringLengthOf1CTag + 1 <= StrLen(FlagOf1CTagStart) And Left(FlagOf1CTagStart, StringLengthOf1CTag + 1) = XMLParseStructure.FullOneCTagName + Char Then
			
			XMLParseStructure.OneCTagStatus = 1;
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			Continue;
			
		ElsIf StringLengthOf1CTag <= StrLen(FlagOf1CTagEnd) And Left(FlagOf1CTagEnd, StringLengthOf1CTag + 1) = XMLParseStructure.FullOneCTagName + Char Then
			
			XMLParseStructure.OneCTagStatus = 5;
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			Continue;
			
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 0 And StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagStart) Then
			XMLParseStructure.OneCTagStatus = 1;
		ElsIf XMLParseStructure.OneCTagStatus = 0 And StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagEnd) Then
			XMLParseStructure.OneCTagStatus = 5;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 1 And Not StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagStart)
			 Or XMLParseStructure.OneCTagStatus = 5 And Not StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagEnd)
			 Or XMLParseStructure.OneCTagStatus = 5 And IsBlankString(XMLParseStructure.AreaName) Then
			Text = XMLParseStructure.TextBefore1CTag + XMLParseStructure.FullOneCTagName + XMLParseStructure.TextAfter1CTag;
			Reset1CTagsStatuses(XMLParseStructure);
			XMLParseStructure.TextBefore1CTag = Text;
			StringLengthOf1CTag = 0;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 1 Or XMLParseStructure.OneCTagStatus = 5 Then
			XMLParseStructure.OneCTagStatus = XMLParseStructure.OneCTagStatus + 1;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 2 Or XMLParseStructure.OneCTagStatus = 6 Then
			
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			
			If(CharCode = 32 Or (CharCode >= 48 And CharCode <= 57) Or (CharCode >= 65 And CharCode <= 90) Or CharCode = 95 Or (CharCode >= 97 And CharCode <= 122) Or (CharCode >= 1040 And CharCode <= 1103)) Then
				XMLParseStructure.OneCTagName = XMLParseStructure.OneCTagName + Char;
			ElsIf Char = "." And XMLParseStructure.OneCTagType = 0 And XMLParseStructure.OneCTagName = "Area" Then
				XMLParseStructure.OneCTagType = 1;
				XMLParseStructure.OneCTagName = "";
			ElsIf Char = "}" Then
				XMLParseStructure.OneCTagStatus = XMLParseStructure.OneCTagStatus + 1;
				XMLParseStructure.OneCTagName = TrimAll(XMLParseStructure.OneCTagName);
			Else
				Text = XMLParseStructure.TextBefore1CTag + XMLParseStructure.FullOneCTagName + XMLParseStructure.TextAfter1CTag;
				Reset1CTagsStatuses(XMLParseStructure);
				XMLParseStructure.TextBefore1CTag = Text;
				StringLengthOf1CTag = 0;
			EndIf;
			
		ElsIf XMLParseStructure.OneCTagStatus = 3 Or XMLParseStructure.OneCTagStatus = 7 Then
			XMLParseStructure.TextAfter1CTag = XMLParseStructure.TextAfter1CTag + Char;
		Else
			XMLParseStructure.TextBefore1CTag = XMLParseStructure.TextBefore1CTag + Char;
		EndIf;
		
	EndDo;
	
	If XMLParseStructure.OneCTagStatus = 0 And XMLParseStructure.ParsedStrings1.Count() > 0 Then
		XMLParseStructure.OneCTagStatus = 3;
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 0 Then
		ResetTemplateStringStreams(XMLParseStructure);
	Else
		InitializeTemplateStringStreams(XMLParseStructure);
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 3 Or XMLParseStructure.OneCTagStatus = 7 Then
		GenerateParsedStrings(XMLParseStructure);
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 0 And XMLParseStructure.ParsedStrings1.Count() = 0 Then
		Reset1CTagsStatuses(XMLParseStructure);
	EndIf;
	
EndProcedure

Procedure SelectHeadersFootersFormSection(XMLReader, DocumentStructure, Section)
	
	HeadersFootersTypes = HeadersFootersTypes();
	
	While XMLReader.Read() Do
		
		If Not (XMLReader.NodeType = XMLNodeType.StartElement And (XMLReader.Name = "w:headerReference" Or XMLReader.Name = "w:footerReference")) Then
			Continue;
		EndIf;
		
		TagName1       = XMLReader.Name;
		Attributewtype = XMLReader.GetAttribute("w:type");
		Attributerid   = XMLReader.GetAttribute("r:id");
		
		FoundRow = DocumentStructure.ContentLinksTable.Find(Attributerid);
		
		If FoundRow = Undefined Then
			Continue;
		EndIf;
		
		HeaderOrFooterType   = HeadersFootersTypes.Get(TagName1 + "_" + Attributewtype);
		
		HeaderOrFooterStructure = HeaderOrFooterArea();
		HeaderOrFooterStructure.Name          = HeaderOrFooterType;
		HeaderOrFooterStructure.InternalName1     = StrReplace(FoundRow.ResourceName, ".xml", "");
		HeaderOrFooterStructure.SectionNumber = Section.Number;
		
		AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooterStructure, FoundRow.ResourceName);
		
	EndDo;
	
EndProcedure

Function ProcessDocumentSection(DocumentStructure, Section)
	
	HeadersFootersTypes = HeadersFootersTypes();
	
	XMLReader = InitializeXMLReader(Section.Text);
	XMLWriter = InitializeXMLRecord("",,,False);
	
	SkipTag = False;
	While XMLReader.Read() Do
		
		If SkipTag = True Then
			SkipTag = False;
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement And (XMLReader.Name = "w:document" Or XMLReader.Name = "w:body") Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement And (XMLReader.Name = "w:headerReference" Or XMLReader.Name = "w:footerReference") Then
			
			TagName1 = XMLReader.Name;
			AttributeValue = XMLReader.GetAttribute("w:type");
			HeaderOrFooterKey = TagName1 + "_" + AttributeValue;
			HeaderOrFooterType = HeadersFootersTypes.Get(HeaderOrFooterKey);
			KeyInDocumentStructure = HeaderOrFooterType + "_" + Format(Section.Number, "NG=0");
			HeaderOrFooterInStructure = DocumentStructure.HeaderFooter.Get(KeyInDocumentStructure);
			
			If HeaderOrFooterInStructure.Text = "" Then
				SkipTag = True;
				Continue;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement And (XMLReader.Name = "w:document" Or XMLReader.Name = "w:body") Then
			Continue;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLWriter);
		
	EndDo;
	
	SectionText = XMLWriter.Close();
	
	Return SectionText;
	
EndFunction

#EndRegion

#EndRegion

#Region ImagesOperations

////////////////////////////////////////////////////////////////////////////////
// 

// Returns the width, height, and image type for GIF, JPG, PNG, BMP, and TIFF files
Function GetImageAttributes(ReadingData)
	
	ImageAttributes = New Structure;
	
	If TypeOf(ReadingData) = Type("String") Then
		
		Try
			DataStream = FileStreams.OpenForRead(ReadingData);
		Except
			Return ImageAttributes;
		EndTry;
		
	ElsIf TypeOf(ReadingData) = Type("BinaryData") Then
		DataStream = ReadingData
	Else
		Return ImageAttributes;
	EndIf;
	
	DataReader = New DataReader(DataStream);
	
	Char1 = DataReader.ReadByte();
	Char2 = DataReader.ReadByte();
	Char3 = DataReader.ReadByte();
	
	// MIME syntax -  "type/subtype"
	ImageType = Null;
	
	Width  = -1;
	Height = -1;
	
	If (Char(Char1) = "G" And Char(Char2) = "I" And Char(Char3) = "F") Then // GIF
		
		DataReader.Skip(3);
		Width  = ReadByteValueFromStream(DataReader, 2, False);
		Height = ReadByteValueFromStream(DataReader, 2 , False);
		ImageType = "image/gif";
		
	ElsIf (Char1 = 255 And Char2 = 216) Then // JPG
		
		While (Char3 = 255) Do 
			
			Marker = DataReader.ReadByte();
			Length = ReadByteValueFromStream(DataReader, 2, True);
			
			If (Marker = 192 Or Marker = 193 Or Marker = 194) Then
				
				DataReader.Skip(1);
				Height = ReadByteValueFromStream(DataReader, 2, True);
				Width  = ReadByteValueFromStream(DataReader, 2, True);
				ImageType = "image/jpeg";
				Break;
				
			EndIf;
			
			DataReader.Skip(Length - 2);
			Char3 = DataReader.ReadByte();
			
		EndDo;
		
	ElsIf  (Char1 = 137 And Char2 = 80 And Char3 = 78) Then // PNG
		
		DataReader.Skip(15);
		Width = ReadByteValueFromStream(DataReader, 2 , True);
		DataReader.Skip(2);
		Height = ReadByteValueFromStream(DataReader, 2, True);
		ImageType = "image/png";
		
	ElsIf  (Char1 = 66 And Char2 = 77) Then // BMP
		
		DataReader.Skip(15);
		Width = ReadByteValueFromStream(DataReader, 2, False);
		DataReader.Skip(2);
		Height = ReadByteValueFromStream(DataReader, 2, False);
		ImageType = "image/bmp";
		
	Else
		
		Char4 = DataReader.ReadByte();
		
		If((Char(Char1) = "M" And Char(Char2) = "M" And Char3 = 0 And Char4 = 42) Or (Char(Char1) = "I" And Char(Char2) = "I" And Char3 = 42 And Char4 = 0)) Then //TIFF
			
			BytesOrderBigEndian = Char(Char1) = "M";
			
			// Image header
			OffsetValue = 0;
			OffsetValue = ReadByteValueFromStream(DataReader, 4, BytesOrderBigEndian);
			
			DataReader.Skip(OffsetValue - 8);
			Occurrences = ReadByteValueFromStream(DataReader, 2, BytesOrderBigEndian);
			
			IndexOf = 1;
			While IndexOf <= Occurrences Do
				
				Tag = ReadByteValueFromStream(DataReader, 2, BytesOrderBigEndian);
				FieldType = ReadByteValueFromStream(DataReader, 2, BytesOrderBigEndian);
				ReadByteValueFromStream(DataReader, 4, BytesOrderBigEndian);
				
				If (FieldType = 3 Or FieldType = 8) Then
					
					OffsetValue = ReadByteValueFromStream(DataReader, 2, BytesOrderBigEndian);
					DataReader.Skip(2);
					
				Else
					
					OffsetValue = ReadByteValueFromStream(DataReader, 4, BytesOrderBigEndian);
					
				EndIf;
				
				If (Tag = 256) Then
					
					Width = OffsetValue;
					
				ElsIf (Tag = 257) Then
					
					Height = OffsetValue;
					
				EndIf;
				
				If (Width <> -1 And Height <> -1) Then
					
					ImageType = "image/tiff";
					Break;
					
				EndIf;
				
				IndexOf = IndexOf + 1;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	DataReader.Close();
	
	ImageAttributes.Insert("ImageType", ImageType);
	ImageAttributes.Insert("Height", ?(ImageType = Null, 0, Height));
	ImageAttributes.Insert("Width", ?(ImageType = Null, 0, Width));
	
	Return ImageAttributes;
	
EndFunction

Function ReadByteValueFromStream(InputStream, BytesCount, BytesOrderBigEndian) 
	
	Value = 0;
	
	OffsetSize = ?(BytesOrderBigEndian = True, (BytesCount - 1) * 8, 0);
	Count = ?(BytesOrderBigEndian = True, -8, 8); 
	
	IndexOf = 0;
	While IndexOf < BytesCount Do
		
		Value = BitwiseOr_(Value, BitwiseShiftLeft_(InputStream.ReadByte(), OffsetSize));
		OffsetSize = OffsetSize + Count;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	Return Value;
	
EndFunction

Function BitwiseShiftLeft_(Val Number, Offset = 0)
	
	BinaryPresentation = GetBinaryNumberPresentation(Number);
	BinaryNumberArray  = ParseBinaryPresentation(BinaryPresentation);
	
	For Indus = 0 To Offset - 1 Do
		
		IndexOf = 1;
		While IndexOf <= BinaryNumberArray.UBound() - Indus Do 
			
			BinaryNumberArray[IndexOf-1] = BinaryNumberArray[IndexOf];
			IndexOf = IndexOf + 1;
			
		EndDo;
		
		BinaryNumberArray[BinaryNumberArray.UBound()- Indus] = "0";
		
	EndDo;
	
	
	BinaryNumberArrayPresentation = GetBinaryNumberArrayPresentation(BinaryNumberArray);	
	
	Result = NumberFromBinaryString("0b" + BinaryNumberArrayPresentation);
	
	Return Result;
	
EndFunction

Function BitwiseOr_(Number1, Number2)
	
	BinaryNumber1Presentation = GetBinaryNumberPresentation(Number1);
	BinaryNumber2Presentation = GetBinaryNumberPresentation(Number2);
	
	BinaryNumberArray1 = ParseBinaryPresentation(BinaryNumber1Presentation);
	BinaryNumberArray2 = ParseBinaryPresentation(BinaryNumber2Presentation);
	
	ArrayLength = BinaryNumberArray1.UBound();
	
	For Indus = 0 To ArrayLength Do
		
		If BinaryNumberArray1[Indus] = "1" Or BinaryNumberArray2[Indus] = "1" Then
			BinaryNumberArray1[Indus] = "1";
		EndIf;
		
	EndDo;
	
	BinaryNumberArrayPresentation = GetBinaryNumberArrayPresentation(BinaryNumberArray1);
	
	Result = NumberFromBinaryString("0b" + BinaryNumberArrayPresentation);
	
	Return Result;
	
EndFunction

Function GetBinaryNumberPresentation(Value, Mask = "00000000000000000000000000000000")
	
	Result = "";
	Template    = "01";
	Basis = StrLen(Template);
	
	While Value > 0 Do
		
		Balance    = Value % Basis;
		Result1 = Mid(Template, Balance + 1, 1);
		Value   = (Value - Balance) / Basis;
		Result  = Result1 + Result;
		
	EndDo;
	
	ZerosCount = StrLen(Mask) - StrLen(Result);
	For Indus = 1 To ZerosCount Do 
		Result = "0" + Result;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetBinaryNumberArrayPresentation(BinaryNumberArray)
	
	Result = "";
	
	For Indus = 0 To BinaryNumberArray.UBound() Do
		Result = Result + BinaryNumberArray[Indus];
	EndDo;
	
	Return Result
	
EndFunction

Function ParseBinaryPresentation(BinaryPresentation)
	
	BinaryNumberArray = New Array(StrLen(BinaryPresentation));
	
	For Indus = 0 To BinaryNumberArray.UBound() Do
		BinaryNumberArray[Indus] = Mid(BinaryPresentation, Indus + 1, 1);
	EndDo;
	
	Return BinaryNumberArray;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// 

Function EventLogEvent()
	
	Return NStr("en = 'Print';", Common.DefaultLanguageCode());
	
EndFunction

Procedure CopyDirectoryContent(From_, Where) Export
	
	PurposeDirectory = New File(Where);
	
	If PurposeDirectory.Exists() Then
		If PurposeDirectory.IsFile() Then
			DeleteFiles(PurposeDirectory.FullName);
			CreateDirectory(Where);
		EndIf;
	Else
		CreateDirectory(Where);
	EndIf;
	
	Files = FindFiles(From_, GetAllFilesMask());
	
	For Each File In Files Do
		If File.IsDirectory() Then
			CopyDirectoryContent(File.FullName, SetPathSeparator(Where + "\" + File.Name));
		Else
			FileCopy(File.FullName, SetPathSeparator(Where + "\" + File.Name));
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//   EventName  - String -  name of the event to record.
//   LevelPresentation  - String -  representation of the values of the log level collection.
//                                     Available values: "Information", "Error", "Warning", "note".
//   Comment - String -  review of the event.
//
Procedure WriteEventsToEventLog(EventName, LevelPresentation, Comment)
	
	EventsList = New ValueList;
	
	EventStructure = New Structure;
	EventStructure.Insert("EventName", EventName);
	EventStructure.Insert("LevelPresentation", LevelPresentation);
	EventStructure.Insert("Comment", Comment);
	
	EventsList.Add(EventStructure);
	
	EventLog.WriteEventsToEventLog(EventsList);
	
EndProcedure

// Defines the extension of the data file based on its signature. The file is analyzed
// by the first 8 bytes in relation to the docx, doc, and odt types.
// To call from client and server modules to print forms based on office document layouts.
//
// Parameters:
//  DataOrStructure - BinaryData
//                     - Structure - 
//
// Returns:
//  String, Undefined -  
//
Function DefineDataFileExtensionBySignature(DataOrStructure) Export
	
	If TypeOf(DataOrStructure) = Type("Structure") Then
		Try
			ObjectTemplateAndData = PrintManagement.TemplatesAndObjectsDataToPrint(DataOrStructure.PrintManager,
				DataOrStructure.Id, New Array);
			BinaryTemplateData = ObjectTemplateAndData.Templates.TemplatesBinaryData.Get(DataOrStructure.Id);
		Except
			Return Undefined;
		EndTry;
	Else
		BinaryTemplateData = DataOrStructure;
	EndIf;
	
	If BinaryTemplateData = Undefined Then
		Return Undefined;
	EndIf;
	
	DataStream = BinaryTemplateData.OpenStreamForRead();
	DataReader = New DataReader(DataStream);
	
	Char1 = DataReader.ReadByte();
	Char2 = DataReader.ReadByte();
	Char3 = DataReader.ReadByte();
	Char4 = DataReader.ReadByte();
	Char5 = DataReader.ReadByte();
	Char6 = DataReader.ReadByte();
	Char7 = DataReader.ReadByte();
	Char8 = DataReader.ReadByte();
	
	DataStream.Close();
	
	If Char1 = 208 And Char2 = 207 And Char3 = 17 And Char4 = 224 And Char5 = 161 And Char6 = 177 And Char7 = 26 And Char8 = 225 Then
		Return "doc";
	ElsIf Char1 = 80 And Char2 = 75 And Char3 = 3 And Char4 = 4 And Char5 = 20
			  Or Char1 = 80 And Char2 = 75 And Char3 = 3 And Char4 = 4 And Char5 = 10 Then
			  	
		TempFileName = GetTempFileName("docx");
	
		BinaryTemplateData.Write(TempFileName);
		Try
			Archiver = New ZipFileReader(TempFileName);
		Except
			DeleteFiles(TempFileName);
			WriteEventsToEventLog(EventLogEvent(), "Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise(NStr("en = 'Cannot open template file. Reason:';") + Chars.LF 
				+ ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		If Archiver.Items.Find("document.xml") = Undefined Then
			Extension = "odt";
		Else
			Extension = "docx";
		EndIf;
		Archiver.Close();
		DeleteFiles(TempFileName);
		
		Return Extension;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function SetPathSeparator(Val Path)
	Return StrConcat(StrSplit(Path, "\/", True), GetPathSeparator());
EndFunction

#EndRegion

#EndRegion
