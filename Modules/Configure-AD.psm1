#Import-Module ActiveDirectory

Function Configure-AD {
    [CmdletBinding()] 
    param (
            [Parameter(Mandatory=$true)] 
            [String]$BaseLDAPPath,
           
            [Parameter(Mandatory=$true)] 
            [String]$DomainFQDN,

                       [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log'

            )
        begin {
                $VerbosePreference = 'Continue'
                $ErrorActionPreference = 'Stop'
               }
        process {
        
            Try {
                Import-Module ActiveDirectory
                Import-Module GroupPolicy
                New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $true -name "Cetus-Citrix" -path "$baseOU"
                $OU = New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $true -name "Targets" -path "OU=`"Cetus-Citrix`",$baseOU"

                

                import-gpo -BackupGpoName "Citrix - User Experience (User)" -TargetName "Citrix User Experience (User)" -path "C:\Cetus\GP\Citrix User Experience (User)" -CreateIfNeeded | new-gplink -target "$OU"
                import-gpo -BackupGpoName "BIS-F (Computer)" -TargetName "BIS-F (Computer)" -path "C:\Cetus\GP\BIS-F (Computer)" -CreateIfNeeded | new-gplink -target "$OU"

            }
            catch {Write-Log -Path $CurrentLogFile -Message $_.Exception -Level Error
                   throw $_.Exception }
        }
        end {}
    }

Export-ModuleMember Configure-AD