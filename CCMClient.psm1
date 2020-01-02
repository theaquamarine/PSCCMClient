$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase

#region Load Public Functions
Try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
}
Catch {
    Write-Warning ("{0}: {1}" -f $Function, $_.Exception.Message)
    Continue
}
#endregion Load Public Functions

#region Load Private Functions
Try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
}
Catch {
    Write-Warning ("{0}: {1}" -f $Function, $_.Exception.Message)
    Continue
}
#endregion Load Private Functions

# #region Format and Type Data
# Try {
#     Update-FormatData "$ScriptPath\TypeData\CCMClient.Format.ps1xml" -ErrorAction Stop
# }
# Catch {
# }
# Try {
#     Update-TypeData "$ScriptPath\TypeData\CCMClient.Types.ps1xml" -ErrorAction Stop
# }
# Catch {
# }
# #endregion Format and Type Data

#region Export Module Members
$ExportModule = @{
    Alias    = @()
    Function =@('ConvertFromCCMSchedule',
    'Get-CCMBaseline',
    'Get-CCMCache',
    'Get-CCMClientDirectory',
    'Get-CCMClientLogDirectory',
    'Get-CCMLastHardwareInventory',
    'Get-CCMLastHeartbeat',
    'Get-CCMLastScheduleTrigger',
    'Get-CCMLastSoftwareInventory',
    'Get-CCMLogFile',
    'Get-CCMMaintenanceWindow',
    'Get-CCMPrimaryUser',
    'Get-CCMServiceWindow',
    'Get-CCMUpdate',
    'Invoke-CCMBaseline',
    'Invoke-CCMClientAction',
    'Invoke-CCMResetPolicy',
    'Invoke-CCMUpdate',
    'Repair-CCMCacheLocation',
    'Set-CCMCacheLocation',
    'Set-CCMCacheSize',
    'Write-CCMLogEntry')
    Variable = @()
}
Export-ModuleMember @ExportModule
#endregion Export Module Members

$env:PSModulePath = $PSModulePath
