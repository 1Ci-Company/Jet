<picture align="center">
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/eb61278b-be85-4d3a-bbe0-b1c5a99321ca">
  <img alt="1C:Jet Logo" src="https://github.com/user-attachments/assets/dc413c38-b74a-4987-b44b-cd3185d3f7bb">
</picture>

[![chat](https://img.shields.io/badge/chat-telegram-blue?logo=telegram)](https://t.me/jet1ci)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/1Ci-Company/test12135436574/blob/main/LICENSE)
[![Last release](https://img.shields.io/github/v/release/1Ci-Company/jet?include_prereleases)](https://github.com/1Ci-Company/Jet/releases)

# 1C Jet Map Extension

## Description
When planning shipments, deliveries, or customer visits, companies often need to calculate distances and estimated travel times between two addresses. Doing this manually for each order or invoice is time-consuming and prone to errors.

This is where the Map extension comes in: it automatically retrieves coordinates from OpenStreetMap (Nominatim) and calculates distance and driving duration using OSRM API. The results can be shown directly inside 1C Jet forms, helping businesses optimize their logistics and save time.

## Features
1. Search any address using Yandex or Google map.
2. See driving distance and estimated duration in Sales and Supplier Invoices.
3. Show the exact location of customer/supplier directly on Google Maps or Yandex Maps inside 1C Jet.
4. Reduce manual effort in logistics planning and minimize risk of wrong delivery addresses.
5. Useful for sales invoices, supplier invoices, and shipment planning.

## Usage

### Story 1
1. Go To Sales Subsystem → Sales Invoices → Choose any Sales Invoice
2. Make sure both Customer Address and Warehouse Address are filled
3. Activate "Show Distance" checkbox
4. Use "Refresh Information" button to get latest data

### Story 2
1. Go To Purchases Subsystem → Purchase Invoices → Choose any Purchase Invoice
2. Make sure both Supplier Address and Warehouse Address are filled
3. Activate "Show Distance" checkbox
4. Use "Refresh Information" button to get latest data

### Story 3
1. Go To "Map" Subsystem
2. Click "Preferred Map Provider" and set your preferred provider (optional)
3. Go To Sales Subsystem → Counterparties catalog → Choose any Counterparty
4. Make sure Counterparty Address is filled
5. Use "Show in Map" button to see the exact location of Counterparty

### Story 4
1. Go To "Map" Subsystem
2. Click "Preferred Map Provider" and set your preferred provider (optional)
3. Go To Map Subsystem → Map
4. Fill the Address field
5. Use "Refresh Map" button to see the exact location

### Story 5
1. Go To "Map" Subsystem
2. Click "Preferred Map Provider" and set your preferred provider (optional)
3. Go To Warehouse Subsystem → Warehouses catalog → Choose any Warehouse
4. Make sure Warehouse Address is filled
5. Use "Show in Map" button to see the exact location of Warehouse

## Requirements
1. 1C Jet Turkish 1.0.3.1
2. Internet connection
