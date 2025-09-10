
#Region Public

// Details of CI address for storing it in the JSON format.
//
// Returns:
//  Structure - contacts fields
//
Function NewAddressDetails() Export
	
	Result = New Structure;
	Result.Insert("value",			"");
	Result.Insert("comment",		"");
	Result.Insert("type",			"Address");
	Result.Insert("AddressType",	ContactsManagerClientServer.CustomFormatAddress());
	Result.Insert("AddressLine1",	"");
	Result.Insert("AddressLine2",	"");
	Result.Insert("City",			"");
	Result.Insert("State",			"");
	Result.Insert("PostalCode",		"");
	Result.Insert("Country",		"");
	Result.Insert("CountryCode",	"");
	Result.Insert("ID",				"");
	
	Return Result;
	
EndFunction

Procedure UpdateAddressPresentation(Address, IncludeCountryInPresentation) Export
	
	If TypeOf(Address) <> Type("Structure") Then
		Raise NStr("en = 'Incorrect address type was passed to generate address representation'; tr = 'Bir adres görünümü oluşturmak için yanlış adres türü iletildi'");
	EndIf;
	
	FilledLevelsList = New Array;
	
	If Address.Property("AddressLine1") And Not IsBlankString(Address.AddressLine1) Then
		FilledLevelsList.Add(Address.AddressLine1);
	EndIf;
	
	If Address.Property("AddressLine2") And Not IsBlankString(Address.AddressLine2) Then
		FilledLevelsList.Add(Address.AddressLine2);
	EndIf;
	
	If Address.Property("City") And Not IsBlankString(Address.City) Then
		FilledLevelsList.Add(Address.City);
	EndIf;
	
	If Address.Property("State") And Not IsBlankString(Address.State) Then
		FilledLevelsList.Add(Address.State);
	EndIf;
	
	If Address.Property("PostalCode") And Not IsBlankString(Address.PostalCode) Then
		FilledLevelsList.Add(Address.PostalCode);
	EndIf;
	
	If IncludeCountryInPresentation
		And Address.Property("Country")
		And Not IsBlankString(Address.Country) Then
		FilledLevelsList.Add(Address.Country);
	EndIf;
	
	Address.Value = StrConcat(FilledLevelsList, ", ");
	
EndProcedure

#EndRegion