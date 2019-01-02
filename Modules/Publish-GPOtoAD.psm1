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
      
            $GPOFolderName = "C:\Cetus\GPO"
            $import_array = get-childitem $GPOFolderName | Select name
            foreach ($ID in $import_array) {
                $XMLFile = $GPOFolderName + "\" + $ID.Name + "\gpreport.xml"
                $XMLData = [XML](get-content $XMLFile)
                $GPOName = $XMLData.GPO.Name

                Write-Log -Message "Importing the GPO `"$GPOName`" into AD" -Path $CurrentLogFile
                import-gpo -BackupId $ID.Name -TargetName $GPOName -path $GPOFolderName -CreateIfNeeded
            }              

            Write-log -Path $CurrentLogFile -Message "Imported AD/GPO Modules"
            if ($VDA -ne $null -or $VDA -ne "") {
                if (Test-Path -Path "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -PathType Container) {
                    Write-Log -Path $CurrentLogFIle -Message "Copying ADMX/ADML files for BIS-F and FSLogix to the Central Store"
                    Copy-Item -Path "\\$VDA\\C$\Program Files (x86)\Base Image Script Framework (BIS-F)\ADMX\BaseImageScriptFramework.admx" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -Force
                    Copy-Item -Path "\\$VDA\\C$\Program Files (x86)\Base Image Script Framework (BIS-F)\ADMX\en-US\BaseImageScriptFramework.adml" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions\en-US" -Force
                    Copy-Item -Path "C:\Cetus\Software\FSLogix\fslogix.admx" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions" -Force
                    Copy-Item -Path "C:\Cetus\Software\FSLogix\fslogix.adml" -Destination "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions\en-US" -Force
                    Write-Log -Path $CurrentLogFIle -Message "Copied ADMX/ADML files for BIS-F and FSLogix to the Central Store"
                }
            }
        }

        end {}
    }
