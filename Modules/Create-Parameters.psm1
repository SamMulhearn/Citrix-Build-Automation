Function Get-OrdinalNumber {
    Param(
        [Parameter(Mandatory=$true)]
        [int64]$num
    )

    $Suffix = Switch -regex ($Num) {
        '1(1|2|3)$' { 'th'; break }
        '.?1$'      { 'st'; break }
        '.?2$'      { 'nd'; break }
        '.?3$'      { 'rd'; break }
        default     { 'th'; break }
    }
    Write-Output "$Num$Suffix"
}

Function Read-BooleanQuestion {
    param (
            [String]$Question
            )
    
    $answer = Read-Host "$Question [Y]es or [N]o"
    while("yes","no","y","n" -notcontains $answer)
    {
	    $answer = Read-Host "$Question [Y]es or [N]o"
    }

    Switch ($answer.ToLower()) {
        "yes" { return $true}
        "y" { return $true}
        "no" { return $false}
        "n" { return $false}
    }
}


Function Select-Products {
    
    [CmdletBinding()] 
    param (
            [String]$Address
            )
    
    
    Write-Host "Select products to install on $Address";
    Write-Host 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); 
     
     $Menu = [ordered]@{
      1 = 'STOREFRONT'
      2 = 'CONTROLLER'
      3 = 'DESKTOPDIRECTOR'
      4 = 'DESKTOPSTUDIO'
      5 = 'LICENSESERVER'
      }
     $Result = $Menu | Out-GridView -PassThru  -Title "What products would you like to install on $address. Hold CTRL or Shift to select multiple products"


        
    $Products = @()
    $Result | foreach {
        $Products += @{name = $_.Value}
    }
    return $Products    
}
     
Function Set-Parameters {
    $Message =  

"
The parameters file was not found, creating a new parameters file...

The parameters for this script are configured in four parts.

Part 1: Nominate machines to install the following components on:

- Delivery Controller
- StoreFront
- License Server
- Citrix Studio
- Citrix Director

Part 2: Nominate machines to install the VDA and associated components on.

Part 3: Nominate machines to install the WEM Infrastructure component on.

Part 4: Configure the setup for AD
"

    Write-Host $Message
    Write-Host 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

    Write-Host "Part 1: - Delivery Controller, StoreFront, License Server, Citrix Studio, Citrix Director"
    [int]$Qty = Read-Host "On how many servers would you like to install one or more of the above products on?"


    $Servers = @()
    
    if ($Qty -gt 0 ) {
        
        1..$Qty| ForEach {
            $OrdNum = Get-OrdinalNumber -num $_
            $Address =  Read-Host "What is the IP address or FQDN of the $OrdNum server?"
            $Products = Select-Products -Address $Address
            $line = [pscustomobject]@{Address=$Address; Products=$Products}
            $servers += @($line)
        }
    }
    
    
    $VDAs = @()

    Write-Host "Part 2: VDA"
    [int]$Qty = Read-Host "How many machines would you like to install the VDA on?"

    if ($Qty -gt 0 ) {

        1..$Qty| ForEach {
            $OrdNum = Get-OrdinalNumber -num $_
            $Address =  Read-Host "What is the IP address or FQDN of the $OrdNum machine?"
            $InstallFSLogix = Read-BooleanQuestion -Question "Would you like to install FSLogix on $Address`?"
            if ($InstallFSLogix -eq $true)
                
                {   If (!(Read-BooleanQuestion -Question "Would you like to use an FSLogix 30 day trial?"))
                        { $FSLogixLicenseKey = (Read-Host -Prompt "Enter the FSLogix license key.") }
                    else { $FSLogixLicenseKey = ""}
                }
            else { $FSLogixLicenseKey = "" }
            $PVS = Read-BooleanQuestion -Question "Are you using PVS with $Address`?"
            $AppV = Read-BooleanQuestion -Question "Are you using AppV with $Address`?"
            $CitrixFiles = Read-BooleanQuestion -Question "Would you like to install Citrix Files on $Address`?"
            $WorkspaceApp = Read-BooleanQuestion -Question "Would you like to install the Workspace App on $Address`?"
            $InstallWEM = Read-BooleanQuestion -Question "Would you like to install the WEM agent on $Address`?"
            $line = [pscustomobject]@{Address=$Address; InstallFSLogix=$InstallFSLogix ;FSLogixLicenseKey=$FSLogixLicenseKey; PVS=$PVS; AppV=$AppV; CitrixFiles=$CitrixFiles; WorkspaceApp=$WorkspaceApp; InstallWEM=$InstallWEM }    
            $VDAs += @($line)
        }
    }
    
    Write-Host "Part 3: WEM"
    [int]$Qty = Read-Host "How many machines would you like to install the WEM infrastructure component on?"

    $WEMServers = @()
    if ($Qty -gt 0 ) {
        
        1..$Qty| ForEach {
            $OrdNum = Get-OrdinalNumber -num $_
            $Address =  Read-Host "What is the IP address or FQDN of the $OrdNum server?"
            $line = [pscustomobject]@{Address=$Address}
            $WEMservers += @($line)
        }
    }

    Write-Host "Part 4: AD"
    $AD = $null
    $ConfigureGPO = Read-BooleanQuestion -Question "Would you like to import the GPO templates into AD?"
    #if ($ConfigureAD -eq $true)
    #    {
    #        $BaseOU = Read-Host "What is the Base OU? e.g. DC=Domain,DC=Local"
    #        $Domain = Read-Host "What is the FQDN for the Domain? e.g. domain.local"
    #    }
    $AD = [pscustomobject]@{ConfigureGPO=$ConfigureGPO } #; BaseOU=$BaseOU ;Domain=$Domain }    


    $ScriptParameters = [pscustomobject]@{Servers=$Servers; VDAs=$VDAs; WEMServers=$WEMservers; AD=$AD}  

    $ScriptParameters | ConvertTo-Json -Depth 4| Out-File "$env:CetusScriptRoot\parameters.json" -Force
    Write-Host "Saved parameters to $env:CetusScriptRoot\parameters.json"

    Write-Host 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); 

}


Export-ModuleMember Read-BooleanQuestion,Set-Parameters,Get-OrdinalNumber