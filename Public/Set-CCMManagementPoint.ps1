function Set-CCMManagementPoint {
    <#
        .SYNOPSIS
            Sets the current management point for the MEMCM Client
        .DESCRIPTION
            This function will set the current management point for the MEMCM Client. This is done using the Microsoft.SMS.Client COM Object.
        .PARAMETER ManagementPointFQDN
            The desired management point that will be set for the specified computers/cimsessions
        .PARAMETER CimSession
            Provides CimSessions to set the current management point for
        .PARAMETER ComputerName
            Provides computer names to set the current management point for
        .EXAMPLE
            C:\PS> Set-CCMManagementPoint -ManagementPointFQDN 'cmmp1.contoso.com'
                Sets the local computer's management point to cmmp1.contoso.com
        .EXAMPLE
            C:\PS> Set-CCMManagementPoint -ComputerName 'Workstation1234','Workstation4321' -ManagementPointFQDN 'cmmp1.contoso.com'
                Sets the management point for Workstation1234, and Workstation4321 to cmmp1.contoso.com
        .NOTES
            FileName:    Set-CCMManagementPoint.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-01-18
            Updated:     2020-01-18
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ComputerName')]
    [Alias('Set-CCMMP')]
    param(
        [parameter(Mandatory = $true)]
        [string]$ManagementPointFQDN,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CimSession')]
        [Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ComputerName')]
        [Alias('Connection', 'PSComputerName', 'PSConnectionName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:ComputerName
    )
    begin {
        $connectionSplat = @{ }
        $invokeCIMPowerShellSplat = @{
            FunctionsToLoad = 'Set-CCMManagementPoint'
        }
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
            $Result['ManagementPointFQDNSet'] = $false

            if ($PSCmdlet.ShouldProcess("[ComputerName = '$Computer'] [ManagementPointFQDN = '$ManagementPointFQDN']", "Set-CCMManagementPoint")) {
                try {
                    switch ($Computer -eq $env:ComputerName) {
                        $true {
                            $Client = New-Object -ComObject Microsoft.SMS.Client
                            $Client.SetCurrentManagementPoint($ManagementPointFQDN, 1)
                        }
                        $false {
                            $ScriptBlock = [string]::Format('Set-CCMManagementPoint -ManagementPointFQDN ', $ManagementPointFQDN)
                            $invokeCIMPowerShellSplat['ScriptBlock'] = [scriptblock]::Create($ScriptBlock)
                            Invoke-CIMPowerShell @invokeCIMPowerShellSplat @connectionSplat
                        }
                    }
                    $Result['ManagementPointFQDNSet'] = $true
                }
                catch {
                    Write-Error "Failure to set management point to $ManagementPointFQDN for $Computer - $($_.Exception.Message)"
                }
                [pscustomobject]$Result
            }
        }
    }
}