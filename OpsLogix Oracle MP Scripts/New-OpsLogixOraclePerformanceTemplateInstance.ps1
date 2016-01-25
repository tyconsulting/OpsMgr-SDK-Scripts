Function New-OpsLogixOraclePerfTemplateInstance
{
<# 
 .Synopsis
  Create a OpsLogix Oracle Performance Collection Rule monitoring template instance in OpsMgr.

 .Description
  Create a OpsLogix Oracle Performance Collection Rule monitoring template instance in OpsMgr using OpsMgr SDK. A boolean value $true will be returned if the monitoring template instance creation has been successful, otherwise, a boolean value of $false is returned if any there are any errors occurred during the creation process.

 .Parameter -SDKConnection
  OpsMgr SDK Connection object (SMA/Azure Automation connection or hash table).

 .Parameter -SDK
  Management Server name

 .Parameter -UserName
  Alternative user name to connect to the management group (optional).

 .Parameter -Password
  Alternative password to connect to the management group (optional).

 .Parameter -MPName
  Name for the unsealed MP of which the OpsLogix Oracle Performance Collection Rule monitoring template instance is going to stored.

 .Parameter -DisplayName
  The OpsLogix Oracle Performance Collection Rule Template instance display name

 .Parameter -Description
  The OpsLogix Oracle Performance Collection Rule Template instance description

 .Parameter -CounterName
  The performance counter name

 .Parameter -Enabled
  Specify if the Rules and Monitors created by the template are enabled by default. this is a boolean parameter. the default value is set to $true if not specified.

 .Parameter -Query
  Specify the query to be executed by the Opslogix Oracle Performance Collection rule

 .Parameter -ReturnColumnName
  Specify the return column name from the query

 .Parameter -Target
  The target class of the Performance Collection rule. Possible values are (case insensitive): 'Instance'; 'Control File'; 'Data File'; 'Redo Log group'; 'Redo Log File'; "Table Space"

 .Parameter -LocaleId
  The Locale ID for the language pack items. This is an optional parameter, if not specifiied, the value "ENU" is used.

 .Parameter -QueryInterval
  The query interval in seconds, the default value is 300 (5 minutes) if it is not specified.

 .Parameter -IncreaseMPVersion
  Increase MP version by 0.0.0.1 (Increase revision by 1).

 .Example
  # Connect to OpsMgr management group via management server "OpsMgrMS01" and then create a OpsLogix Oracle Performance Collection Rule monitor template instance with the following properties:
   $parms = @{
        SDK = "OpsMgrMS01";
        UserName = "domain\SCOM.Admin"
        Password = $(ConvertTo-SecureString -AsPlainText "password1234" -force);
        MPName = "TYANG.Lab.Test";
        DisplayName = "Test Oracle Performance Collection rule";
        Description = "This is a test instance for the OpsLogix Oracle performance collection rule template";
        Enabled = $true;
        CounterName = "OrderCOUNT"
        Query = 'select count(*) "Order_COUNT" from sys.orders';
        ReturnColumnName = "Order_COUNT";
        Target="Instance";
        QueryInterval = 300
   }
  
  New-OpsLogixOraclePerfTemplateInstance @parms
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(ParameterSetName='SMAConnection',Mandatory=$true,HelpMessage='Please specify the SMA Connection object')][Alias('Connection','c')][Object]$SDKConnection,
		[Parameter(ParameterSetName='IndividualParameter',Mandatory=$true,HelpMessage='Please enter the Management Server name')][Alias('DAS','Server','s')][String]$SDK,
        [Parameter(ParameterSetName='IndividualParameter',Mandatory=$false,HelpMessage='Please enter the user name to connect to the OpsMgr management group')][Alias('u')][String]$Username = $null,
        [Parameter(ParameterSetName='IndividualParameter',Mandatory=$false,HelpMessage='Please enter the password to connect to the OpsMgr management group')][Alias('p')][SecureString]$Password = $null,
        [Parameter(Mandatory=$true,HelpMessage='Please enter management pack name')][ValidateNotNullOrEmpty()][String]$MPName,
        [Parameter(Mandatory=$true,HelpMessage='Please enter Template Instance Display Name')][ValidateNotNullOrEmpty()][String]$DisplayName,
        [Parameter(Mandatory=$true,HelpMessage='Please enter Template Instance description')][String]$Description,
        [Parameter(Mandatory=$false,HelpMessage='Please specify if the rule is enabled by default')][Boolean]$Enabled=$true,
        [Parameter(Mandatory=$true,HelpMessage='Please enter the performance counter name')][ValidateNotNullOrEmpty()][String]$CounterName,
        [Parameter(Mandatory=$true,HelpMessage='Please enter the query executed by the Performance Collection rule')][ValidateNotNullOrEmpty()][String]$Query,
        [Parameter(Mandatory=$true,HelpMessage='Please enter the return column name')][ValidateNotNullOrEmpty()][String]$ReturnColumnName,
        [Parameter(Mandatory=$true,HelpMessage='Please select target class of the Performance Collection rule')][ValidateSet('Instance', 'Control File', 'Data File', 'Redo Log group', 'Redo Log File', 'Table Space')][String]$Target,
        [Parameter(Mandatory=$false,HelpMessage='Please enter the Management Pack Locale ID')][ValidateNotNullOrEmpty()][String]$LocaleId="ENU",
        [Parameter(Mandatory=$false,HelpMessage='Please enter the query interval (in seconds)')][Int]$QueryInterval=300,
        [Parameter(Mandatory=$false,HelpMessage='Increase MP version by 0.0.0.1')][Boolean]$IncreaseMPVersion = $false
    )

    #Connect to MG
	If ($SDKConnection)
	{
		Write-Verbose "Connecting to Management Group via SDK $($SDKConnection.ComputerName)`..."
		$MG = Connect-OMManagementGroup -SDKConnection $SDKConnection
		$SDK = $SDKConnection.ComputerName
		$Username = $SDKConnection.Username
		$Password= ConvertTo-SecureString -AsPlainText $SDKConnection.Password -force
	} else {
		Write-Verbose "Connecting to Management Group via SDK $SDK`..."
		If ($Username -and $Password)
		{
			$MG = Connect-OMManagementGroup -SDK $SDK -UserName $Username -Password $Password
		} else {
			$MG = Connect-OMManagementGroup -SDK $SDK
		}
	}

    #Get the unsealed MP
    Write-Verbose "Getting destination MP '$MPName'..."
    $strMPquery = "Name = '$MPName'"
    $mpCriteria = New-Object  Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria($strMPquery)
    $MP = $MG.GetManagementPacks($mpCriteria)[0]

    If ($MP)
    {
        #MP found, now check if it is sealed
        Write-Verbose "Found destination MP '$MPName', the MP display name is '$($MP.DisplayName)'. MP Sealed: $($MP.Sealed)"
        Write-Verbose $MP.GetType()
        If ($MP.sealed)
        {
            Write-Error 'Unable to save to the management pack specified. It is sealed. Please specify an unsealed MP.'
            return $false
        }
    } else {
        Write-Error 'The management pack specified cannot be found. please make sure the correct name is specified.'
        return $false
    }

    #Get the target class
    Switch ($Target.ToLower())
    {
        'instance' {$TargetClass = 'OpsLogix.IMP.Oracle.Instance'}
        'control file' {$TargetClass = 'OpsLogix.IMP.Oracle.ControlFile'}
        'data file' {$TargetClass = 'OpsLogix.IMP.Oracle.DataFile'}
        'redo log group' {$TargetClass = 'OpsLogix.IMP.Oracle.RedoLogGroup'}
        'redo log file' {$TargetClass = 'OpsLogix.IMP.Oracle.RedoLogFile'}
        'table space' {$TargetClass = 'OpsLogix.IMP.Oracle.TableSpace'}
    }


    #Get the template
    Write-Verbose "Getting the OpsLogix Oracle Performance Collection Rule monitoring template..."
    $strTemplatequery = "Name = 'OpsLogix.IMP.Oracle.Config.2012.SQL.Query.Template'"
    $TemplateCriteria = New-object Microsoft.EnterpriseManagement.Configuration.ManagementPackTemplateCriteria($strTemplatequery)
    $OpsLogixOraclePerfTemplate = $MG.GetMonitoringTemplates($TemplateCriteria)[0]
    if (!$OpsLogixOraclePerfTemplate)
    {
        Write-Error "The Opslogix Oracle Performance Collection Rule Monitoring Template cannot be found. please make sure the OpsLogix Oracle management packs are imported into your management group."
        return $false
    }

    #Generate template instance configuration
    $NewGUID = [GUID]::NewGuid().ToString().Replace("-","")
    $NameSpace = "OpsLogixOracleAlertTemplate_$NewGUID"
    $StringBuilder = New-Object System.Text.StringBuilder
    $configurationWriter = [System.Xml.XmlWriter]::Create($StringBuilder)
    $configurationWriter.WriteStartElement("Configuration");
    $configurationWriter.WriteElementString("CounterName", $CounterName);
    $configurationWriter.WriteElementString("ColumnName", $ReturnColumnName);
    $configurationWriter.WriteElementString("Query", $Query);
    $configurationWriter.WriteElementString("IntervalSeconds", $QueryInterval);
    $configurationWriter.WriteElementString("HostReference", "");
    $configurationWriter.WriteElementString("Target", $TargetClass);
    $configurationWriter.WriteElementString("ColumnNamePropertySubs", "`$Data/Property[`@Name='$ReturnColumnName']`$");
    $configurationWriter.WriteElementString("Name", $DisplayName);
    $configurationWriter.WriteElementString("Description", $Description);
    $configurationWriter.WriteElementString("LocaleId", $LocaleId);
    $configurationWriter.WriteElementString("ManagementPack", $MPName);
    $configurationWriter.WriteElementString("NameSpace", $NameSpace);
    $configurationWriter.WriteElementString("Enabled", $Enabled.ToString().ToLower());
    $configurationWriter.WriteEndElement();
    $configurationWriter.Flush();
    $XmlWriter = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackXmlWriter([System.Xml.XmlWriter]::Create($StringBuilder))
    $strConfiguration = $StringBuilder.ToString()
    Write-Verbose "Template Instance Configuration:"
    Write-Verbose $strConfiguration
    #Create the template instance
    Write-Verbose "Creating the OpsLogix Oracle Performance Collection Rule template instance on management pack '$MPName'..."
    Try {
        [Void]$MP.ProcessMonitoringTemplate($OpsLogixOraclePerfTemplate, $strConfiguration, "TemplateoutputOpsLogixIMPOracleConfig2012SQLQueryTemplate$NewGUID", $DisplayName, $Description)
    } Catch {
        Write-Error $_.Exception.InnerException
        Return $False
    }
    #Increase MP version
    If ($IncreaseMPVersion)
    {
        Write-Verbose "the version of managemnet pack '$MPVersion' will be increased by 0.0.0.1"
        $CurrentVersion = $MP.Version.Tostring()
        $vIncrement = $CurrentVersion.Split('.')
        $vIncrement[$vIncrement.Length - 1] = ([System.Int32]::Parse($vIncrement[$vIncrement.Length - 1]) + 1).ToString()
        $NewVersion = ([System.String]::Join('.', $vIncrement))
        $MP.Version = $NewVersion
    }

    #Verify and save the monitor
    Try {
        $MP.verify()
        $MP.AcceptChanges()
        $Result = $true
		Write-Verbose "OpsLogix Oracle Performance Collection Rule template instance '$DisplayName' successfully created in Management Pack '$MPName'($($MP.Version))."
    } Catch {
        $Result = $false
		$MP.RejectChanges()
        Write-Error "Unable to create OpsLogix Oracle Performance Collection Rule template instance '$DisplayName' in management pack $MPName."
    }
    $Result
}