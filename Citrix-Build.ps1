# Change the color of error and warning text
$opt = (Get-Host).PrivateData
$opt.WarningBackgroundColor = "Yellow"
$opt.WarningForegroundColor = "Black"
$opt.ErrorBackgroundColor = "red"
$opt.ErrorForegroundColor = "white"
$opt.VerboseForegroundColor = "white"
$opt.VerboseBackgroundColor = "black"
Clear-Host

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}


$env:CetusScriptRoot = $PSScriptRoot
#Import Modules
Get-ChildItem -Path "$env:CetusScriptRoot\Modules\*.psm1" | Import-Module -Force -Verbose

#Set Log File
$LogFile = "C:\Cetus\Logs\_CitrixBuild.log"

Write-Log -Path $LogFile -Message "Checking Modules..."

Try { 
    If (!(Get-Module -ListAvailable -Name PoshRSJob)) 
        { 
            Write-Log -Path $LogFile -Message "Installing Jobs Module"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            #Register-PSRepository -Default
            #Register-PSRepository -Name "PSGallery" –SourceLocation "https://www.powershellgallery.com/api/v2/" -InstallationPolicy Trusted 
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            Install-Module PoshRSJob -Verbose -Force
        }
    If (!(Get-Module -Name PoshRSJob)) { Import-Module PoshRSJob -Verbose }

    If (!(Get-Module -ListAvailable -Name ServerManager))
        {
            Write-Log -Path $LogFile -Message "RSAT isn't installed, install RSAT first! (or run on a server OS)" -Level Warn
            Start https://www.microsoft.com/en-us/download/confirmation.aspx?id=45520
            Exit
        }
    If (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
        Install-WindowsFeature -Name RSAT-AD-Powershell
        Import-Module ActiveDirectory,GroupPolicy
    } else {Import-Module ActiveDirectory,GroupPolicy -Force}
}
catch { 
    Write-Log -Path $LogFile -Message $_.Exception -level Error
    throw $_.Exception
}

#load Paramaters
Write-Log -Path $LogFile -Message "Starting Build"
Write-Log -Path $LogFile -Message "Loading Parameters"
$ParametersFile = "$env:CetusScriptRoot\parameters.json"
    If (Test-JSONFile -JSONFile $ParametersFile) { $ScriptParameters = (Get-Content -Path $ParametersFile | ConvertFrom-Json) }
    else { 
            Write-Log "Parameters file not found or not valid, creating new parameters file" -Path $LogFile
            Set-Parameters
            $ScriptParameters = Get-Content -Path $ParametersFile | ConvertFrom-Json
          }
Write-Log -Path $LogFile -Message "Loaded Parameters"


$SourceFiles = $null
("$PSScriptRoot\Software\*FSLogix*.zip", "$PSScriptRoot\Software\CitrixOptimizer.zip", "$PSScriptRoot\Software\setup-BIS-F*.exe.zip", `
    "$PSScriptRoot\Software\Workspace-Environment-Management*.zip", "$PSScriptRoot\Software\*Citrix*.iso") | `
ForEach {
    If (!(Test-Path -Path $_ -PathType Leaf))
        { Write-Log -Path $LogFile -Message "Could not find $_" -Level Error
          throw "Could not find $_"
        }
    $SourceFiles += @( Get-Item $_ | Select -First 1 )
}
Try {
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $SourceFiles[0] -DestinationFolder "C:\Cetus\Software\FSLogix"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $SourceFiles[1] -DestinationFolder "C:\Cetus\Software\CitrixOptimizer"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $SourceFiles[2] -DestinationFolder "C:\Cetus\Software\BIS-F"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $SourceFiles[3] -DestinationFolder "C:\Cetus\Software\WEM"
        Copy-FromISO -CurrentLogFile $LogFile -Source $SourceFiles[4] -Destination "C:\Cetus\Software\CVAD"
    }
catch {
    Write-Log -Message $_.Exception -Path $LogFile -Level Error
    throw $_
}

#Reset Jobs
$Jobs = $null
#Install Infrastructure Components        
ForEach ($server in $ScriptParameters.Servers) { 
  
    $ServerProducts = $server.Products.name
    $ServerAddress = $server.Address
    $ServerLogFile = ("C:\Cetus\Logs\" + $ServerAddress + ".ctxinf.log")
    $ServerTranscriptFile = ("C:\Cetus\Logs\" + $ServerAddress + ".transcript.log")
        
    $SBjob = {
            
            #Start a transcript
            #Start-Transcript -Path $Using:ServerTranscriptFile -Verbose
            
            #Import Modules
            Get-ChildItem -Path "$env:CetusScriptRoot\Modules\*.psm1" | Import-Module -Force -Verbose -ErrorAction Stop
            
            #Import Script Params
            $ParametersFile = "$env:CetusScriptRoot\parameters.json"
            $ScriptParameters = (Get-Content -Path $ParametersFile | ConvertFrom-Json)

            Try {
                 Install-CitrixProduct -TargetMachine $Using:ServerAddress -Products ($Using:serverProducts) -LogFile $Using:ServerLogFile
            }
            Catch {
                Write-Log -Path $Using:ServerLogFile -Message $_.Exception.Message -Level Error
                throw $_.Exception.Message
            }

        }
    Write-Log -Path $LogFile -Message "Starting Citrix Install on $ServerAddress. Log File: $ServerLogFile"
    $Jobs += @(Start-RSJob -ScriptBlock $SBjob -Name $serverAddress)
}



ForEach ($VDA in $ScriptParameters.VDAs) { 
  
    
    [string]$VDAAddress = $VDA.Address
    [string]$VDALogFile = ("C:\Cetus\Logs\" + $VDAAddress + ".vda.log")
    [bool]$InstallFSLogix = $VDA.InstallFSLogix
    [string]$FSLogixLicenseKey = $VDA.FSLogixLicenseKey.ToString()
    [bool]$PVS = $VDA.PVS
    [bool]$AppV = $VDA.AppV
    [bool]$CitrixFiles = $VDA.CitrixFiles
    [bool]$WorkspaceApp = $VDA.WorkspaceApp
    [bool]$InstallWEM = $VDA.InstallWEM
    
        
    $SBjob = {
            
            #Start a transcript
            #Start-Transcript -Path $Using:ServerTranscriptFile -Verbose
            
            #Import Modules
            Get-ChildItem -Path "$env:CetusScriptRoot\Modules\*.psm1" | Import-Module -Force -Verbose -ErrorAction Stop
            
            #Import Script Params
            $ParametersFile = "$env:CetusScriptRoot\parameters.json"
            $ScriptParameters = (Get-Content -Path $ParametersFile | ConvertFrom-Json)

            Try {
                 Install-VDA -TargetMachine $Using:VDAAddress -CurrentLogFile $Using:VDALogFile -InstallFSLogix $Using:InstallFSLogix -FSLogixLicenseKey $Using:FSLogixLicenseKey -PVS $Using:PVS -AppV $Using:AppV -CitrixFiles $Using:CitrixFiles -WorkSpaceApp $Using:WorkspaceApp -InstallWEM $Using:InstallWEM
            }
            Catch {
                Write-log -path $Using:VDALogFile -Message $_.Exception -Level Error
                throw $_.Exception
            }

        }
    Write-Log -Path $LogFile -Message "Starting VDA Install on $VDAAddress. Log File: $VDALogFile"
    $Jobs += @(Start-RSJob -ScriptBlock $SBjob -Name $VDAAddress)
}

#Install WEM
ForEach ($server in $ScriptParameters.WEMServers) { 
  
    $ServerAddress = $server.Address
    $ServerLogFile = ("C:\Cetus\Logs\" + $ServerAddress + ".wem.log")
        
    $SBjob = {
            
            #Import Modules
            Get-ChildItem -Path "$env:CetusScriptRoot\Modules\*.psm1" | Import-Module -Force -Verbose -ErrorAction Stop
            
            #Import Script Params
            $ParametersFile = "$env:CetusScriptRoot\parameters.json"
            $ScriptParameters = (Get-Content -Path $ParametersFile | ConvertFrom-Json)
            Try {
                    Install-WEM -TargetMachine $Using:ServerAddress -LogFile $Using:ServerLogFile
                }
            Catch {
                Write-Log -Path $Using:ServerLogFile -Message $_.Exception -Level Error
                throw $_.Exception
            }
        }
    
    if ($Jobs.Name -contains $ServerAddress) 
        {
            Write-Log -Path $LogFile -Message "WEM: A Job is already running on $ServerAddress. Waiting for job to complete."
            Start "C:\Cetus\Logs"
            $Jobs| ? {$_.Name -eq $ServerAddress} | Wait-RSJob
        }
    Write-Log -Path $LogFile -Message "Starting WEM Install on $ServerAddress. Log File: $ServerLogFile"
    
    $Jobs += @(Start-RSJob -ScriptBlock $SBjob -Name $serverAddress)
}


Write-Log -Path $LogFile -Message "Waiting for jobs to complete. This might take a while"
Start "C:\Cetus\Logs"
If ($Jobs -ne $null) {$Jobs | Wait-RSJob}
Write-Log -Path $LogFile -Message "Jobs have completed."

if ($ScriptParameters.AD.ConfigureGPO = $true) {
    Write-Log -Path $LogFile -Message "Importing GPO's to AD"
    Try { 
        Copy-RoboMirror -SourceDirectory "$env:CetusScriptRoot\GPO" -DestinationDirectory "C:\Cetus\GPO" -CurrentLogFile $LogFile
        if ($ScriptParameters.VDAs.Count -gt 0) { 
            $VDA = $ScriptParameters.VDAs[0].Address
        } else {
            $VDA = $null
        }
        Publish-GPOtoAD -CurrentLogFile $LogFile -VDA $VDA
        Write-Log -Path $LogFile -Message "Imported GPO's to AD"
    }
    
    catch { Write-Log -Path $LogFile -Message $_.Exception }

$Jobs | forEach { 
        
        if ( $_.HasErrors -eq $true )
            { 
                Write-Log -Path $LogFile -message (  $_.Name + " finished with errors. Check logs for more information C:\Cetus\ on both this machine and the target." ) -Level Warn
            }

        else
            {
                Write-Log -Path $LogFile -message ( $_.Name + " finished successfully")
            }
    }


    
    

        
}

Write-Log -Path $LogFile -Message "Build Complete"