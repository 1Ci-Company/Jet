///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotifyDescription = New NotifyDescription("ImportCurrencyRatesClient", ThisObject);
	ShowQueryBox(NotifyDescription, 
		NStr("en = 'You are about to import a file with full exchange rates data for all the periods from the service manager.
              |The exchange rates that are marked to be imported from the Internet in specific data areas will be replaced in a background job. Do you want to continue?';tr = 'Servis yöneticisinden tüm dönemler için tam döviz kuru verilerini içeren bir dosyayı içe aktarmak üzeresiniz.
              |Belirli veri alanlarında internetten içe aktarılmak üzere işaretlenen döviz kurları arka plan işinde değiştirilecek. Devam etmek istiyor musunuz?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportCurrencyRatesClient(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ImportCurrencyRates();
	
	ShowUserNotification(
		NStr("en = 'The import is scheduled.';tr = 'İçe aktarım planlandı.'"), ,
		NStr("en = 'The exchange rates will soon be imported in background mode.';tr = 'Döviz kurları kısa süre içinde arka plan modunda içe aktarılacak.'"),
		PictureLib.DialogInformation);
	
EndProcedure

&AtServer
Procedure ImportCurrencyRates()
	
	CurrencyRateOperationsInternal.ImportCurrencyRates();
	
EndProcedure

#EndRegion
