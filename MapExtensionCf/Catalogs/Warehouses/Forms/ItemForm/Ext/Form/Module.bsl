
&AtServer
Function Map_ShowinMapAfterAtServer()
	params = New Structure;
	Adress = ContactsManager.ObjectContactInformation(ThisObject.Object.Ref ,Enums.ContactInformationTypes.Address,,True); 
	params.Insert("Adress" , Adress);
	Return params;
EndFunction

&AtClient
Procedure Map_ShowinMapAfter(Command)
	params = Map_ShowinMapAfterAtServer();		

	OpenForm("DataProcessor.Map.Form.MapForm",params);
EndProcedure
