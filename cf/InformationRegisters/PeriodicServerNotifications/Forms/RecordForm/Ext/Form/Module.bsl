///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ReadOnly = True;
	
	IBUserID = Record.IBUserID;
	
	Store = FormAttributeToValue("Record").Notifications;
	
	Items.PageNotifications.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Notifications (size, bytes: %1)';"),
		String(Base64Value(XMLString(Store)).Size()));
	
	StorageContents = Store.Get();
	Try
		Notifications = Common.ValueToXMLString(StorageContents);
	Except
		Notifications = ValueToStringInternal(StorageContents);
	EndTry;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion
