///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("CurrentEncoding", CurrentEncoding);
	
	ShowOnlyPrimaryEncodings = True;
	FillEncodingsList(Not ShowOnlyPrimaryEncodings);
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowOnlyPrimaryEncodingsOnChange(Item)
	
	FillEncodingsList(Not ShowOnlyPrimaryEncodings);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEncodingsList

&AtClient
Procedure EncodingsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	CloseFormWithEncodingReturn();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectEncoding(Command)
	
	CloseFormWithEncodingReturn();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CloseFormWithEncodingReturn()
	
	Presentation = Items.EncodingsList.CurrentData.Presentation;
	If Not ValueIsFilled(Presentation) Then
		Presentation = Items.EncodingsList.CurrentData.Value;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("Value", Items.EncodingsList.CurrentData.Value);
	SelectionResult.Insert("Presentation", Presentation);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

&AtServer
Procedure FillEncodingsList(FullList)
	
	ElementID = Undefined;
	EncodingsListLocal = Undefined;
	EncodingsList.Clear();
	
	If Not FullList Then
		EncodingsListLocal = FilesOperationsInternal.Encodings();
	Else
		EncodingsListLocal = GetFullEncodingsList();
	EndIf;
	
	For Each Encoding In EncodingsListLocal Do
		
		ListItem = EncodingsList.Add(Encoding.Value, Encoding.Presentation);
		
		If Lower(Encoding.Value) = Lower(CurrentEncoding) Then
			ElementID = ListItem.GetID();
		EndIf;
		
	EndDo;
	
	If ElementID <> Undefined Then
		Items.EncodingsList.CurrentRow = ElementID;
	EndIf;
	
EndProcedure

// Returns a table of encoding names.
//
// Returns:
//   ValueTable
//
&AtServerNoContext
Function GetFullEncodingsList()

	EncodingsList = New ValueList;
	
	EncodingsList.Add("Adobe-Standard-Encoding");
	EncodingsList.Add("Big5");
	EncodingsList.Add("Big5-HKSCS");
	EncodingsList.Add("BOCU-1");
	EncodingsList.Add("CESU-8");
	EncodingsList.Add("cp1006");
	EncodingsList.Add("cp1025");
	EncodingsList.Add("cp1097");
	EncodingsList.Add("cp1098");
	EncodingsList.Add("cp1112");
	EncodingsList.Add("cp1122");
	EncodingsList.Add("cp1123");
	EncodingsList.Add("cp1124");
	EncodingsList.Add("cp1125");
	EncodingsList.Add("cp1131");
	EncodingsList.Add("cp1386");
	EncodingsList.Add("cp33722");
	EncodingsList.Add("cp437");
	EncodingsList.Add("cp737");
	EncodingsList.Add("cp775");
	EncodingsList.Add("cp850");
	EncodingsList.Add("cp851");
	EncodingsList.Add("cp852");
	EncodingsList.Add("cp855");
	EncodingsList.Add("cp856");
	EncodingsList.Add("cp857");
	EncodingsList.Add("cp858");
	EncodingsList.Add("cp860");
	EncodingsList.Add("cp861");
	EncodingsList.Add("cp862");
	EncodingsList.Add("cp863");
	EncodingsList.Add("cp864");
	EncodingsList.Add("cp865");
	EncodingsList.Add("cp866",   NStr("en = 'CP866 (Cyrillic DOS)';"));
	EncodingsList.Add("cp868");
	EncodingsList.Add("cp869");
	EncodingsList.Add("cp874");
	EncodingsList.Add("cp875");
	EncodingsList.Add("cp922");
	EncodingsList.Add("cp930");
	EncodingsList.Add("cp932");
	EncodingsList.Add("cp933");
	EncodingsList.Add("cp935");
	EncodingsList.Add("cp937");
	EncodingsList.Add("cp939");
	EncodingsList.Add("cp949");
	EncodingsList.Add("cp949c");
	EncodingsList.Add("cp950");
	EncodingsList.Add("cp964");
	EncodingsList.Add("ebcdic-ar");
	EncodingsList.Add("ebcdic-de");
	EncodingsList.Add("ebcdic-dk");
	EncodingsList.Add("ebcdic-he");
	EncodingsList.Add("ebcdic-xml-us");
	EncodingsList.Add("EUC-JP");
	EncodingsList.Add("EUC-KR");
	EncodingsList.Add("GB_2312-80");
	EncodingsList.Add("gb18030");
	EncodingsList.Add("GB2312");
	EncodingsList.Add("GBK");
	EncodingsList.Add("hp-roman8");
	EncodingsList.Add("HZ-GB-2312");
	EncodingsList.Add("IBM01140");
	EncodingsList.Add("IBM01141");
	EncodingsList.Add("IBM01142");
	EncodingsList.Add("IBM01143");
	EncodingsList.Add("IBM01144");
	EncodingsList.Add("IBM01145");
	EncodingsList.Add("IBM01146");
	EncodingsList.Add("IBM01147");
	EncodingsList.Add("IBM01148");
	EncodingsList.Add("IBM01149");
	EncodingsList.Add("IBM037");
	EncodingsList.Add("IBM1026");
	EncodingsList.Add("IBM1047");
	EncodingsList.Add("ibm-1047_P100-1995,swaplfnl");
	EncodingsList.Add("ibm-1129");
	EncodingsList.Add("ibm-1130");
	EncodingsList.Add("ibm-1132");
	EncodingsList.Add("ibm-1133");
	EncodingsList.Add("ibm-1137");
	EncodingsList.Add("ibm-1140_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1142_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1143_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1144_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1145_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1146_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1147_P100-1997,swaplfnl ");
	EncodingsList.Add("ibm-1148_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1149_P100-1997,swaplfnl");
	EncodingsList.Add("ibm-1153");
	EncodingsList.Add("ibm-1153_P100-1999,swaplfnl");
	EncodingsList.Add("ibm-1154");
	EncodingsList.Add("ibm-1155");
	EncodingsList.Add("ibm-1156");
	EncodingsList.Add("ibm-1157");
	EncodingsList.Add("ibm-1158");
	EncodingsList.Add("ibm-1160");
	EncodingsList.Add("ibm-1162");
	EncodingsList.Add("ibm-1164");
	EncodingsList.Add("ibm-12712_P100-1998,swaplfnl");
	EncodingsList.Add("ibm-1363");
	EncodingsList.Add("ibm-1364");
	EncodingsList.Add("ibm-1371");
	EncodingsList.Add("ibm-1388");
	EncodingsList.Add("ibm-1390");
	EncodingsList.Add("ibm-1399");
	EncodingsList.Add("ibm-16684");
	EncodingsList.Add("ibm-16804_X110-1999,swaplfnl");
	EncodingsList.Add("IBM278");
	EncodingsList.Add("IBM280");
	EncodingsList.Add("IBM284");
	EncodingsList.Add("IBM285");
	EncodingsList.Add("IBM290");
	EncodingsList.Add("IBM297");
	EncodingsList.Add("IBM367");
	EncodingsList.Add("ibm-37_P100-1995,swaplfnl");
	EncodingsList.Add("IBM420");
	EncodingsList.Add("IBM424");
	EncodingsList.Add("ibm-4899");
	EncodingsList.Add("ibm-4909");
	EncodingsList.Add("ibm-4971");
	EncodingsList.Add("IBM500");
	EncodingsList.Add("ibm-5123");
	EncodingsList.Add("ibm-803");
	EncodingsList.Add("ibm-8482");
	EncodingsList.Add("ibm-867");
	EncodingsList.Add("IBM870");
	EncodingsList.Add("IBM871");
	EncodingsList.Add("ibm-901");
	EncodingsList.Add("ibm-902");
	EncodingsList.Add("IBM918");
	EncodingsList.Add("ibm-971");
	EncodingsList.Add("IBM-Thai");
	EncodingsList.Add("IMAP-mailbox-name");
	EncodingsList.Add("ISO_2022,locale=ja,version=3");
	EncodingsList.Add("ISO_2022,locale=ja,version=4");
	EncodingsList.Add("ISO_2022,locale=ko,version=1");
	EncodingsList.Add("ISO-2022-CN");
	EncodingsList.Add("ISO-2022-CN-EXT");
	EncodingsList.Add("ISO-2022-JP");
	EncodingsList.Add("ISO-2022-JP-2");
	EncodingsList.Add("ISO-2022-KR");
	EncodingsList.Add("iso-8859-1",   NStr("en = 'ISO-8859-1 (Western European ISO)';"));
	EncodingsList.Add("iso-8859-13");
	EncodingsList.Add("iso-8859-15");
	EncodingsList.Add("iso-8859-2",   NStr("en = 'ISO-8859-2 (Central European ISO)';"));
	EncodingsList.Add("iso-8859-3",   NStr("en = 'ISO-8859-3 (Latin-3 ISO)';"));
	EncodingsList.Add("iso-8859-4",   NStr("en = 'ISO-8859-4 (Baltic ISO)';"));
	EncodingsList.Add("iso-8859-5",   NStr("en = 'ISO-8859-5 (Cyrillic ISO)';"));
	EncodingsList.Add("iso-8859-6");
	EncodingsList.Add("iso-8859-7",   NStr("en = 'ISO-8859-7 (Greek ISO)';"));
	EncodingsList.Add("iso-8859-8");
	EncodingsList.Add("iso-8859-9",   NStr("en = 'ISO-8859-9 (Turkish ISO)';"));
	EncodingsList.Add("JIS_Encoding");
	EncodingsList.Add("koi8-r",       NStr("en = 'KOI8-R (Cyrillic KOI8-R)';"));
	EncodingsList.Add("koi8-u",       NStr("en = 'KOI8-U (Cyrillic KOI8-U)';"));
	EncodingsList.Add("KSC_5601");
	EncodingsList.Add("LMBCS-1");
	EncodingsList.Add("LMBCS-11");
	EncodingsList.Add("LMBCS-16");
	EncodingsList.Add("LMBCS-17");
	EncodingsList.Add("LMBCS-18");
	EncodingsList.Add("LMBCS-19");
	EncodingsList.Add("LMBCS-2");
	EncodingsList.Add("LMBCS-3");
	EncodingsList.Add("LMBCS-4");
	EncodingsList.Add("LMBCS-5");
	EncodingsList.Add("LMBCS-6");
	EncodingsList.Add("LMBCS-8");
	EncodingsList.Add("macintosh");
	EncodingsList.Add("SCSU");
	EncodingsList.Add("Shift_JIS");
	EncodingsList.Add("us-ascii",     NStr("en = 'US-ASCII (USA)';"));
	EncodingsList.Add("UTF-16");
	EncodingsList.Add("UTF16_OppositeEndian");
	EncodingsList.Add("UTF16_PlatformEndian");
	EncodingsList.Add("UTF-16BE");
	EncodingsList.Add("UTF-16LE");
	EncodingsList.Add("UTF-32");
	EncodingsList.Add("UTF32_OppositeEndian");
	EncodingsList.Add("UTF32_PlatformEndian");
	EncodingsList.Add("UTF-32BE");
	EncodingsList.Add("UTF-32LE");
	EncodingsList.Add("UTF-7");
	EncodingsList.Add("UTF-8",        NStr("en = 'UTF-8 (Unicode UTF-8)';"));
	EncodingsList.Add("windows-1250", NStr("en = 'Windows-1250 (Central European Windows)';"));
	EncodingsList.Add("windows-1251", NStr("en = 'Windows-1251 (Cyrillic Windows)';"));
	EncodingsList.Add("windows-1252", NStr("en = 'Windows-1252 (Western European Windows)';"));
	EncodingsList.Add("windows-1253", NStr("en = 'Windows-1253 (Greek Windows)';"));
	EncodingsList.Add("windows-1254", NStr("en = 'Windows-1254 (Turkish Windows)';"));
	EncodingsList.Add("windows-1255");
	EncodingsList.Add("windows-1256");
	EncodingsList.Add("windows-1257", NStr("en = 'Windows-1257 (Baltic Windows)';"));
	EncodingsList.Add("windows-1258");
	EncodingsList.Add("windows-57002");
	EncodingsList.Add("windows-57003");
	EncodingsList.Add("windows-57004");
	EncodingsList.Add("windows-57005");
	EncodingsList.Add("windows-57007");
	EncodingsList.Add("windows-57008");
	EncodingsList.Add("windows-57009");
	EncodingsList.Add("windows-57010");
	EncodingsList.Add("windows-57011");
	EncodingsList.Add("windows-874");
	EncodingsList.Add("windows-949");
	EncodingsList.Add("windows-950");
	EncodingsList.Add("x-mac-centraleurroman");
	EncodingsList.Add("x-mac-cyrillic");
	EncodingsList.Add("x-mac-greek");
	EncodingsList.Add("x-mac-turkish");
	
	Return EncodingsList;

EndFunction

#EndRegion
