///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

Function OnDefineSettings() Export
	
	Settings = New Structure("TemplatesSubjects, CommonAttributes");
	Settings.Insert("UseArbitraryParameters", False);
	Settings.Insert("DCSParametersValues", New Structure);
	Settings.Insert("EmailFormat1", "");
	Settings.Insert("ExtendedRecipientsList", False);
	Settings.Insert("AlwaysShowTemplatesChoiceForm", True);
	
	CommonAttributesTree = MessageTemplatesInternal.DetermineCommonAttributes();
	Settings.CommonAttributes = MessageTemplatesInternal.CommonAttributes(CommonAttributesTree);
	Settings.TemplatesSubjects = MessageTemplatesInternal.DefineTemplatesSubjects();
	
	MessageTemplatesOverridable.OnDefineSettings(Settings);
	Settings.CommonAttributes = CommonAttributesTree;
	
	For Each TemplateSubject In Settings.TemplatesSubjects Do
		For Each DSCParameter In Settings.DCSParametersValues Do
			If Not TemplateSubject.DCSParametersValues.Property(DSCParameter.Key)
				Or TemplateSubject.DCSParametersValues[DSCParameter.Key] = Null Then
					TemplateSubject.DCSParametersValues.Insert(DSCParameter.Key, Settings.DCSParametersValues[DSCParameter.Key]);
			EndIf;
		EndDo;
	EndDo;
	
	Settings.TemplatesSubjects.Sort("Presentation");
	
	Result = New FixedStructure(Settings);
	Return Result;
	
EndFunction


Function MessageTemplatesAvailableSendOutOptions() Export
	
	Result = New Structure;
	Result.Insert("SMS", 
		Common.SubsystemExists("StandardSubsystems.SendSMSMessage"));
	Result.Insert("Mail", 
		Common.SubsystemExists("StandardSubsystems.EmailOperations"));
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion
