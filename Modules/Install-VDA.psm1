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
        

        Write-Log -Path $CurrentLogFIle -Message "Starting VDA Installation on $TargetMachine"
        Initialize-Machine -TargetMachine $TargetMachine -LogFile $CurrentLogFile
        Write-Log -Path $CurrentLogFIle -Message "Determining OS of $TargetMachine"
        $OS = Get-WmiObject -Computer $TargetMachine -Class Win32_OperatingSystem
        $DesktopOS = switch -Wildcard ( $OS.Caption )
            {
                '*Windows Server 2016*' { $false }
                '*Windows 10*'   { $true }
             }

        if ($DesktopOS -eq $false)
            {
                Write-Log -Path $CurrentLogFIle -Message "Detected Server OS"
                $FeaturestoInstall = ("RDS-RD-Server","Remote-Assistance")
                Install-WinRolesAndFeatures -TargetMachine $TargetMachine -CurrentLogFile $CurrentLogFile -RolesAndFeatures $FeaturestoInstall
                
             }
        else { Write-Log -Path $CurrentLogFIle -Message "Detected Desktop OS" }
        
            
        #Install CVDA
        $Command = "C:\Cetus\Software\CVAD\x64\XenDesktop Setup\XenDesktopVDASetup.exe"
        if ($WorkSpaceApp -eq $true) {$Arguments = @("/components VDA,PLUGINS")}
        else {$Arguments = @("/components VDA")}

        $Arguments += ("/enable_framehawk_port", "/enable_hdx_ports", `
            "/enable_hdx_udp_ports","/enable_real_time_transport","/enable_remote_assistance", `
            "/logpath C:\Cetus","/noreboot","/Optimize","/quiet","/virtualmachine", "/noresume" ) 

        if ($PVS -eq $true) {$Arguments += "/masterpvsimage"}
        else {$Arguments += ("/mastermcsimage","/install_mcsio_driver")}

        #Exclude specified components
        $Exclude = @("`"Personal vDisk`"")
        If ($CitrixFiles -eq $false) {$Exclude += @("`"Citrix Files for Windows`"")}
        If ($AppV -eq $false) {$Exclude += @("`"Citrix Personalization for App-V - VDA`"")}
        #add exclude to VDA arguments
        $Arguments += ("/exclude " + ($Exclude -join ","))
        Try { Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile }
        catch {throw $_.Exception}
        
        #Install FXLogix
        $Command = "C:\Cetus\Software\FSLogix\x64\Release\FSLogixAppsSetup.exe"

        #Build Args
        if ($InstallFSLogix -eq $true) {
            $Arguments = ("/install","/quiet", "/norestart")
            if ($FSLogixLicenseKey -ne "")  {$Arguments += "ProductKey=$FSLogixLicenseKey"}
        }

        Try { Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile }
        catch {throw $_.Exception}
        
        #Install WEM
        $Command = (Get-Item -Path "C:\Cetus\Software\WEM\Workspace-Environment-Management*\Citrix Workspace Environment Management Agent Setup.exe" | Select -First 1)
        if ($InstallWEM -eq $true) { $Arguments = @( "/S", "/V/qn/norestart") }
        Try {Install-Software -TargetMachine $TargetMachine -Executable $Command -CommandArguments $Arguments -RestartExitCodes @(3010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile }
        catch {throw $_.Exception}

         #Install BIS-F
         $Executable = (Get-Item -Path "C:\Cetus\Software\BIS-F\setup-BIS-F*.exe" | Select -First 1)
         $Arguments = ("/VERYSILENT", "/LOG", "/NORESTART", "/RESTARTEXITCODE=1010", "/CLOSEAPPLICATIONS")
         try { Install-Software -TargetMachine $TargetMachine -Executable $Executable -CommandArguments $Arguments -RestartExitCodes @(1010) -SuccessExitCodes @(0) -CurrentLogFile $CurrentLogFile }
         catch { throw $_.Exception }

        #Optimising VDA
        Write-Log -Path $CurrentLogFile -Message "Optimising VDA with Citrix Optimiser"
        $Service = Get-Service -ComputerName $TargetMachine -Name RemoteRegistry
        (Get-Service -ComputerName $TargetMachine -Name RemoteRegistry)|Set-Service -StartupType Manual -Status Running
        Get-Service -ComputerName $TargetMachine -Name RemoteRegistry|Set-Service -StartupType $service.StartType      
        $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $TargetMachine)
        $RegKey= $Reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
        $ReleaseID = $RegKey.GetValue("ReleaseID")
        Write-Log -Path $CurrentLogFIle -Message "Detected OS Version $ReleaseID"      
        if ($DesktopOS -eq $true) {
            $File = `
                switch ($ReleaseID) {
                    "1607" {"Citrix_Windows_10_1607.xml"}
                    "1703" {"Citrix_Windows_10_1703.xml"}
                    "1709" {"Citrix_Windows_10_1709.xml"}
                    "1803" {"Citrix_Windows_10_1803.xml"}
                    "1809" {"Citrix_Windows_10_1809.xml"}
                    
                }
         }
         else { $File = `
            switch ($ReleaseID) {
                "1607" {"Citrix_Windows_Server_2016_1607.xml"}
                "1809" {"Citrix_Windows_Server_2019_1809.xml"}
                  }
         }
            
         $File = "C:\Cetus\Software\CitrixOptimizer\Templates\$File"
         Write-Log -Path $CurrentLogFile -Message "Optimisation template is $File"
         $session = New-PSSession -computername $TargetMachine
         Try { 
            Invoke-Command -Session $session -ScriptBlock { 
                $File = $args[0]
                $EX = Get-ExecutionPolicy
                Set-ExecutionPolicy ByPass -Force
                & "C:\Cetus\Software\CitrixOptimizer\CtxOptimizerEngine.ps1" -Source $file -Mode execute -OutputHtml C:\Cetus\Optimise.html -OutputXml C:\Cetus\Optimise.xml
                Set-ExecutionPolicy $EX -Force
             } -ArgumentList $File
         }
         catch { throw $_.Exception }
         If (Test-Path ("\\$TargetMachine\C$\Cetus\Optimise.html")) {
            Write-Log -Path $CurrentLogFile -Message "Finished Optimisations see \\$TargetMachine\C$\Cetus\Optimise.html"
         }
         else { throw "Optimisations may have failed, see \\$TargetMachine\C$\Cetus\Software\CitrixOptimizer\Logs" }
        #Finish
        Write-Log -Path $CurrentLogFIle -Message "Finished VDA Installation on $TargetMachine"
    }
    end {}
}
