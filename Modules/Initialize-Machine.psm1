﻿function Initialize-Machine
{ 
    [CmdletBinding()] 
    param ([String]$TargetMachine,

           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log'
    ) 
 
   begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 
    Process 
    {   

        Try {
            #Start
            Write-Log -Path $CurrentLogFile -Message "Starting Prerequsite tasks on $TargetMachine"
            Write-Log -Path $CurrentLogFile -Message "Checking remote PowerShell connectivity to $TargetMachine"
            #Test PowerShell Remote
            Try { Test-WSMan -ComputerName $TargetMachine -ErrorAction Stop -Authentication Kerberos | Out-Null }
            catch { throw $_ }
        
            #Disable Windows Firewall
            Write-Log -Path $CurrentLogFile -Message "Disabling firewall on $TargetMachine"

            $session = New-PSSession -computername $TargetMachine
            Invoke-Command -Session $session -ScriptBlock { Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False }
            Remove-PSSession $session
            Write-Log -Path $CurrentLogFile -Message "Disabled Firewall on $TargetMachine"
        
            Write-Log -Path $CurrentLogFile -Message "Enabling Remote Desktop on $TargetMachine"
            $session = New-PSSession -computername $TargetMachine
            Invoke-Command -Session $session -ScriptBlock { Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 0 }
            Remove-PSSession $session
            Write-Log -Path $CurrentLogFile -Message "Enabled Remote Desktop on $TargetMachine"
        
            #Copy files to target
            Write-Log -Path $CurrentLogFile -Message "Copying installation files to $TargetMachine. This might take a few minutes."
            Try {
                    Copy-RoboMirror -SourceDirectory "C:\Cetus\Software" -DestinationDirectory "\\$TargetMachine\C$\Cetus\Software" -logFile $CurrentLogFile
                }
            Catch { throw $_.Exception }
            
            Write-Log -Path $CurrentLogFile -Message "Copied installation files to $TargetMachine"

            Write-Log -message "Installing .net" -Path $CurrentLogFile
            try {
                #Install .net
                $command = (Get-Item -path "C:\Cetus\Software\CVAD\Support\DotNet*\NDP*.exe" | Select -First 1).FullName
                $commandargs =  @("/norestart", "/quiet" ,"/q:a")
                Install-Software -TargetMachine $TargetMachine -Executable $command -CommandArguments $commandargs -RestartExitCodes @(3010) -SuccessExitCodes @('0') -LogFile $CurrentLogFile
            }
            catch { throw $_.exception }
        
            Write-Log -message "Installed .net" -Path $CurrentLogFile

            #Finished
            Write-Log -Path $CurrentLogFile -Message "Finished Prerequsite tasks on $TargetMachine"
        }
        catch {throw $_.Exception}
    }
    End 
    { 
 
    } 
}
