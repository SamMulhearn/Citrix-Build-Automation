@echo off
@echo new-module -name CitrixBuild -scriptblock { > web.txt
type *.psm1 >> web.txt
@echo export-modulemember -Function Copy-FromISO,Copy-FromZip,Publish-GPOtoAD,Copy-RoboMirror,Get-OrdinalNumber,Read-BooleanQuestion,Select-Products,Set-Parameters,Initialize-Machine,Install-CitrixProduct,Install-Software,Install-VDA,Install-WEM,Install-WinRolesAndFeatures,Test-JSONFile,Write-Log } >> web.txt