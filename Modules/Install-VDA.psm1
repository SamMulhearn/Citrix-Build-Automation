Function Install-VDA {
    [CmdletBinding()] 
    param (
            [Parameter(Mandatory=$true)]
            [String]$TargetMachine,
            
            [Parameter(Mandatory=$true)] 
            [Alias('LogFile')] 
            [string]$CurrentLogFile,

            [Parameter(Mandatory=$true)]
            [boolean]$InstallFSLogix,

            [Parameter(Mandatory=$true)]
            [AllowEmptyString()]
            [string]$FSLogixLicenseKey,

            [Parameter(Mandatory=$true)]
            [boolean]$PVS,

            [Parameter(Mandatory=$true)]
            [boolean]$AppV,

            [Parameter(Mandatory=$true)]
            [boolean]$CitrixFiles,

            [Parameter(Mandatory=$true)]
            [boolean]$WorkSpaceApp,

            [Parameter(Mandatory=$true)]
            [boolean]$InstallWEM


            )

    begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 
    process {
        
        Try  { 
            Write-Log -Path $CurrentLogFIle -Message "Starting VDA Installation on $TargetMachine"
            Initialize-Server -TargetMachine $TargetMachine -LogFile $CurrentLogFile
            Write-Log -Path $CurrentLogFIle -Message "Determining OS of $TargetMachine"
            $OS = Get-WmiObject -Computer $TargetMachine -Class Win32_OperatingSystem
            $DesktopOS = switch -Wildcard ( $OS.Caption )
                {
                    '*Windows Server 2016*' { $false }
                    '*Windows 10'   { $true }
                }

            if ($DesktopOS -eq $false)
                    {
                        Write-Log -Path $CurrentLogFIle -Message "Detected Server OS"
                        $FeaturestoInstall = ("RDS-RD-Server","Remote-Assistance")
                        Install-WinRolesAndFeatures -TargetMachine $TargetMachine -CurrentLogFile $CurrentLogFile -RolesAndFeatures $FeaturestoInstall
                        
                    }
            else { Write-Log -Path $CurrentLogFIle -Message "Detected Desktop OS" }
        
            
            #Install CVDA
            $Command = "C:\Cetus\Software\CAVD\x64\XenDesktop Setup\XenDesktopVDASetup.exe"
            if ($WorkSpaceApp -eq $true) {$Arguments = @("/components VDA,PLUGINS")}
            else {$Arguments = @("/components VDA")}

            $Arguments += ("/enable_framehawk_port", "/enable_hdx_ports", `
                "/enable_hdx_udp_ports","/enable_real_time_transport","/enable_remote_assistance", `
                "/logpath C:\Cetus","/noreboot","/optimize","/quiet","/virtualmachine", "/noresume" ) 

            if ($PVS -eq $true) {$Arguments += "/masterpvsimage"}
            else {$Arguments += ("/mastermcsimage","/install_mcsio_driver")}

            #Exclude specified components
            $Exclude = @("`"Personal vDisk`"")
            If ($CitrixFiles -eq $false) {$Exclude += @("`"Citrix Files for Windows`"")}
            If ($AppV -eq $false) {$Exclude += @("`"Citrix Personalization for App-V - VDA`"")}
            #add exclude to VDA arguments
            $Arguments += ("/exclude " + ($Exclude -join ","))
            Try {
                    Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile
                }

        
            #Install FXLogix
            $Command = "C:\Cetus\Software\FSLogix\x64\Release\FSLogixAppsSetup.exe"

            #Build Args
            if ($InstallFSLogix -eq $true)   
                {
                    $Arguments = ("/install","/quiet", "/norestart")
                    if ($FSLogixLicenseKey -ne "")
                        {$Arguments += "ProductKey=$FSLogixLicenseKey"}
                }

            Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile    
    
            #Install WEM
            $Command = (Get-Item -Path "C:\Cetus\Software\WEM\Workspace-Environment-Management*\Citrix Workspace Environment Management Agent Setup.exe" | Select -First 1)
            if ($InstallWEM -eq $true)   
                {
                    $Arguments = @( "/S", "/V/qn/norestart")
                }

            Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile    



            #Optimising VDA
            Write-Log -Path $CurrentLogFile -Message "Optimizing VDA with Citrix Optimiser"
            

            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $TargetMachine)
            $RegKey= $Reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
            $ReleaseID = $RegKey.GetValue("ReleaseID")
            Write-Log -Path $CurrentLogFIle -Message "Detected OS Version $ReleaseID"

            if ($DesktopOS -eq $true) {
                $File = `
                    switch ($ReleaseID) {
                        "1607" {"Citrix_Windows10_1607.xml"}
                        "1703" {"Citrix_Windows10_1703.xml"}
                        "1709" {"Citrix_Windows10_1709.xml"}
                        "1803" {"Citrix_Windows10_1803.xml"}
                    }
                }
            else { $File = `
                    switch ($ReleaseID) {
                        "1607" {"Citrix_WindowsServer2016_1607.xml"}
                  }
            }
   
            $File = "C:\Cetus\Software\CitrixOptimizer\Templates\$File"

            $session = New-PSSession -computername $TargetMachine
            Invoke-Command -Session $session -ScriptBlock { C:\Cetus\Software\CitrixOptimizer\CtxOptimizerEngine.ps1 -Source $args[0] -Mode execute -OutputHtml C:\Cetus\Optimize.html -OutputXml C:\Cetus\Optimize.xml } -ArgumentList $File
            Write-Log -Path $CurrentLogFile -Message "Finished Optimizations see \\$TargetMachine\C$\Cetus\Optimize.html"

            #Install BIS-F
            $Executable = (Get-Item -Path "C:\Cetus\Software\BIS-F\setup-BIS-F*.exe" | Select -First 1)
            $Arguments = ("/VERYSILENT", "/LOG", "/NORESTART", "/RESTARTEXITCODE=1010", "/CLOSEAPPLICATIONS")
            Install-Software -TargetMachine $TargetMachine -Executable $Executable -CommandArguments $Arguments -RestartExitCodes @(1010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile
            Write-Log -Path $CurrentLogFIle -Message "Finished VDA Installation on $TargetMachine"
        }
        catch {throw $_.Exception}
    }
    end {}
}
Export-ModuleMember Install-VDA