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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("UseForSending");
	Result.Add("UseForReceiving");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	CASE WHEN AccountOwner = VALUE(Catalog.Users.EmptyRef) THEN
	|		ValueAllowed(Ref)
	|	ELSE
	|		ValueAllowed(Ref, Disabled AS FALSE)
	|		OR ValueAllowed(AccountOwner, Disabled AS FALSE)
	|		OR IsAuthorizedUser(AccountOwner)
	|	END
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ValueAllowed(AccountOwner, EmptyRef AS FALSE)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Email");
	Fields.Add("Description");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)

	StandardProcessing = False;
	If ValueIsFilled(Data.Email) And StrFind(Data.Description, Data.Email) = 0 Then
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2)';"), 
			Data.Description, Data.Email);
	Else
		Presentation = Data.Description;
	EndIf;

EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.RegisterEmailAccountsToProcessingToMigrateToNewVersion(Parameters);
	EndIf;
	
	QueryText =
	"SELECT
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	NOT EmailAccounts.AuthorizationRequiredOnSendEmails
	|	AND (EmailAccounts.SMTPUser <> """"
	|	OR EmailAccounts.SignInBeforeSendingRequired)";
	
	Query = New Query(QueryText);
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Accounts_ = New Array;
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.EmailAccounts");
	While Selection.Next() Do
		Accounts_.Add(Selection.Ref);
	EndDo;
	
	QueryText =
	"SELECT
	|	EmailAccounts.Ref AS Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.Ref IN(&Accounts_)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Accounts_", Accounts_);
	
	Block = New DataLock;
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.BeforeSetLockInEmailAccountsUpdateHandler(Block);
	EndIf;
	Block.Add("Catalog.EmailAccounts");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		AccountOwners = New Map;
		If Common.SubsystemExists("StandardSubsystems.Interactions") Then
			ModuleInteractions = Common.CommonModule("Interactions");
			AccountOwners = ModuleInteractions.EmailAccountsOwners(Accounts_);
		EndIf;
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Account = Selection.Ref.GetObject();
			Account.AdditionalProperties.Insert("DoNotCheckSettingsForChanges");
			If AccountOwners[Selection.Ref] <> Undefined Then
				Account.AccountOwner = AccountOwners[Selection.Ref];
			EndIf;
			If Not Account.AuthorizationRequiredOnSendEmails 
				And (Account.SMTPUser <> ""
				Or Account.SignInBeforeSendingRequired) Then
				Account.AuthorizationRequiredOnSendEmails = True;
				If Account.UseForSending And Account.User <> Account.SMTPUser Then
					Account.User = Account.SMTPUser;
					SetPrivilegedMode(True);
					Passwords = Common.ReadDataFromSecureStorage(Account.Ref, "Password,SMTPPassword");
					If Passwords.Password <> Passwords.SMTPPassword Then
						Common.WriteDataToSecureStorage(Account.Ref, Passwords.SMTPPassword);
					EndIf;
					SetPrivilegedMode(False);
				EndIf;
			EndIf;
			If Common.SubsystemExists("StandardSubsystems.Interactions") Then
				ModuleInteractions.ClearPersonalAccountFlag(Account.Ref);
			EndIf;
			InfobaseUpdate.WriteData(Account);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Email account update';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.EmailAccounts");
	
EndProcedure

// Initial population.

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	Item = Items.Add();
	Item.PredefinedDataName        = "SystemEmailAccount";
	Item.Description                     = NStr("en = 'System account';", 
		Common.DefaultLanguageCode());
	Item.UserName                  = NStr("en = '1C:Enterprise';", Common.DefaultLanguageCode());
	Item.UseForReceiving         = False;
	Item.UseForSending          = False;
	Item.KeepMessageCopiesAtServer = False;
	Item.KeepMailAtServerPeriod = 0;
	Item.Timeout                    = 30;
	Item.IncomingMailServerPort         = 110;
	Item.OutgoingMailServerPort        = 25;
	Item.ProtocolForIncomingMail            = "POP";
	
EndProcedure

#EndRegion

#Region Private

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ObjectForm" 
		And Not Parameters.Property("CopyingValue")
		And AccessRight("Edit", Metadata.Catalogs.EmailAccounts)
		And (Not Parameters.Property("Key") 
			Or Not EmailOperations.AccountSetUp(Parameters.Key, False, False) And EditionAllowed(Parameters.Key)) Then
		
		SelectedForm = "AccountSetupWizard";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

Function EditionAllowed(Account) Export
	Result = AccessRight("Edit", Metadata.Catalogs.EmailAccounts);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		Result = Result And ModuleAccessManagement.EditionAllowed(Account);
	EndIf;
	Return Result;
EndFunction

Function AccountPermissions(Account = Undefined) Export
	
	Result = New Map;
	
	QueryText = 
	"SELECT
	|	EmailAccounts.ProtocolForIncomingMail AS Protocol,
	|	EmailAccounts.IncomingMailServer AS Server,
	|	EmailAccounts.IncomingMailServerPort AS Port,
	|	EmailAccounts.Ref
	|INTO MailServers
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.ProtocolForIncomingMail <> """"
	|	AND EmailAccounts.DeletionMark = FALSE
	|	AND EmailAccounts.UseForReceiving = TRUE
	|	AND EmailAccounts.IncomingMailServer <> """"
	|	AND EmailAccounts.IncomingMailServerPort > 0
	|
	|UNION ALL
	|
	|SELECT
	|	""SMTP"",
	|	EmailAccounts.OutgoingMailServer,
	|	EmailAccounts.OutgoingMailServerPort,
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND EmailAccounts.UseForSending = TRUE
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND EmailAccounts.OutgoingMailServerPort > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MailServers.Ref AS Ref,
	|	MailServers.Protocol AS Protocol,
	|	MailServers.Server AS Server,
	|	MailServers.Port AS Port
	|FROM
	|	MailServers AS MailServers
	|WHERE
	|	&Ref = UNDEFINED
	|
	|GROUP BY
	|	MailServers.Protocol,
	|	MailServers.Server,
	|	MailServers.Port,
	|	MailServers.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	MailServers.Ref,
	|	MailServers.Protocol,
	|	MailServers.Server,
	|	MailServers.Port
	|FROM
	|	MailServers AS MailServers
	|WHERE
	|	MailServers.Ref = &Ref
	|
	|GROUP BY
	|	MailServers.Protocol,
	|	MailServers.Server,
	|	MailServers.Port,
	|	MailServers.Ref
	|TOTALS BY
	|	Ref";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Account);
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Accounts_ = Query.Execute().Select(QueryResultIteration.ByGroups);
	While Accounts_.Next() Do
		Permissions = New Array;
		AccountSettings1 = Accounts_.Select();
		While AccountSettings1.Next() Do
			Permissions.Add(
				ModuleSafeModeManager.PermissionToUseInternetResource(
					AccountSettings1.Protocol,
					AccountSettings1.Server,
					AccountSettings1.Port,
					NStr("en = 'Email.';")));
		EndDo;
		Result.Insert(Accounts_.Ref, Permissions);
	EndDo;
	
	Return Result;
	
EndFunction

Function DefineDomainMailServersNames(Domain)
	
	Result = New Array;
	
	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	ApplicationStartupParameters.ExecutionEncoding = "OEM";
	
	DNSServerAddresses = EmailOperationsInternal.DNSServerAddresses();
	DNSServerAddresses.Insert(0, ""); // Default server.
	
	CommandsStrings = New Array;
	
	For Each ServerAddress In DNSServerAddresses Do
		CommandTemplate = "nslookup -type=mx %1 %2";
		CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandTemplate, Domain, ServerAddress);
		CommandsStrings.Add(CommandString);
		
		RunResult = FileSystem.StartApplication(CommandString, ApplicationStartupParameters);
		If RunResult.ReturnCode = 0 Then
			Response = RunResult.OutputStream + Chars.LF + RunResult.ErrorStream;
			
			For Each String In StrSplit(Response, Chars.LF, False) Do
				If StrFind(String, "mail exchanger") > 0 Then
					StringParts1 = StrSplit(String, " ", False);
					ServerName  = StringParts1[StringParts1.UBound()];
					ServerName  = StrConcat(StrSplit(ServerName, ".", False), ".");
					Result.Add(ServerName);
				EndIf;
			EndDo;
		EndIf;
		
		If ValueIsFilled(Result) Then
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function DefineAccountSettings(Val Email, Password, ForSending, ForReceiving) Export
	
	Email = EmailOperationsInternal.StringIntoPunycode(Email);
	SetPrivilegedMode(True);
	FoundSettings = ConnectionSettingsByEmailAddress(Email, Password);
	SetPrivilegedMode(False);
	
	Return PickMailSettings(Email, Password, ForSending, ForReceiving, FoundSettings.Profile);
	
EndFunction

// Returns:
//  Structure:
//   * Profile - InternetMailProfile
//   * MailServerName - String
//   * AuthorizationSettings - See Catalogs.InternetServicesAuthorizationSettings.SettingsAuthorizationInternetService
//
Function ConnectionSettingsByEmailAddress(Email, Password = "") Export
	
	AddressStructure1 = CommonClientServer.URIStructure(Email);
	MailDomain = AddressStructure1.Host;
	
	FoundSettings = Undefined;
	MailServerName = "";
	
	MailServersSettings = MailServersSettings();
	If MailServersSettings <> Undefined Then
		FoundSettings = MailServersSettings[AddressStructure1.Host];
		MailServerName = AddressStructure1.Host;
		If TypeOf(FoundSettings) = Type("String") Then
			MailServerName = FoundSettings;
			FoundSettings = MailServersSettings[FoundSettings];
		EndIf;

		If FoundSettings = Undefined Then
			ServerNames = DefineDomainMailServersNames(AddressStructure1.Host);
			For Each ServerName In ServerNames Do
				DomainLevels = StrSplit(ServerName, ".", False);
				While DomainLevels.Count() > 1 Do
					Host = StrConcat(DomainLevels, ".");
				
					FoundSettings = MailServersSettings[Host];
					MailServerName = Host;
					
					If TypeOf(FoundSettings) = Type("String") Then
						MailServerName = FoundSettings;
						FoundSettings = MailServersSettings[FoundSettings];
					EndIf;
					
					If TypeOf(FoundSettings) = Type("Map") Then
						Break;
					Else
						FoundSettings = Undefined;
					EndIf;
					
					DomainLevels.Delete(0);
				EndDo;
				
				If TypeOf(FoundSettings) = Type("Map") Then
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If FoundSettings = Undefined Then
		FoundSettings = New Map;
	EndIf;
	
	Profile = Undefined;
	If ValueIsFilled(FoundSettings) Then
		Profile = GenerateProfile(FoundSettings, Email, Password);
	EndIf;
	
	SetPrivilegedMode(True);
	AuthorizationSettings = ServerAuthorizationSettings(FoundSettings, MailServerName, MailDomain);
	SetPrivilegedMode(False);
	
	Result = New Structure;
	Result.Insert("Profile", Profile);
	Result.Insert("MailServerName", MailServerName);
	Result.Insert("AuthorizationSettings", AuthorizationSettings);
	
	Return Result;
	
EndFunction

// Returns:
//   See Catalogs.InternetServicesAuthorizationSettings.SettingsAuthorizationInternetService
//
Function ServerAuthorizationSettings(FoundSettings, MailServerName, MailDomain)
	
	AuthorizationSettings = Catalogs.InternetServicesAuthorizationSettings.SettingsAuthorizationInternetService(MailServerName, MailDomain);
	SettingsFromClassifier = FoundSettings["OAuth"];
	
	If Not ValueIsFilled(SettingsFromClassifier) Then
		Return AuthorizationSettings;
	EndIf;
	
	AuthorizationSettings.InternetServiceName = MailServerName;
	AuthorizationSettings.DataOwner = MailDomain;
	
	If Not ValueIsFilled(AuthorizationSettings.AuthorizationAddress) Then
		AuthorizationSettings.AuthorizationAddress = SettingsFromClassifier["AuthorizationURI"];
	EndIf;
	
	If Not ValueIsFilled(AuthorizationSettings.KeyReceiptAddress) Then
		AuthorizationSettings.KeyReceiptAddress = SettingsFromClassifier["TokenExchangeURI"];
	EndIf;
	
	AuthorizationSettings.PermissionsToRequest = SettingsFromClassifier["MailScope"];
	If TypeOf(AuthorizationSettings.PermissionsToRequest) = Type("Array") Then
		AuthorizationSettings.PermissionsToRequest = StrConcat(AuthorizationSettings.PermissionsToRequest, " ");
	EndIf;
	
	AuthorizationSettings.UsePKCEAuthenticationKey = SettingsFromClassifier["UsePKCE"];
	AuthorizationSettings.UseApplicationPassword = SettingsFromClassifier["UseClientSecret"];
	
	AdditionalAuthorizationParameters = SettingsFromClassifier["AuthorizationParameters"];
	If ValueIsFilled(AdditionalAuthorizationParameters) Then
		ParametersDescriptions = New Array;
		For Each Item In AdditionalAuthorizationParameters Do
			ParametersDescriptions.Add(Item.Key + "=" + XMLString(Item.Value));
		EndDo;
		AuthorizationSettings.AdditionalAuthorizationParameters = StrConcat(ParametersDescriptions, " ");
	EndIf;
	
	AdditionalTokenReceiptParameters = SettingsFromClassifier["TokenExchangeParameters"];
	If ValueIsFilled(AdditionalTokenReceiptParameters) Then
		ParametersDescriptions = New Array;
		For Each Item In AdditionalTokenReceiptParameters Do
			ParametersDescriptions.Add(Item.Key + "=" + XMLString(Item.Value));
		EndDo;
		AuthorizationSettings.AdditionalTokenReceiptParameters = StrConcat(ParametersDescriptions, " ");
	EndIf;
	
	AuthorizationSettings.ExplanationByRedirectAddress = StringFunctions.FormattedString(
		StringForCurrentLanguage(SettingsFromClassifier["RedirectURIDescription"]));
		
	AuthorizationSettings.ExplanationByApplicationID = StringFunctions.FormattedString(
		StringForCurrentLanguage(SettingsFromClassifier["ClientIDDescription"]));
		
	AuthorizationSettings.ExplanationApplicationPassword = StringFunctions.FormattedString(
		StringForCurrentLanguage(SettingsFromClassifier["ClientSecretDescription"]));
	
	AuthorizationSettings.AdditionalNote = StringFunctions.FormattedString(
		StringForCurrentLanguage(SettingsFromClassifier["AdditionalDescription"]));
	
	AuthorizationSettings.AliasRedirectAddresses = StringForCurrentLanguage(SettingsFromClassifier["RedirectURICaption"]);
	AuthorizationSettings.ApplicationIDAlias = StringForCurrentLanguage(SettingsFromClassifier["ClientIDCaption"]);
	AuthorizationSettings.ApplicationPasswordAlias = StringForCurrentLanguage(SettingsFromClassifier["ClientSecretCaption"]);
	
	AuthorizationSettings.RedirectAddressDefault = SettingsFromClassifier["DefaultRedirectURI"];
	AuthorizationSettings.RedirectionAddressWebClient = SettingsFromClassifier["WebClientRedirectURI"];
	
	AuthorizationSettings.DeviceRegistrationAddress = SettingsFromClassifier["DeviceAuthorizationURI"];
	
	Return AuthorizationSettings;
	
EndFunction

Function StringForCurrentLanguage(Multilingual_String)
	
	If TypeOf(Multilingual_String) <> Type("Map") Then
		Return Multilingual_String;
	EndIf;
	
	If Not ValueIsFilled(Multilingual_String) Then
		Return "";
	EndIf;
	
	LanguagesCodes = New Structure;
	LanguagesCodes.Insert(CurrentLanguage().LanguageCode);
	LanguagesCodes.Insert(Common.DefaultLanguageCode());
	LanguagesCodes.Insert("en");
	
	For Each Item In LanguagesCodes Do
		LanguageCode = Item.Key;
		If ValueIsFilled(Multilingual_String[LanguageCode]) Then
			Return Multilingual_String[LanguageCode];
		EndIf;
	EndDo;
	
	Return "";
	
EndFunction

Function MailServersSettings()
	
	MailServersSettings = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		
		AddressOfFileWithSettings = EmailOperationsInternal.AddressOfFileWithSettings();
		ImportedFile = ModuleNetworkDownload.DownloadFileAtServer(AddressOfFileWithSettings);
		
		If ImportedFile.Status Then
			JSONReader = New JSONReader();
			JSONReader.OpenFile(ImportedFile.Path);
			MailServersSettings = ReadJSON(JSONReader, True);
			JSONReader.Close();
		EndIf;
	EndIf;
	
	Return MailServersSettings;
	
EndFunction

Function PickMailSettings(Email, Password, ForSending, ForReceiving, Profile = Undefined)
	
	SettingsReceived = Profile <> Undefined;
	
	FoundSMTPProfile = ?(SettingsReceived And ValueIsFilled(Profile.SMTPServerAddress), Profile, Undefined);
	FoundIMAPProfile = ?(SettingsReceived And ValueIsFilled(Profile.IMAPServerAddress), Profile, Undefined);
	FoundPOPProfile = ?(SettingsReceived And FoundIMAPProfile = Undefined And ValueIsFilled(Profile.POP3ServerAddress), Profile, Undefined);
	
	If Not SettingsReceived Then
		If ForSending Then
			FoundSMTPProfile = DefineSMTPSettings(Email, Password);
		EndIf;
		
		If ForSending Or ForReceiving Then
			FoundIMAPProfile = DefineIMAPSettings(Email, Password);
			If FoundIMAPProfile = Undefined And ForReceiving Then
				FoundPOPProfile = DefinePOPSettings(Email, Password);
			EndIf;
		EndIf;
	EndIf;
	
	Result = New Structure;
	
	If FoundIMAPProfile <> Undefined Then
		Result.Insert("UsernameForReceivingEmails", FoundIMAPProfile.IMAPUser);
		Result.Insert("PasswordForReceivingEmails", FoundIMAPProfile.IMAPPassword);
		Result.Insert("Protocol", "IMAP");
		Result.Insert("IncomingMailServer", FoundIMAPProfile.IMAPServerAddress);
		Result.Insert("IncomingMailServerPort", FoundIMAPProfile.IMAPPort);
		Result.Insert("UseSecureConnectionForIncomingMail", FoundIMAPProfile.IMAPUseSSL);
	EndIf;
	
	If FoundPOPProfile <> Undefined Then
		Result.Insert("UsernameForReceivingEmails", FoundPOPProfile.User);
		Result.Insert("PasswordForReceivingEmails", FoundPOPProfile.Password);
		Result.Insert("Protocol", "POP");
		Result.Insert("IncomingMailServer", FoundPOPProfile.POP3ServerAddress);
		Result.Insert("IncomingMailServerPort", FoundPOPProfile.POP3Port);
		Result.Insert("UseSecureConnectionForIncomingMail", FoundPOPProfile.POP3UseSSL);
	EndIf;
	
	If FoundSMTPProfile <> Undefined Then
		Result.Insert("UsernameToSendMail", FoundSMTPProfile.SMTPUser);
		Result.Insert("PasswordForSendingEmails", FoundSMTPProfile.SMTPPassword);
		Result.Insert("OutgoingMailServer", FoundSMTPProfile.SMTPServerAddress);
		Result.Insert("OutgoingMailServerPort", FoundSMTPProfile.SMTPPort);
		Result.Insert("UseSecureConnectionForOutgoingMail", FoundSMTPProfile.SMTPUseSSL);
	EndIf;
	
	Result.Insert("ForReceiving", FoundIMAPProfile <> Undefined Or FoundPOPProfile <> Undefined);
	Result.Insert("ForSending", FoundSMTPProfile <> Undefined);
	Result.Insert("SettingsCheckCompleted", Not SettingsReceived);
	
	Return Result;
	
EndFunction

Function GenerateProfile(KnownSettings, Email, Password = "")
	
	AddressStructure1 = CommonClientServer.URIStructure(Email);
	
	Profile = New InternetMailProfile;
	For Each Connection In KnownSettings["Services"] Do
		If Connection["Protocol"] = "SMTP" And Not ValueIsFilled(Profile.SMTPServerAddress) Then
			If Connection["SMTPAuthentication"] = "Enabled" Or Connection["SMTPAuthentication"] = Undefined Then
				Profile.SMTPUser = ?(Connection["LoginFormat"] = "username", AddressStructure1.Login, Email);
				Profile.SMTPPassword = Password;
			EndIf;
			Profile.SMTPUseSSL = Connection["Encryption"] = "SSL";
			Profile.SMTPServerAddress = Connection["Host"];
			Profile.SMTPPort = Connection["Port"];
			Profile.POP3BeforeSMTP = Connection["SMTPAuthentication"] = "POPBeforeSMTP";
		EndIf;
		
		If Connection["Protocol"] = "IMAP" And Not ValueIsFilled(Profile.IMAPServerAddress) Then
			Profile.IMAPUseSSL = Connection["Encryption"] = "SSL";
			Profile.IMAPUser = ?(Connection["LoginFormat"] = "username", AddressStructure1.Login, Email);
			Profile.IMAPPassword = Password;
			Profile.IMAPServerAddress = Connection["Host"];
			Profile.IMAPPort = Connection["Port"];
		EndIf;

		If Connection["Protocol"] = "POP3" And Not ValueIsFilled(Profile.POP3ServerAddress) Then
			Profile.POP3UseSSL = Connection["Encryption"] = "SSL";
			Profile.User = ?(Connection["LoginFormat"] = "username", AddressStructure1.Login, Email);
			Profile.Password = Password;
			Profile.POP3ServerAddress = Connection["Host"];
			Profile.POP3Port = Connection["Port"];
		EndIf;
	EndDo;
	
	Return Profile;
	
EndFunction
	
Function DefinePOPSettings(Email, Password)
	For Each Profile In POPProfiles(Email, Password) Do
		ServerMessage = TestConnectionToIncomingMailServer(Profile, InternetMailProtocol.POP3);
		
		If AuthenticationError(ServerMessage) Then
			For Each UserName In UsernameOptions(Email) Do
				SetUserName(Profile, UserName);
				ServerMessage = TestConnectionToIncomingMailServer(Profile, InternetMailProtocol.POP3);
				If Not AuthenticationError(ServerMessage) Then
					Break;
				EndIf;
			EndDo;
			If AuthenticationError(ServerMessage) Then
				Break;
			EndIf;
		EndIf;
		
		If Connected1(ServerMessage) Then
			Return Profile;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function DefineIMAPSettings(Email, Password)
	For Each Profile In IMAPProfiles(Email, Password) Do
		ServerMessage = TestConnectionToIncomingMailServer(Profile, InternetMailProtocol.IMAP);
		
		If AuthenticationError(ServerMessage) Then
			For Each UserName In UsernameOptions(Email) Do
				SetUserName(Profile, UserName);
				ServerMessage = TestConnectionToIncomingMailServer(Profile, InternetMailProtocol.IMAP);
				If Not AuthenticationError(ServerMessage) Then
					Break;
				EndIf;
			EndDo;
			If AuthenticationError(ServerMessage) Then
				Break;
			EndIf;
		EndIf;
		
		If Connected1(ServerMessage) Then
			Return Profile;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function DefineSMTPSettings(Email, Password)
	For Each Profile In SMTPProfiles(Email, Password) Do
		ServerMessage = TestConnectionToOutgoingMailServer(Profile, Email);
		
		If AuthenticationError(ServerMessage) Then
			For Each UserName In UsernameOptions(Email) Do
				SetUserName(Profile, UserName);
				ServerMessage = TestConnectionToOutgoingMailServer(Profile, Email);
				If Not AuthenticationError(ServerMessage) Then
					Break;
				EndIf;
			EndDo;
			If AuthenticationError(ServerMessage) Then
				Break;
			EndIf;
		EndIf;
		
		If Connected1(ServerMessage) Then
			Return Profile;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function POPProfiles(Email, Password)
	Result = New Array;
	ProfileSettings = DefaultSettings(Email, Password);
	
	For Each ConnectionSettingsOption In POPServerConnectionSettingsOptions(Email) Do
		Profile = New InternetMailProfile;
		FillPropertyValues(ProfileSettings, ConnectionSettingsOption);
		FillPropertyValues(Profile, InternetMailProfile(ProfileSettings, InternetMailProtocol.POP3));
		Result.Add(Profile);
	EndDo;
	
	Return Result;
EndFunction

Function IMAPProfiles(Email, Password)
	Result = New Array;
	ProfileSettings = DefaultSettings(Email, Password);
	
	For Each ConnectionSettingsOption In IMAPServerConnectionSettingsOptions(Email) Do
		FillPropertyValues(ProfileSettings, ConnectionSettingsOption);
		Profile = InternetMailProfile(ProfileSettings, InternetMailProtocol.IMAP);
		Result.Add(Profile);
	EndDo;
	
	Return Result;
EndFunction

Function SMTPProfiles(Email, Password)
	Result = New Array;
	ProfileSettings = DefaultSettings(Email, Password);
	
	For Each ConnectionSettingsOption In SMTPServerConnectionSettingsOptions(Email) Do
		Profile = New InternetMailProfile;
		FillPropertyValues(ProfileSettings, ConnectionSettingsOption);
		FillPropertyValues(Profile, InternetMailProfile(ProfileSettings, InternetMailProtocol.SMTP));
		Result.Add(Profile);
	EndDo;
	
	Return Result;
EndFunction

Function AuthenticationError(ServerMessage)
	Return StrFind(Lower(ServerMessage), "auth") > 0
		Or StrFind(Lower(ServerMessage), "password") > 0
		Or StrFind(Lower(ServerMessage), "credentials") > 0;
EndFunction

Function Connected1(ServerMessage)
	Return IsBlankString(ServerMessage);
EndFunction

Procedure SetUserName(Profile, UserName)
	If Not IsBlankString(Profile.User) Then
		Profile.User = UserName;
	EndIf;
	If Not IsBlankString(Profile.IMAPUser) Then
		Profile.IMAPUser = UserName;
	EndIf;
	If Not IsBlankString(Profile.SMTPUser) Then
		Profile.SMTPUser = UserName;
	EndIf;
EndProcedure

Function DefaultSettings(Email, Password)
	
	Position = StrFind(Email, "@");
	ServerNameInAccount = Mid(Email, Position + 1);
	
	Settings = New Structure;
	
	Settings.Insert("UsernameForReceivingEmails", Email);
	Settings.Insert("UsernameToSendMail", Email);
	
	Settings.Insert("PasswordForSendingEmails", Password);
	Settings.Insert("PasswordForReceivingEmails", Password);
	
	Settings.Insert("Protocol", "POP");
	Settings.Insert("IncomingMailServer", "pop." + ServerNameInAccount);
	Settings.Insert("IncomingMailServerPort", 995);
	Settings.Insert("UseSecureConnectionForIncomingMail", True);
	
	Settings.Insert("OutgoingMailServer", "smtp." + ServerNameInAccount);
	Settings.Insert("OutgoingMailServerPort", 465);
	Settings.Insert("UseSecureConnectionForOutgoingMail", True);
	Settings.Insert("SignInBeforeSendingRequired", False);
	
	Settings.Insert("ServerTimeout", 30);
	Settings.Insert("KeepEmailCopiesOnServer", True);
	Settings.Insert("DeleteEmailsFromServerAfter", 0);
	
	Return Settings;
	
EndFunction

Function TestConnectionToIncomingMailServer(Profile, Protocol)
	
	InternetMail = New InternetMail;
	
	ErrorText = "";
	Try
		InternetMail.Logon(Profile, Protocol);
	Except
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
	InternetMail.Logoff();
	
	If Protocol = InternetMailProtocol.POP3 Then
		TextForLog = StringFunctionsClientServer.SubstituteParametersToString("%1:%2%3 (%4)" + Chars.LF + "%5",
			Profile.POP3ServerAddress,
			Profile.POP3Port,
			?(Profile.POP3UseSSL, "/SSL", ""),
			Profile.User,
			?(IsBlankString(ErrorText), NStr("en = 'OK';"), ErrorText));
	Else
		TextForLog = StringFunctionsClientServer.SubstituteParametersToString("%1:%2%3 (%4)" + Chars.LF + "%5",
			Profile.IMAPServerAddress,
			Profile.IMAPPort,
			?(Profile.IMAPUseSSL, "/SSL", ""),
			Profile.IMAPUser,
			?(IsBlankString(ErrorText), NStr("en = 'OK';"), ErrorText));
	EndIf;
	
	WriteLogEvent(MailServerConnectionTestEvent(), 
		EventLogLevel.Information, , , TextForLog);
	
	Return ErrorText;
	
EndFunction

Function TestConnectionToOutgoingMailServer(Profile, Email)
	
	Subject = NStr("en = 'Test message from 1C:Enterprise';");
	Body = NStr("en = 'This message is sent by 1C:Enterprise.';");
	EmailSenderName = NStr("en = '1C:Enterprise';");
	
	MailMessage = New InternetMailMessage;
	MailMessage.Subject = Subject;
	
	Recipient = MailMessage.To.Add(Email);
	Recipient.DisplayName = EmailSenderName;
	
	MailMessage.SenderName = EmailSenderName;
	MailMessage.From.DisplayName = EmailSenderName;
	MailMessage.From.Address = Email;
	
	Text = MailMessage.Texts.Add(Body);
	Text.TextType = InternetMailTextType.PlainText;

	InternetMail = New InternetMail;
	
	ErrorText = "";
	Try
		InternetMail.Logon(Profile);
		InternetMail.Send(MailMessage);
	Except
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
	InternetMail.Logoff();
	
	TextForLog = StringFunctionsClientServer.SubstituteParametersToString("%1:%2%3 (%4)" + Chars.LF + "%5",
		Profile.SMTPServerAddress,
		Profile.SMTPPort,
		?(Profile.SMTPUseSSL, "/SSL", ""),
		Profile.SMTPUser,
		?(IsBlankString(ErrorText), NStr("en = 'OK';"), ErrorText));
		
	WriteLogEvent(MailServerConnectionTestEvent(), 
		EventLogLevel.Information, , , TextForLog);
	
	Return ErrorText;
	
EndFunction

Function InternetMailProfile(ProfileSettings, Protocol)
	
	ForReceiving = Protocol <> InternetMailProtocol.SMTP;
	
	Profile = New InternetMailProfile;
	If ForReceiving Or ProfileSettings.SignInBeforeSendingRequired Then
		If Protocol = InternetMailProtocol.IMAP Then
			Profile.IMAPServerAddress = ProfileSettings.IncomingMailServer;
			Profile.IMAPUseSSL = ProfileSettings.UseSecureConnectionForIncomingMail;
			Profile.IMAPPassword = ProfileSettings.PasswordForReceivingEmails;
			Profile.IMAPUser = ProfileSettings.UsernameForReceivingEmails;
			Profile.IMAPPort = ProfileSettings.IncomingMailServerPort;
		Else
			Profile.POP3ServerAddress = ProfileSettings.IncomingMailServer;
			Profile.POP3UseSSL = ProfileSettings.UseSecureConnectionForIncomingMail;
			Profile.Password = ProfileSettings.PasswordForReceivingEmails;
			Profile.User = ProfileSettings.UsernameForReceivingEmails;
			Profile.POP3Port = ProfileSettings.IncomingMailServerPort;
		EndIf;
	EndIf;
	
	If Not ForReceiving Then
		Profile.POP3BeforeSMTP = ProfileSettings.SignInBeforeSendingRequired;
		Profile.SMTPServerAddress = ProfileSettings.OutgoingMailServer;
		Profile.SMTPUseSSL = ProfileSettings.UseSecureConnectionForOutgoingMail;
		Profile.SMTPPassword = ProfileSettings.PasswordForSendingEmails;
		Profile.SMTPUser = ProfileSettings.UsernameToSendMail;
		Profile.SMTPPort = ProfileSettings.OutgoingMailServerPort;
	EndIf;
	
	Profile.Timeout = ProfileSettings.ServerTimeout;
	
	Return Profile;
	
EndFunction

Function UsernameOptions(Email)
	
	Position = StrFind(Email, "@");
	UserNameInAccount = Left(Email, Position - 1);
	
	Result = New Array;
	Result.Add(UserNameInAccount);
	
	Return Result;
	
EndFunction

Function IMAPServerConnectionSettingsOptions(Email) Export
	
	Position = StrFind(Email, "@");
	ServerNameInAccount = Mid(Email, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("IncomingMailServer");
	Result.Columns.Add("IncomingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForIncomingMail");
	
	// icloud.com
	If ServerNameInAccount = "icloud.com" Then
		SettingsMode = Result.Add();
		SettingsMode.IncomingMailServer = "imap.mail.me.com";
		SettingsMode.IncomingMailServerPort = 993;
		SettingsMode.UseSecureConnectionForIncomingMail = True;
		Return Result;
	EndIf;
	
	// outlook.com
	If ServerNameInAccount = "outlook.com" Then
		SettingsMode = Result.Add();
		SettingsMode.IncomingMailServer = "outlook.office365.com";
		SettingsMode.IncomingMailServerPort = 993;
		SettingsMode.UseSecureConnectionForIncomingMail = True;
		Return Result;
	EndIf;

	// Standard settings suitable for Gmail, Yandex, and Mail.ru accounts.
	// The server name is prefixed with "imap." and the connection is secured.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "imap." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 993;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name with the "mail." prefix, secure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 993;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name without the "imap." prefix, secure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 993;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name with the "imap." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "imap." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 143;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	// Server name with the "mail." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 143;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	// Server name without the "imap." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 143;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	Return Result;
	
EndFunction

Function POPServerConnectionSettingsOptions(Email)
	
	Position = StrFind(Email, "@");
	ServerNameInAccount = Mid(Email, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("IncomingMailServer");
	Result.Columns.Add("IncomingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForIncomingMail");
	
	// Standard settings suitable for Gmail, Yandex, and Mail.ru accounts.
	// The server name is prefixed with "pop." and the connection is secured.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "pop." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 995;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name with the "pop3." prefix, secure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "pop3." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 995;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name with the "mail." prefix, secure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 995;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name without a prefix, secure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 995;
	SettingsMode.UseSecureConnectionForIncomingMail = True;
	
	// Server name with the "pop." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "pop." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 110;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	// Server name with the "pop3." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "pop3." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 110;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	// Server name with the "mail." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 110;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	// Server name without a prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.IncomingMailServer = ServerNameInAccount;
	SettingsMode.IncomingMailServerPort = 110;
	SettingsMode.UseSecureConnectionForIncomingMail = False;
	
	Return Result;
	
EndFunction

Function SMTPServerConnectionSettingsOptions(Email) Export
	
	Position = StrFind(Email, "@");
	ServerNameInAccount = Mid(Email, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("OutgoingMailServer");
	Result.Columns.Add("OutgoingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForOutgoingMail");
	
	// icloud.com
	If ServerNameInAccount = "icloud.com" Then
		SettingsMode = Result.Add();
		SettingsMode.OutgoingMailServer = "smtp.mail.me.com";
		SettingsMode.OutgoingMailServerPort = 587;
		SettingsMode.UseSecureConnectionForOutgoingMail = False;
		Return Result;
	EndIf;
	
	// outlook.com
	If ServerNameInAccount = "outlook.com" Then
		SettingsMode = Result.Add();
		SettingsMode.OutgoingMailServer = "smtp-mail.outlook.com";
		SettingsMode.OutgoingMailServerPort = 587;
		SettingsMode.UseSecureConnectionForOutgoingMail = False;
		Return Result;
	EndIf;
	
	// Standard settings suitable for Gmail, Yandex, and Mail.ru accounts.
	// The server name is prefixed with "smtp.", the connection is secured, and the port is 465.
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 465;
	SettingsMode.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with the "mail." prefix, secure connection, port 465.
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 465;
	SettingsMode.UseSecureConnectionForOutgoingMail = True;
	
	// Server name without a prefix, secure connection, port 465.
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 465;
	SettingsMode.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with the "smtp." prefix, secure connection (STARTTLS), port 587
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 587;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	// Server name with the "mail." prefix, secure connection (STARTTLS), port 587
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 587;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	// Server name without a prefix, secure connection (STARTTLS), port 587
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 587;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	// Server name with the "smtp." prefix, insecure connection
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 25;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	// Server name with the "mail." prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 25;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	// Server name without a prefix, insecure connection.
	SettingsMode = Result.Add();
	SettingsMode.OutgoingMailServer = ServerNameInAccount;
	SettingsMode.OutgoingMailServerPort = 25;
	SettingsMode.UseSecureConnectionForOutgoingMail = False;
	
	Return Result;
	
EndFunction

Function AttributesRequiringPasswordToChange() Export
	
	Attributes = New Array;
	Attributes.Add("UseForSending");
	Attributes.Add("UseForReceiving");
	Attributes.Add("IncomingMailServer");
	Attributes.Add("OutgoingMailServer");
	Attributes.Add("AccountOwner");
	Attributes.Add("UseSecureConnectionForIncomingMail");
	Attributes.Add("UseSecureConnectionForOutgoingMail");
	Attributes.Add("User");
	Attributes.Add("SMTPUser");
	Attributes.Add("AuthorizationRequiredOnSendEmails");
	Attributes.Add("UserName");
	
	Return StrConcat(Attributes, ",");
	
EndFunction

Function PasswordCheckIsRequired(Ref, AttributesValuesBeforeWrite) Export
	
	If Ref.IsEmpty() Then
		Return False;
	EndIf;
	
	AttributesList = AttributesRequiringPasswordToChange();
	WrittenAttributeValues = Common.ObjectAttributesValues(Ref, AttributesList);
	
	Result = ValueIsFilled(WrittenAttributeValues.AccountOwner);
	If Result Then
		BeforeChange = New Structure(AttributesList);
		FillPropertyValues(BeforeChange, WrittenAttributeValues);
		AfterChange = New Structure(AttributesList);
		FillPropertyValues(AfterChange, AttributesValuesBeforeWrite);
		Result = Common.ValueToXMLString(BeforeChange) <> Common.ValueToXMLString(AfterChange);
	EndIf;
	
	Return Result;
	
EndFunction

Function CheckCanConnectToMailServer(Val Account, Val IncomingMail) Export
	
	SetSafeModeDisabled(True);
	Profile = EmailOperationsInternal.InternetMailProfile(Account, IncomingMail);
	
	If IncomingMail Then
		Protocol = InternetMailProtocol.POP3;
		If Common.ObjectAttributeValue(Account, "ProtocolForIncomingMail") = "IMAP" Then
			Protocol = InternetMailProtocol.IMAP;
		EndIf;
		ErrorText = TestConnectionToIncomingMailServer(Profile, Protocol);
	Else 
		Address = Common.ObjectAttributeValue(Account, "Email");
		ErrorText = TestConnectionToOutgoingMailServer(Profile, Address);
	EndIf;
	
	Return ErrorText;
	
EndFunction

Function ValidateAccountSettings(Account) Export
	
	AccountSettings1 = Common.ObjectAttributesValues(Account,
		"UseForSending,UseForReceiving,Email");
	
	OutgoingMailProfile = Undefined;
	IncomingMailProfile = Undefined;

	SetSafeModeDisabled(True);
	If AccountSettings1.UseForSending Then
		OutgoingMailProfile = EmailOperationsInternal.InternetMailProfile(Account, False);
	EndIf;
	If AccountSettings1.UseForReceiving Then
		IncomingMailProfile = EmailOperationsInternal.InternetMailProfile(Account, True);
	EndIf;
	SetSafeModeDisabled(False);
	
	Email = EmailOperationsInternal.StringIntoPunycode(AccountSettings1.Email);
	
	Return CheckProfilesSettings(OutgoingMailProfile, IncomingMailProfile, Email);
	
EndFunction

Function CheckProfilesSettings(OutgoingMailProfile, IncomingMailProfile, Val Email) Export
	
	Email = EmailOperationsInternal.StringIntoPunycode(Email);
	MessageText = New Array;
	TechnicalDetails = New Array;
	ExecutedChecks = New Array;
	
	AuthenticationError = False;
	OutgoingMailSettingsCheckRequired = False;
	IncomingMailSettingsCheckRequired = False;
	
	ErrorsTexts = New Array;
	
	If OutgoingMailProfile <> Undefined Then
		ErrorText = TestConnectionToOutgoingMailServer(OutgoingMailProfile, Email);
		If ValueIsFilled(ErrorText) Then
			ErrorsTexts.Add(ErrorText);
			TechnicalDetails.Add(ErrorText);
			
			AuthenticationError = AuthenticationError(ErrorText);
			If AuthenticationError(ErrorText) Then
				MessageText.Add(NStr("en = 'Cannot send test mail: authorization failed.';"));
			Else
				MessageText.Add(NStr("en = 'Sending the test mail failed.';"));
				OutgoingMailSettingsCheckRequired = True;
				
				If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
					ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
					ConnectionDiagnostics = ModuleNetworkDownload.ConnectionDiagnostics(OutgoingMailProfile.SMTPServerAddress);
					TechnicalDetails.Add(ConnectionDiagnostics.DiagnosticsLog);
				EndIf;
			EndIf;
		Else
			ExecutedChecks.Add("- " + NStr("en = 'Sending the test mail succeeded.';"));
		EndIf;
		
	EndIf;
	
	If IncomingMailProfile <> Undefined Then
		Protocol = ?(ValueIsFilled(IncomingMailProfile.IMAPServerAddress), InternetMailProtocol.IMAP, InternetMailProtocol.POP3);
		ErrorText = TestConnectionToIncomingMailServer(IncomingMailProfile, Protocol);
		If ValueIsFilled(ErrorText) Then
			ErrorsTexts.Add(ErrorText);
			TechnicalDetails.Add(ErrorText);
			
			AuthenticationError = AuthenticationError(ErrorText);
			If AuthenticationError(ErrorText) Then
				MessageText.Add(NStr("en = 'Cannot connect to the incoming mail server: authorization failed.';"));
			Else
				MessageText.Add(NStr("en = 'Connection to the incoming mail server failed.';"));
				IncomingMailSettingsCheckRequired = True;
				
				If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
					ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
					IncomingMailServer = ?(Protocol = InternetMailProtocol.IMAP, IncomingMailProfile.IMAPServerAddress, IncomingMailProfile.POP3ServerAddress);
					ConnectionDiagnostics = ModuleNetworkDownload.ConnectionDiagnostics(IncomingMailServer);
					TechnicalDetails.Add(ConnectionDiagnostics.DiagnosticsLog);
				EndIf;
			EndIf;
		Else
			ExecutedChecks.Add("- " + NStr("en = 'Connection to the incoming mail server succeeded.';"));
		EndIf;
		
	EndIf;
	
	TechnicalDetails.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Email address: %1';"), Email));
	
	TechnicalDetails.Add(SettingsDescription(OutgoingMailProfile, IncomingMailProfile));
	
	TechnicalDetails.Add(ApplicationInfo());
	
	ConnectionErrors = "";
	
	If ValueIsFilled(MessageText) Then
		AddressParts = StrSplit(Email, "@", True);
		DomainName_SSLy = AddressParts[AddressParts.UBound()];
		MessageText = StrConcat(MessageText, Chars.LF);
		
		TechnicalDetails = StrConcat(TechnicalDetails, Chars.LF + Chars.LF);
		
		Recommendations = New Array;
		If AuthenticationError Then
			Recommendations.Add(NStr("en = 'Ensure that the username, password, and authentication method are correct.';"));
		EndIf;
		If OutgoingMailSettingsCheckRequired Then
			Recommendations.Add(NStr("en = 'Ensure that the outgoing mail server settings are correct.';"));
		EndIf;
		If IncomingMailSettingsCheckRequired Then
			Recommendations.Add(NStr("en = 'Ensure that the incoming mail server settings are correct.';"));
		EndIf;
		If OutgoingMailSettingsCheckRequired Or IncomingMailSettingsCheckRequired Then
			Recommendations.Add(NStr("en = 'Contact the network administrator.';"));
		EndIf;
		
		Recommendations = StrConcat(Recommendations, Chars.LF);
		
		ConnectionErrors = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1
			|
			|%2
			|
			|Contact the %3 server administrator.
			|
			|============================
			|
			|Details to provide to technical support:
			|
			|%4';"), MessageText, Recommendations, DomainName_SSLy, TechnicalDetails);
	EndIf;
	
	ExecutedChecks = StrConcat(ExecutedChecks, Chars.LF);
	
	If ValueIsFilled(ConnectionErrors) Then
		WriteLogEvent(NStr("en = 'Validating email account settings';", Common.DefaultLanguageCode()),
			EventLogLevel.Warning, , , ConnectionErrors);
	EndIf;
	
	Result = New Structure;
	Result.Insert("ExecutedChecks", ExecutedChecks);
	Result.Insert("ConnectionErrors", ConnectionErrors);
	Result.Insert("ErrorsTexts", ErrorsTexts);
	
	Return Result;
	
EndFunction

Function SettingsDescription(OutgoingMailProfile, IncomingMailProfile)
	
	SettingsDescription = New Array;
	
	IMAPPropertyList = "IMAPServerAddress,IMAPPort,IMAPUseSSL,IMAPUser";
	POP3PropertyList = "POP3ServerAddress,POP3Port,POP3UseSSL,User";
	SMTPPropertyList = "SMTPServerAddress,SMTPPort,SMTPUseSSL,SMTPUser,POP3BeforeSMTP";
	
	Profile = New InternetMailProfile();
	If IncomingMailProfile <> Undefined Then
		FillPropertyValues(Profile, IncomingMailProfile);
		Profile.IMAPPort = IncomingMailProfile.IMAPPort;
	EndIf;
	
	If OutgoingMailProfile <> Undefined Then
		FillPropertyValues(Profile, OutgoingMailProfile, , POP3PropertyList);
		Profile.IMAPPort = OutgoingMailProfile.IMAPPort;
	EndIf;
	
	If ValueIsFilled(Profile.SMTPServerAddress) Then
		Settings = New Array;
		For Each PropertyName In StrSplit(SMTPPropertyList, ",", False) Do
			Settings.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1=""%2""';"), PropertyName, Profile[PropertyName]));
		EndDo;
		SettingsDescription.Add(StrConcat(Settings, ", "));
	EndIf;

	If ValueIsFilled(Profile.IMAPServerAddress) Then
		Settings = New Array;
		For Each PropertyName In StrSplit(IMAPPropertyList, ",", False) Do
			Settings.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1=""%2""';"), PropertyName, Profile[PropertyName]));
		EndDo;
		SettingsDescription.Add(StrConcat(Settings, ", "));
	EndIf;
	
	If ValueIsFilled(Profile.POP3ServerAddress) Then
		Settings = New Array;
		For Each PropertyName In StrSplit(POP3PropertyList, ",", False) Do
			Settings.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1=""%2""';"), PropertyName, Profile[PropertyName]));
		EndDo;
		SettingsDescription.Add(StrConcat(Settings, ", "));
	EndIf;	
	
	Return StrConcat(SettingsDescription, Chars.LF);
	
EndFunction

Function ApplicationInfo()
	
	SystemInfo = New SystemInfo;
	
	Result = New Array;
	Result.Add(StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Operating system: %1';"), SystemInfo.OSVersion));
	Result.Add(StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '1C:Enterprise platform: %1 (%2)';"),
		SystemInfo.AppVersion, SystemInfo.PlatformType));
	Result.Add(StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '1C:Enterprise application: %1 (%2)';"), 
		?(ValueIsFilled(Metadata.Synonym), Metadata.Synonym, Metadata.Name), Metadata.Version));
		
	Result.Add(Chars.LF + NStr("en = 'Extensions:';"));
	
	SetPrivilegedMode(True);
	For Each Extension In ConfigurationExtensions.Get() Do
		If Extension.Active Then
			Result.Add(StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2)';"),
				?(ValueIsFilled(Extension.Synonym), Extension.Synonym, Extension.Name), Extension.Version));
		EndIf;
	EndDo;
	SetPrivilegedMode(False);
	
	Return StrConcat(Result, Chars.LF);
	
EndFunction

Function MailServerConnectionTestEvent()
	Return NStr("en = 'Mail server connection test';", Common.DefaultLanguageCode());
EndFunction

#EndRegion

#EndIf