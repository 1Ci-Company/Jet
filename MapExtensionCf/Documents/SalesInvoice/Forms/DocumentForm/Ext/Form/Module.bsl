&AtServer
Function EncodeURL(URL)
	Return EncodeString(URL, StringEncodingMethod.URLEncoding);
EndFunction    

&AtServer
Function GetOSRMRoadRoute(Location , TargetLocation)
	Cord1 = coordinates(Location);
	Cord2 = coordinates(TargetLocation);
	Lat1 = Cord1.lat;
	Lon1 = Cord1.lon;
	Lat2 = Cord2.lat;
	Lon2 = Cord2.lon;
	
	HTTPConnection = New HTTPConnection("router.project-osrm.org"); 
	HTTPRequest = New HTTPRequest; 
	HTTPRequest.ResourceAddress = "/route/v1/driving/" + 
	String(Lon1) + "," + String(Lat1) + ";" + 
	String(Lon2) + "," + String(Lat2) + "?overview=false";
	
	HTTPResponse = HTTPConnection.Get(HTTPRequest);
	If HTTPResponse.StatusCode = 200 Then
		
		ResponseText = HTTPResponse.GetBodyAsString();
		Reader = New JSONReader;
		Reader.SetString(ResponseText);
		ResponseStructure = ReadJSON(Reader);
		Reader.Close();
		
		Time = (ResponseStructure.routes[0].duration) / 3600;
		Distance = (ResponseStructure.routes[0].distance) / 1000; 
		MapValues = New Structure;
		MapValues.Insert("Time" , Time);
		MapValues.Insert("Distance" , Distance);
		
		Return MapValues;
		
	EndIf;
	
EndFunction 

&AtServer
Function coordinates(MapAdress)
	HTTPConnection = New HTTPConnection("nominatim.openstreetmap.org",,,,,,NEW OpenSSLSecureConnection); 
	HTTPRequest = New HTTPRequest; 
	HTTPRequest.ResourceAddress = "/search?q=" + 
	EncodeUrl(MapAdress) + "&format=json&limit=1"; 
	
	HTTPResponse = HTTPConnection.Get(HTTPRequest);
	
	If HTTPResponse.StatusCode = 200 Then
		ResponseText = HTTPResponse.GetBodyAsString();
		Reader = New JSONReader;
		Reader.SetString(ResponseText);
		ResponseStructure = ReadJSON(Reader);
		Reader.Close();	 
		
		Lat = ResponseStructure[0].lat;
		Lon = ResponseStructure[0].lon;
		Cords = New Structure ;
		Cords.Insert("lat" , Lat);
		Cords.Insert("lon" , Lon);
		Return Cords;
	EndIf;
	
EndFunction  

&AtClient
Procedure RefreshInformation(Command) 
	CustomerAdress = GetCustomerAdress();
	WarehouseAdress =GetWarehouseAdress(); 
	If NOT TrimAll(ThisObject.CustomerAdress)= "" AND NOT TrimAll(ThisObject.WarehouseAdress) = "" Then 
			GetOSRMRoadRoute(CustomerAdress , WarehouseAdress); 
		Else
			Raise("Please make sure adress of counterparty and warehouse are filled!"); 
		
	EndIf;
EndProcedure
&AtServer
Function GetCustomerAdress() 
	
	Return ContactsManager.ObjectContactInformation(ThisObject.Object.Customer ,Enums.ContactInformationTypes.Address,,True); 
EndFunction 
&AtServer
Function GetWarehouseAdress() 
	
	Return ContactsManager.ObjectContactInformation(ThisObject.Object.Warehouse ,Enums.ContactInformationTypes.Address,,True); 
EndFunction

&AtClient
Procedure Map_ShowDistanceOnChangeAfter(Item)
	If ShowDistance Then 
		ThisForm.Items.MapGroup.Visible = True;	
	Else
		ThisForm.Items.MapGroup.Visible = False;
	EndIf;
EndProcedure
