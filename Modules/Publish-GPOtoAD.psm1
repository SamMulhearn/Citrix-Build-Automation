#Import-Module ActiveDirectory

Function Publish-GPOtoAD {
    [CmdletBinding()] 
    param (
            #[Parameter(Mandatory=$true)] 
            #[String]$BaseLDAPPath,
           
            #[Parameter(Mandatory=$true)] 
            #[String]$DomainFQDN,

           [string]$VDA,
           
           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log'

           

            )
        begin {
                $VerbosePreference = 'Continue'
                $ErrorActionPreference = 'Stop'
               }
        process {
            Write-log -Path $CurrentLogFile -Message "Importing AD/GPO Modules"
            Import-Module ActiveDirectory, GroupPolicy | Out-Null
            Write-log -Path $CurrentLogFile -Message "Imported AD/GPO Modules"
            $GPOs = Get-ChildItem -Path C:\Cetus\GPO
            ForEach ($GPO in $GPOs) {
                Write-Log -Message "Importing the GPO `"$GPO`" into AD" -Path $CurrentLogFile
                Import-GPO -BackupGpoName $GPO -Path 'C:\Cetus\GPO' -TargetName $GPO -CreateIfNeeded
            }
        
            if ($VDA -ne $null) {
                if (Test-Path -Path "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -PathType Container) {
                    Write-Log -Path $CurrentLogFIle -Message "Copying ADMX/ADML files for BIS-F & FSLogix to the Central Store"
                    Copy-Item -Path "$VDA\\C$\Program Files (x86)\Base Image Script Framework (BIS-F)\ADMX\BaseImageScriptFramework.admx" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -Force
                    Copy-Item -Path "$VDA\\C$\Program Files (x86)\Base Image Script Framework (BIS-F)\ADMX\en-US\BaseImageScriptFramework.adml" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions\en-US" -Force
                    Copy-Item -Path "C:\Cetus\Software\FSLogix\fslogix.admx" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -Force
                    Copy-Item -Path "C:\Cetus\Software\FSLogix\fslogix.adml" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions\en-US" -Force
                    Write-Log -Path $CurrentLogFIle -Message "Copied ADMX/ADML files for BIS-F & FSLogix to the Central Store"
                }
            }
        }

        end {}
    }


Export-ModuleMember Publish-GPOtoAD