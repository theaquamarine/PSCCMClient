function Get-CCMLastHardwareInventory {
    <#
    .SYNOPSIS
        Returns info about the last time Hardware Inventory ran
    .DESCRIPTION
        This function will return info about the last time Hardware Inventory was ran. This is pulled from the InventoryActionStatus WMI Class.
        The hardware inventory major, and minor version is included. This can be helpful in troubleshooting hardware inventory issues.
    .PARAMETER CimSession
        Provides CimSession to gather hardware inventory last run info from
    .PARAMETER ComputerName
        Provides computer names to gather hardware inventory last run info from
    .EXAMPLE
        C:\PS> Get-CCMLastHardwareInventory
            Returns info regarding the last hardware inventory cycle for the local computer
    .EXAMPLE
        C:\PS> Get-CCMLastHardwareInventory -ComputerName 'Workstation1234','Workstation4321'
            Returns info regarding the last hardware inventory cycle for Workstation1234, and Workstation4321
    .NOTES
        FileName:    Get-CCMLastHardwareInventory.ps1
        Author:      Cody Mathis
        Contact:     @CodyMathis123
        Created:     2020-01-01
        Updated:     2020-01-18
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    [Alias('Get-CCMLastHINV')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CimSession')]
        [Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ComputerName')]
        [Alias('Connection', 'PSComputerName', 'PSConnectionName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:ComputerName
    )
    begin {
        $getLastHinvSplat = @{
            Namespace = 'root\CCM\InvAgt'
            Query     = "SELECT LastCycleStartedDate, LastReportDate, LastMajorReportVersion, LastMinorReportVersion, InventoryActionID FROM InventoryActionStatus WHERE InventoryActionID = '{00000000-0000-0000-0000-000000000001}'"
        }
        $connectionSplat = @{ }
    }
    process {
        foreach ($Connection in (Get-Variable -Name $PSCmdlet.ParameterSetName -ValueOnly)) {
            $getConnectionInfoSplat = @{
                $PSCmdlet.ParameterSetName = $Connection
            }
            $ConnectionInfo = Get-CCMConnection @getConnectionInfoSplat
            $Computer = $ConnectionInfo.ComputerName
            $connectionSplat = $ConnectionInfo.connectionSplat

            $Result = [ordered]@{ }
            $Result['ComputerName'] = $Computer

            try {
                [ciminstance[]]$LastHinv = Get-CimInstance @getLastHinvSplat @connectionSplat
                if ($LastHinv -is [Object] -and $LastHinv.Count -gt 0) {
                    foreach ($Occurrence in $LastHinv) {
                        $Result['LastCycleStartedDate'] = $Occurrence.LastCycleStartedDate
                        $Result['LastReportDate'] = $Occurrence.LastReportDate
                        $Result['LastMajorReportVersion'] = $Occurrence.LastMajorReportVersion
                        $Result['LastMinorReportVersion'] = $Occurrence.LastMinorReportVersion
                        [PSCustomObject]$Result
                    }
                }
                else {
                    Write-Warning "No hardware inventory run found for $Computer"
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}