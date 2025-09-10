
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	XSLTTemplate = GetXSLTTemplate();
	CommonClientServer.SetFormItemProperty(Items, "Download", "Visible", Not IsBlankString(XSLTTemplate));
	
	If Not IsBlankString(XSLTTemplate) Then
		
		BinaryData = Base64Value(XSLTTemplate);
		FileSize = BinaryData.Size();
		
		CommandTitle = StrTemplate(NStr("en = 'Download ""%1.xsl"" (%2 KB).'; tr = '""%1.xsl"" indir (%2 KB).'"),
			Object.Description,
			Round(FileSize/1024, 0));
		CommonClientServer.SetFormItemProperty(Items, "Download", "Title", CommandTitle);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not ValueIsFilled(PathFile)
		And IsBlankString(XSLTTemplate) Then
		
		Raise NStr("en = 'Fill in the file path.'; tr = 'Dosya yolunu doldurun.'");
		Cancel = True;
		Return;
		
	EndIf;
	
	If Not IsBlankString(FileAddressInTempStorage)
		And Modified Then
		
		BinaryData = GetFromTempStorage(FileAddressInTempStorage);
		Base64Value = Base64String(BinaryData);
		CurrentObject.XSLT = New ValueStorage(Base64Value, New Deflation(9));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Async Procedure PathFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Filter = NStr("en = 'XSLT File (*.xslt*;*.xsl)|*.xslt*;*.xsl';tr = 'XSLT Dosyası (*.xslt*;*.xsl)|*.xslt*;*.xsl'");
	Dialog.Title = NStr("en = 'Select templates';tr = 'Şablon seç'");

	ProcessingResultsParameters = New Structure;
	ProcessingResultsParameters.Insert("CompletionHandler", "AfterSelectingTheFile");
	
	CallbackDescription = New CallbackDescription(
		"ProcessPutFilesResult", ThisObject, ProcessingResultsParameters);
	
	BeginPuttingFiles(CallbackDescription, Dialog, True, UUID);
	
EndProcedure

&AtClient
// Putting files completion.
Procedure ProcessPutFilesResult(PlacedFiles, ProcessingResultsParameters) Export
	
	If PlacedFiles <> Undefined Then
		
		If TypeOf(PlacedFiles) = Type("Array") Then
			
			PutFilesToServe = New Array;
			For Each File In PlacedFiles Do
				
				FileProperties = New Structure("Name, FullName, Location");
				FillPropertyValues(FileProperties, File);
				
				FileProperties.Insert("FileName", File.Name);
				If Not IsBlankString(File.FullName) Then
					FileProperties.Name = File.FullName;
				EndIf;
				
				PutFilesToServe.Add(FileProperties);
				
			EndDo;
			
		Else
			
			PutFilesToServe = New Structure;
			PutFilesToServe.Insert("Location", PlacedFiles);
			PutFilesToServe.Insert("Name",      Undefined);
			
		EndIf;
		
	Else
		PutFilesToServe = Undefined;
	EndIf;

	If PutFilesToServe <> Undefined Then
		PathFile = PutFilesToServe[0].Name;
		FileAddressInTempStorage = PutFilesToServe[0].Location;
		Modified = Not IsBlankString(PathFile);
	EndIf;
	
EndProcedure

&AtClient
Procedure PathFileClearing(Item, StandardProcessing)
	Modified = Not IsBlankString(PathFile);
	FileAddressInTempStorage = "";
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Download(Command)
	
	XSLTTemplate = GetXSLTTemplate();
	
	If Not IsBlankString(XSLTTemplate) Then
		
		BinaryData = Base64Value(XSLTTemplate);
		EncodedBinary = GetStringFromBinaryData(BinaryData);
		TempFile = PutToTempStorage(EncodedBinary);
		
		TransferableFileDescription = New TransferableFileDescription;
		TransferableFileDescription.Location = TempFile;
		TransferableFileDescription.Name = Object.Description + ".xsl";
		
		FilesToObtain = New Array;
		FilesToObtain.Add(TransferableFileDescription);
		
		FilesDialogParameters = new GetFilesDialogParameters;
		FilesDialogParameters.ChooseDirectory = True;
		
		BeginGetFilesFromServer(FilesToObtain, FilesDialogParameters,);
		
		ShowUserNotification(NStr("en = 'File saved.';tr = 'Dosya kaydedildi.'"),, TransferableFileDescription.Name);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetXSLTTemplate()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CatalogXSLT.XSLT AS XSLT
	|FROM
	|	Catalog.XSLT AS CatalogXSLT
	|WHERE
	|	CatalogXSLT.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Try
			
			If Selection.XSLT.Get() <> Undefined Then
				Return Selection.XSLT.Get();
			EndIf;
			
		Except
			Return "";
		EndTry;
		
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion