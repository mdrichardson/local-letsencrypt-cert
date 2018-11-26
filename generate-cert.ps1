# Run as Admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Notify about requirements
Write-Host 'This script requires Node.js and http-server to be installed'
Write-Host ''
Write-Host 'To install:'
Write-Host '    Node.js - Go to https://nodejs.org/en/' -foregroundColor Yellow
Write-Host '    http-server - Open a command prompt and type: npm install -g http-server' -foregroundColor Yellow
Write-Host ''
Read-Host -Prompt 'Press Enter once Complete'

# Get User Input for Variables
$email = Read-Host -Prompt 'Enter your email for ACME Registration'
$domain = Read-Host -Prompt 'Enter your hostname (www.example.com)'
$attempt = Read-Host -Prompt 'What do you want to call this registration attempt, alphanumeric only (example: attempt1)?'
Clear-Host

# Initialize ACMESharp
Write-Host -------------------------------------------------------------------------------
Write-Host 'Installing and Initializing ACMESharp'
Write-Host -------------------------------------------------------------------------------
Install-Module -Name ACMESharp -AllowClobber
Import-Module ACMESharp
Initialize-ACMESharp
Write-Host 'ACMESharp is Ready' -foregroundColor Green
Write-Host ''


# Register User
Write-Host -------------------------------------------------------------------------------
Write-Host 'Registering User and Preparing to Validate' $domain
Write-Host -------------------------------------------------------------------------------
New-ACMERegistration -Contacts mailto:$email -AcceptTos
New-ACMEIdentifier -Dns $domain -Alias $attempt
$rootPath = 'C:\'
New-Item -Path $rootPath -Name 'acme' -ItemType directory -Force | Out-Null
$savePath = $rootPath + 'acme\'
$instructions = $savePath + 'ACMEinstructions.txt'
# Validate Host
Complete-ACMEChallenge $attempt -ChallengeType http-01 -Handler manual -RepeatHandler -HandlerParameters @{WriteOutPath = $instructions; Append = $true}
$instructionsContent = Get-Content $instructions
# Extract token
$regexInstructions = '(?<=File Path:    \[\.well-known\/acme-challenge\/)\S*\b'
$token = [regex]::Match($instructionsContent, $regexInstructions).Groups.Value
$regexContent = '(?<=File Content: \[)\S*\b'
$content = [regex]::Match($instructionsContent, $regexContent).Groups.Value
Write-Host 'User is Registered' -foregroundColor Green
Write-Host ''

# Create Validation File
Write-Host -------------------------------------------------------------------------------
Write-Host 'Creating Validation File'
Write-Host -------------------------------------------------------------------------------
New-Item -Path $savePath'.well-known' -Name 'acme-challenge' -ItemType directory -Force | Out-Null
New-Item -Path $savePath'.well-known\acme-challenge' -Name $token'.txt' -ItemType 'file' -Value $content -Force | Out-Null
Rename-Item -Path $savePath'.well-known\acme-challenge\'$token'.txt' -NewName $token -Force | Out-Null
Write-Host 'Validation File Created' -foregroundColor Green
Write-Host ''

# Start HTTP Server
Write-Host -------------------------------------------------------------------------------
Write-Host 'Starting HTTP Server'
Write-Host -------------------------------------------------------------------------------
cd $savePath'.well-known'
Start-Process cmd.exe -ArgumentList "/C http-server -p 80"
Write-Host ''
Write-Host '** http-server is running on port 80 **' -foregroundColor Cyan
Write-Host ''
Write-Host 'Ensure your router firewall is directing all traffic from port 80 to this computer' -foregroundColor Cyan
Write-Host ''
Read-Host -Prompt 'Press Enter once Complete'
Write-Host ''

# Validate
Write-Host -------------------------------------------------------------------------------
Write-Host 'Validating Connection to' $domain
Write-Host -------------------------------------------------------------------------------
Submit-ACMEChallenge $attempt -ChallengeType http-01
Write-Host 'Challenge submitted. Waiting 1 minute for validation' -foregroundColor Yellow
Write-Host ''
Start-Sleep -s 60
$validation = (Update-ACMEIdentifier $attempt -ChallengeType http-01).Challenges | Where-Object {$_.Type -eq "http-01"}

if ($validation.status -Contains 'valid') {
  # Submit certificates
  Write-Host -------------------------------------------------------------------------------
  Write-Host 'Saving Certificates'
  Write-Host -------------------------------------------------------------------------------
  New-ACMECertificate -Generate -Alias $attempt -IdentifierRef $attempt
  Submit-ACMECertificate -CertificateRef $attempt
  Update-ACMECertificate -CertificateRef $attempt
  Write-Host 'Certificates Submitted'

  # Export certificates
  Write-Host ''
  $caption = 'Choose how you want to export your certificates';
  $message = '';
  $pemCrt = new-Object System.Management.Automation.Host.ChoiceDescription "&CRT/PEM","CRT/PEM";
  $pfx = new-Object System.Management.Automation.Host.ChoiceDescription "&PFX","PFX";
  $both = new-Object System.Management.Automation.Host.ChoiceDescription "&Both","Both";
  $choices = [System.Management.Automation.Host.ChoiceDescription[]]($pemCrt,$pfx,$both);
  $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

  switch ($answer){
      0 {Get-ACMECertificate attempt1 -ExportIssuerPEM $Home'\Documents\'$domain'.pem' -ExportIssuerDER $Home'\Documents\'$domain'.crt'; break}
      1 {
        $certPass = Read-Host -Prompt 'Enter a password for your PFX or leave blank'
        if ($certPass)
        {
          Get-ACMECertificate attempt1 -ExportPkcs12 $Home'\Documents\'$domain'.pfx' -CertificatePassword $certPass
        }
        else
        {
          Get-ACMECertificate attempt1 -ExportPkcs12 $Home'\Documents\'$domain'.pfx'
        }
        break
        }
      2 {
        Get-ACMECertificate attempt1 -ExportIssuerPEM $Home'\Documents\'$domain'.pem' -ExportIssuerDER $Home'\Documents\'$domain'.crt'
        $certPass = Read-Host -Prompt 'Enter a password for your PFX or leave blank'
        if ($certPass)
        {
          Get-ACMECertificate attempt1 -ExportPkcs12 $Home'\Documents\'$domain'.pfx' -CertificatePassword $certPass
        }
        else
        {
          Get-ACMECertificate attempt1 -ExportPkcs12 $Home'\Documents\'$domain'.pfx'
        }
        break
      }
  }
  Write-Host ''
  Write-Host ''
  Write-Host 'Certificates have been saved to your user folder' -foregroundColor Green
  Write-Host ''
  Write-Host ''
}
else {
  Write-Host 'Unable to Validate. Try again with a different attempt name.'  -foregroundColor Red
}

# Clean up
cd 'C:\'
Stop-Process -Name 'node' -Force
Stop-Process -Name 'cmd' -Force
Remove-Item $savePath -Force -Recurse

# Prevent close on error
Write-Host ''
Read-Host -Prompt 'Press Enter to exit'