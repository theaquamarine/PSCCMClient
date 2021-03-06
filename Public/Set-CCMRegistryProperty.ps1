function Set-CCMRegistryProperty {
    <#
        .SYNOPSIS
            Set registry properties values using the CIM StdRegProv, or Invoke-CCMCommand
        .DESCRIPTION
            Relies on remote CIM and StdRegProv to allow for setting a Registry Property value. If a PSSession, or ConnectionPreference
            is used, then Invoke-CCMCommand is used instead.
        .PARAMETER RegRoot
            The root key you want to search under
            ('HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG', 'HKEY_DYN_DATA', 'HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER')
        .PARAMETER Key
            The key you want to set properties of. (ie. SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties)
        .PARAMETER Property
            The property name you want to set the value for
        .PARAMETER Value
            The desired value for the property
        .PARAMETER PropertyType
            The type of property you are setting. This is needed because the method for setting a registry value changes based on property type.
            'String', 'ExpandedString', 'Binary', 'DWORD', 'MultiString', 'QWORD'
        .PARAMETER Force
            Create the Property if it does not exist, otherwise only existing properties will have their value modified
        .PARAMETER CimSession
            Provides CimSessions to set registry properties for
        .PARAMETER ComputerName
            Provides computer names to set registry properties for
        .PARAMETER PSSession
            Provides PSSessions to set registry properties for
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to.
        .EXAMPLE
            PS> Set-CCMRegistryProperty -RegRoot HKEY_LOCAL_MACHINE -Key 'SOFTWARE\Microsoft\SMS\Client\Client Components\Remote Control' -Property "Allow Remote Control of an unattended computer" -Value 1 -PropertyType DWORD
            Name                           Value
            ----                           -----
            Computer123                    $true
        .OUTPUTS
            [System.Collections.Hashtable]
        .NOTES
            FileName:    Set-CCMRegistryProperty.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     Uhh... I forget
            Updated:     2020-03-02
#>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ComputerName')]
    [Alias('Set-CIMRegistryProperty')]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet('HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG', 'HKEY_DYN_DATA', 'HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER')]
        [string]$RegRoot,
        [parameter(Mandatory = $true)]
        [string]$Key,
        [parameter(Mandatory = $true)]
        [string]$Property,
        [parameter(Mandatory = $true)]
        $Value,
        [parameter(Mandatory = $true)]
        [ValidateSet('String', 'ExpandedString', 'Binary', 'DWORD', 'MultiString', 'QWORD')]
        [string]$PropertyType,
        [parameter(Mandatory = $false)]
        [switch]$Force,
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
        #region create hash tables for translating values
        $RootKey = @{
            HKEY_CLASSES_ROOT   = 2147483648
            HKEY_CURRENT_USER   = 2147483649
            HKEY_LOCAL_MACHINE  = 2147483650
            HKEY_USERS          = 2147483651
            HKEY_CURRENT_CONFIG = 2147483653
            HKEY_DYN_DATA       = 2147483654
        }
        <#
            Maps the 'PropertyType' per property to the method we will invoke to set the value.
            For example, if the 'type' is string we have invoke the SetStringValue method
        #>
        $RegPropertyMethod = @{
            'String'         = 'SetStringValue'
            'ExpandedString' = 'SetExpandedStringValue'
            'Binary'         = 'SetBinaryValue'
            'DWORD'          = 'SetDWORDValue'
            'MultiString'    = 'SetMultiStringValue'
            'QWORD'          = 'SetQWORDValue'
        }
        $Method = $RegPropertyMethod[$PropertyType]
        #endregion create hash tables for translating values

        # convert RootKey friendly name to the [uint32] equivalent so it can be used later
        $Root = $RootKey[$RegRoot]

        #region define our hash tables for parameters to pass to Get-CIMInstance and our return hash table
        $setCIMRegPropSplat = @{
            Namespace   = 'root\default'
            ClassName   = 'StdRegProv'
            ErrorAction = 'Stop'
        }
        #endregion define our hash tables for parameters to pass to Get-CIMInstance and our return hash table

        $PropertyTypeMap = @{
            SetDWORDValue          = [UInt32]
            SetQWORDValue          = [UInt64]
            SetStringValue         = [String]
            SetMultiStringValue    = [String[]]
            SetExpandedStringValue = [String]
            SetBinaryValue         = [byte[]]
        }

        $ReturnValName = @{
            SetDWORDValue          = 'uValue'
            SetQWORDValue          = 'uValue'
            SetStringValue         = 'sValue'
            SetMultiStringValue    = 'sValue'
            SetExpandedStringValue = 'sValue'
            SetBinaryValue         = 'uValue'
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

            $Return = [ordered]@{ }
            $Return[$Computer] = $false

            if ($PSCmdlet.ShouldProcess("[ComputerName = '$Computer'] [sValueName = '$Property'] [Value = '$Value']", "Set-CCMRegistryProperty")) {
                switch -regex ($ConnectionInfo.ConnectionType) {
                    '^CimSession$|^ComputerName$' {
                        $setCIMRegPropSplat['MethodName'] = 'EnumValues'
                        $setCIMRegPropSplat['Arguments'] = @{
                            hDefKey     = [uint32]$Root
                            sSubKeyName = $Key
                        }

                        $EnumValues = Invoke-CimMethod @setCIMRegPropSplat @connectionSplat

                        $setCIMRegPropSplat['MethodName'] = $Method
                        $setCIMRegPropSplat['Arguments']['sValueName'] = $Property
                        $setCIMRegPropSplat['Arguments'][$ReturnValName[$Method]] = $Value -as $PropertyTypeMap[$Method]

                        switch ($EnumValues.sNames -contains $Property) {
                            $true {
                                $SetProperty = Invoke-CimMethod @setCIMRegPropSplat @connectionSplat
                            }
                            $false {
                                switch ($Force.IsPresent) {
                                    $true {
                                        $SetProperty = Invoke-CimMethod @setCIMRegPropSplat @connectionSplat
                                    }
                                    $false {
                                        Write-Warning ([string]::Format('[Property = {0}] does not exist under [Key = {1}\{2}] and the force parameter was not specified. No changes will be made', $Property, $RegRoot, $Key))
                                    }
                                }
                            }
                        }
                        if ($null -ne $SetProperty) {
                            switch ($SetProperty.ReturnValue) {
                                0 {
                                    $Return[$Computer] = $true
                                }
                                default {
                                    Write-Error ([string]::Format('Failed to set value [Property = {0}] [Key = {1}\{2}] [Value = {3}] [PropertyType = {4}] [Method = {5}]', $Property, $RegRoot, $Key, $Value, $PropertyType, $Method))
                                }
                            }
                        }
                    }
                    '^PSSession$' {
                        $RegPath = [string]::Format('registry::{0}\{1}', $RegRoot, $Key)
                        $InvokeCommandSplat = @{
                            ArgumentList = $RegPath, $Property, $Value, $PropertyType, $Force.IsPresent
                        }

                        $InvokeCommandSplat['ScriptBlock'] = {
                            param(
                                $RegPath,
                                $Property,
                                $Value,
                                $PropertyType,
                                $Force
                            )
                            $Exists = Get-ItemProperty -Path $RegPath -Name $Property -ErrorAction SilentlyContinue
                            try {
                                switch ([bool]$Exists) {
                                    $true {
                                        Set-ItemProperty -Path $RegPath -Name $Property -Value $Value -Type $PropertyType -ErrorAction Stop
                                        Write-Output $true
                                    }
                                    $false {
                                        switch ([bool]$Force) {
                                            $true {
                                                Set-ItemProperty -Path $RegPath -Name $Property -Value $Value -Type $PropertyType -ErrorAction Stop
                                                Write-Output $true
                                            }
                                            $false {
                                                Write-Warning ([string]::Format('[Property = {{0}}] does not exist under [Key = {{1}}] and the force parameter was not specified. No changes will be made', $Property, $RegPath))
                                                Write-Output $false
                                            }
                                        }
                                    }
                                }
                            }
                            catch {
                                Write-Error $_.Exception.Message
                                Write-Output $false
                            }
                        }
                        
                        $Return[$Computer] = Invoke-CCMCommand @InvokeCommandSplat @connectionSplat
                    }
                }

                Write-Output $Return
            }
        }
    }
}