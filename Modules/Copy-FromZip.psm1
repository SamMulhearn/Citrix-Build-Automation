Function Copy-FromZip {
    [CmdletBinding()] 
    param (

           [Parameter(Mandatory=$true)] 
           [Alias('LogFile')] 
           [string]$CurrentLogFile='C:\Logs\PowerShellLog.log',

           [Parameter(Mandatory=$true)] 
           [string]$ZipFile,

           [Parameter(Mandatory=$true)] 
           [string]$DestinationFolder
    )
    
    begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 

    process {
        Try {
                #If destination folder exists, delete the folder.
                if (!(Test-Path $ZipFile -PathType Leaf))
                    {
                        throw "$ZipFile not found"
                    }
                If (Test-Path $DestinationFolder -PathType Container)
                    { Remove-Item $DestinationFolder -Force -Recurse -ErrorAction SilentlyContinue }
                New-Item -Path $DestinationFolder -ItemType directory -Force |Out-Null
    
                #Extract Zip
                Write-Log "Extracting $ZipFile to $DestinationFolder" -Path $CurrentLogFile
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $DestinationFolder)
            }
        catch {
                throw $_.Exception
        }
        Write-Log "Extracted $ZipFile to $DestinationFolder"
    }
    end {}
}

Export-ModuleMember Copy-FromZip