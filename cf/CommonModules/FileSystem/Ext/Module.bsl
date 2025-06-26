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

#Region TemporaryFiles

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to manage temporary files.

// Creates a temporary directory. If a temporary directory is not required anymore, deleted it 
// with the FileSystem.DeleteTemporaryDirectory procedure.
//
// Parameters:
//   Extension - String - the temporary directory extension that contains the directory designation
//                         and its subsystem.
//                         It is recommended that you use only Latin characters in this parameter.
//
// Returns:
//   String - the full path to the directory, including path separators.
//
Function CreateTemporaryDirectory(Val Extension = "") Export
	
	PathToDirectory = CommonClientServer.AddLastPathSeparator(GetTempFileName(Extension));
	CreateDirectory(PathToDirectory);
	Return PathToDirectory;
	
EndFunction

// Deletes the temporary directory and its content if possible.
// If a temporary directory cannot be deleted (for example, if it is busy),
// the procedure is completed and the warning is added to the event log.
//
// This procedure is for using with the FileSystem.CreateTemporaryDirectory procedure 
// after a temporary directory is not required anymore.
//
// Parameters:
//   Path - String - the full path to a temporary directory.
//
Procedure DeleteTemporaryDirectory(Val Path) Export
	
	If Not IsTempFileName(Path) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter %1 in %2:
				|The catalog is not temporary ""%3"".';"), 
			"Path", "FileSystem.DeleteTemporaryDirectory", Path);
	EndIf;
	
	DeleteTempFiles(Path);
	
EndProcedure

// Deletes a temporary file.
// 
// Throws an exception if not a temporary file name is passed.
// 
// If you cannot delete the temporary file (for example, if it is busy),
// the procedure is ended and the warning is added to the event log.
//
// This procedure is for using with the  
// GetTempFileName method after a temporary file is not required anymore.
//
// Parameters:
//   Path - String - a full path to a temporary file.
//
Procedure DeleteTempFile(Val Path) Export
	
	If Not IsTempFileName(Path) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter %1 in %2:
				|The file is not temporary ""%3"".';"), 
			"Path", "FileSystem.DeleteTempFile", Path);
	EndIf;
	
	DeleteTempFiles(Path);
	
EndProcedure

// Generates a unique file name in the specified folder and adds a sequence number to the name if needed.
// For example: "file (2).txt", "file (3).txt", and so on.
//
// Parameters:
//   FileName - String - a full name of the file and folder. For example: "C:\Documents\file.txt".
//
// Returns:
//   String - For example: "C:\Documents\file (2).txt" if "file.txt" already exists in the folder.
//
Function UniqueFileName(Val FileName) Export
	
	Return FileSystemInternalClientServer.UniqueFileName(FileName);

EndFunction

#EndRegion

#Region RunExternalApplications

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external applications.

// Parameter constructor for FileSystem.StartApplication.
//
// Returns:
//  Structure:
//    * CurrentDirectory - String - sets the current directory of the application being started up.
//    * WaitForCompletion - Boolean - False - wait for the running application to end 
//         before proceeding.
//    * GetOutputStream - Boolean - False - result is passed to stdout.
//         Ignored if WaitForCompletion is not specified.
//    * GetErrorStream - Boolean - False - errors are passed to stderr stream.
//         Ignored if WaitForCompletion is not specified.
//    * ThreadsEncoding - TextEncoding
//                       - String - an encoding used to read stdout и stderr.
//         "CP866" is default for Windows and "UTF-8" is default for others.
//    * ExecutionEncoding - String
//                          - Number - an encoding set in Windows using the chcp command,
//             the possible values ​​are "OEM", "CP866", "UTF8" or the code page number.
//         On Linux, it is set by the environment variable "LANGUAGE" for a particular command.
//             Possible values ​​can be determined by executing the "locale -a" command, for example, "en_EN.UTF-8".
//         Ignored when under MacOS.
//
Function ApplicationStartupParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDirectory", "");
	Parameters.Insert("WaitForCompletion", False);
	Parameters.Insert("GetOutputStream", False);
	Parameters.Insert("GetErrorStream", False);
	Parameters.Insert("ThreadsEncoding", Undefined);
	Parameters.Insert("ExecutionEncoding", Undefined);
	
	Return Parameters;
	
EndFunction

// Starts up an external application for execution (for example, * .exe, * bat), 
// or a system command (for example, ping, tracert or traceroute, access the rac client),
// It also allows you to get a return code and the values ​​of output streams (stdout) and errors (stderr)
//
// When an external program is started up in batch mode, the output stream and error stream may return in an unexpected language. 
// To pass to the external application the language in which the expected result must be, you need to:
// - Specify the language in the startup parameter of this application (if such a parameter is provided). 
//   For example, batch mode of 1C:Enterprise has the "/L en" key;
// - In other cases, explicitly set the encoding for the batch command execution.
//   See the ExecutionEncoding property of return value FileSystem.ApplicationStartupParameters. 
//
// Parameters:
//  StartupCommand - String - application startup command line.
//                 - Array - the first element is the path to the application, 
//                            the rest of the elements are its startup parameters.
//                            The procedure generates an argv string from the array.
//  ApplicationStartupParameters - See FileSystem.ApplicationStartupParameters
//
// Returns:
//  Structure:
//    * ReturnCode - Number  - the application return code;
//    * OutputStream - String - the application result passed to stdout;
//    * ErrorStream - String - the application errors passed to stderr.
//
// Example:
//	// Simple start
//	FileSystem.StartApplication("calc");
//	
//	// Starting with waiting for completion
//	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
//	ApplicationStartupParameters.WaitForCompletion = True;
//	FileSystem.StartApplication("C:\Program Files\1cv8\common\1cestart.exe", 
//		ApplicationStartupParameters);
//	
//	// Starting with waiting for completion and getting output thread
//	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
//	ApplicationStartupParameters.WaitForCompletion = True;
//	ApplicationStartupParameters.GetOutputStream = True;
//	Result = FileSystem("ping 127.0.0.1 -n 5", ApplicationStartupParameters);
//	Common.MessageToUser(Result.OutputStream);
//
//	// Starting with waiting for completion and getting output thread, and with start command concatenation
//	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
//	ApplicationStartupParameters.WaitForCompletion = True;
//	ApplicationStartupParameters.GetOutputStream = True;
//	StartupCommand = New Array;
//	StartupCommand.Add("ping");
//	StartupCommand.Add("127.0.0.1");
//	StartupCommand.Add("-n");
//	StartupCommand.Add(5);
//	Result = FileSystem.StartApplication(StartupCommand, ApplicationStartupParameters);
//	Common.MessageToUser(Result.OutputStream);
//
Function StartApplication(Val StartupCommand, ApplicationStartupParameters = Undefined) Export 
	
	// CAC:534-off safe start methods are provided with this function
	
	CommandString = CommonInternalClientServer.SafeCommandString(StartupCommand);
	
	If ApplicationStartupParameters = Undefined Then 
		ApplicationStartupParameters = ApplicationStartupParameters();
	EndIf;
	
	CurrentDirectory = ApplicationStartupParameters.CurrentDirectory;
	WaitForCompletion = ApplicationStartupParameters.WaitForCompletion;
	GetOutputStream = ApplicationStartupParameters.GetOutputStream;
	GetErrorStream = ApplicationStartupParameters.GetErrorStream;
	ThreadsEncoding = ApplicationStartupParameters.ThreadsEncoding;
	ExecutionEncoding = ApplicationStartupParameters.ExecutionEncoding;
	
	CheckCurrentDirectory(CommandString, CurrentDirectory);
	
	If WaitForCompletion Then 
		If GetOutputStream Then 
			OutputThreadFileName = GetTempFileName("stdout.tmp");
			CommandString = CommandString + " > """ + OutputThreadFileName + """";
		EndIf;
		
		If GetErrorStream Then 
			ErrorsThreadFileName = GetTempFileName("stderr.tmp");
			CommandString = CommandString + " 2>""" + ErrorsThreadFileName + """";
		EndIf;
	EndIf;
	
	If ThreadsEncoding = Undefined Then 
		ThreadsEncoding = StandardStreamEncoding();
	EndIf;
	
	// Hardcode the default code page since cmd does not always take the current code page.
	If ExecutionEncoding = Undefined And Common.IsWindowsServer() Then 
		ExecutionEncoding = "CP866";
	EndIf;
	
	ReturnCode = Undefined;
	
	If Common.IsWindowsServer() Then
		
		CommandString = CommonInternalClientServer.TheWindowsCommandStartLine(
			CommandString, CurrentDirectory, WaitForCompletion, ExecutionEncoding);
		
		If Common.FileInfobase() Then
			// In a file infobase, the console window must be hidden in the server context as well.
			Shell = New COMObject("Wscript.Shell");
			ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
			Shell = Undefined;
		Else
			RunApp(CommandString,, WaitForCompletion, ReturnCode);
		EndIf;
		
	Else
		
		If Common.IsLinuxServer() And ValueIsFilled(ExecutionEncoding) Then
			CommandString = "LANGUAGE=" + ExecutionEncoding + " " + CommandString;
		EndIf;
		
		RunApp(CommandString, CurrentDirectory, WaitForCompletion, ReturnCode);
	EndIf;
	
	OutputStream = "";
	ErrorStream = "";
	
	If WaitForCompletion Then 
		If GetOutputStream Then
			OutputStream = ReadFileIfExists(OutputThreadFileName, ThreadsEncoding);
			DeleteTempFile(OutputThreadFileName);
		EndIf;
		
		If GetErrorStream Then 
			ErrorStream = ReadFileIfExists(ErrorsThreadFileName, ThreadsEncoding);
			DeleteTempFile(ErrorsThreadFileName);
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ReturnCode", ReturnCode);
	Result.Insert("OutputStream", OutputStream);
	Result.Insert("ErrorStream", ErrorStream);
	
	Return Result;
	
	// ACC:534-on
	
EndFunction

#EndRegion

// Returns the path to the shared network directory containing temporary files.
//
// For the proper functioning in the client/server mode, place temporary files 
// to a shared network directory that any server in the cluster have access to. 
// This will ensure fault tolerance in cases when a temporary file is used by multiple servers. 
// For example, when a file is processed by multiple parallel background jobs.
// The path to the directory is specified in "Administration > General settings".
// If no path is provided or this is a file infobase, 1C:Enterprise will create a directory 
// in the user's temporary directory.
// In this case, the user should delete the temporary files manually to prevent
// the disk space from being flooded with temporary files.
//
// Parameters:
//  NestedDirectory - String - If it is passed, the function creates a subdirectory in the shared network directory.
// 
// Returns:
//  String - Path to the temporary file directory.
//
Function SharedDirectoryOfTemporaryFiles(NestedDirectory = Undefined) Export
	
	If Common.FileInfobase() And Not Common.DebugMode() Then
		
		Return TempFilesDirName(NestedDirectory);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	CommonPlatformType = "";
	If Common.IsWindowsServer() Then
		
		Result         = Constants.WindowsTemporaryFilesDerectory.Get();
		CommonPlatformType = "Windows";
		
	Else
		
		Result         = Constants.LinuxTemporaryFilesDerectory.Get();
		CommonPlatformType = "Linux";
		
	EndIf;
	
	SetPrivilegedMode(False);
	
	If IsBlankString(Result) Then
		
		Return TempFilesDirName(NestedDirectory);
		
	Else
		
		Result = TrimAll(Result);
		
		Directory = New File(Result);
		If Not Directory.Exists() Then
			
			ConstantPresentation = ?(CommonPlatformType = "Windows", 
				Metadata.Constants.WindowsTemporaryFilesDerectory.Presentation(),
				Metadata.Constants.LinuxTemporaryFilesDerectory.Presentation());
			
			MessageTemplate = NStr("en = 'Temporary file directory does not exist.
					|Ensure that the value is valid for the parameter:
					|""%1"".';", Common.DefaultLanguageCode());
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ConstantPresentation);
			Raise(MessageText);
			
		EndIf;
		
		If ValueIsFilled(NestedDirectory) Then
			Result = CommonClientServer.AddLastPathSeparator(Result) + NestedDirectory;
			CreateDirectory(Result);
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction
	
#EndRegion

#Region Private

Procedure DeleteTempFiles(Val Path)
	
	Try
		DeleteFiles(Path);
	Except
		WriteLogEvent(
			NStr("en = 'Standard subsystems';", Common.DefaultLanguageCode()),
			EventLogLevel.Warning,,, // ACC:154 - A warning (not an error).
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot delete temporary file %1. Reason:
					|%2';"),
				Path,
				ErrorProcessing.DetailErrorDescription(ErrorInfo())));
	EndTry;
	
EndProcedure

Function IsTempFileName(Path)
	
	// It is expected that "Path" was obtained using the method "GetTempFileName".
	// Before validating, normalize all the slashes/backslashes.
	Return StrStartsWith(StrReplace(Path, "/", "\"), StrReplace(TempFilesDir(), "/", "\"));
	
EndFunction

#Region StartApplication

Procedure CheckCurrentDirectory(CommandString, CurrentDirectory)
	
	If Not IsBlankString(CurrentDirectory) Then 
		
		FileInfo3 = New File(CurrentDirectory);
		
		If Not FileInfo3.Exists() Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t start %1.
				           |Reason:
				           |The catalog %2 does not exist
				           |%3';"),
				CommandString, "CurrentDirectory", CurrentDirectory);
		EndIf;
		
		If Not FileInfo3.IsDirectory() Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t start %1.
				           |Reason:
				           |%2 is not a directory:
				           |%3';"),
				CommandString, "CurrentDirectory", CurrentDirectory);
		EndIf;
		
	EndIf;
	
EndProcedure

Function TempFilesDirName(NestedDirectory)
	
	Result = CommonClientServer.AddLastPathSeparator(TempFilesDir());
	If ValueIsFilled(NestedDirectory) Then
		Result = Result + CommonClientServer.AddLastPathSeparator(NestedDirectory);
	EndIf;
	
	CreateDirectory(Result);
	
	Return Result;
	
EndFunction

Function ReadFileIfExists(Path, Encoding)
	
	Result = Undefined;
	FileInfo3 = New File(Path);
	
	If FileInfo3.Exists() Then 
		
		ErrorStreamReader = New TextReader(Path, Encoding);
		Result = ErrorStreamReader.Read();
		ErrorStreamReader.Close();
		
	EndIf;
	
	If Result = Undefined Then 
		Result = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Returns encoding of standard output and error threads for the current operating system.
//
// Returns:
//  TextEncoding
//
Function StandardStreamEncoding()
	
	If Common.IsWindowsServer() Then
		Encoding = "CP866";
	Else
		Encoding = "UTF-8";
	EndIf;
	
	Return Encoding;
	
EndFunction

#EndRegion

#EndRegion