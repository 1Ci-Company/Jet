<picture align="center">
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/eb61278b-be85-4d3a-bbe0-b1c5a99321ca">
  <img alt="1C:Jet Logo" src="https://github.com/user-attachments/assets/dc413c38-b74a-4987-b44b-cd3185d3f7bb">
</picture>

[![chat](https://img.shields.io/badge/chat-telegram-blue?logo=telegram)](https://t.me/jet1ci)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/1Ci-Company/test12135436574/blob/main/LICENSE)
[![Last release](https://img.shields.io/github/v/release/1Ci-Company/jet?include_prereleases)](https://github.com/1Ci-Company/Jet/releases)

# 1C Jet Translator Extension

## Description
When sending e-invoices, especially export invoices, some legal obligations have to be added to the comment section. These obligations have to be written in different languages, sometimes in English, sometimes in Russian. The user does not want to deal with translation every time. This is where the translator extension comes in: it automatically provides the translation, which can then be added to the comment field.

## Features
1. Translate text from any language to Turkish, English, Russian, or other languages.
2. Supports DeepL Free and Pro APIs.
3. Reduces manual translation effort and risk of errors.
4. Useful for international invoices, export documents, and compliance.

## Usage

### Story 1
1. Take your API from DeepL
2. Go To Translate Subsystem in 1C Jet and enter "Translate Token"
3. Go To Translate Subsystem in 1C Jet and set your "Translate Settings"
4. Go to SalesInvoice → Choose any document → go to Additional Information
5. Check Activate Translator
6. Choose Target Language
7. Enter the text to be translated then click at "Translate"

### Story 2
1. Take your API from DeepL
2. Go To Translate Subsystem in 1C Jet and enter "Translate Token"
3. Go To Translate Subsystem in 1C Jet and set your "Translate Settings"
4. Go To Translate Subsystem in 1C Jet and open Translate
5. Choose Target Language
6. Enter the text to be translated then click at "Translate"

## Requirements
1. 1C Jet Turkish 1.0.3.1
2. DeepL API key (Free or Pro)
3. Internet connection
