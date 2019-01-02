function Copy-FromISO { 
   [CmdletBinding()] 
   param ([String]$TargetMachine,

           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log',

           [Parameter(Mandatory=$true)] 
           [string]$Destination,
           
           [Parameter(Mandatory=$true)] 
           [string]$Source


    ) 
 
   begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 
   Process {
    #Mount Disk ISO
    Write-Log -Path $CurrentLogFile -Message "Mounting $Source"
  
        
    $Source
    If (!(Test-Path -Path $Source -PathType Leaf))
        {
            throw "Couldn't find $Source"
        }
        
    $Source = (Get-ChildItem -Path $Source -File | Select -First 1)
        
    $mount_params = @{ImagePath = $Source; PassThru = $true; ErrorAction = "Ignore"}
    $mount = Mount-DiskImage @mount_params
    if($mount) {
        $volume = Get-DiskImage -ImagePath $mount.ImagePath | Get-Volume
        Write-Log -path $CurrentLogFile -message ("Mounted $Source to " + $volume.DriveLetter + ":\" )
        }
    else {
        Write-Log -Path $CurrentLogFile -Message ("ERROR: Could not mount $Source check if file is already in use") -level Error
        throw ("ERROR: Could not mount $Source check if file is already in use")
        }
        #Extract ISO
        Write-Log -Path $CurrentLogFile "Extracting $Source to $Destination. This might take a few minutes"
        Try { Copy-RoboMirror -SourceDirectory ( $volume.DriveLetter + ":\") -DestinationDirectory $Destination -logFile $CurrentLogFile }
        catch { throw $_.Exception }
    Write-Log -Path $CurrentLogFile "Extracted $Source to $Destination"
    #Dismount ISO
    if (Dismount-DiskImage -ImagePath $mount.ImagePath -PassThru) {Write-Log -Path $CurrentLogFile -Message ("Dismounted " + $volume.DriveLetter + ":\")}
    }
    end {}
}
