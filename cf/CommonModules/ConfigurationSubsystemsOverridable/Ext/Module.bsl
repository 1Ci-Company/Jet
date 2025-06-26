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

// Defines the list of configuration and library modules that provide
// the following general details: name, version, update handler list,
// and its dependence on other libraries.
//
// See the composition of the mandatory procedures of such a module in the InfobaseUpdateSSL common module
// (Public area).
// There is no need to add
// the InfobaseUpdateSSL module of the Library of standard subsystems to the SubsystemModules array.
//
// Parameters:
//  SubsystemsModules - Array - names of the common server library modules and the configurations.
//                             For example, CRLInfobaseUpdate - library,
//                                       EAInfobaseUpdate - configuration.
//                    
Procedure OnAddSubsystems(SubsystemsModules) Export
	
	SubsystemsModules.Add("InfobaseUpdateJet");
	
EndProcedure

#EndRegion
