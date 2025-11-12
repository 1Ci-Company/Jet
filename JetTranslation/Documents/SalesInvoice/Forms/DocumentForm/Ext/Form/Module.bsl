
&AtClient
Procedure Translate_ActivateTranslatorOnChangeAfter(Item)
	If ActivateTranslator Then
		ThisForm.Items.TranslatorItems.Visible = True;
	Else
		ThisForm.Items.TranslatorItems.Visible = False;
	EndIf;
EndProcedure

&AtServer
Procedure Translate_TranslateAfterAtServer()
	APIUrl = "/v2/translate";
	APItype = Constants.Translate_Settings.Get();
	If APItype Then
		site ="api.deepl.com";
	Else
		site = "api-free.deepl.com";
	EndIf;
	
    HTTPConnection = New HTTPConnection(site,,,,,,NEW OpenSSLSecureConnection);
    HTTPRequest = New HTTPRequest; 
	HTTPRequest.ResourceAddress = APIUrl;
    HTTPRequest.Headers.Insert("Content-Type", "application/json");
	HTTPRequest.Headers.Insert("Authorization", "DeepL-Auth-Key " + constants.Translate_Token.Get());

    SystemMsg = New Structure;
	SystemMsgArray = New Array;
	SystemMsgArray.Add(Text);
    SystemMsg.Insert("text", SystemMsgArray);
    SystemMsg.Insert("target_lang", String(TargetLanguage));
	
	
	
    Writer = New JSONWriter;
    Writer.SetString(NEW JSONWriterSettings());
    WriteJSON(Writer , SystemMsg);

    Body = Writer.Close();
	
    HTTPRequest.SetBodyFromString(Body , TextEncoding.UTF8);
    HTTPResponse = HTTPConnection.Post(HTTPRequest);

    If HTTPResponse.StatusCode = 200 Then
        ResponseText = HTTPResponse.GetBodyAsString();
		Reader = New JSONReader;
		Reader.SetString(ResponseText);
		ResponseStructure = ReadJSON(Reader);
		Reader.Close(); 
		
		Translation = ResponseStructure.translations[0].text;
	EndIf;
EndProcedure

&AtClient
Procedure Translate_TranslateAfter(Command)
	Translate_TranslateAfterAtServer();
EndProcedure
