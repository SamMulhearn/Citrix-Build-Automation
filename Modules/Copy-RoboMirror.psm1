Function Copy-RoboMirror {
    [CmdletBinding()] 
    param (
            [Alias('Source')] 
            [String]$SourceDirectory,
            
            [Alias('Destination')] 
            [String]$DestinationDirectory,
            
            [Parameter(Mandatory=$true)] 
            [Alias('LogFile')] 
            [string]$CurrentLogFile='C:\Logs\PowerShellLog.log'

            )
            
            #$CurrentLogFile = ( (Get-Item $CurrentLogFIle).DirectoryName + "\" + (Get-Item $CurrentLogFIle).BaseName + "_robocopy.log" )


            $Args = @($SourceDirectory, $DestinationDirectory, "/MIR","/R:5", "/W:15" ,"/MT:4","/unilog+:$CurrentLogFile")
            Try {
                $process = Start-Process -FilePath "$env:SystemRoot\system32\Robocopy.exe" -ArgumentList $Args -PassThru -Wait -Verb runAs -WindowStyle Hidden
            }
            catch { throw $_.Exception}

            If ($process.ExitCode -notin (0,1,4))
                {
                    
                    throw ("Copying files from $SourceDirectory to $DestinationDirectory Failed. the exitcode was "+ $process.ExitCode) 
                 }
}

Export-ModuleMember -Function Copy-RoboMirror