function Set-CCMClientAlwaysOnInternet {
    <#
        .SYNOPSIS
            Set the ClientAlwaysOnInternet registry key on a computer
        .DESCRIPTION
            This function leverages the Set-CCMRegistryProperty function in order to configure
            the ClientAlwaysOnInternet property for the MEMCM Client.
        .PARAMETER Status
            Determines if the setting should be Enabled or Disabled
        .PARAMETER CimSession
            Provides CimSessions to set the ClientAlwaysOnInternet setting for
        .PARAMETER ComputerName
            Provides computer names to set the ClientAlwaysOnInternet setting for
        .PARAMETER PSSession
            Provides PSSessions to set the ClientAlwaysOnInternet setting for
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to.
        .EXAMPLE
            C:\PS> Set-CCMClientAlwaysOnInternet -Status Enabled
                Sets ClientAlwaysOnInternet to Enabled for the local computer
        .EXAMPLE
            C:\PS> Set-CCMClientAlwaysOnInternet -ComputerName 'Workstation1234','Workstation4321' -Status Disabled
                Sets ClientAlwaysOnInternet to Disabled for 'Workstation1234', and 'Workstation4321'
        .NOTES
            FileName:    Set-CCMClientAlwaysOnInternet.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-02-13
            Updated:     2020-02-27
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enabled', 'Disabled')]
        [string]$Status,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CimSession')]
        [Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ComputerName')]
        [Alias('Connection', 'PSComputerName', 'PSConnectionName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:ComputerName,
        [Parameter(Mandatory = $false, ParameterSetName = 'PSSession')]
        [Alias('Session')]      
        [System.Management.Automation.Runspaces.PSSession[]]$PSSession,
        [Parameter(Mandatory = $false, ParameterSetName = 'ComputerName')]
        [ValidateSet('CimSession', 'PSSession')]
        [string]$ConnectionPreference
    )
    begin {
        $Enablement = switch ($Status) {
            'Enabled' {
                1
            }
            'Disabled' {
                0
            }
        }
        $SetAlwaysOnInternetSplat = @{
            Force        = $true
            PropertyType = 'DWORD'
            Property     = 'ClientAlwaysOnInternet'
            Value        = $Enablement
            Key          = 'SOFTWARE\Microsoft\CCM\Security'
            RegRoot      = 'HKEY_LOCAL_MACHINE'
        }
    }
    process {
        foreach ($Connection in (Get-Variable -Name $PSCmdlet.ParameterSetName -ValueOnly)) {
            $getConnectionInfoSplat = @{
                $PSCmdlet.ParameterSetName = $Connection
            }
            switch ($PSBoundParameters.ContainsKey('ConnectionPreference')) {
                $true {
                    $getConnectionInfoSplat['Prefer'] = $ConnectionPreference
                }
            }
            $ConnectionInfo = Get-CCMConnection @getConnectionInfoSplat
            $Computer = $ConnectionInfo.ComputerName
            $connectionSplat = $ConnectionInfo.connectionSplat

            try {
                Set-CCMRegistryProperty @SetAlwaysOnInternetSplat @connectionSplat
            }
            catch {
                Write-Error "Failure to set MEMCM ClientAlwaysOnInternet to $Enablement for $Computer - $($_.Exception.Message)"
            }
        }
    }
}