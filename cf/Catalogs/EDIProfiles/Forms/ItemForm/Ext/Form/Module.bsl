
#Region Variables

&AtClient
Var CurrentHost;

&AtClient
Var CurrentHostRow;

&AtClient
Var ThisIsNewRow;

&AtClient
Var CurrentProvider;

&AtClient
Var SaveType;

&AtClient
Var AddedRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.DocumentsForExchangeDocumentType.ChoiceList.Clear();
	ItemChoice = Common.MetadataObjectID(Type("DocumentRef.SalesInvoice"));
	Items.DocumentsForExchangeDocumentType.ChoiceList.Add(ItemChoice);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Hosts.Count() = 0 Then
	
		ShowAllItem = Items.ShowAll;
		ShowAllItem.Check = Not ShowAllItem.Check;
		Items.HostsEditHost.Enabled = False;
		ActivateHosts();
		
	EndIf;
	
	SaveType = "Add";
	AddedRow = False;
	
	FormManagement();
	EDocumentTypeChange();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If Object.DocumentsForExchange.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Please add documents to exchange.'; tr = 'Lütfen değiştirilecek belgeleri ekleyin.'"),
			,
			"Object.DocumentsForExchange");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not MessageWasShown Then
		
		CompanyInfo = CompanyInfo(Object.Company);
		
		If Not ValueIsFilled(CompanyInfo.CompanyPostalAddress)Then
			
			MessageToUserText = 
				NStr("en = 'Before you start the exchange, please fill in the legal address in your company’s profile.'; tr = 'Değişime başlamadan önce lütfen iş yeri profilinizde yasal adresi doldurun.'");
			MessageWasShown = True;
			Cancel = True;
			Res = New CallbackDescription("DoAfterCloseMessageBox", ThisObject);
			ShowMessageBox(Res, MessageToUserText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CheckEDIProfile(Command)
	
	ErrorText = ConnectionTest();
	
	If IsBlankString(ErrorText) Then
		EDIClient.CheckConnection(Object.Company, CurrentHostRow.Provider);
	Else
		ShowMessageBox(, ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddHost(Command)
	
	SaveType = "Add";
	AddedRow = True;
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("SaveType", SaveType);
	SelectionParameters.Insert("AddedRow", AddedRow);
	
	OpenForm("Catalog.EDIProfiles.Form.SettingProvider",
		SelectionParameters,,,,,
		New CallbackDescription("EditHostsCallbackDescription", ThisObject));
	
EndProcedure

&AtClient
Procedure EditHost(Command)
	
	SaveType = "Update";
	AddedRow = False;
	
	CurrentHostRow = Items.Hosts.CurrentData;
	
	If CurrentHostRow <> Undefined Then
		
		SelectionParameters = New Structure;
		SelectionParameters.Insert("Ref",			Object.Ref);
		SelectionParameters.Insert("SaveType",		SaveType);
		SelectionParameters.Insert("AddedRow",		AddedRow);
		SelectionParameters.Insert("LineID",		CurrentHostRow.LineID);
		SelectionParameters.Insert("Provider",		CurrentHostRow.Provider);
		SelectionParameters.Insert("Description",	CurrentHostRow.Description);
		SelectionParameters.Insert("ProviderURL",	CurrentHostRow.URL);
		SelectionParameters.Insert("Username",		CurrentHostRow.Username);
		SelectionParameters.Insert("Password",		CurrentHostRow.Password);
		
		OpenForm("Catalog.EDIProfiles.Form.SettingProvider",
			SelectionParameters,,,,,
			New CallbackDescription("EditHostsCallbackDescription", ThisObject));
			
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	CommonClientServer.SetFormItemProperty(Items, "EInvoiceStartDate", "Visible", Object.UseEInvoice);
	CommonClientServer.SetFormItemProperty(Items, "EDocumentScenario", "Visible", Object.UseEInvoice);
	
EndProcedure

&AtServerNoContext
Function CompanyInfo(Company)
	
	Result = New Structure;
	
	Result.Insert("CompanyPostalAddress",
		ContactsManager.ObjectContactInformation(Company, ContactsManager.ContactInformationKindByName("CompanyLegalAddress")));
	
	Return Result;
	
EndFunction

&AtClient
Procedure DoAfterCloseMessageBox(Result) Export
	
	ThisObject.Write();
	
EndProcedure

&AtClient
Procedure UseEInvoiceOnChange(Item)
	EDocumentTypeChange();
EndProcedure

&AtClient
Procedure EDocumentTypeChange()
	
	Items.EInvoiceStartDate.Visible = Object.UseEInvoice;
	Items.EDocumentScenario.Visible = Object.UseEInvoice;
	
	Items.DocumentsForExchangeEDocumentType.ChoiceList.Clear();
	Items.DocumentsForExchangeEDocumentType.ChoiceList.Add(PredefinedValue("Enum.EDocumentType.EArchive"));
	
	If Object.UseEInvoice Then
		Items.DocumentsForExchangeEDocumentType.ChoiceList.Add(PredefinedValue("Enum.EDocumentType.EInvoice"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivateHosts()
	
	ShowAll = Items.ShowAll.Check;
	DocumentItem = Items.DocumentsForExchange;
	
	If Not ShowAll 
		And (DocumentItem.RowFilter = Undefined 
			Or DocumentItem.RowFilter.SourceID <> CurrentHost) Then
		
		DocumentItem.RowFilter = New FixedStructure("SourceID", CurrentHost);
		
	ElsIf ShowAll And DocumentItem.RowFilter <> Undefined Then
		
		DocumentItem.RowFilter = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowAll(Command)
	
	ShowAllItem = Items.ShowAll;
	ShowAllItem.Check = Not ShowAllItem.Check;
	ActivateHosts();
	
EndProcedure

&AtClient
Procedure HostsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	SaveType = "Update";
	AddedRow = False;
	
	CurrentHostRow = Item.CurrentData;
	
	If CurrentHostRow <> Undefined Then
		
		SelectionParameters = New Structure;
		SelectionParameters.Insert("Ref",			Object.Ref);
		SelectionParameters.Insert("SaveType",		SaveType);
		SelectionParameters.Insert("AddedRow",		AddedRow);
		SelectionParameters.Insert("LineID",		CurrentHostRow.LineID);
		SelectionParameters.Insert("Provider",		CurrentHostRow.Provider);
		SelectionParameters.Insert("Description",	CurrentHostRow.Description);
		SelectionParameters.Insert("ProviderURL",	CurrentHostRow.URL);
		SelectionParameters.Insert("Username",		CurrentHostRow.Username);
		SelectionParameters.Insert("Password",		CurrentHostRow.Password);
		
		OpenForm("Catalog.EDIProfiles.Form.SettingProvider",
			SelectionParameters,,,,,
			New CallbackDescription("EditHostsCallbackDescription", ThisObject));
		
	EndIf;

EndProcedure

&AtClient
Procedure HostsOnActivateRow(Item)
	
	StandardProcessing = False;
	CurrentHostRow = Item.CurrentData;
	
	If CurrentHostRow <> Undefined Then
		
		Provider = CurrentHostRow.Provider;
		Description = CurrentHostRow.Description;
		ProviderURL = CurrentHostRow.URL;
		Username = CurrentHostRow.UserName;
		Password = CurrentHostRow.Password;
		If Not AddedRow Then
			SaveType = "Update";
		EndIf;
		
	EndIf;
	
	If CurrentHostRow = Undefined Then
		CurrentHost = Undefined;
	Else
		CurrentHost = CurrentHostRow.LineID;
	EndIf;
	
	AttachIdleHandler("ActivateHosts", 0.2, True);
	
EndProcedure

&AtClient
Procedure HostsBeforeDeleteRow(Item, Cancel)
	
	HDGelectedRows = Items.Hosts.SelectedRows;
	
	For Each HostsRowID In HDGelectedRows Do
		
		HostsRow = Object.Hosts.FindByID(HostsRowID);
		
		DocumentsForExchangeRows = Object.DocumentsForExchange.FindRows(
			New Structure("SourceID", HostsRow.LineID));
		
		For Each DocumentsForExchangeRow In DocumentsForExchangeRows Do
			
			DocumentsForExchangeRow.SourceID = 0;
			
		EndDo;
		
	EndDo;

EndProcedure

&AtClient
Procedure HostsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		Item.CurrentData.LineID = New UUID;
		CurrentHostRow = Item.CurrentData;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		If Not CurrentHostRow = Undefined Then
			
			DocumentRow = Item.CurrentData;
			DocumentRow.SourceID = CurrentHostRow.LineID;
			DocumentRow.Use = True;
			
		EndIf;
		
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentsForExchangeBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If CurrentHostRow = Undefined Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Please add host before add document'; tr = 'Lütfen belge eklemeden önce E- Fatura entegratörünü ve E- Fatura entegratörünün verdiği bilgileri doldurun'", CommonClientServer.DefaultLanguageCode()));
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Function ConnectionTest()
	
	If Modified Then
		Return NStr("en = 'Please save changes before test connection.'; tr = 'Lütfen, test bağlantısından önce değişiklikleri kaydedin.'",
			CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	If CurrentHostRow = Undefined Then
		Return NStr("en = 'Please add host to test connection.'; tr = 'Lütfen, bağlantıyı test etmek için entegratör ekleyin.'",
			CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	If Not ValueIsFilled(CurrentHostRow.Provider) Then
		Return NStr("en = 'Please add select provider to test connection.'; tr = 'Lütfen, bağlantıyı test etmek için entegratörü seçin.'",
			CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	Return "";
	
EndFunction

&AtClient
Procedure EditHostsCallbackDescription(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		If Result.SaveType = "Update" Then
			
			FindParams = New Structure("LineID", Result.LineID);
			FindRow = Object.Hosts.FindRows(FindParams);
			HostRow = FindRow[0];
			
		Else
			
			HostRow = Object.Hosts.Add();
			HostRow.LineID = New UUID;
			
		EndIf;
		
		HostRow.Provider = Result.Provider;
		HostRow.Description = Result.Description;
		HostRow.URL = Result.ProviderURL;
		HostRow.UserName = Result.Username;
		HostRow.Password = Result.Password;
		
		AddedRow = False;
		Items.HostsEditHost.Enabled = True;
		Modified = True;
		
	EndIf;

EndProcedure

#EndRegion
