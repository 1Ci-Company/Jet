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

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.Notes.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.UsingNotes";
	NewName  = "Role.AddEditNotes";
	Common.AddRenaming(Total, "2.3.3.11", OldName, NewName, Library);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Edit", Metadata.Catalogs.Notes)
		Or Not GetFunctionalOption("UseNotes")
		Or ModuleToDoListServer.UserTaskDisabled("UserNotes") Then
		Return;
	EndIf;
	
	// The procedure can be called only if the "To-do list" subsystem is integrated.
	// Therefore, don't check if the subsystem is integrated.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.Notes.FullName());
	
	NumberOfNotes = NumberOfNotes();
	
	For Each Section In Sections Do
		NoteID = "UserNotes" + StrReplace(Section.FullName(), ".", "");
		ToDoItem = ToDoList.Add();
		ToDoItem.Id = NoteID;
		ToDoItem.HasToDoItems      = NumberOfNotes > 0;
		ToDoItem.Presentation = NStr("en = 'My notes';");
		ToDoItem.Count    = NumberOfNotes;
		ToDoItem.Form         = "Catalog.Notes.Form.AllNotes";
		ToDoItem.Owner      = Section;
	EndDo;
	
EndProcedure

// See UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates.
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesArray) Export
	
	If TypeOf(Source) = Type("CatalogRef.Notes") Then
		AttributesArray.Clear();
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.Notes, True);
	
EndProcedure

// Parameters:
//  TypesToExclude - See DuplicateObjectsDetection.TypesToExcludeFromPossibleDuplicates
//
Procedure OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude) Export

	TypesToExclude.Add(Type("CatalogRef.Notes"));

EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	If AccessRight("InteractiveInsert", Metadata.Catalogs.Notes) Then
		Command = Commands.Add();
		Command.Kind = "Organizer";
		Command.Presentation = NStr("en = 'Create note';");
		Command.FunctionalOptions = "UseNotes";
		Command.Picture = PictureLib.Note;
		Command.ParameterType = Metadata.DefinedTypes.NotesSubject.Type;
		Command.WriteMode = "NotWrite";
		Command.Order = 50;
		Command.Handler = "UserNotesInternalClient.CreateSubjectNote"; 
		Command.MultipleChoice = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetClearNotesDeletionMark(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	DeletionMark = Source.DeletionMark;
	If Not DeletionMark And Not Source.AdditionalProperties.Property("DeletionMarkCleared") Then
		Return;
	EndIf;
	
	QueryText =
	"SELECT
	|	Notes.Ref AS Ref
	|FROM
	|	Catalog.Notes AS Notes
	|WHERE
	|	Notes.DeletionMark = &DeletionMark
	|	AND &OwnerField = &Owner";
	
	OwnerField = "SubjectOf";
	If TypeOf(Source) = Type("CatalogObject.Users") 
		And (DeletionMark Or Source.AdditionalProperties.Property("DeletionMarkCleared")) Then
			OwnerField = "Author";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&OwnerField", "Notes." + OwnerField);
	
	Query = New Query(QueryText);
	Query.SetParameter("Owner", Source.Ref);
	Query.SetParameter("DeletionMark", Not DeletionMark);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.Notes");
	LockItem.SetValue(OwnerField, Source.Ref);
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block.Lock();
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			NoteObject = Selection.Ref.GetObject();
			NoteObject.SetDeletionMark(DeletionMark, False);
			NoteObject.AdditionalProperties.Insert("NoteDeletionMark", True);
			Try
				NoteObject.Write();
			Except
				ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Notes.Change deletion mark';", Common.DefaultLanguageCode()),
					EventLogLevel.Error, NoteObject.Metadata(), NoteObject.Ref, ErrorText);
			EndTry;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds a flag of changing object deletion mark.
Procedure SetDeletionMarkChangeStatus(Source) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Source.DeletionMark Then
		DeletionMarkByRef = Common.ObjectAttributeValue(Source.Ref, "DeletionMark");
		If DeletionMarkByRef = True Then
			Source.AdditionalProperties.Insert("DeletionMarkCleared");
		EndIf;
	EndIf;
	
EndProcedure

Function NumberOfNotes()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(CatalogNotes.Ref) AS Count
	|FROM
	|	Catalog.Notes AS CatalogNotes
	|WHERE
	|	CatalogNotes.Author = &User
	|		AND NOT CatalogNotes.DeletionMark";
	
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute().Unload();
	Return QueryResult[0].Count;
	
EndFunction

#EndRegion
