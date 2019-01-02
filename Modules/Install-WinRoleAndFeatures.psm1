Function Install-WinRolesAndFeatures {
    [CmdletBinding()] 
    param (
            [Parameter(Mandatory=$true)]
            [String]$TargetMachine,

            [Parameter(Mandatory=$true)]
            [String[]]$RolesAndFeatures,

 
            [Parameter(Mandatory=$true)] 
            [Alias('LogFile')] 
            [string]$CurrentLogFile

        )

   begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 
    process {
    Try {
            Do {            
                    If (!($winFeatures)) { Write-Log -Path $CurrentLogFile -Message ("Installing " + ($RolesAndFeatures -join ",") + " on $TargetMachine" ) }
                    Else { Write-Log -Path $CurrentLogFile -Message ("Resuming installation of " + ($RolesAndFeatures -join ",") + " on $TargetMachine" ) }

                    $WinFeatures = Add-WindowsFeature -ComputerName $TargetMachine -Name $RolesAndFeatures -IncludeAllSubFeature -IncludeManagementTools
                    
                    if ($WinFeatures.Success -ne 'True' )
                        {
                            throw "Failed to install $RolesAndFeatures on $TargetMachine"
                        }
                    if ($WinFeatures.RestartNeeded -eq 'Yes')
                        {
                            Write-Log -Path $CurrentLogFile -Message "Restart required, restarting $TargetMachine"
                            Restart-Computer -ComputerName $TargetMachine -Wait -For PowerShell -Timeout 600 -Protocol WSMan -Force
                        }
                }
            While ($WinFeatures.RestartNeeded -eq 'Yes')
            Write-Log -Path $CurrentLogFile -Message ("Installed " + ($RolesAndFeatures -join ",") + " on $TargetMachine" )
        }
    catch {throw $_.Exception}
    }
    end {}       
}
