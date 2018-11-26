# Local LetsEncrypt Certificate Generator

This PowerShell script uses [ACMESharp](https://github.com/ebekker/ACMESharp) to generate certificates used for local development.

I created this because I found that when using ACMESharp for dynamic DNS certification on my local machine, it was difficult to use the manual 'http-1' method. This can still be done using ACMESharp, but this automates the process a lot better

## How this works:

1. Installs ACMESharp to Windows PowerShell
2. Sets up http-1 challenge with ACME/LetsEncrypt
3. Starts an instance of http-server so that it can serve the validation file
4. Prompts ACME to validate the file
5. Once valid, saves certificates for user

## Requirements

1. [Node.js](https://nodejs.org)
2. http-server - `npm install -g http-server`
3. Ability to port-forward on your router

## Installation

Clone this repo or just copy the `generate-cert.ps1` file.

## Usage

1. Run `generate-cert.ps1` as admin
2. Follow the prompts