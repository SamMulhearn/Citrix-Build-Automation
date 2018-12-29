Function Install-WEM {
    [CmdletBinding()] 
    param (
            [Parameter(Mandatory=$true)]
            [String]$TargetMachine,
            
            [Parameter(Mandatory=$true)] 
            [Alias('LogFile')] 
            [string]$CurrentLogFile
            )

    begin {
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    }
    process {
        
        Try {
                Write-Log -Path $CurrentLogFIle -Message "Starting WEM Installation on $TargetMachine"
                Initialize-Machine -TargetMachine $TargetMachine -CurrentLogFile $CurrentLogFile
                $arguments = @( "/S", "/V/qn/norestart")

                $WEM = (Get-Item -Path "C:\Cetus\Software\WEM\Workspace-Environment-Management*\Citrix Workspace Environment Management Infrastructure Services Setup.exe" | Select -First 1)
                Install-Software -TargetMachine $TargetMachine -Executable $WEM -CommandArguments $arguments -RestartExitCodes @('3010') -SuccessExitCodes @('0') -CurrentLogFile $CurrentLogFile 
                
                
                $WEMConsole = (Get-Item -Path "C:\Cetus\Software\WEM\Workspace-Environment-Management*\Citrix Workspace Environment Management Console Setup.exe" | Select -First 1)
                Install-Software -TargetMachine $TargetMachine -Executable $WEMConsole -CommandArguments $arguments -RestartExitCodes @('3010') -SuccessExitCodes @('0') -CurrentLogFile $CurrentLogFile 
                
                Write-Log -Path $CurrentLogFIle -Message "Finished WEM Installation on $TargetMachine"


            }
        catch {
                throw $_.Exception
            }
    }
    end {
    }

}

Export-ModuleMember Install-WEM