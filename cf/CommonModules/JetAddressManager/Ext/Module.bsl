
#Region Public

// Returns a namespace for XDTO contact information management.
//
// Returns:
//      String - a namespace.
//
Function Namespace() Export
	
	Return "http://www.v8.1c.ru/ssl/contactinfo";
	
EndFunction

// Internal, for serialization purposes.
Function ConvertAddressFromJSONToXML(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined) Export
	
	// Old format with line separator and equality.
	Namespace = Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	// Common composition
	Address = Result.Content;
	
	PresentationField = "";
	
	For Each ListItem In FieldsValues Do
		
		If IsBlankString(ListItem.Value) Then
			Continue;
		EndIf;
		
		FieldName = Upper(ListItem.Key);
		
		If FieldName = "COMMENT" Then
			Comment = TrimAll(ListItem.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = String(ListItem.Value);
		ElsIf FieldName = "VALUE" Then
			PresentationField = TrimAll(ListItem.Value);
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = Result.Presentation;
	
	Return Result;
	
EndFunction

#EndRegion