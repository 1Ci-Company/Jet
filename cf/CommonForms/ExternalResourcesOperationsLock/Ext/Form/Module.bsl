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
	
	EventLogEventName = ExternalResourcesOperationsLock.EventLogEventName();
	
	LockParameters = ExternalResourcesOperationsLock.SavedLockParameters();
	CheckServerName = LockParameters.CheckServerName;
	
	If Parameters.LockDecisionMaking Then
		
		UnlockText = ScheduledJobsInternal.SettingValue("UnlockCommandPlacement");
		DataSeparationEnabled = Common.DataSeparationEnabled();
		DataSeparationChanged = LockParameters.DataSeparationEnabled <> DataSeparationEnabled;
		
		If DataSeparationEnabled Then
			Items.InfobaseMoved.Title = NStr("en = 'Moved application';tr = 'Taşınan uygulama'");
			Items.IsInfobaseCopy.Title = NStr("en = 'Application copy';tr = 'Uygulama kopyası'");
			Title = NStr("en = 'Moved or restored application';tr = 'Taşınan veya geri yüklenen uygulama'");
		EndIf;
		
		If Not DataSeparationEnabled And Not DataSeparationChanged Then
			
			ScalableClusterClarification = ?(Common.FileInfobase(), "",
				NStr("en = '• For scalable clusters, to prevent false starts due to change of computers acting as production servers
				           |, disable the computer name check by clicking <b>More > Check server name.</b>';tr = '• Ölçeklendirilebilir kümeler için, üretim sunucuları olarak görev yapan bilgisayarlardaki 
				           |değişikliklerden kaynaklanan yanlış başlatmaları önlemek amacıyla <b>Daha fazla > Sunucu adını kontrol et''e tıklayarak bilgisayar adını devre dışı bırakın.</b>'"));
			
			WarningLabel = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Scheduled online activities such as data synchronization and emailing are disabled
				           |to prevent conflicts with the main infobase.
				           |
				           |%1
				           |
				           |<a href = ""%2"">Technical information</a>
				           |
				           | • If you are going to use the infobase for accounting, select <b>Moved infobase</b>.
				           | • If this is an infobase copy, select <b>Infobase copy</b>.
				           |%3
				           |
				           |%4';tr = 'Ana infobase ile uyuşmazlıkları önlemek için, veri senkronizasyonu ve e-posta işlemleri gibi 
				           |planlı çevrimiçi işlemler devre dışı bırakıldı.
				           |
				           |%1
				           |
				           |<a href = ""%2"">Teknik bilgiler</a>
				           |
				           | • Infobase''i muhasebe için kullanacaksanız <b>Taşınmış infobase</b>''i seçin.
				           | • Bu bir infobase kopyası ise <b>Infobase kopyası</b>''nı seçin.
				           |%3
				           |
				           |%4'"),
				LockParameters.LockReason,
				"EventLog",
				ScalableClusterClarification,
				UnlockText);
		ElsIf Not DataSeparationEnabled And DataSeparationChanged Then
			WarningLabel = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Scheduled online activities such as data synchronization and emailing are disabled
				           |to prevent conflicts with the web application.
				           |
				           |<b>This infobase was imported from the web application</b>.
				           |
				           | • If you are going to use the infobase for accounting, select <b>Moved infobase</b>.
				           | • If this is an infobase copy, select <b>Infobase copy</b>.
				           |
				           |%1';tr = 'Web uygulaması ile uyuşmazlıkları önlemek için, veri senkronizasyonu ve e-posta işlemleri gibi 
				           |planlı çevrimiçi işlemler devre dışı bırakıldı.
				           |
				           |<b>Bu infobase web uygulamasından içe aktarıldı</b>.
				           |
				           | • Infobase''i muhasebe için kullanacaksanız <b>Taşınmış infobase</b>''i seçin.
				           | • Bu bir infobase kopyası ise <b>Infobase kopyası</b>''nı seçin.
				           |
				           |%1'"),
				UnlockText);
		ElsIf DataSeparationEnabled And Not DataSeparationChanged Then
			WarningLabel = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Scheduled online activities such as data synchronization and emailing are disabled
				           |to prevent conflicts with the web application.
				           |
				           |<b>The application was moved.</b>
				           |
				           | • If you are going to use the application for accounting, select <b>Moved application</b>.
				           | • If this is an application copy, select <b>Application copy</b>.
				           |
				           |%1';tr = 'Web uygulaması ile uyuşmazlıkları önlemek için, veri senkronizasyonu ve e-posta işlemleri gibi 
				           |planlı çevrimiçi işlemler devre dışı bırakıldı.
				           |
				           |<b>Uygulama taşındı.</b>
				           |
				           |• Uygulamayı muhasebe için kullanacaksanız <b>Taşınmış uygulama</b>''yı seçin.
				           | • Bu bir uygulama kopyası ise <b>Uygulama kopyası</b>''nı seçin.
				           |
				           |%1'"),
				UnlockText);
		Else // If DataSeparationEnabled and DataSeparationChanged
			WarningLabel = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Scheduled online activities such as data synchronization and emailing are disabled
				           |to prevent conflicts with the local version.
				           |
				           |The application was imported from the local version.
				           |
				           | • If you are going to use the application for accounting, select <b>Moved application</b>.
				           | • If this is an application copy, select <b>Application copy</b>.
				           |
				           |%1';tr = 'Yerel sürüm ile uyuşmazlıkları önlemek için, veri senkronizasyonu ve e-posta işlemleri gibi 
				           |planlı çevrimiçi işlemler devre dışı bırakıldı.
				           |
				           |Uygulama yerel sürümden içe aktarıldı.
				           |
				           |• Uygulamayı muhasebe için kullanacaksanız <b>Taşınmış uygulama</b>''yı seçin.
				           | • Bu bir uygulama kopyası ise <b>Uygulama kopyası</b>''nı seçin.
				           |
				           |%1'"),
				UnlockText);
		EndIf;
		
		Items.WarningLabel.Title = StringFunctions.FormattedString(WarningLabel);
		
		If Common.FileInfobase() Then
			Items.FormMoreGroup.Visible = False;
		Else
			Items.FormCheckServerName.Check = CheckServerName;
			Items.FormHelp.Visible = False;
		EndIf;
		
	Else
		Items.FormParametersGroup.CurrentPage = Items.LockParametersGroup;
		Items.WarningLabel.Visible = False;
		Items.WriteAndClose.DefaultButton = True;
		Title = NStr("en = 'Lock settings of external resources';tr = 'Dış kaynak kilitleme seçenekleri'");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WarningLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogEvent", EventLogEventName);
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure InfobaseMoved(Command)
	
	AllowExternalResources();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	RefreshInterface();
	Close();
	
EndProcedure

&AtClient
Procedure IsInfobaseCopy(Command)
	
	DenyExternalResources();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	RefreshInterface();
	Close();
	
EndProcedure

&AtClient
Procedure CheckServerName(Command)
	
	CheckServerName = Not CheckServerName;
	Items.FormCheckServerName.Check = CheckServerName;
	SetServerNameCheckInLockParameters(CheckServerName);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	SetServerNameCheckInLockParameters(CheckServerName);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure AllowExternalResources()
	
	ExternalResourcesOperationsLock.AllowExternalResources();
	
EndProcedure

&AtServerNoContext
Procedure DenyExternalResources()
	
	ExternalResourcesOperationsLock.DenyExternalResources();
	
EndProcedure

&AtServerNoContext
Procedure SetServerNameCheckInLockParameters(CheckServerName)
	
	ExternalResourcesOperationsLock.SetServerNameCheckInLockParameters(CheckServerName);
	
EndProcedure

#EndRegion
