#Internal Function to validate JSON file
Function Test-JSONFile
{
    Param ([string]$JSONFile)
    try {
        Get-Content -Path $JSONFile -ErrorAction Stop| ConvertFrom-Json -ErrorAction Stop;
        $validJson = $true;
    } catch {
        $validJson = $false;
    }

    if ($validJson) {
        return $true;
    } else {
        return $false;
    } 
}
