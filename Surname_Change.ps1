Write-Host "-----------------------------------"
Write-Host "|             NAME CHANGE SCRIPT  |"
Write-Host "-----------------------------------"
Write-Host "Be advised this script is unforgiving of errors. You will be prompted to login, use admin acct where possible"
[System.Net.WebRequest]::DefaultWebProxy.Credentials =
[System.Net.CredentialCache]::DefaultCredentials

#1. Set-up
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Write-Host "Loading..."
#Install-Module MSOnline
Write-host "."
#Install-Module AzureADPreview -Force
Write-host ".."
Import-Module ActiveDirectory
Write-host "..."
#Import-Module ExchangeOnlineManagement
Write-Host "Modules loaded"

#2. Query admin for some info
$Cred = Read-Host -Prompt "Please enter your admin username" 
$FN = Read-Host -Prompt "Enter the FIRSTNAME of the employee you wish to rename (e.g. 'John')"
$OLDLN = Read-Host -Prompt "Enter the OLD LASTNAME of the employee you wish to rename (e.g. 'Smith')"
$NEWLN = Read-Host -Prompt "Enter the NEW LASTNAME of the employee you wish to rename (e.g. 'Jones')"
$OldUser = Read-Host -Prompt "Enter the OLD USERNAME of the employee you wish to rename (e.g. 'jsmith')" 
$NewUser = Read-Host -Prompt "Enter the NEW USERNAME of the employee you wish to rename (e.g. 'jjones')" 
$OldDName = $FN + " " + $OLDLN
$NewDName = $FN + " " + $NEWLN
$OldEmail = $OldUser + "@URL.net"
$NewEmail = $NewUser + "@URL.net"
#TEST

#Checking to make sure new username doesn't already exist
$QName = Get-ADUser -Filter {sAMAccountName -eq $NewUser}
While ($QName -ne $Null){
    $NewUser = Read-Host -Prompt "The chosen new username already exists in AD, please enter a different new username."
    $QName = Get-ADUser -Filter {sAMAccountName -eq $NewUser}
    }
Write-Host "New username chosen is available, script will continue."
$NewUPN = $NewUser + "@URL.net"

$User = Get-ADUser -Identity $OldUser

#changes cn, dn, name
$user = Get-AdUser $OldUser | Rename-ADObject -NewName $NewDName -Passthru

#changes sAMAccountName
Set-AdUser -Identity $OldUser -SamAccountName $NewUser

#3. Change attribute editor
Set-AdUser -Identity $NewUser -displayName $NewDName
#Set-ADUser -Identity $NewUser -Replace @{Name = $NewDName}
Set-AdUser -Identity $NewUser -EmailAddress $NewEmail 
Set-ADUser -Identity $NewUser -Replace @{MailNickName = $NewUser}
Set-AdUser -Identity $NewUser -Surname $NEWLN
Set-ADUser -Identity $NewUser -Replace @{targetAddress = "SMTP:" + $NewUser + "@PLACE.mail.onmicrosoft.com"}
Set-AdUser -Identity $NewUser -UserPrincipalName $NewUPN

#proxyAddresses
Set-ADUser -Identity $NewUser -Remove @{proxyAddresses = "SMTP:" + $OldUser + "@URL.net"}
Set-ADUser -Identity $NewUser -Add @{proxyAddresses = "SMTP:" + $NewUser + "@URL.net"}
Set-ADUser -Identity $NewUser -Add @{proxyAddresses = "SMTP:" + $NewUser + "@URL.net"}
Set-ADUser -Identity $NewUser -Add @{proxyAddresses = "smtp:" + $OldUser + "@URL.net"}
Set-ADUser -Identity $NewUser -Remove @{proxyAddresses = "smtp:" + $OldUser + "@PLACE.mail.onmicrosoft.com"}
Set-ADUser -Identity $NewUser -Add @{proxyAddresses = "smtp:" + $NewUser + "@PLACE.mail.onmicrosoft.com"}
Write-host "Changing H drive name, this takes time."
Rename-Item "\\UNC\t\$OldUser" "\\UNC\t\$NewUser"
Set-ADUser -Identity $User -HomeDirectory \\UNC\t\$NewUser -HomeDrive H;

#4. Dirsync, no wait needed
Write-Host "Beginning DirSync"

Invoke-Command -ComputerName <azure box> -Credential bcc\$Cred -ScriptBlock {
	Import-Module ADSync
	Start-ADSyncSyncCycle -PolicyType Delta
    }

#4. Send email from your regular email account

$Reg = $Cred.substring(0,$Cred.Length-1)
$RegMail = $Reg + "@URL.net"

#Send-MailMessage -From $RegMail -To $NewEmail -Subject "Name change from $($OldDName) to $($NewDName)" -Body "Hi User,
#The name change for your login (User account), email, and home folder (H: drive) has been completed.  
#Please note that when you sign in after the change, use $($NewUser) rather than $($OldUser).  Your email address will change from $($OldEmail) to $($NewEmail).  Your password will not be changed for your login or email.  If you have your  email on a smartphone, it will also need to be deleted and then re-setup.
#Your H: drive will be changed from $($OldUser) to $($NewUser) as well. 
#If you have any file or folder shortcuts to your H: drive, they will need to be updated or recreated." -SmtpServer fqdn

