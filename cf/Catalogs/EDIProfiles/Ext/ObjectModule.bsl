#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If CheckCompany() And Not DeletionMark Then
		MessageText = NStr("en = '%1 is already has EDI Profile.'; tr = '%1 zaten EDI profiline sahip.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Company);
		CommonClientServer.MessageToUser(MessageText,,,, Cancel);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Host In Hosts Do
		
		If Host.UseTest Then
			CheckedAttributes.Add("Hosts.URLTest");
			CheckedAttributes.Add("Hosts.UserNameTest");
			CheckedAttributes.Add("Hosts.PasswordTest");
		Else
			CheckedAttributes.Add("Hosts.URL");
			CheckedAttributes.Add("Hosts.UserName");
			CheckedAttributes.Add("Hosts.Password");
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	For Each Host In Hosts Do
		
		NewUUID = New UUID;
		
		Filter = New Structure("SourceID", Host.LineID);
		ConnectedLines = DocumentsForExchange.FindRows(Filter);
		
		For Each Line In ConnectedLines Do
			Line.SourceID = NewUUID;
		EndDo;
		
		Host.LineID = NewUUID;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function CheckCompany()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	EDIProfiles.Ref AS Ref
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|WHERE
	|	EDIProfiles.Company = &Company
	|	AND EDIProfiles.Ref <> &Ref
	|	AND NOT EDIProfiles.DeletionMark";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Ref", Ref);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#EndIf