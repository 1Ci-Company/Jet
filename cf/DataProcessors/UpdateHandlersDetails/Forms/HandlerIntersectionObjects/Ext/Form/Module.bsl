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
	
	If ValueIsFilled(Parameters.DataAddress) Then
		If Parameters.AreLowPriorityHandlers Then
			Data = GetFromTempStorage(Parameters.DataAddress);
			LowPriorityHandlers.Load(Data);
			Items.TablesPages.CurrentPage = Items.PageLowPriorityHandlers;
			Title = NStr("en = 'Handlers with low priority';");
		Else
			Data = GetFromTempStorage(Parameters.DataAddress);
			Intersections.Load(Data);
			Items.TablesPages.CurrentPage = Items.IntersectionsPage;
			Title = NStr("en = 'Handler intersection objects';");
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion