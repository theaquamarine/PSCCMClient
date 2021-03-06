function Test-CCMIsClientOnInternet {
    <#
        .SYNOPSIS
            Return the status of the MEMCM client being on the internet (CMG/IBCM)
        .DESCRIPTION
            This function will invoke the IsClientOnInternet of the MEMCM Client.
             This is done using the Microsoft.SMS.Client COM Object.
        .PARAMETER CimSession
            Provides CimSessions to return IsClientOnInternet setting info from
        .PARAMETER ComputerName
            Provides computer names to return IsClientOnInternet setting info from
        .PARAMETER PSSession
            Provides PSSession to return IsClientOnInternet setting info from
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to.
        .EXAMPLE
            C:\PS> Test-CCMIsClientOnInternet
                Returns the status of the local computer having IsClientOnInternet set
        .EXAMPLE
            C:\PS> Test-CCMIsClientOnInternet -ComputerName 'Workstation1234','Workstation4321'
                Returns the status of 'Workstation1234','Workstation4321' having IsIsClientOnInternet set
        .NOTES
            FileName:    Test-CCMIsClientOnInternet.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-01-29
            Updated:     2020-02-27
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param(
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
        $IsClientOnInternetScriptBlock = {
            $Client = New-Object -ComObject Microsoft.SMS.Client
            [bool]$Client.IsClientOnInternet()
        }
        $invokeCommandSplat = @{
            ScriptBlock = $IsClientOnInternetScriptBlock
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

            $Result = [ordered]@{ }
            $Result['ComputerName'] = $Computer

            try {
                switch ($Computer -eq $env:ComputerName) {
                    $true {
                        $Result['IsClientOnInternet'] = $IsClientOnInternetScriptBlock.Invoke()
                    }
                    $false {
                        $Result['IsClientOnInternet'] = Invoke-CCMCommand @invokeCommandSplat @connectionSplat
                    }
                }
                [pscustomobject]$Result
            }
            catch {
                Write-Error "Failure to determine if the MEMCM client is set to always be on the internet for $Computer - $($_.Exception.Message)"
            }
        }
    }
}