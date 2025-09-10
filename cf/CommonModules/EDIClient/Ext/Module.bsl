#Region Public

Async Procedure EDIExecuteCommand(Val CommandParams) Export
	
	Ref = CommandParams.Ref;
	Form = CommandParams.Form;
	
	ClearMessages();
	
	If Ref.IsEmpty() Or Form.Modified Then
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data is not written yet. You can access ""%1"" after writing the data only.'; tr = 'Veriler henüz kaydedilmedi. ''''%1'''' sadece veri kaydından sonra erişilebilir.'"),
			CommandParams.Title);
		
		Response = Await DoQueryBoxAsync(QueryText, QuestionDialogMode.OKCancel);
		If Response <> DialogReturnCode.OK Then
			Return;
		EndIf;
		
		Form.Write();
		
	EndIf;
	
	DocRefArray = CommonClientServer.ArrayOfValues(Ref);
	
	NotifyParameters = New Structure;
	NotifyParameters.Insert("AccountingDocuments", DocRefArray);
	Notify("RefreshEDIState", NotifyParameters);
	
	AdditionalParameters = New Structure("BaseObjects", DocRefArray);
	
	If CommandParams.CommandID = "EInvoicePrint" Then
		
		PrintDocument(AdditionalParameters);
		
	ElsIf CommandParams.CommandID = "EInvoiceDownload" Then
		
		DownloadDocument(AdditionalParameters);
		
	ElsIf Not IsBlankString(CommandParams.Handler) Then
		
		TimeConsumingOperation = EDIServerCall.EDIExecuteCommandTimeConsumingOperation(DocRefArray, CommandParams.Handler);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
		IdleParameters.MessageText = NStr("en = 'EDI exchange'; tr = 'EDI değişimi'");
		
		CompletionNotification = New CallbackDescription("EDIExecuteCommandCompletion", ThisObject, AdditionalParameters);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
		
	EndIf;
	
EndProcedure

Procedure EDIStateDecorationClick(Val Form, Val Item) Export
	
	EDI_StatusDescription = "EDI_StatusDescription";
	
	ValueToShow = Item.Title;
	If ValueIsFilled(Form[EDI_StatusDescription]) Then
		ValueToShow = Form[EDI_StatusDescription];
	EndIf;
	
	ShowValue(, ValueToShow);
	
EndProcedure

Procedure EDIExecuteCommandCompletion(Result, ExecuteParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		Return;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClient.MessageToUser(Result.BriefErrorDescription);
		
	ElsIf Result.Status = "Completed2" Then
		
		ResultStructure = GetFromTempStorage(Result.ResultAddress);
		If ResultStructure.ErrorsInEventLog Then
			ShowEDIExchangeErrorMessage();
		ElsIf ResultStructure.ErrorsToShow Then
			For Each ErrorText In ResultStructure.ListOfErrorsToShow Do
				
				CommonClient.MessageToUser(ErrorText);
				
			EndDo;
		Else
			
			If ResultStructure.WarningsToShow Then
				For Each ErrorText In ResultStructure.ListOfErrorsToShow Do
					CommonClient.MessageToUser(ErrorText);
				EndDo;
			EndIf;
			
			Notify("RefreshEDIState", ExecuteParameters.BaseObjects);
			ShowUserNotification(NStr("en = 'Completed successfully'; tr = 'Başarıyla tamamlandı'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function ParametersNotificationProcessing() Export
	
	ParametersNotificationProcessing = New Structure("
		|Form,
		|Ref,
		|StateDecoration,
		|StateGroup,
		|ResponseStatusDecoration,
		|ResponseStatusGroup");
	
	Return ParametersNotificationProcessing;
	
EndFunction

Procedure NotificationProcessing_DocumentForm(EventName, Parameter, Source, NotificationParameters) Export
	
	If Not EventName = "RefreshEDIState" Then
		Return;
	EndIf;
	
	Form = NotificationParameters.Form;
	Ref = NotificationParameters.Ref;
	
	If TypeOf(Parameter) = Type("Structure")
		And Parameter.Property("AccountingDocuments")
		And TypeOf(Parameter.AccountingDocuments) = Type("Array")
		And Parameter.AccountingDocuments.Find(Ref) = Undefined Then
		
		Return;
	EndIf;
	
	EDIState = EDIServerCall.GetEDIState(Ref);
	
	EDI_StatusDescription = "EDI_StatusDescription";
	EDI_SendStatusResponse = "EDI_SendStatusResponse";
	
	StateDecoration = NotificationParameters.StateDecoration;
	ResponseStatusDecoration = NotificationParameters.ResponseStatusDecoration;
	
	StateDecoration.Title = EDIState.Status;
	Form[EDI_StatusDescription] = EDIState.StatusDescription;
	
	ResponseStatusDecoration.Title = EDIState.SendStatusResponse;
	Form[EDI_SendStatusResponse] = EDIState.StatusDescription;
	Form.Read();
	
EndProcedure

Procedure CheckConnection(Company, EDIProvider) Export
	
	ClearMessages();
	HasErrors = False;
	
	EDIServerCall.CheckConnection(Company, EDIProvider, HasErrors);
	
	If HasErrors Then
		ShowCheckConnectionErrorMessage();
	Else
		ShowMessageBox(
			,
			NStr("en = 'Profile parameters check is completed successfully'; tr = 'Profil parametresi kontrolü başarıyla tamamlandı'"),
			,
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'"));
	EndIf;
	
EndProcedure

Procedure DocumentWasChanged(DocumentRef) Export
	
	If EDIServerCall.DocumentWasSent(DocumentRef) Then
		
		ShowMessageBox(,
			NStr("en = 'Document has already been sent to EDI system.
				|When you change main document attributes, you need to change it in EDI system manually.'; 
				|tr = 'Belge EDI sistemine gönderildi.
				| Ana belge öznitelikleri EDI sisteminde manuel olarak değiştirilmelidir.'"),,
			NStr("en = 'Key attributes were changed'; tr = 'Anahtar öznitelikler değiştirildi'"));
		
	EndIf;
	
EndProcedure

Procedure PrintDocument(Parameters) Export
	
	HasError = False;
	DecodedString = "";
	EDIClientServer.PrintDocument(Parameters.BaseObjects, DecodedString, HasError);
	
	If Not HasError Then
		
		If Not IsBlankString(DecodedString) Then
			
			OpenForm("CommonForm.EInvoicePrintForm", New Structure("DocumentString", DecodedString)
				,,,,,,FormWindowOpeningMode.Independent);
			
		Else
			CommonClient.MessageToUser(NStr("en = 'Please create e-document before you print.'; tr = 'Lütfen yazdırmadan önce e-belge oluşturun.'"));
		EndIf;
	
	Else
		ShowEDIExchangeErrorMessage();
	EndIf;
	
EndProcedure

Procedure DownloadDocument(Parameters) Export
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	Dialog.Title = NStr("en = 'Select folder'; tr = 'Klasörü seç'");
	Dialog.FullFileName = "";
	
	If Dialog.Choose() Then
		
		Path = Dialog.Directory;
		Result = EDIClientServer.DownloadDocument(Parameters.BaseObjects, Path);
		
		If Not Result.Error Then
			
			Text = New TextWriter(Path + "/" + Result.UUID + ".xml", TextEncoding.UTF8);
			Base64String = Base64Value(Result.UBL);
			UBL = ?(Result.Encoded, GetStringFromBinaryData(Base64String), Result.UBL);
			
			Text.Write(UBL);
			Text.Close();
			
			UserMessage = NStr("en = 'The document downloaded successfully.'; tr = 'Doküman başarıyla indirildi.'");
			CommonClientServer.MessageToUser(UserMessage);
			
		EndIf; 
		
	EndIf;
	
EndProcedure

Function CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ShowMessage = False) Export
	
	HasError = False;
	
	ResultStructure = New Structure;
	ResultStructure.Insert("IsTaxpayer", False);
	ResultStructure.Insert("IsPublicEstablishment", False);
	ResultStructure.Insert("Description", "");
	ResultStructure.Insert("Error", "");
	
	EDIClientServer.CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError);
	
	If Not HasError Then
		
		If Not ResultStructure.IsTaxpayer
			And ShowMessage Then
			CommonClientServer.MessageToUser(NStr("en = 'Counterparty is not a taxpayer'; tr = 'Cari hesap, vergi mükellefi değil'"));
		ElsIf ResultStructure.IsTaxpayer Then
			CommonClientServer.MessageToUser(NStr("en = 'Counterparty is a taxpayer'; tr = 'Cari hesap, vergi mükellefi'"));
		EndIf;
		
	Else
		ShowEDIExchangeErrorMessage();
	EndIf;
	
	Return ResultStructure;
	
EndFunction

#EndRegion

#Region Private

Procedure ShowCheckConnectionErrorMessage()
	
	ErrorText = NStr("en = 'Profile parameters check is completed with errors. Technical info was written to the event log.
		|Proceed to the event log?'; 
		|tr = 'Profil parametreleri kontrolü hatalarla tamamlandı. Teknik bilgiler olay günlüğüne yazıldı.
		|Olay günlüğüne gitmek istiyor musunuz?'");
	Notification = New CallbackDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No,
		NStr("en = 'EDI exchange'; tr = 'EDI değişimi'"));
	
EndProcedure

Procedure ShowEDIExchangeErrorMessage()
	
	ErrorText = NStr("en = 'Something went wrong on EDI system side. Technical info was written to the event log.
		|Proceed to the event log?'; 
		|tr = 'EDI sistemi tarafında hata oluştu. Teknik bilgiler olay günlüğüne yazıldı.
		|Olay günlüğüne gitmek istiyor musunuz?'");
	Notification = New CallbackDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No,
		NStr("en = 'EDI exchange'; tr = 'EDI değişimi'"));
	
EndProcedure

Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", NStr("en = 'EDI exchange'; tr = 'EDI değişimi'"));
		OpenForm("DataProcessor.EventLog.Form", Filter);
		
	EndIf;
	
EndProcedure

Function EDICommandDescription(CommandName, CommandsAddressInTempStorage)
	
	Return EDIServerCall.EDICommandDescription(CommandName, CommandsAddressInTempStorage);
	
EndFunction

#EndRegion