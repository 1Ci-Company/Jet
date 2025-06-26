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

Function ExceptionsOfSearchForRefsAllowingDeletion() Export
	Return MarkedObjectsDeletionInternal.ExceptionsOfSearchForRefsAllowingDeletionInternal();
EndFunction

Function CheckIfObjectsToDeleteAreUsed() Export
	Result = New Structure("Value, TimeStamp");
	Result.Value = Constants.CheckIfObjectsToDeleteAreUsed.Get();
	Result.TimeStamp = CurrentUniversalDateInMilliseconds();
	Return Result;
EndFunction

#EndRegion

#Region Private

// Returns:
//   String
//
Function RegisterMasterDimensions(Val FullRegisterName) Export
	
	RegisterMetadata = Common.MetadataObjectByFullName(FullRegisterName);
	Result = New Array;
	Container = New Structure("Dimensions", New Array);
	FillPropertyValues(Container, RegisterMetadata);
	Dimensions = Container.Dimensions; // MetadataObjectCollection
	For Each Dimension In Dimensions Do
		Container = New Structure("Master", False);
		FillPropertyValues(Container, Dimension);
		If Container.Master Then
			Result.Add(Dimension.Name);
		EndIf;
	EndDo;
	Return StrConcat(Result, ",");
	
EndFunction

#EndRegion