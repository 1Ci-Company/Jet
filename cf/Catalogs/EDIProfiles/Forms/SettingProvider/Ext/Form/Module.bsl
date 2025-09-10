
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.SaveType = "Update" Then
		
		Provider = Parameters.Provider;
		LineID = Parameters.LineID;
		Description = Parameters.Description;
		ProviderURL = Parameters.ProviderURL;
		Username = Parameters.Username;
		Password = Parameters.Password;
		SaveType = Parameters.SaveType;
		
	Else
		Title = NStr("en = 'Create'; tr = 'Oluştur'");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddHost(Command)
	
	If SaveType = "Add" Then
		LineID = New UUID;
	EndIf;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("LineID",			LineID);
	LabelStructure.Insert("SaveType",		SaveType);
	LabelStructure.Insert("Provider",		Provider);
	LabelStructure.Insert("Description",	Description);
	LabelStructure.Insert("ProviderURL",	ProviderURL);
	LabelStructure.Insert("Username",		Username);
	LabelStructure.Insert("Password",		Password);
	
	ThisObject.Close(LabelStructure);
	
EndProcedure

#EndRegion