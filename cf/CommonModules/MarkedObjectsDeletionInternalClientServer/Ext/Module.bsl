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

// Parameters:
//   List - DynamicList
//   FilterValue - Boolean
//
Procedure SetFilterByDeletionMark(List, FilterValue) Export
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False,,,
		FilterValue);
EndProcedure

#EndRegion