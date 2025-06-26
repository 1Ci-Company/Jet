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

// procedure to be executed after the check is completed.
// Changing parameter StandardProcessing can cancel opening the form.
//
// Parameters:
//  SendOptions    - See EmailOperationsClient.EmailSendOptions
//  CompletionHandler - NotifyDescription - description of the procedure that is called after
//                                              sending email.
//  StandardProcessing - Boolean - shows whether a new email form continues opening after the
//                                  procedure ends. If False, the email form is not opened.
//
Procedure BeforeOpenEmailSendingForm(SendOptions, CompletionHandler, StandardProcessing) Export

	
EndProcedure

#EndRegion