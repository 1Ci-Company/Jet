///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Generates a list of configuration reports available for the current user.
// Use it in all queries to the table
// of the "ReportsOptions" catalog as a filter for the "Report" attribute.
//
// Returns:
//   Array - References to the reports the current user can access.
//            See the item type in Catalogs.ReportsOptions.Attributes.Report.
//
Function AvailableReports(CheckFunctionalOptions = True) Export
	
	Result = New Array;
	FullReportsNames = New Array;
	
	AllAttachedByDefault = Undefined;
	For Each ReportMetadata In Metadata.Reports Do
		If Not AccessRight("View", ReportMetadata)
			Or Not ReportsOptions.ReportAttachedToStorage(ReportMetadata, AllAttachedByDefault) Then
			Continue;
		EndIf;
		If CheckFunctionalOptions
			And Not Common.MetadataObjectAvailableByFunctionalOptions(ReportMetadata) Then
			Continue;
		EndIf;
		FullReportsNames.Add(ReportMetadata.FullName());
	EndDo;
	
	ReportsIDs = Common.MetadataObjectIDs(FullReportsNames);
	For Each ReportID In ReportsIDs Do
		Result.Add(ReportID.Value);
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Generates a list of configuration report option unavailable for the current user by functional options.
// Use in all queries to the table
// of the "ReportsOptions" catalog as an excluding filter for the "PredefinedOption" attribute.
//
// Returns:
//   Array - Report options disabled by functional options.
//            
//            See the item type in CatalogRef.PredefinedReportOptions,
//            
//            CatalogRef.PredefinedReportOptionsOfExtensions.
//
Function DIsabledApplicationOptions() Export
	
	Return New FixedArray(ReportsOptions.DisabledReportOptions());
	
EndFunction

#EndRegion

#Region Private

// Generates a tree of subsystems available for the current user.
//
// Returns:
//   FixedStructure:
//    * Tree - ValueTree:
//       ** SectionReference  - CatalogRef.MetadataObjectIDs - Section reference.
//       ** Ref        - CatalogRef.MetadataObjectIDs - Subsystem reference.
//       ** Name           - String - Subsystem name.
//       ** FullName     - String - Full subsystem name.
//       ** Presentation - String - Subsystem presentation.
//       ** Priority     - String - Subsystem priority.
//    * List - FixedArray of CatalogRef.MetadataObjectIDs
//
Function CurrentUserSubsystems() Export
	
	IDTypes = New Array;
	IDTypes.Add(Type("CatalogRef.MetadataObjectIDs"));
	IDTypes.Add(Type("CatalogRef.ExtensionObjectIDs"));
	
	Result = New ValueTree;
	Result.Columns.Add("Ref",              New TypeDescription(IDTypes));
	Result.Columns.Add("Name",                 ReportsOptions.TypesDetailsString(150));
	Result.Columns.Add("FullName",           ReportsOptions.TypesDetailsString(510));
	Result.Columns.Add("Presentation",       ReportsOptions.TypesDetailsString(150));
	Result.Columns.Add("SectionReference",        New TypeDescription(IDTypes));
	Result.Columns.Add("SectionFullName",     ReportsOptions.TypesDetailsString(510));
	Result.Columns.Add("Priority",           ReportsOptions.TypesDetailsString(100));
	Result.Columns.Add("FullPresentation", ReportsOptions.TypesDetailsString(300));
	
	RootRow = Result.Rows.Add();
	RootRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
	RootRow.Presentation = NStr("en = 'All sections';");
	
	FullSubsystemsNames = New Array;
	TreeRowsFullNames = New Map;
	
	HomePageID = ReportsOptionsClientServer.HomePageID();
	SectionsList = ReportsOptions.SectionsList();
	
	Priority = 0;
	For Each ListItem In SectionsList Do
		
		MetadataSection = ListItem.Value;
		If Not (TypeOf(MetadataSection) = Type("MetadataObject") And StrStartsWith(MetadataSection.FullName(), "Subsystem"))
			And Not (TypeOf(MetadataSection) = Type("String") And MetadataSection = HomePageID) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid section values in %1 procedure.';"), 
				"ReportsOptionsOverridable.DefineSectionsWithReportOptions");
			
		EndIf;
		
		If ValueIsFilled(ListItem.Presentation) Then
			TitleTemplate1 = ListItem.Presentation;
		Else
			TitleTemplate1 = NStr("en = '%1 section reports';");
		EndIf;
		
		IsHomePage = (MetadataSection = HomePageID);
		
		If Not IsHomePage
			And (Not AccessRight("View", MetadataSection)
				Or Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataSection)) Then
			Continue; // The subsystem is unavailable by functional options or rights.
		EndIf;
		
		TreeRow = RootRow.Rows.Add();
		If IsHomePage Then
			TreeRow.Name           = HomePageID;
			TreeRow.FullName     = HomePageID;
			TreeRow.Presentation = StandardSubsystemsServer.HomePagePresentation();
		Else
			TreeRow.Name           = MetadataSection.Name;
			TreeRow.FullName     = MetadataSection.FullName();
			TreeRow.Presentation = MetadataSection.Presentation();
		EndIf;
		
		FullSubsystemsNames.Add(TreeRow.FullName);
		
		If TreeRowsFullNames[TreeRow.FullName] = Undefined Then
			TreeRowsFullNames.Insert(TreeRow.FullName, TreeRow);
		Else
			TreeRowsFullNames.Insert(TreeRow.FullName, True); // A search in the tree is required.
		EndIf;
		
		TreeRow.SectionFullName = TreeRow.FullName;
		TreeRow.FullPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			TitleTemplate1,
			TreeRow.Presentation);
		
		Priority = Priority + 1;
		TreeRow.Priority = Format(Priority, "ND=4; NFD=0; NLZ=; NG=0");
		If Not IsHomePage Then
			AddCurrentUserSubsystems(TreeRow, MetadataSection, FullSubsystemsNames, TreeRowsFullNames);
		EndIf;
	EndDo;
	
	List = New Array;
	SubsystemsReferences = Common.MetadataObjectIDs(FullSubsystemsNames);
	For Each KeyAndValue In SubsystemsReferences Do
		TreeRow = TreeRowsFullNames[KeyAndValue.Key];
		If TreeRow = True Then // A search in the tree is required.
			FoundItems = Result.Rows.FindRows(New Structure("FullName", KeyAndValue.Key), True);
			For Each TreeRow In FoundItems Do
				TreeRow.Ref = KeyAndValue.Value;
				TreeRow.SectionReference = SubsystemsReferences[TreeRow.SectionFullName];
			EndDo;
		Else
			TreeRow.Ref = KeyAndValue.Value;
			TreeRow.SectionReference = SubsystemsReferences[TreeRow.SectionFullName];
		EndIf;
		List.Add(KeyAndValue.Value);
	EndDo;
	
	TreeRowsFullNames.Clear();
	
	Results = New Structure;
	Results.Insert("Tree", Result);
	Results.Insert("List", New FixedArray(List));
	
	Return New FixedStructure(Results);
	
EndFunction

Procedure AddCurrentUserSubsystems(ParentLevelRow, ParentMetadata, FullSubsystemsNames, TreeRowsFullNames)
	
	ParentPriority = ParentLevelRow.Priority;
	
	Priority = 0;
	For Each SubsystemMetadata1 In ParentMetadata.Subsystems Do
		Priority = Priority + 1;
		
		If Not SubsystemMetadata1.IncludeInCommandInterface
			Or Not AccessRight("View", SubsystemMetadata1)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(SubsystemMetadata1) Then
			Continue; // The subsystem is unavailable by functional options or rights.
		EndIf;
		
		TreeRow = ParentLevelRow.Rows.Add();
		TreeRow.Name           = SubsystemMetadata1.Name;
		TreeRow.FullName     = SubsystemMetadata1.FullName();
		TreeRow.Presentation = SubsystemMetadata1.Presentation();
		FullSubsystemsNames.Add(TreeRow.FullName);
		If TreeRowsFullNames[TreeRow.FullName] = Undefined Then
			TreeRowsFullNames.Insert(TreeRow.FullName, TreeRow);
		Else
			TreeRowsFullNames.Insert(TreeRow.FullName, True); // A search in the tree is required.
		EndIf;
		TreeRow.SectionFullName = ParentLevelRow.SectionFullName;
		
		If StrLen(ParentPriority) > 12 Then
			TreeRow.FullPresentation = ParentLevelRow.Presentation + ": " + TreeRow.Presentation;
		Else
			TreeRow.FullPresentation = TreeRow.Presentation;
		EndIf;
		TreeRow.Priority = ParentPriority + Format(Priority, "ND=4; NFD=0; NLZ=; NG=0");
		
		AddCurrentUserSubsystems(TreeRow, SubsystemMetadata1, FullSubsystemsNames, TreeRowsFullNames);
	EndDo;
	
EndProcedure

Function SubsystemsPresentations() Export
	
	IDTypes = New Array;
	IDTypes.Add(Type("CatalogRef.MetadataObjectIDs"));
	IDTypes.Add(Type("CatalogRef.ExtensionObjectIDs"));
	
	Result = New ValueTable;
	Result.Columns.Add("Ref",        New TypeDescription(IDTypes));
	Result.Columns.Add("FullName",     ReportsOptions.TypesDetailsString(510));
	Result.Columns.Add("Presentation", ReportsOptions.TypesDetailsString(150));
	
	If Common.IsMainLanguage() Then
		Return Result;
	EndIf;
	
	HomePageID = ReportsOptionsClientServer.HomePageID();
	For Each Section In ReportsOptions.SectionsList() Do
		
		MetadataSection = Section.Value;
		If Not (TypeOf(MetadataSection) = Type("MetadataObject") And StrStartsWith(MetadataSection.FullName(), "Subsystem"))
			And Not (TypeOf(MetadataSection) = Type("String") And MetadataSection = HomePageID) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid section values in %1 procedure.';"),
				"ReportsOptionsOverridable.DefineSectionsWithReportOptions");
		EndIf;
		
		IsHomePage = (MetadataSection = HomePageID);
		If Not IsHomePage
			And (Not AccessRight("View", MetadataSection)
				Or Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataSection)) Then
			Continue; 
		EndIf;
		
		TableRow = Result.Add();
		If IsHomePage Then
			TableRow.FullName     = HomePageID;
			TableRow.Presentation = StandardSubsystemsServer.HomePagePresentation();
		Else
			TableRow.FullName     = MetadataSection.FullName();
			TableRow.Presentation = MetadataSection.Presentation();
		EndIf;
		TableRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
		If Not IsHomePage Then
			AddSubsystems(Result, MetadataSection);
		EndIf;
	EndDo;
	
	Result.Indexes.Add("FullName");
	
	SubsystemsReferences = Common.MetadataObjectIDs(Result.UnloadColumn("FullName"), False);
	For Each SubsystemRef1 In SubsystemsReferences Do
		TableRow = Result.Find(SubsystemRef1.Key, "FullName");
		If TableRow <> Undefined Then 
			TableRow.Ref = SubsystemRef1.Value;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure AddSubsystems(SubsystemsTable, ParentMetadata)

	For Each SubsystemMetadata1 In ParentMetadata.Subsystems Do
		
		If Not SubsystemMetadata1.IncludeInCommandInterface
			Or Not AccessRight("View", SubsystemMetadata1)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(SubsystemMetadata1) Then
			Continue; 
		EndIf;
		
		TableRow = SubsystemsTable.Add();
		TableRow.FullName = SubsystemMetadata1.FullName();
		TableRow.Presentation = SubsystemMetadata1.Presentation();
		TableRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
		AddSubsystems(SubsystemsTable, SubsystemMetadata1);
	EndDo;
	
EndProcedure

// Returns True if the user has the right to read report options.
Function ReadRight1() Export
	
	Return AccessRight("Read", Metadata.Catalogs.ReportsOptions);
	
EndFunction

// Returns True if the user has the right to save report options.
Function InsertRight1() Export
	
	Return AccessRight("SaveUserData", Metadata)
		And AccessRight("Insert", Metadata.Catalogs.ReportsOptions);
	
EndFunction

// Subsystem parameters cached during the update
// .
//
// Returns:
//   Structure:
//     * FunctionalOptionsTable - ValueTable - Association between functional options and predefined report options::
//       ** Report - CatalogRef.MetadataObjectIDs
//       ** PredefinedOption - CatalogRef.PredefinedReportsOptions
//       ** FunctionalOptionName - String
//     * ReportsWithSettings - Array of CatalogRef.MetadataObjectIDs - Reports whose
//          object module contains procedures for integrating with the common report form.
// 
Function Parameters() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	FullSubsystemName = ReportsOptionsClientServer.FullSubsystemName();
	Parameters = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName);
	If Parameters = Undefined Then
		ReportsOptions.ConfigurationCommonDataNonexclusiveUpdate(New Structure("SeparatedHandlers"));
		Parameters = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName);
	EndIf;
	
	If ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName);
		If ExtensionParameters = Undefined Then
			ReportsOptions.OnFillAllExtensionParameters();
			ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName);
		EndIf;
		
		If ExtensionParameters <> Undefined Then
			CommonClientServer.SupplementArray(Parameters.ReportsWithSettings, ExtensionParameters.ReportsWithSettings);
			CommonClientServer.SupplementTable(ExtensionParameters.FunctionalOptionsTable, Parameters.FunctionalOptionsTable);
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDetermineReportsWithSettings(Parameters.ReportsWithSettings);
	EndIf;

	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Parameters;
	
EndFunction

#EndRegion
