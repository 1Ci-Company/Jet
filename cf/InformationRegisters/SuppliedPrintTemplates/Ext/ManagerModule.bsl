///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure UpdateTemplatesCheckSum(Parameters) Export
	
	TemplateVersion = Metadata.Version;
	
	If Parameters.Property("TemplatesRequiringChecksumUpdate") Then
		TemplatesToProcess = Parameters.TemplatesRequiringChecksumUpdate;
	Else
		TemplatesToProcess = ExtensionsPrintFormTemplates();
	EndIf;
	
	TemplatesRequiringChecksumUpdate = New Map;
	ErrorList = New Array;
	
	For Each TemplateDetails In TemplatesToProcess Do
		Owner = TemplateDetails.Value;
		OwnerName = ?(Owner = Metadata.CommonTemplates, "CommonTemplate", Owner.FullName());
		OwnerMetadataObjectID = 
			?(Owner = Metadata.CommonTemplates, Catalogs.ExtensionObjectIDs.EmptyRef(), Common.MetadataObjectID(Owner));
		Template = TemplateDetails.Key;
		TemplateName = Template.Name;
		
		If Owner = Metadata.CommonTemplates Then
			TemplateData1 = GetCommonTemplate(Template);
		Else
			SetSafeModeDisabled(True);
			SetPrivilegedMode(True);
			
			TemplateData1 = Common.ObjectManagerByFullName(Owner.FullName()).GetTemplate(Template);
			
			SetPrivilegedMode(False);
			SetSafeModeDisabled(False);
		EndIf;
		
		Checksum = Common.CheckSumString(TemplateData1);
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.InformationRegisters.SuppliedPrintTemplates.FullName());
		DataLockItem.SetValue("TemplateName", TemplateName);
		DataLockItem.SetValue("Object", OwnerMetadataObjectID);
		
		BeginTransaction();
		Try
			DataLock.Lock();
			
			RecordSet = InformationRegisters.SuppliedPrintTemplates.CreateRecordSet();
			RecordSet.Filter.TemplateName.Set(Template.Name);
			RecordSet.Filter.Object.Set(OwnerMetadataObjectID);
			RecordSet.Read();
			
			If RecordSet.Count() > 0 Then
				Record = RecordSet[0];
			Else
				Record = RecordSet.Add();
				Record.TemplateName = Template.Name;
				Record.Object = OwnerMetadataObjectID;
			EndIf;
		
			If Record.TemplateVersion = TemplateVersion Then
				RollbackTransaction();
				Continue;
			EndIf;
			
			Record.TemplateVersion = TemplateVersion;
			Record.PreviousCheckSum = Record.Checksum;
			Record.Checksum = Checksum;
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			ErrorInfo = ErrorInfo();
			
			ErrorText = NStr("en = 'Failed to save template info';") + Chars.LF
				+ Template.FullName() + Chars.LF
				+ ErrorProcessing.DetailErrorDescription(ErrorInfo);
			
			WriteLogEvent(NStr("en = 'Build-in template edit monitor';", Common.DefaultLanguageCode()),
				EventLogLevel.Error, Template, , ErrorText);
			
			ErrorList.Add(OwnerName + "." + TemplateName + ": " + ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			TemplatesRequiringChecksumUpdate.Insert(TemplateDetails.Key, TemplateDetails.Value);
		EndTry;
	EndDo;
	
	If ValueIsFilled(TemplatesRequiringChecksumUpdate) Then
		ErrorList.Insert(0, NStr("en = 'Couldn''t save the template details of print forms stored in extensions:';"));
		Parameters.Insert("TemplatesRequiringChecksumUpdate", TemplatesRequiringChecksumUpdate);
		ErrorText = StrConcat(ErrorList, Chars.LF);
		Raise ErrorText;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function ExtensionsPrintFormTemplates()
	
	Result = New Map;
	
	For Each Template In PrintManagement.PrintFormTemplates() Do
		If Template.Key.ConfigurationExtension() = Undefined Then
			Continue;
		EndIf;
		Result.Insert(Template.Key, Template.Value);
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf