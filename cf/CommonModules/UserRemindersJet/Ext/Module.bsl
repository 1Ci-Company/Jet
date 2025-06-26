
#Region Public

// StandardSubsystems.ToDoList

// Integration with the StandardSubsystems.ToDoList subsystem.
// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - a value table with the following columns:
//    * Id - String - an internal to-do ID used by the To-do list algorithm.
//    * HasToDoItems      - Boolean - if True, the to-do item is displayed in the user's to-do list.
//    * Important        - Boolean - if True, the to-do item is highlighted in red.
//    * Presentation - String - To-do item presentation displayed to a user.
//    * Count    - Number  - a number related to a to-do item; it is displayed in a to-do item's title.
//    * Form         - String - Full path to the form that is displayed by clicking on the
//                               to-do item hyperlink in the "To-do list" panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner      - String, MetadataObject - String ID of the to-do item that is the owner of the current to-do item,
//                      or a subsystem metadata object.
//    * ToolTip     - String - Tooltip text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserReminders) Then
		Return;
	EndIf;
	
	RemindersCount = RemindersCount();
	
	RowID = "UserReminders";
	
	ToDoRow					= ToDoList.Add();
	ToDoRow.ID				= RowID;
	ToDoRow.HasToDoItems	= (RemindersCount > 0);
	ToDoRow.Presentation	= NStr("en = 'My reminders'");
	ToDoRow.Owner			= DataProcessors.ToDoList;
	
	ToDoRow					= ToDoList.Add();
	ToDoRow.ID				= "MyReminders";
	ToDoRow.HasToDoItems	= (RemindersCount > 0);
	ToDoRow.Presentation	= NStr("en = 'All reminders'");
	ToDoRow.Count			= RemindersCount;
	ToDoRow.Form			= "InformationRegister.UserReminders.Form.MyReminders";
	ToDoRow.Owner			= RowID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#Region Private

#Region ToDoList

Function RemindersCount()
	
	Result = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(*) AS TotalCount
	|FROM
	|	InformationRegister.UserReminders AS InformationRegisterUserReminders
	|WHERE
	|	InformationRegisterUserReminders.User = &User";
	
	Query.SetParameter("User", Users.AuthorizedUser());
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.TotalCount;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion
