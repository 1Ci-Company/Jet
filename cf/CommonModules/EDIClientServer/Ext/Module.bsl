#Region Public

Procedure CheckCounterpartyIsReadyForExchange(Counterparty, HasErrors = False, ArrayToSaveMessages = Undefined) Export
	
	CounterpartyInfo = EDIServerCall.CounterpartyInfoToCheck(Counterparty);
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyTIN) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the TIN in their profile.'; tr = '%1 ile belge değişimi için lütfen profillerinde VKN''yi doldurun.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			#If Server Then
				Common.MessageToUser(MessageToUserText);	
			#EndIf
			#If Client Then
				CommonClient.MessageToUser(MessageToUserText);
			#EndIf
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyEmail) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the email in their profile.'; tr = '%1 ile belge değişimi için lütfen profillerinde e-postayı doldurun.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			#If Server Then
				Common.MessageToUser(MessageToUserText);
			#EndIf	
			#If Client Then	
				CommonClient.MessageToUser(MessageToUserText);
			#EndIf			
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyPostalAddress) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the legal address in their profile.'; tr = '%1 ile belge değişimi için lütfen profillerinde yasal adresi doldurun.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			#If Server Then
				Common.MessageToUser(MessageToUserText);	
			#EndIf
			#If Client Then
				CommonClient.MessageToUser(MessageToUserText);
			#EndIf
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.TaxOffice) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the tax office in their profile.'; tr = 'Belgeleri %1 ile değiştirmek için lütfen profillerinde vergi dairesini doldurun.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			#If Server Then
				Common.MessageToUser(MessageToUserText);	
			#EndIf
			#If Client Then
				CommonClient.MessageToUser(MessageToUserText);
			#EndIf
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If CounterpartyInfo.IsIndividual Then
		
		If CounterpartyInfo.NameParts.Count() < 2 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty must have at least a two-part name.'; tr = '%1 ile belge değişimi için cari hesabın en az iki kısımlı ismi olmalıdır.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				#If Server Then
					Common.MessageToUser(MessageToUserText);	
				#EndIf
				#If Client Then
					CommonClient.MessageToUser(MessageToUserText);
				#EndIf
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 11 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Individual'' type must have 11 digits TIN.'; tr = '%1 ile belge değişimi için ''Kişi'' türünde cari hesabın 11 haneli VKN''si olmalıdır.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				#If Server Then
					Common.MessageToUser(MessageToUserText);	
				#EndIf
				#If Client Then
					CommonClient.MessageToUser(MessageToUserText);
				#EndIf
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
	Else
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 10 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Legal entity'' type must have 10 digits TIN.'; tr = '%1 ile belge değişimi için ''Tüzel kişi'' türünde cari hesabın 10 haneli VKN''si olmalıdır.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				#If Server Then
					Common.MessageToUser(MessageToUserText);
				#EndIf	
				#If Client Then	
					CommonClient.MessageToUser(MessageToUserText);
				#EndIf				
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure PrintDocument(DocumentArray, DecodedString, HasError) Export
	
	EDIServerCall.PrintDocument(DocumentArray, DecodedString, HasError);
	
EndProcedure

Function DownloadDocument(DocumentArray, Path) Export
	
	Return EDIServerCall.DownloadDocument(DocumentArray, Path);
	
EndFunction

Procedure CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError) Export
	
	EDIServerCall.CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError);
	
EndProcedure

Function IsTaxpayer(TIN, EDocumentType, Identifier = Undefined) Export
	
	Return EDIServerCall.IsTaxpayer(TIN, EDocumentType, Identifier);
	
EndFunction

#EndRegion
