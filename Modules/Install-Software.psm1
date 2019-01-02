Function Install-Software {
    [CmdletBinding()] 
    param (
            [Parameter(Mandatory=$true)]
            [String]$TargetMachine,

            [Parameter(Mandatory=$true)]
            [String]$Executable,

            [Parameter(Mandatory=$true)]
            [String[]]$CommandArguments,

            [Parameter(Mandatory=$true)]
            [int[]]$RestartExitCodes,

            [Parameter(Mandatory=$true)]
            [int[]]$SuccessExitCodes,

            [Parameter(Mandatory=$true)] 
            [Alias('LogFile')] 
            [string]$CurrentLogFile

        )

    begin { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $ErrorActionPreference = 'Stop'
    } 

    process {
        Write-Log -Path $CurrentLogFile -Message ("Installing $Executable on $TargetMachine with the following parameters " + ($CommandArguments -join " "))

        $InstallScriptBlock = { 
                $env:SEE_MASK_NOZONECHECKS = 1
                $Executable = $args[($args.Count -1)]
                $args = $args[0..($args.Count-2)]
                $command = (Get-Item -path $Executable | Select -First 1).FullName
                $Process = Start-Process -FilePath $Executable -ArgumentList $args -Verb runAs -Wait -PassThru
                return $process.ExitCode
            }


        $ExitCode = $null
        Try {   
                #Repeat instalation until exit code not restart required.
                Do {
                    $session = New-PSSession -computername $TargetMachine
                    if ($ExitCode -ne $null) 
                        { Write-Log -Path $CurrentLogFile -Message ("Resuming $Executable Install on $TargetMachine") }
                    Else
                        { $CommandArguments += $Executable }
                    $ExitCode = Invoke-Command -Session $session -ScriptBlock $InstallScriptBlock -ArgumentList $CommandArguments
                    
                    If ($ExitCode -in $RestartExitCodes) 
                        {
                            Write-Log -Path $CurrentLogFile -Message "Restart required, restarting $TargetMachine"
                            Restart-Computer -ComputerName $TargetMachine -Wait -For PowerShell -Timeout 600 -Protocol WSMan  -Force
                        }
                     
                    }
                 While ($ExitCode -in $RestartExitCodes)
            }
                
        Catch { 
                throw $_.exception
              }

        If ($ExitCode -eq 0)
            { Write-Log "Successfully installed $Executable on $TargetMachine" -path $CurrentLogFile}
        else
            {
                $HEXExitCode = "{0:x}" -f $ExitCode
                throw "Failed to install $Exectuable on $TargetMachine, error code was $ExitCode. The HEX error code was $HEXExitCode."
                
            }
    }
    end {}
}
