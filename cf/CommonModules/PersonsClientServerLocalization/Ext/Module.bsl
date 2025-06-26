///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, ООО 1С-Софт
// Все права защищены. Эта программа и сопроводительные материалы предоставляются 
// в соответствии с условиями лицензии Attribution 4.0 International (CC BY 4.0)
// Текст лицензии доступен по ссылке:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Abbreviates a person's name.
//
// Parameters:
//  FullName - String - For example, "John Quentin Doe".
//            - Structure:
//                        * LastName  - String
//                        * Name      - String
//                        * MiddleName - String
//  FullNameFormat - String - "LastName, FirstName, MiddleName" (the default order) or "FirstName, MiddleName, LastName".
//  IsInitialsComeFirst    - Boolean - If set to "False" (the default value), returns "Doe J. Q."
//                                Otherwise, returns "J. Q. Doe".
//  Result - String - Last name and initials. For example, "Doe J. Q." 
//
Procedure OnDefineSurnameAndInitials(Val FullName, Val FullNameFormat, Val IsInitialsComeFirst, Result) Export
EndProcedure

// Splits a person's name into first name, middle name, and last name.
// If a name (usually, Central Asian) ends with "oğlu", " "qızı", "kizi", "uulu", or "kyzy",
// they are considered a part of the middle name.
//
// Parameters:
//  FullName - String - Full name in the format "LastName FirstName MiddleName".
//  NameFormat - String - Determines the order of name components.
//                         The default order is "LastName,FirstName,MiddleName".
//                         The alternative order is "FirstName,MiddleName,LastName".
//  Result - Structure:
//   * LastName  - String - Last name.
//   * Name      - String - First name.
//   * MiddleName - String - Middle name.
//
// Example:
//   "IndividualsClientServer.NameParts()" returns a structure with the following values: 
//    - If "John Doe" is passed,  returns "John", "Doe", "".
//    - If "Sidorova Anna Ivanovna" is passed, returns "Sidorova", "Anna", "Ivanovna". 
//    - If "Aliev Akhmed Oktai oglu" is passed, returns "Aliev", "Akhmed", "Oktai oglu".
//    
//   
//
Procedure OnDefineFullNameComponents(Val FullName, Val NameFormat, Result) Export
EndProcedure

// Проверяет, верно ли написано ФИО физического лица.
//
// Parameters:
//  LastFirstName - String - фамилия, имя и отчество.
//  IsOnlyNationalScriptLetters - Boolean - при проверке ФИО должна включать только символы национального алфавита.
//  CheckResult - Boolean - возвращаемое значение. Если Истина, то ФИО написано верно.
//
Procedure FullNameWrittenCorrectly(Val LastFirstName, Val IsOnlyNationalScriptLetters, CheckResult) Export
	
	
EndProcedure

#EndRegion

