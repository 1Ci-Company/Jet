///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Fills access kinds used in access restrictions.
// Note: the Users and ExternalUsers access kinds are predefined,
// but you can remove them from the AccessKinds list if you do not need them for access restriction.
//
// Parameters:
//  AccessKinds - ValueTable:
//   * Name                    - String - Name used in the description of the built-in access group profiles and RLS text.
//                                       
//   * Presentation          - String - presents an access kind in profiles and access groups.
//   * ValuesType            - Type    - an access value reference type,
//                                       for example, Type("CatalogRef.Products").
//   * ValuesGroupsType       - Type    - an access value group reference type,
//                                       for example, Type("CatalogRef.ProductsAccessGroups").
//   * MultipleValuesGroups - Boolean - True indicates that you can
//                                       select multiple value groups (Products access group) for an access value (Products).
//
// Example:
//  1. To set access rights by companies:
//  AccessKind = AccessKinds.Add(),
//  AccessKind.Name = "Companies",
//  AccessKind.Presentation = NStr("en = 'Companies'");
//  AccessKind.ValueType = Type("CatalogRef.Companies");
//
//  2.To set access rights by partner groups:
//  AccessKind = AccessKinds.Add(),
//  AccessKind.Name = "PartnersGroups",
//  AccessKind.Presentation = NStr("en = 'Partner groups'");
//  AccessKind.ValueType = Type("CatalogRef.Partners");
//  AccessKind.ValuesGroupsType = Type("CatalogRef.PartnersAccessGroups");
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	
	
EndProcedure

// Allows specifying the metadata objects for which the data access restriction logic is set.
// In manager modules of the specified lists, there is a handler procedure, for example:
//
//Parameters:
//Constraint - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
////
//
//	
//  Procedure OnFillAccessRestriction(Constraint) Export
//  Restriction.Text =
//  "AllowReadEdit
//  |WHERE
//  |	ValueAllowed(Company)
//	
//|	AND ValueAllowed(Counterparty)";
//
// EndProcedure
// The data access restriction logic can also be overridden in the procedure
// "AccessManagementOverridable.OnFillAccessRestriction".
//
// Parameters:
//  Lists - Map of KeyAndValue - lists with access restriction:
//             * Key     - MetadataObject - a list with access restriction.
//             * Value - Boolean - True - a restriction text in the manager module.
//                                   False - a restriction text in the overridable
//                          module in the OnFillAccessRestriction procedure.
//
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	
	
EndProcedure

// Fills descriptions of built-in access group profiles and
// overrides update parameters of profiles and access groups.
//
// To generate the procedure code automatically, it is recommended that you use the developer
// tools from the Access management subsystem.
//
// Parameters:
//  ProfilesDetails - Array of See AccessManagement.NewAccessGroupProfileDescription,
//                               See AccessManagement.NewDescriptionOfTheAccessGroupProfilesFolder
//  ParametersOfUpdate - Structure:
//   * UpdateModifiedProfiles - Boolean - an initial value is True.
//   * DenyProfilesChange - Boolean - an initial value is True.
//        If False, the built-in profiles can not only be viewed but also edited.
//   * UpdatingAccessGroups     - Boolean - an initial value is True.
//   * UpdatingAccessGroupsWithObsoleteSettings - Boolean - the initial value is False.
//       If True, the value settings made by the administrator for
//       he access kind, which was deleted from the profile, are also deleted from the access groups.
//
// Example:
//  ProfileDetails = AccessManagement.NewAccessGroupProfileDescription();
//  ProfileDetails.Name = "Manager";
//  ProfileDetails.ID = "75fa0ecb-98aa-11df-b54f-e0cb4ed5f655";
//  ProfileDetails.Description = NStr("en = 'Sales representative'", Common.DefaultLanguageCode());
//  ProfileDetails.Roles.Add("StartWebClient");
//  ProfileDetails.Roles.Add("StartThinClient");
//  ProfileDetails.Roles.Add("BasicAccessSSL");
//  ProfileDetails.Roles.Add("Subsystem_Sales");
//  ProfileDetails.Roles.Add("AddEditCustomersDocuments");
//  ProfileDetails.Roles.Add("ViewReportPurchaseLedger");
//  ProfileDetails.Roles.Add(ProfileDetails);
//
//  FolderDetails = AccessManagement.NewAccessGroupsProfilesFolderDetails();
//  FolderDetails.Name = "AdditionalProfiles";
//  FolderDetails.ID = "69a066e7-ce81-11eb-881c-b06ebfbf08c7";
//  FolderDetails.Description = NStr("en = 'Additional profiles'", Common.DefaultLanguageCode());
//  ProfilesDetails.Add(FolderDetails);
//
//  ProfileDetails = AccessManagement.NewAccessGroupProfileDescription();
//  ProfileDetails.Parent = "AdditionalProfiles";
//  ProfileDetails.ID = "70179f20-2315-11e6-9bff-d850e648b60c";
//  ProfileDetails.Description = NStr("en = 'Editing, sending by email, saving a print form to a file (additionally)'",
//  	Common.DefaultLanguageCode());
//  ProfileDetails.Details = NStr("en = It is additionally assigned to those users who must be able to edit
//  	|before printing, sending by email and saving print forms to a file.'");
//  ProfileDetails.Roles.Add("PrintFormsEdit");
//  ProfilesDetails.Add(ProfileDetails);
//
Procedure OnFillSuppliedAccessGroupProfiles(ProfilesDetails, ParametersOfUpdate) Export
	
	
	
EndProcedure

// Fills in non-standard access right dependencies of the subordinate object on the main object. For example, access right dependencies
// of the PerformerTask task on the Job business process.
//
// Access right dependencies are used in the standard access restriction template for Object access kind.
// 1. By default, when reading a subordinate object,
//    the right to read a leading object is checked and
//    if there are no restrictions to read the leading object.
// 2. When adding, changing, or deleting a subordinate object,
//    a right to edit a leading object is checked and
//    whether there are no restrictions to edit the leading object.
//
// Only one reassignment is allowed, compared to the standard dependencies, that is,
// in clause 2, checking the right to change the leading object can be replaced with checking
// the right to read the leading object.
//
// Parameters:
//  RightsDependencies - ValueTable:
//   * LeadingTable     - String - for example, Metadata.BusinessProcesses.Job.FullName().
//   * SubordinateTable - String - for example, Metadata.Tasks.PerformerTask.FullName().
//
Procedure OnFillAccessRightsDependencies(RightsDependencies) Export
	
	
	
EndProcedure

// Fills in details of available rights assigned to the objects of the specified types.
//
// Parameters:
//  AvailableRights - ValueTable:
//   * RightsOwner - String - a full name of the access value table.
//
//   * Name          - String - a right ID, for example, FoldersChange. The RightsManagement right
//                  must be defined for the "Access rights" common form for setting rights.
//                  RightsManagement is a right to change rights by the owner checked
//                  upon opening CommonForm.ObjectsRightsSettings.
//
//   * Title    - String - a right title, for example, in the ObjectsRightsSettings form:
//                  "Folders.
//                  |сhange".
//
//   * ToolTip    - String - a tooltip of the right title.
//                  For example, "Add, change, and mark folders for deletion".
//
//   * InitialValue - Boolean - an initial value of right check box when adding a new row
//                  in the "Access rights" form.
//
//   * RequiredRights1 - Array of String - names of rights required by this right.
//                  For example, the ChangeFiles right is required by the AddFiles right.
//
//   * ReadInTables - Array of String - full names of tables, for which this right means the Read right.
//                  You can use the "*" character that means "for all other tables",
//                  as the Read right depends only on the Read right, only the "*" character makes sense
//                  (it is required for access restriction templates).
//
//   * ChangeInTables - Array of String - full names of tables, for which this right means the Update right.
//                  You can use an asterisk (*), which means "for all other tables"
//                  (it is required for access restriction templates).
//
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export
	
EndProcedure

// Defines the user interface type used for access setup.
//
// Parameters:
//  SimplifiedInterface - Boolean - the initial value is False.
//
Procedure OnDefineAccessSettingInterface(SimplifiedInterface) Export
	SimplifiedInterface = True;
EndProcedure

// Fills in the usage of access kinds depending on functional options of the configuration,
// for example, UseProductsAccessGroups.
//
// Parameters:
//  AccessKind    - String - an access kind name specified in the OnFillAccessKinds procedure.
//  Use - Boolean - an initial value is True.
// 
Procedure OnFillAccessKindUsage(AccessKind, Use) Export
	
	
	
EndProcedure

// Allows to override the restriction specified in the metadata object manager module.
//
// Parameters:
//  List - MetadataObject - a list, for which restriction text return is required.
//                              Specify False for the list
//                              in the OnFillListsWithAccessRestriction procedure, otherwise, a call will not be made.
//
//  Restriction - Structure:
//    * Text                             - String - access restriction for users.
//                                          If the string is blank, access is granted.
//    * TextForExternalUsers1      - String - access restriction for external users.
//                                          If the string is blank, access denied.
//    * ByOwnerWithoutSavingAccessKeys - Undefined - define automatically.
//                                        - Boolean - if False, always write access keys.
//                                          If True, do not write access keys,
//                                          but use owner access keys (the restriction
//                                          must be by the owner object only).
//   * ByOwnerWithoutSavingAccessKeysForExternalUsers - Undefined, Boolean - the same
//                                          as the ByOwnerWithoutSavingAccessKeys parameter.
//
Procedure OnFillAccessRestriction(List, Restriction) Export
	
	
	
EndProcedure

// Fills in the list of access kinds used to set metadata object right restrictions.
// If the list of access kinds is not filled, the Access rights report displays incorrect data.
//
// Only access kinds explicitly used in access restriction templates must be filled.
// Access kinds used in access value sets can be obtained from the current
// state of the AccessValuesSets information register.
//
//  To generate the procedure code automatically, it is recommended that you use the developer
// tools from the Access management subsystem.
//
// Parameters:
//  LongDesc     - String - a multiline string of the <Table>.<Right>.<AccessKind>[.Object table] format.
//                 For example "Document.PurchaseInvoice.Read.Companies",
//                           "Document.PurchaseInvoice.Read.Counterparties",
//                           "Document.PurchaseInvoice.Change.Companies",
//                           "Document.PurchaseInvoice.Change.Counterparties",
//                           "Document.Emails.Read.Object.Document.Emails",
//                           "Document.Emails.Change.Object.Document.Emails",
//                           "Document.Files.Read.Object.Catalog.FilesFolders",
//                           "Document.Files.Read.Object.Document.Email",
//                           "Document.Files.Change.Object.Catalog.FilesFolders",
//                           "Document.Files.Change.Object.Document.Email".
//                 The Object access kind is predefined as a literal. This access kind is used in
//                 access restriction templates as a reference to another object used for
//                 applying restrictions to the current object of the table.
//                 When the Object access kind is set, set table types
//                 used for this access kind. That means to enumerate types
//                 corresponding to the field used in the access restriction template
//                 together with the "Object" access kind. When listing types by the Object access kind,
//                 list only those field types that
//                 the InformationRegisters.AccessValuesSets.Object field has, other types are excess.
// 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	
	
EndProcedure

// Allows to overwrite dependent access value sets of other objects.
//
// Called from the 
//  AccessManagementInternal.WriteAccessValuesSets,
//  AccessManagementInternal.WriteDependentAccessValuesSets procedures.
//
// Parameters:
//  Ref - AnyRef - a reference to the object the access value sets are written for.
//
//  RefsToDependentObjects - Array - an array of items of the CatalogRef, DocumentRef type and so on.
//                 Contains references to objects with dependent access value sets.
//                 Initial value is a blank array.
//
Procedure OnChangeAccessValuesSets(Ref, RefsToDependentObjects) Export
	
	
	
EndProcedure

#EndRegion