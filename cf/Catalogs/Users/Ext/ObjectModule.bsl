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

#If Not MobileStandaloneServer Then

#Region Variables

// 
Var IsNew;
Var IBUserProcessingParameters; // Parameters to be populated when processing a user.

#EndRegion

// 
//
// 
//
// 
//   
//      
//      
//      
//      
//      
//      
//
//   
//                            
//                            
//                            
//                          
//                            
//                            
//                            
//                            
//
//   
//                                  
//                                        
//
//   
//   
//      
//      
// 
//   
//      
//      
//      
//
//      
//      
//      
//      
//
//   
//   
//
//   
//   
//      
 //         
//      
//          
//   
//
//   
//
// 
//   
//   
//   
//   
//
// 

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	UsersInternal.UserObjectBeforeWrite(ThisObject, IBUserProcessingParameters);
	// ACC:75-on
	
	// ACC:75-off - The check "DataExchange.Import" should run after the registers are locked.
	If Common.FileInfobase() Then
		UsersInternal.LockRegistersBeforeWritingToFileInformationSystem(False);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	If DataExchange.Load And IBUserProcessingParameters <> Undefined Then
		UsersInternal.EndIBUserProcessing(
			ThisObject, IBUserProcessingParameters);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		And ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.UserGroups");
		LockItem.SetValue("Ref", AdditionalProperties.NewUserGroup);
		Block.Lock();
		
		GroupObject1 = AdditionalProperties.NewUserGroup.GetObject(); // CatalogObject.UserGroups
		GroupObject1.Content.Add().User = Ref;
		GroupObject1.Write();
	EndIf;
	
	// Updating the content of "All users" auto group.
	ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
	UsersInternal.UpdateUserGroupCompositionUsage(Ref, ChangesInComposition);
	UsersInternal.UpdateAllUsersGroupComposition(Ref, ChangesInComposition);
	
	UsersInternal.EndIBUserProcessing(ThisObject,
		IBUserProcessingParameters);
	
	UsersInternal.AfterUserGroupsUpdate(ChangesInComposition);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	UsersInternal.UserObjectBeforeDelete(ThisObject);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	UsersInternal.UpdateGroupsCompositionBeforeDeleteUserOrGroup(Ref);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	Properties = New Structure("ContactInformation");
	FillPropertyValues(Properties, ThisObject);
	If Properties.ContactInformation <> Undefined Then
		Properties.ContactInformation.Clear();
	EndIf;
	
	Comment = "";
	
EndProcedure

#EndRegion

#EndIf

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf