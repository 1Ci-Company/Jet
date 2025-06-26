
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Customer") Then
		FilterCustomers = Parameters.Customer;
	EndIf;
	
	If Parameters.Property("Supplier") Then
		FilterSuppliers = Parameters.Supplier;
	EndIf;
	
	SetFilterCustomersSuppliers(ThisObject, "Customer", FilterCustomers);
	SetFilterCustomersSuppliers(ThisObject, "Supplier", FilterSuppliers);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCustomersOnChange(Item)
	
	SetFilterCustomersSuppliers(ThisObject, "Customer", FilterCustomers);
	
EndProcedure

&AtClient
Procedure FilterSuppliersOnChange(Item)
	
	SetFilterCustomersSuppliers(ThisObject, "Supplier", FilterSuppliers);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SetFilterCustomersSuppliers(Form, FieldName, Use)
	
	ItemCount = CommonClientServer.ChangeFilterItems(
		Form.List.SettingsComposer.FixedSettings.Filter,
		FieldName,,
		True,
		DataCompositionComparisonType.Equal,
		Use,
		DataCompositionSettingsItemViewMode.Inaccessible);
	
	If ItemCount = 0 Then
		
		GroupCustomersOrSuppliers = CommonClientServer.FindFilterItemByPresentation(
			Form.List.SettingsComposer.FixedSettings.Filter.Items,
			"CustomersOrSuppliers");
		
		If GroupCustomersOrSuppliers = Undefined Then
			GroupCustomersOrSuppliers = CommonClientServer.CreateFilterItemGroup(
				Form.List.SettingsComposer.FixedSettings.Filter.Items,
				"CustomersOrSuppliers",
				DataCompositionFilterItemsGroupType.OrGroup);
		EndIf;
		
		CommonClientServer.AddCompositionItem(
			GroupCustomersOrSuppliers,
			FieldName,
			DataCompositionComparisonType.Equal,
			True,,
			Use,
			DataCompositionSettingsItemViewMode.Inaccessible);
		
	EndIf;
	
EndProcedure

#EndRegion
