#Import-Module ActiveDirectory

Function Publish-toAD {
    [CmdletBinding()] 
    param (
            #[Parameter(Mandatory=$true)] 
            #[String]$BaseLDAPPath,
           
            #[Parameter(Mandatory=$true)] 
            #[String]$DomainFQDN,

           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log'

            )
        begin {
                $VerbosePreference = 'Continue'
                $ErrorActionPreference = 'Stop'
               }
        process {
            Import-Module ActiveDirectory
            Import-Module GroupPolicy
            $GPOs = Get-ChildItem -Path C:\Cetus\GPO
            ForEach ($GPO in $GPOs) {
                Write-Log -Message "Importing the GPO `"$GPO`" into AD" -Path $CurrentLogFile
                Import-GPO -BackupGpoName $GPO -Path 'C:\Cetus\GPO' -TargetName $GPO -CreateIfNeeded
            }
        }
        end {}
    }

Export-ModuleMember Publish-toAD