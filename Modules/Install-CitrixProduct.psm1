function Install-CitrixProduct {
    [CmdletBinding()] 
    param ([String]$TargetMachine,

           [String[]]$Products, #Array of Citrix Products

           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')]
           [string]$CurrentLogFile

           ) 
 
   begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 
    Process 
    { 
        Write-Log -Path $CurrentLogFile -Message ("Starting installation of " + ($Products -join ", ") + " on $TargetMachine")
        Try { Initialize-Machine -TargetMachine $TargetMachine -ErrorAction Stop -LogFile $CurrentLogFile }
            catch { throw $_.Exception }
        try {
            Write-Log -Message "Installing Windows Roles" -Path $CurrentLogFile
            switch ( $products ) #ForEach Product
                {
                    "CONTROLLER" { $FeaturesToInstall  += @('NET-Framework-45-Core','NET-Framework-Core')    }
                    "DESKTOPSTUDIO" { $FeaturesToInstall += @('NET-Framework-45-Core','NET-Framework-Core')    }
                    "DESKTOPDIRECTOR" { $FeaturesToInstall += @('NET-Framework-45-Core','NET-Framework-Core',"Web-WebServer", "Web-ASP")   }
                    "LICENSESERVER" { $FeaturesToInstall += @('NET-Framework-45-Core','NET-Framework-Core') }
                    "STOREFRONT" { $FeaturesToInstall += @('NET-Framework-45-Core','NET-Framework-Core',"Web-Static-Content","Web-Default-Doc","Web-Http-Errors","Web-Http-Redirect","Web-Http-Logging","Web-Mgmt-Console","Web-Scripting-Tools","Web-Windows-Auth","Web-Basic-Auth","Web-AppInit","Web-Asp-Net45","Net-Wcf-Tcp-PortSharing45","Web-WebServer")  }
                }
        
                $FeaturesToInstall = $FeaturesToInstall | select -uniq
        
                Install-WinRolesAndFeatures -TargetMachine $TargetMachine -RolesAndFeatures $FeaturesToInstall -CurrentLogFile $CurrentLogFile
            }
        catch { throw $_}
        Write-Log -Message "Installed Windows Roles" -Path $CurrentLogFile
        
        Write-Log -Message "Installing Citrix Product(s)" -Path $CurrentLogFile
        Try {
            Write-Log -Path $CurrentLogFile -Message ("Installing " + ($Products -join ", ") + " on $TargetMachine. See \\$TargetMachine\C$\Cetus\ for logs.")
            $commandargs =  @("/configure_firewall", "/quiet", "/logpath C:\Cetus", "/noreboot", "/nosql")
            $commandargs += ("/components " + ($Products -join ","))        
            Install-Software -TargetMachine $TargetMachine -Executable "C:\Cetus\Software\CAVD\x64\XenDesktop Setup\XenDesktopServerSetup.exe" -CommandArguments $commandargs -RestartExitCodes @('3010') -SuccessExitCodes @(0) -LogFile $CurrentLogFile
        }
        catch {throw $_}
        
        Write-Log -Path $CurrentLogFile -Message ("Finished Installation of  " + ($Products -join ", ") + " on $TargetMachine. See \\$TargetMachine\C$\Cetus\ for logs.")
    }
    End 
    { 
    } 
}

Export-ModuleMember -Function Install-CitrixProduct