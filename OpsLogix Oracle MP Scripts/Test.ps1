#Create MP
New-OMManagementPack -SDK "OMMS01" -Name "TYANG.OpsLogix.Test" -DisplayName "TYANG OpsLogix Test MP" -Description "Custom MP for OpsLogix test MP" -Version 1.0.0.0 -Verbose


#Alert rule
$parms = @{
    SDK = "OMMS01";
    UserName = "domain\user"
    Password = $(ConvertTo-SecureString -AsPlainText "password" -force);
    MPName = "TYANG.OpsLogix.Test";
    DisplayName = "Test Oracle Alert rule";
    Description = "This is a test instance for the OpsLogix Oracle alert rule template";
    Enabled = $true;
    Query = 'select count(*) "Order_COUNT" from sys.orders';
    ReturnColumnName = "Order_COUNT";
    Target="Instance";
    QueryInterval = 300;
    Operator = "Equal";
    TargetValue = 0;
    AlertName= "Order Table Has no rows";
    AlertDescription = "please refer check the order table, it is empty.";
    AlertPriority = "Medium";
    AlertSeverity = "Critical"
}
  
New-OpsLogixOracleAlertTemplateInstance @parms -Verbose

#Perf rule
$parms = @{
    SDK = "OMMS01";
    MPName = "TYANG.OpsLogix.Test";
    DisplayName = "Test Oracle performance collection rule";
    Description = "This is a test instance for the OpsLogix Oracle Performance Collection rule template";
    Enabled = $true;
    CounterName = "OrderCOUNT";
    Query = 'select count(*) "Order_COUNT" from sys.orders';
    ReturnColumnName = "Order_COUNT";
    Target="Instance";
    QueryInterval = 300
}
  
New-OpsLogixOraclePerfTemplateInstance @parms -verbose

#2-state monitor
 $parms = @{
    SDK = "OMMS01";
    MPName = "TYANG.OpsLogix.Test";
    DisplayName = "Test Oracle two-state monitor";
    Description = "This is a test instance for the OpsLogix Oracle Two-State Monior template";
    Enabled = $true;
    Query = 'select count(*) "Order_COUNT" from sys.orders';
    ReturnColumnName = "Order_COUNT";
    Target="Instance";
    MonitorState="Error";
    QueryInterval = 300;
    UnhealthyOperator = "Greater";
    TargetValue = 300;
    AlertName= "The Order Table Has too many rows";
    AlertDescription = "please check the order table, it has too many outstanding rows.";
    AlertPriority = "Normal";
    AlertSeverity = "Warning"
   }
  
  New-OpsLogixOracle2StateMonitorTemplateInstance @parms -Verbose

  Remove-OMManagementPack -SDK OMMS01 -Name "TYANG.OpsLogix.Test" -Verbose