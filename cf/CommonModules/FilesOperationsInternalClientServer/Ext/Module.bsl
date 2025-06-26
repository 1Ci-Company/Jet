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

// Gets the unique file name for using it in the working directory.
// If there are matches, the name is similar to "A1Order.doc".
//
Function UniqueNameByWay(Val DirectoryName, Val FileName) Export
	
	CommonClientServer.Validate(ValueIsFilled(DirectoryName),
		NStr("en = 'Fill in the directory.';"),	"FilesOperationsInternalClientServer.UniqueNameByWay");
	
	FinalPath = "";
	
	Counter = 0;
	DoNumber = 0;
	Success = False;
	CodeOfFirstLetter = CharCode("A", 1);
	
	RandomValueGenerator = Undefined;
	
#If Not WebClient Then
	RandomValueGenerator = New RandomNumberGenerator(CurrentUniversalDateInMilliseconds());
#EndIf

	RandomOptionsCount = 26;
	
	While Not Success And DoNumber < 100 Do
		DirectoryNumber = 0;
		
#If Not WebClient Then
		DirectoryNumber = RandomValueGenerator.RandomNumber(0, RandomOptionsCount - 1);
#Else
		DirectoryNumber = CurrentUniversalDateInMilliseconds() % RandomOptionsCount;
#EndIf

		If Counter > 1 And RandomOptionsCount < 26 * 26 * 26 * 26 * 26 Then
			RandomOptionsCount = RandomOptionsCount * 26;
		EndIf;
		
		DirectoryLetters = "";
		CodeOfFirstLetter = CharCode("A", 1);
		
		While True Do
			LetterNumber = DirectoryNumber % 26;
			DirectoryNumber = Int(DirectoryNumber / 26);
			
			DirectoryCode = CodeOfFirstLetter + LetterNumber;
			
			DirectoryLetters = DirectoryLetters + Char(DirectoryCode);
			If DirectoryNumber = 0 Then
				Break;
			EndIf;
		EndDo;
		
		Subdirectory = ""; // A partial path.
		
		// Try using the root. If it fails, add A, B, … Z, … ZZZZZ, … AAAAA, … AAAAAZ, etc.
		// 
		If  Counter = 0 Then
			Subdirectory = "";
		Else
			Subdirectory = DirectoryLetters;
			DoNumber = Round(Counter / 26);
			
			If DoNumber <> 0 Then
				DoNumberString = String(DoNumber);
				Subdirectory = Subdirectory + DoNumberString;
			EndIf;
			
			If IsReservedDirectoryName(Subdirectory) Then
				Continue;
			EndIf;
			
			Subdirectory = CommonClientServer.AddLastPathSeparator(Subdirectory);
		EndIf;
		
		FullSubdirectory = DirectoryName + Subdirectory;
		
		// Creating a directory for files.
		DirectoryOnHardDrive = New File(FullSubdirectory);
		If Not DirectoryOnHardDrive.Exists() Then
			Try
				CreateDirectory(FullSubdirectory);
			Except
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot create the ""%1"" directory:
						| %2.';"),
					FullSubdirectory,
					ErrorProcessing.BriefErrorDescription(ErrorInfo()) );
			EndTry;
		EndIf;
		
		AttemptFile = FullSubdirectory + FileName;
		Counter = Counter + 1;
		
		// Checking whether the file name is unique
		FileOnHardDrive = New File(AttemptFile);
		If Not FileOnHardDrive.Exists() Then  // File doesn't exist.
			FinalPath = Subdirectory + FileName;
			Success = True;
		EndIf;
	EndDo;
	
	Return FinalPath;
	
EndFunction

// Returns True if the file with such extension is in the list of extensions.
Function FileExtensionInList(ExtensionsList, FileExtention) Export
	
	FileExtentionWithoutDot = CommonClientServer.ExtensionWithoutPoint(FileExtention);
	
	ExtensionsArray = StrSplit(
		Lower(ExtensionsList), " ", False);
	
	If ExtensionsArray.Find(FileExtentionWithoutDot) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For user interface.

// Returns the message stating that locked files cannot be signed.
//
Function MessageAboutInvalidSigningOfLockedFile(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en = 'Cannot sign the file because it is locked.';");
	Else
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot sign the file %1 because it is locked.';"),
			String(FileRef) );
	EndIf;
	
EndFunction

// Returns the message stating that encrypted files cannot be signed.
//
Function MessageAboutInvalidSigningOfEncryptedFile(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en = 'Cannot sign the file because it is encrypted.';");
	Else
		Return StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot sign the file %1 because it is encrypted.';"),
						String(FileRef) );
	EndIf;
	
EndFunction

// Receive a row representing the file size. For example, to display the state when the file is transferred.
Function FileSizePresentation(Val SizeInMB) Export
	
	If SizeInMB < 0.1 Then
		SizeInMB = 0.1;
	EndIf;	
	
	SizeString = ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0"));
	Return SizeString;
	
EndFunction	

// Get the index of the file icon. It is the index in the "FileIconCollection" picture.
Function IndexOfFileIcon(Val FileExtention) Export
	
	If TypeOf(FileExtention) <> Type("String")
		Or IsBlankString(FileExtention) Then
		Return 0;
	EndIf;
	
	FileExtention = CommonClientServer.ExtensionWithoutPoint(FileExtention);
	
	Extension = "." + Lower(FileExtention) + ";";
	
	If StrFind(".dt;.1cd;.cf;.cfu;", Extension) <> 0 Then
		Return 6; // 1C:Enterprise files.
		
	ElsIf Extension = ".mxl;" Then
		Return 8; // Spreadsheet files
		
	ElsIf StrFind(".txt;.log;.ini;", Extension) <> 0 Then
		Return 10; // Text files
		
	ElsIf Extension = ".epf;" Then
		Return 12; // External data processors.
		
	ElsIf StrFind(".ico;.wmf;.emf;",Extension) <> 0 Then
		Return 14; // Pictures
		
	ElsIf StrFind(".htm;.html;.url;.mht;.mhtml;",Extension) <> 0 Then
		Return 16; // HTML.
		
	ElsIf StrFind(".doc;.dot;.rtf;",Extension) <> 0 Then
		Return 18; // Microsoft Word file.
		
	ElsIf StrFind(".xls;.xlw;",Extension) <> 0 Then
		Return 20; // Microsoft Excel file.
		
	ElsIf StrFind(".ppt;.pps;",Extension) <> 0 Then
		Return 22; // Microsoft PowerPoint file.
		
	ElsIf StrFind(".vsd;",Extension) <> 0 Then
		Return 24; // Microsoft Visio file.
		
	ElsIf StrFind(".mpp;",Extension) <> 0 Then
		Return 26; // Microsoft Visio file.
		
	ElsIf StrFind(".mdb;.adp;.mda;.mde;.ade;",Extension) <> 0 Then
		Return 28; // Microsoft Access database.
		
	ElsIf StrFind(".xml;",Extension) <> 0 Then
		Return 30; // xml.
		
	ElsIf StrFind(".msg;.eml;",Extension) <> 0 Then
		Return 32; // Email message.
		
	ElsIf StrFind(".zip;.rar;.arj;.cab;.lzh;.ace;",Extension) <> 0 Then
		Return 34; // Archives.
		
	ElsIf StrFind(".exe;.com;.bat;.cmd;",Extension) <> 0 Then
		Return 36; // Executable files.
		
	ElsIf StrFind(".grs;",Extension) <> 0 Then
		Return 38; // Graphical schema.
		
	ElsIf StrFind(".geo;",Extension) <> 0 Then
		Return 40; // Geographical schema.
		
	ElsIf StrFind(".jpg;.jpeg;.jp2;.jpe;",Extension) <> 0 Then
		Return 42; // jpg.
		
	ElsIf StrFind(".bmp;.dib;",Extension) <> 0 Then
		Return 44; // bmp.
		
	ElsIf StrFind(".tif;.tiff;",Extension) <> 0 Then
		Return 46; // tif.
		
	ElsIf StrFind(".gif;",Extension) <> 0 Then
		Return 48; // gif.
		
	ElsIf StrFind(".png;",Extension) <> 0 Then
		Return 50; // png.
		
	ElsIf StrFind(".pdf;",Extension) <> 0 Then
		Return 52; // pdf.
		
	ElsIf StrFind(".odt;",Extension) <> 0 Then
		Return 54; // Open Office writer.
		
	ElsIf StrFind(".odf;",Extension) <> 0 Then
		Return 56; // Open Office math.
		
	ElsIf StrFind(".odp;",Extension) <> 0 Then
		Return 58; // Open Office Impress.
		
	ElsIf StrFind(".odg;",Extension) <> 0 Then
		Return 60; // Open Office draw.
		
	ElsIf StrFind(".ods;",Extension) <> 0 Then
		Return 62; // Open Office calc.
		
	ElsIf StrFind(".mp3;",Extension) <> 0 Then
		Return 64;
		
	ElsIf StrFind(".erf;",Extension) <> 0 Then
		Return 66; // External reports.
		
	ElsIf StrFind(".docx;",Extension) <> 0 Then
		Return 68; // Microsoft Word 2007 file (DOCX).
		
	ElsIf StrFind(".xlsx;",Extension) <> 0 Then
		Return 70; // Microsoft Excel 2007 file (XLSX).
		
	ElsIf StrFind(".pptx;",Extension) <> 0 Then
		Return 72; // Microsoft PowerPoint 2007 file (PPTX).
		
	ElsIf StrFind(".p7s;",Extension) <> 0 Then
		Return 74; // Signature file.
		
	ElsIf StrFind(".p7m;",Extension) <> 0 Then
		Return 76; // Encrypted message.
	Else
		Return 4;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// For internal use only.
Procedure FillSignatureStatus(SignatureRow, CurrentDate) Export
	
	If Not ValueIsFilled(SignatureRow.SignatureValidationDate) Then
		SignatureRow.Status = "";
		Return;
	EndIf;
	
	If SignatureRow.SignatureCorrect
		And ValueIsFilled(SignatureRow.DateActionLastTimestamp)
		And SignatureRow.DateActionLastTimestamp < CurrentDate Then
		SignatureRow.Status = NStr("en = 'Was valid on the date of signature';");
	ElsIf SignatureRow.SignatureCorrect Then
		SignatureRow.Status = NStr("en = 'Valid';");
	ElsIf SignatureRow.IsVerificationRequired Then
		SignatureRow.Status = NStr("en = 'Verification required';");
	Else
		SignatureRow.Status = NStr("en = 'Invalid';");
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File synchronization.

Function AddressInCloudService(Service, Href) Export
	
	ObjectAddress = Href;
	
	If Not IsBlankString(Service) Then
		If Service = "https://webdav.yandex.com" Then
			ObjectAddress = StrReplace(Href, "https://webdav.yandex.com", "https://disk.yandex.com/client/disk");
		ElsIf Service = "https://dav.box.com/dav" Then
			ObjectAddress = "https://app.box.com/files/0/";
		ElsIf Service = "https://dav.dropdav.com" Then
			ObjectAddress = "https://www.dropbox.com/home/";
		EndIf;
	EndIf;
	
	Return ObjectAddress;
	
EndFunction

// Parameters to lock a file for editing.
//
// Returns:
//   Structure:
//     * UUID - form UUID.
//     * User - CatalogRef.Users
//     * AdditionalProperties - Structure - additional properties for writing a file.
//
Function FileLockParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("UUID");
	Parameters.Insert("User");
	Parameters.Insert("AdditionalProperties");
	Parameters.Insert("RaiseException1", True);
	
	Return Parameters;
	
EndFunction

// Scanning add-in attachment details.
//
// Returns:
//  Structure:
//   * FullTemplateName - String
//   * ObjectName      - String
//
Function ComponentDetails() Export
	
	Parameters = New Structure;
	Parameters.Insert("ObjectName", "ImageScan");
	Parameters.Insert("FullTemplateName", "CommonTemplate.DocumentScanningAddIn");
	Return Parameters;
	
EndFunction

#Region TextExtraction

// Extracts text in the specified encoding.
// If encoding is not specified, it calculates the encoding itself.
//
Function ExtractTextFromTextFile(FullFileName, Encoding, Cancel) Export
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	// Determine encoding.
	If Not ValueIsFilled(Encoding) Then
		Encoding = Undefined;
	EndIf;
	
	Try
		EncodingForRead = ?(Encoding = "utf-8_WithoutBOM", "utf-8", Encoding);
		TextReader = New TextReader(FullFileName, EncodingForRead);
		ExtractedText = TextReader.Read();
	Except
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extracts text from an OpenDocument file and returns it as String.
//
Function ExtractOpenDocumentText(PathToFile, Cancel) Export
	
	ExtractedText = "";
	
#If Not WebClient And Not MobileClient Then
	
	TemporaryFolderForUnzipping = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip"); 
	
	FileCopy(PathToFile, TemporaryZIPFile);
	File = New File(TemporaryZIPFile);
	File.SetReadOnly(False);

	Try
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderForUnzipping, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		XMLReader = New XMLReader();
		
		XMLReader.OpenFile(TemporaryFolderForUnzipping + "/content.xml");
		ExtractedText = ExtractTextFromXMLContent(XMLReader);
		XMLReader.Close();
	Except
		// This is not an error because the OTF extension, for example, is related both to OpenDocument format and OpenType font format.
		Archive     = Undefined;
		XMLReader = Undefined;
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
	DeleteFiles(TemporaryFolderForUnzipping);
	DeleteFiles(TemporaryZIPFile);
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Extract text from the XMLReader object (that was read from an OpenDocument file).
Function ExtractTextFromXMLContent(XMLReader)
	
	ExtractedText = "";
	LastTagName = "";
	
#If Not WebClient Then
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			
			LastTagName = XMLReader.Name;
			
			If XMLReader.Name = "text:p" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:line-break" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:tab" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.Tab;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:s" Then
				
				AdditionString = " "; // A whitespace.
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.Name = "text:c"  Then
							SpaceCount = Number(XMLReader.Value);
							AdditionString = "";
							For IndexOf = 0 To SpaceCount - 1 Do
								AdditionString = AdditionString + " "; // A whitespace.
							EndDo;
						EndIf;
					EndDo
				EndIf;
				
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + AdditionString;
				EndIf;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			
			If StrFind(LastTagName, "text:") <> 0 Then
				ExtractedText = ExtractedText + XMLReader.Value;
			EndIf;
			
		EndIf;
		
	EndDo;
	
#EndIf

	Return ExtractedText;
	
EndFunction

// Receive scanned file name of the type DM-00000012, where DM is base prefix.
//
// Parameters:
//  FileNumber  - Number - an integer, for example, 12.
//  BasePrefix - String - a base prefix, for example, DM.
//
// Returns:
//  String - scanned file name, for example, "DM-00000012".
//
Function ScannedFileName(FileNumber, BasePrefix) Export
	
	FileName = "";
	If Not IsBlankString(BasePrefix) Then
		FileName = BasePrefix + "-";
	EndIf;
	
	FileName = FileName + Format(FileNumber, "ND=9; NLZ=; NG=0");
	Return FileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function IsReservedDirectoryName(SubDirectoryName)
	
	NamesList = New Map();
	NamesList.Insert("CON", True);
	NamesList.Insert("PRN", True);
	NamesList.Insert("AUX", True);
	NamesList.Insert("NUL", True);
	
	Return NamesList[SubDirectoryName] <> Undefined;
	
EndFunction

// Initializes parameter structure to add the file.
// Use this function in StoredFiles.AddToFile and FilesOperationsInternalServerCall.AddFile.
//
Function FileAddingOptions(AdditionalAttributes = Undefined) Export
	
	If TypeOf(AdditionalAttributes) = Type("Structure") Then
		FileAttributes = Undefined;
		AddingOptions = AdditionalAttributes;
	Else
		
		AddingOptions = New Structure;
		FileAttributes = ?(TypeOf(AdditionalAttributes) = Type("Array"),
			AdditionalAttributes,
			StringFunctionsClientServer.SplitStringIntoSubstringsArray(AdditionalAttributes, ",", True, True));
		
	EndIf;
	
	AddProperty(AddingOptions, "Author");
	AddProperty(AddingOptions, "FilesOwner");
	AddProperty(AddingOptions, "BaseName", "");
	AddProperty(AddingOptions, "ExtensionWithoutPoint", "");
	AddProperty(AddingOptions, "ModificationTimeUniversal");
	AddProperty(AddingOptions, "FilesGroup");
	AddProperty(AddingOptions, "IsInternal", False);
	
	If FileAttributes = Undefined Then
		Return AddingOptions;
	EndIf;
	
	For Each AdditionalAttribute In FileAttributes Do
		AddProperty(AddingOptions, AdditionalAttribute);
	EndDo;
	
	Return AddingOptions;
	
EndFunction

Procedure AddProperty(Collection, Var_Key, Value = Undefined)
	
	If Not Collection.Property(Var_Key) Then
		Collection.Insert(Var_Key, Value);
	EndIf;
	
EndProcedure

// Automatically determines and returns the text file encoding.
//
// Parameters:
//  DataForAnalysis - BinaryData, String - data to determine encoding or data address.
//  Extension         - String - file extension.
//
// Returns:
//  String
//
Function DetermineBinaryDataEncoding(DataForAnalysis, Extension) Export
	
	If TypeOf(DataForAnalysis) = Type("BinaryData") Then
		BinaryData = DataForAnalysis;
	ElsIf IsTempStorageURL(DataForAnalysis) Then
		BinaryData = GetFromTempStorage(DataForAnalysis);
	Else
		BinaryData = Undefined;
	EndIf;

	Encoding = Undefined;
	
	If BinaryData <> Undefined Then
		Encoding = EncodingFromBinaryData(BinaryData);
		If Not ValueIsFilled(Encoding) Then
			If StrEndsWith(Lower(Extension), "xml") Then
				Encoding = EncodingFromXMLNotification(BinaryData);
			Else
				Encoding = EncodingFromAlphabetMap(BinaryData);
			EndIf;
			
			If Lower(Encoding) = "utf-8" Then
				Encoding = Lower(Encoding) + "_WithoutBOM";
			EndIf;
			
		EndIf;
	EndIf;
	Return Encoding;
	
EndFunction

// Returns the encoding received from file binary data if 
// the file contains the BOM signature in the beginning.
//
// Parameters:
//  BinaryData - BinaryData - binary data of the file.
//
// Returns:
//  String - file encoding. If the file does not contain the BOM signature, 
//           returns an empty string.
//
Function EncodingFromBinaryData(BinaryData)

	DataReader        = New DataReader(BinaryData);
	BinaryDataBuffer = DataReader.ReadIntoBinaryDataBuffer(5);
	
	Return BOMEncoding(BinaryDataBuffer);

EndFunction

// Returns the encoding received from file binary data if 
// the file contains the XML notification.
//
// Parameters:
//  BinaryData - BinaryData- binary data of the file.
//
// Returns:
//  String - file encoding. If  
//                          the XML notification cannot be read, returns an empty string.
//
Function EncodingFromXMLNotification(BinaryData)
	
#If WebClient Then
	String = GetStringFromBinaryData(BinaryData);
	FirstTag = StrSplit(String, ">", False)[0];
	Encoding = Mid(FirstTag, StrFind(FirstTag, "encoding") + 10);
	XMLEncoding = StrSplit(Encoding, """")[0];
#Else
	BinaryDataBuffer = GetBinaryDataBufferFromBinaryData(BinaryData);
	MemoryStream = New MemoryStream(BinaryDataBuffer);
	XMLEncoding = "";
	
	XMLReader = New XMLReader;
	XMLReader.OpenStream(MemoryStream);
	Try
		XMLReader.MoveToContent();
		XMLEncoding = XMLReader.XMLEncoding;
	Except
		XMLEncoding = "";
	EndTry;
	XMLReader.Close();
	MemoryStream.Close();
#EndIf
	Return XMLEncoding;
	
EndFunction

// Returns the text encoding received from the BOM signature in the beginning.
//
// Parameters:
//  BinaryDataBuffer - Number - a collection of bytes to define encoding.
//
// Returns:
//  String - file encoding. If the file does not contain the BOM signature, 
//                       returns an empty string.
//
Function BOMEncoding(BinaryDataBuffer)
	
	ReadBytes = New Array(5);
	For IndexOf = 0 To 4 Do
		If IndexOf < BinaryDataBuffer.Size Then
			ReadBytes[IndexOf] = BinaryDataBuffer[IndexOf];
		Else
			ReadBytes[IndexOf] = NumberFromHexString("0xA5");
		EndIf;
	EndDo;
	
	If ReadBytes[0] = NumberFromHexString("0xFE")
		And ReadBytes[1] = NumberFromHexString("0xFF") Then
		Encoding = "UTF-16BE";
	ElsIf ReadBytes[0] = NumberFromHexString("0xFF")
		And ReadBytes[1] = NumberFromHexString("0xFE") Then
		If ReadBytes[2] = NumberFromHexString("0x00")
			And ReadBytes[3] = NumberFromHexString("0x00") Then
			Encoding = "UTF-32LE";
		Else
			Encoding = "UTF-16LE";
		EndIf;
	ElsIf ReadBytes[0] = NumberFromHexString("0xEF")
		And ReadBytes[1] = NumberFromHexString("0xBB")
		And ReadBytes[2] = NumberFromHexString("0xBF") Then
		Encoding = "UTF-8";
	ElsIf ReadBytes[0] = NumberFromHexString("0x00")
		And ReadBytes[1] = NumberFromHexString("0x00")
		And ReadBytes[2] = NumberFromHexString("0xFE")
		And ReadBytes[3] = NumberFromHexString("0xFF") Then
		Encoding = "UTF-32BE";
	ElsIf ReadBytes[0] = NumberFromHexString("0x0E")
		And ReadBytes[1] = NumberFromHexString("0xFE")
		And ReadBytes[2] = NumberFromHexString("0xFF") Then
		Encoding = "SCSU";
	ElsIf ReadBytes[0] = NumberFromHexString("0xFB")
		And ReadBytes[1] = NumberFromHexString("0xEE")
		And ReadBytes[2] = NumberFromHexString("0x28") Then
		Encoding = "BOCU-1";
	ElsIf ReadBytes[0] = NumberFromHexString("0x2B")
		And ReadBytes[1] = NumberFromHexString("0x2F")
		And ReadBytes[2] = NumberFromHexString("0x76")
		And (ReadBytes[3] = NumberFromHexString("0x38")
			Or ReadBytes[3] = NumberFromHexString("0x39")
			Or ReadBytes[3] = NumberFromHexString("0x2B")
			Or ReadBytes[3] = NumberFromHexString("0x2F")) Then
		Encoding = "UTF-7";
	ElsIf ReadBytes[0] = NumberFromHexString("0xDD")
		And ReadBytes[1] = NumberFromHexString("0x73")
		And ReadBytes[2] = NumberFromHexString("0x66")
		And ReadBytes[3] = NumberFromHexString("0x73") Then
		Encoding = "UTF-EBCDIC";
	Else
		Encoding = "";
	EndIf;
	
	Return Encoding;
	
EndFunction

// Returns the most suitable text encoding obtained by comparing with the alphabet.
//
// Parameters:
//  TextData - BinaryData - binary data of the file.
//
// Returns:
//  String - file encoding.
//
Function EncodingFromAlphabetMap(TextData)
	
	Encodings = Encodings();
	Encodings.Delete(Encodings.FindByValue("utf-8_WithoutBOM"));
	
	EncodingKOI8R = Encodings.FindByValue("koi8-r");
	Encodings.Move(EncodingKOI8R, -Encodings.IndexOf(EncodingKOI8R));
	
	EncodingWin1251 = Encodings.FindByValue("windows-1251");
	Encodings.Move(EncodingWin1251, -Encodings.IndexOf(EncodingWin1251));
	
	EncodingUTF8 = Encodings.FindByValue("utf-8");
	Encodings.Move(EncodingUTF8, -Encodings.IndexOf(EncodingUTF8));
	
	CorrespondingEncoding = "";
	MaxEncodingMap = 0;
	For Each Encoding In Encodings Do
		
		EncodingMap = AlphabetMapPercentage(TextData, Encoding.Value);
		If EncodingMap > 0.95 Then
			Return Encoding.Value;
		EndIf;
		
		If EncodingMap > MaxEncodingMap Then
			CorrespondingEncoding = Encoding.Value;
			MaxEncodingMap = EncodingMap;
		EndIf;
		
	EndDo;
	
	Return CorrespondingEncoding;
	
EndFunction

Function AlphabetMapPercentage(BinaryData, EncodingToCheck)
	
	// ACC:1036-off, ACC:163-off The alphabet doesn't require spell check.
	Alphabet = "AABBBBGgDDHerHerLJZZIIYyKKLlMmNNOOPPPPSSTTUuFFXXCCHHShhShhYyYyEEYyYy"
		+ "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"
		+ "1234567890 ";
	// ACC:1036-on, ACC:163-on
	
	AlphabetStream = New MemoryStream();
	WriteAlphabet = New DataWriter(AlphabetStream);
	WriteAlphabet.WriteLine(Alphabet, EncodingToCheck);
	WriteAlphabet.Close();
	
	AlphabetData = AlphabetStream.CloseAndGetBinaryData();
	ReadAlphabetData = New DataReader(AlphabetData);
	AlphabetBufferInEncoding = ReadAlphabetData.ReadIntoBinaryDataBuffer();
	
	IndexOf = 0;
	AlphabetChars = New Array;
	While IndexOf <= AlphabetBufferInEncoding.Size - 1 Do
		
		CurrentChar = AlphabetBufferInEncoding[IndexOf];
		
		// Cyrillic characters in UTF-8 encoding are double-byte.
		If EncodingToCheck = "utf-8"
			And (CurrentChar = 208
			Or CurrentChar = 209) Then
			
			IndexOf = IndexOf + 1;
			CurrentChar = Format(CurrentChar, "NZ=0; NG=") + Format(AlphabetBufferInEncoding[IndexOf], "NZ=0; NG=");
		EndIf;
		
		IndexOf = IndexOf + 1;
		AlphabetChars.Add(CurrentChar);
		
	EndDo;
	
	ReadTextData = New DataReader(BinaryData);
	TextDataBuffer = ReadTextData.ReadIntoBinaryDataBuffer(?(EncodingToCheck = "utf-8", 200, 100));
	TextBufferSize = TextDataBuffer.Size;
	CharsCount = TextBufferSize;
	
	IndexOf = 0;
	OccurrencesCount = 0;
	While IndexOf <= TextBufferSize - 1 Do
		
		CurrentChar = TextDataBuffer[IndexOf];
		If EncodingToCheck = "utf-8"
			And (CurrentChar = 208
			Or CurrentChar = 209) Then
			
			// If the last byte in buffer is the first byte of a double-byte character, ignore it.
			If IndexOf = TextBufferSize - 1 Then
				Break;
			EndIf;
			
			IndexOf = IndexOf + 1;
			CharsCount = CharsCount - 1;
			CurrentChar = Format(CurrentChar, "NZ=0; NG=") + Format(TextDataBuffer[IndexOf], "NZ=0; NG=");
			
		EndIf;
		
		IndexOf = IndexOf + 1;
		If AlphabetChars.Find(CurrentChar) <> Undefined Then
			OccurrencesCount = OccurrencesCount + 1;
		EndIf;
		
	EndDo;
	
	Return ?(CharsCount = 0, 100, OccurrencesCount/CharsCount);
	
EndFunction

// Returns a table of encoding names.
//
// Returns:
//   ValueList:
//     * Value - String - for example, "ibm852".
//     * Presentation - String - for example, "ibm852 (Central European DOS)".
//
Function Encodings() Export

	EncodingsList = New ValueList;
	
	EncodingsList.Add("ibm852",       NStr("en = 'IBM852 (Central European DOS)';"));
	EncodingsList.Add("ibm866",       NStr("en = 'IBM866 (Cyrillic DOS)';"));
	EncodingsList.Add("iso-8859-1",   NStr("en = 'ISO-8859-1 (Western European ISO)';"));
	EncodingsList.Add("iso-8859-2",   NStr("en = 'ISO-8859-2 (Central European ISO)';"));
	EncodingsList.Add("iso-8859-3",   NStr("en = 'ISO-8859-3 (Latin-3 ISO)';"));
	EncodingsList.Add("iso-8859-4",   NStr("en = 'ISO-8859-4 (Baltic ISO)';"));
	EncodingsList.Add("iso-8859-5",   NStr("en = 'ISO-8859-5 (Cyrillic ISO)';"));
	EncodingsList.Add("iso-8859-7",   NStr("en = 'ISO-8859-7 (Greek ISO)';"));
	EncodingsList.Add("iso-8859-9",   NStr("en = 'ISO-8859-9 (Turkish ISO)';"));
	EncodingsList.Add("iso-8859-15",  NStr("en = 'ISO-8859-15 (Latin-9 ISO)';"));
	EncodingsList.Add("koi8-r",       NStr("en = 'KOI8-R (Cyrillic KOI8-R)';"));
	EncodingsList.Add("koi8-u",       NStr("en = 'KOI8-U (Cyrillic KOI8-U)';"));
	EncodingsList.Add("us-ascii",     NStr("en = 'US-ASCII (USA)';"));
	EncodingsList.Add("utf-8",        NStr("en = 'UTF-8 (Unicode UTF-8)';"));
	EncodingsList.Add("utf-8_WithoutBOM", NStr("en = 'UTF-8 (Unicode UTF-8 without BOM)';"));
	EncodingsList.Add("windows-1250", NStr("en = 'Windows-1250 (Central European Windows)';"));
	EncodingsList.Add("windows-1251", NStr("en = 'Windows-1251 (Cyrillic Windows)';"));
	EncodingsList.Add("windows-1252", NStr("en = 'Windows-1252 (Western European Windows)';"));
	EncodingsList.Add("windows-1253", NStr("en = 'Windows-1253 (Greek Windows)';"));
	EncodingsList.Add("windows-1254", NStr("en = 'Windows-1254 (Turkish Windows)';"));
	EncodingsList.Add("windows-1257", NStr("en = 'Windows-1257 (Baltic Windows)';"));
	
	Return EncodingsList;

EndFunction

Function ScanningParameters() Export
	
	ScanningParameters = New Structure; 
	ScanningParameters.Insert("ShowDialogBox", True);
	ScanningParameters.Insert("SelectedDevice", "");
	ScanningParameters.Insert("PictureFormat", "png");
	ScanningParameters.Insert("Resolution", 200);
	ScanningParameters.Insert("Chromaticity", 1);
	ScanningParameters.Insert("Rotation", 0);
	ScanningParameters.Insert("PaperSize", 1);
	ScanningParameters.Insert("JPGQuality", 100);
	ScanningParameters.Insert("TIFFDeflation", 6);
	ScanningParameters.Insert("DuplexScanning", False);
	ScanningParameters.Insert("DocumentAutoFeeder", False);
	ScanningParameters.Insert("ShouldSaveAsPDF", False);
	ScanningParameters.Insert("UseImageMagickToConvertToPDF", False);
	Return ScanningParameters;
	
EndFunction

#EndRegion