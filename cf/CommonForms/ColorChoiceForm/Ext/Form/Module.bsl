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
	AddColors("BlackAndWhiteItems", "000000,444444,666666,999999,CCCCCC,EEEEEE,F3F3F3,FFFFFF");
	AddColors("Main_", "EB3541,EB9635,EBDE35,41EB35,35EBDE,3541EB,9635EB,DE35EB");
	AddColors("Rest", "E5717C,F9AC75,FFCE73,A1CA86,81B3B7,79BAE1,9085C9,C884AE");
	AddColors("Rest", "D31225,EB8A46,F5B640,7EB15C,539399,4B9CCD,6B5BB0,AF5A8D");
	AddColors("Rest", "B10E1E,CB5B11,D78F0A,518B2B,246B72,1871AA,3B2B8A,892A61");
	AddColors("Rest", "680910,7B310B,845008,2E4D17,133B3F,0E3D63,1D164C,4B1635");
EndProcedure 

&AtServer
Procedure AddColors(GroupName, StringOfColors)
	
	Location = Items.Find(GroupName);
	
	If Location = Undefined Then
		Location = Items.Add(GroupName, Type("FormGroup"));
		Location.Type = FormGroupType.UsualGroup;
		Location.Group = ChildFormItemsGroup.Vertical;
		Location.ShowTitle = False;
		Items.Move(Location, ThisObject, Items.GroupAdditionalActions);
		Location.VerticalSpacing = FormItemSpacing.None;
	EndIf;
	
	Counter = 0;
	
	While Items.Find("Group"+Format(Counter, "NG=0;")) <> Undefined Do
		Counter = Counter + 1;
	EndDo;
	
	GroupOfColors = Items.Add("Group"+Format(Counter, "NG=0;"), Type("FormGroup"), Location);
	GroupOfColors.Type = FormGroupType.UsualGroup;
	GroupOfColors.Group = ChildFormItemsGroup.AlwaysHorizontal;
	GroupOfColors.ShowTitle = False;
	GroupOfColors.HorizontalSpacing = FormItemSpacing.None;
	GroupOfColors.VerticalSpacing = FormItemSpacing.None;
	
	ArrayOfColors = StrSplit(StringOfColors, ",");
	
	For Each Color In ArrayOfColors Do
		ColorDecoration = Items.Add("Color_"+Color, Type("FormDecoration"), GroupOfColors);
		ColorDecoration.Type = FormDecorationType.Label;
		Red = NumberFromHexString("0x" + Mid(Color, 1, 2));
		Green = NumberFromHexString("0x" + Mid(Color, 3, 2));
		B = NumberFromHexString("0x" + Mid(Color, 5, 2));
		// @skip-check new-color - Algorithmic creation of pallet colors
		ColorDecoration.BackColor = New Color(Red, Green, B); 
		ColorDecoration.Title = "  ";
		ColorDecoration.Width = 4;
		ColorDecoration.Height = 2;
		ColorDecoration.Border = New Border(ControlBorderType.Single);
		ColorDecoration.BorderColor = StyleColors.FormBackColor;
		ColorDecoration.SetAction("Click", "Attachable_ClickColor");
		ColorDecoration.Hyperlink = True;
	EndDo;
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
Procedure ClearUpColor(Command)
	Close(New Color());
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_ClickColor(Item)
	Close(Item.BackColor);
EndProcedure

&AtClient
Procedure OtherColorsClick(Item)
	Close("OtherColors");
EndProcedure


#EndRegion
