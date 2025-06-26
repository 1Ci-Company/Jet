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
	
	CommonClientServer.SetDynamicListParameter(
		List,
		"PresentationAdditionalInfo",
		NStr("en = 'Additional information records';"),
		True);
	
	CommonClientServer.SetDynamicListParameter(
		List,
		"PresentationAdditionalAttributes",
		NStr("en = 'Additional attributes';"),
		True);
	
	// Grouping properties to sets.
	DataGroup2 = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup2.UserSettingID = "GroupPropertiesBySets";
	DataGroup2.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup2.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertiesSetGroup");
	DataGroupItem.Use = True;
	
EndProcedure

#EndRegion
