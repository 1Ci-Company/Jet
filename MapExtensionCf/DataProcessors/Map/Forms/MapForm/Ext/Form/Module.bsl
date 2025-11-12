&AtClient
Procedure RefreshTheMap(Command) 
	
	If ThisForm.MapType = "Google" Then
	ThisForm.OpenURL =
		"https://www.google.com/maps/search/?api=1&query=" +
		EncodeURL(ThisForm.Adress);
	ElsIf ThisForm.MapType = "Yandex" Then
		ThisForm.OpenURL =
		"https://yandex.com.tr/maps/?text=" +
		EncodeURL(ThisForm.Adress);	
	EndIf;
	
EndProcedure                        
	

&AtServer
Function EncodeURL(URL)
	Return EncodeString(URL, StringEncodingMethod.URLEncoding);
EndFunction    

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If NOT constants.PreferredMapProvider.Get() = "" or constants.PreferredMapProvider.Get() = Undefined Then
		ThisObject.MapType = constants.PreferredMapProvider.Get();	
	EndIf; 
	
	If Parameters.Property("Adress") Then
		ThisObject.Adress = Parameters.Adress;
	EndIf;
EndProcedure


&AtClient
Procedure OnOpen(Cancel)
	If Not ThisObject.Adress = "" Then
		RefreshTheMapAuto();	
	EndIf;
EndProcedure 

&AtClient
Procedure RefreshTheMapAuto() 
	
	If ThisForm.MapType = "Google" Then
	ThisForm.OpenURL =
		"https://www.google.com/maps/search/?api=1&query=" +
		EncodeURL(ThisForm.Adress);
	ElsIf ThisForm.MapType = "Yandex" Then
		ThisForm.OpenURL =
		"https://yandex.com.tr/maps/?text=" +
		EncodeURL(ThisForm.Adress);	
	EndIf;
	
EndProcedure

