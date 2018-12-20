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
            Write-Log "Parameters file not found or not valid, creating new parameters file"
            Set-Parameters
            $ScriptParameters = Get-Content -Path $ParametersFile | ConvertFrom-Json
          }
Write-Log -Path $LogFile -Message "Loaded Parameters"

Try {
    #Mount Disk ISO
    Write-Log -Path $LogFile -Message "Mounting Disk Image"
  
    $ISO = Get-ChildItem -Path "$PSScriptRoot\Software\*Citrix*.iso" | Select -First 1
    if (!(Test-Path $ISO -PathType Leaf)) 
        { 
          Write-Log -Path $LogFile -Message "Couldn't find $PSScriptRoot\Software\*Citrix*.iso" -level Error
          Throw "Couldn't find $PSScriptRoot\Software\*Citrix*.iso"
        }
    
    $mount_params = @{ImagePath = $iso; PassThru = $true; ErrorAction = "Ignore"}
    $mount = Mount-DiskImage @mount_params
    if($mount) {
        $volume = Get-DiskImage -ImagePath $mount.ImagePath | Get-Volume
        Write-Log -path $LogFile -message ("Mounted $ISO to " + $volume.DriveLetter + ":\" )
    }
    else {
         Write-Log -Path $LogFile -Message ("ERROR: Could not mount $iso check if file is already in use") -level Error
         throw ("ERROR: Could not mount $iso check if file is already in use")
    }
}
catch {
    Write-Log -path $LogFile -message ($_.Exception) -level Error
    throw $_.Exception
}


#Extract ISO
Write-Log -Path $LogFile "Extracting CAVD ISO. This might take a few minutes"
Try {
        Copy-RoboMirror -SourceDirectory ( $volume.DriveLetter + ":\") -DestinationDirectory "C:\Cetus\Software\CAVD" -logFile $LogFile
    }
catch {
    Write-Log -Path $LogFile -Message "Failed to extract files from CAVD ISO"
    Write-Error $_.Exception.Message
    Write-Error $_.Exception.Message -ErrorAction Stop    
}
Write-Log -Path $LogFile "Extracted CAVD ISO"

#Dismount ISO
if (Dismount-DiskImage -ImagePath $mount.ImagePath -PassThru) {Write-Log -Path $LogFile -Message ("Dismounted " + $volume.DriveLetter + ":\")}    

$ZipFile = $null
("$PSScriptRoot\Software\*FSLogix*.zip", "$PSScriptRoot\Software\CitrixOptimizer.zip", "$PSScriptRoot\Software\setup-BIS-F*.exe.zip", "$PSScriptRoot\Software\Workspace-Environment-Management*.zip") | `
ForEach {
    If (!(Test-Path -Path $_ -PathType Leaf))
        { Write-Log -Path $LogFile -Message "Could not find $_" -Level Error
          throw "Could not find $_"
        }
    $ZipFile += @( Get-Item $_ | Select -First 1 )
}
Try {
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $ZipFile[0] -DestinationFolder "C:\Cetus\Software\FSLogix"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $ZipFile[1] -DestinationFolder "C:\Cetus\Software\CitrixOptimizer"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $ZipFile[2] -DestinationFolder "C:\Cetus\Software\BIS-F"
        Copy-FromZip -CurrentLogFile $LogFile -ZipFile $ZipFile[3] -DestinationFolder "C:\Cetus\Software\WEM"
    }
catch {
    Write-Log -Message $_.Exception -Path $LogFile -Level Error
    throw $_
}

#Reset Jobs
$Jobs = $null
Start "C:\Cetus\Logs"
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
            $Jobs| ? {$_.Name -eq $ServerAddress} | Wait-RSJob
        }
    Write-Log -Path $LogFile -Message "Starting WEM Install on $ServerAddress. Log File: $ServerLogFile"
    
    $Jobs += @(Start-RSJob -ScriptBlock $SBjob -Name $serverAddress)
}


Write-Log -Path $LogFile -Message "Waiting for jobs to complete. This might take a while"
$Jobs | Wait-RSJob
Write-Log -Path $LogFile -Message "Jobs have completed."

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

Write-Log -Path $LogFile -Message "Build Complete"