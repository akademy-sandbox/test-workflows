Using Namespace System.Data.SqlClient
Using Namespace System.Xml.Linq

# Input Parameters. 
Param(
    <# Host name on which REALTIME Database is  present#> 
    [Parameter(Mandatory=$False)]
    [String]
    $DBHost, # "ULDWDB02V",

    <# Database Name #>
    [Parameter(Mandatory=$False)]
    [String]
    $DBName,   # "REALTIME",

    # Source CSV Dir
    [Parameter(Mandatory=$False)]
    [String]
    $SourceCSVDir,

    # Target Environment
    [Parameter(Mandatory=$False)]
    [String]
    $TargetEnv,

    <# ATMConfigurationSuccessCSVFile #>
    [Parameter(Mandatory=$False)]
    [String]
    $ATMConfigurationSuccessCSVFile,   

    # ATMTerminalNotFoundCSVFile
    [Parameter(Mandatory=$False)]
    [String]
    $ATMTerminalNotFoundCSVFile,

    # ATMTerminalAlreadyOnboardedCSVFile
    [Parameter(Mandatory=$False)]
    [String]
    $ATMTerminalAlreadyOnboardedCSVFile,

    # ToEmail
    [Parameter(Mandatory=$False)]
    [String]
    $ToEmail,

    # FromEmail
    [Parameter(Mandatory=$False)]
    [String]
    $FromEmail,

    [Parameter(Mandatory=$False)]
    [String]
    $MaxRecords
)

$TimeStamp = (Get-Date).toString("yyyy-MM-dd-HHmmss")
$Global:LogFileName = -join($PSScriptRoot,"\logs","\script_",$TimeStamp,".log")
$Global:ScreenshotPath = -join($PSScriptRoot,"\screenshot_",$TimeStamp,".png")
$Global:IsInsertSuccess = $Null
$Global:ResultDir = -join($PSScriptRoot,"\result")
$Global:TerminalNotFoundCSVFile = -join($Global:ResultDir,"\",$ATMTerminalNotFoundCSVFile)
$Global:ATMConfigFoundCSVFile = -join($Global:ResultDir,"\",$ATMTerminalAlreadyOnboardedCSVFile)
$Global:ATMConfigurationSuccess = -join($Global:ResultDir,"\",$ATMConfigurationSuccessCSVFile)
$Global:BadFileErrorFile = -join($Global:ResultDir,"\","bad_file_error.csv")
$Global:ConsolidatedOutput = -join($Global:ResultDir,"\","consolifated_output.csv")
$Global:SuccessCount=0
$Global:TerminalNotFoundCount=0
$Global:ATMConfigFoundCount=0
New-Item -Path "$PSScriptRoot\logs" -ItemType Directory -Force

Function Debug-Input-Params{
    Write-Log -Level "DEBUG" -Message "DBHost: $DBHost"
    Write-Log -Level "DEBUG" -Message "DBName: $DBName"
    Write-Log -Level "DEBUG" -Message "SourceCSVDir: $SourceCSVDir"
    Write-Log -Level "DEBUG" -Message "TargetEnv: $TargetEnv"
    Write-Log -Level "DEBUG" -Message "ATMConfigurationSuccessCSVFile: $ATMConfigurationSuccessCSVFile"
    Write-Log -Level "DEBUG" -Message "ATMTerminalNotFoundCSVFile: $ATMTerminalNotFoundCSVFile"
    Write-Log -Level "DEBUG" -Message "ATMTerminalAlreadyOnboardedCSVFile: $ATMTerminalAlreadyOnboardedCSVFile"
    Write-Log -Level "DEBUG" -Message "ToEmail: $ToEmail"
    Write-Log -Level "DEBUG" -Message "FromEmail: $FromEmail"
}

Function Create-Result-File{
    New-Item -Path "$Global:ResultDir" -ItemType Directory -Force
    
    Remove-Item -Path "$Global:ResultDir\*" -Force

    New-Item -ItemType File -Path $Global:TerminalNotFoundCSVFile
    New-Item -ItemType File -Path $Global:ATMConfigFoundCSVFile
    New-Item -ItemType File -Path $Global:ATMConfigurationSuccess
    New-Item -ItemType File -Path $Global:BadFileErrorFile

    $headers = "atmterminalid,cardacceptorid,errordescription"
    Add-Content -Path $Global:TerminalNotFoundCSVFile -Value $headers
    Add-Content -Path $Global:ATMConfigFoundCSVFile -Value $headers
	
	$headers = "term_group_id,source_node,card_acceptor_id,terminal_id,local_currency,rates_profile,commission_profile,markup_profile,scheme_rule_profile"
	Add-Content -Path $Global:ATMConfigurationSuccess -Value $headers

    $headers = "sno,filename,total_records, success, terminal_not_found, config_found"
	Add-Content -Path $Global:ConsolidatedOutput -Value $headers

    $headers = "sno,filename,error_description"
	Add-Content -Path $Global:BadFileErrorFile -Value $headers
}

Function Execute-Onboarding-Query{
    $CSVFileName = -join($PSScriptRoot,"\result\$ATMTerminalId",".csv")
    Try{
        
       $SqlQuery = "select card_acceptor from term(nolock) where id='$ATMTerminalId'" 
       Write-Log -Level "INFO" -Message "Querying the Database. DBHost: $DBHost, DBName: $DBName"
       $SqlResult = Invoke-Sqlcmd -ServerInstance $DBHost -Database $DBName -Query $SqlQuery
       If (-not $SqlResult){
           Write-Log -Level "INFO" -Message "Records not found for the given ATM Terminal ID: $ATMTerminalId in TERM Table"
           Write-Log -Level "INFO" -Message "Script Exited without further action"
           $StatusValue="Term table doesnt have records for given Terminal ID $ATMTerminalId, Hence, ATM is not onboarded"
           $Global:TerminalNotFoundCount++
           Add-Content -Path $Global:TerminalNotFoundCSVFile -Value "$ATMTerminalId,$CardAcceptorId,$StatusValue"
        }Else{
           Write-Log -Level "INFO" -Message "Records found for the given ATM Terminal ID: $ATMTerminalId in TERM Table"
           Write-Log -Level "INFO" -Message "Proceeding with further actions"
           $CardAcceptorId = $SqlResult.card_acceptor
		   Write-Log -Level "INFO" -Message "CardAcceptorId: $CardAcceptorId"
           $SqlQuery = "select top 10 * from fx_term_groups(nolock) where terminal_id in ('$ATMTerminalId')"
           $SqlResult = Invoke-Sqlcmd -ServerInstance $DBHost -Database $DBName -Query $SqlQuery
           If ($SqlResult){
               Write-Log -Level "INFO" -Message "Records found for the given ATM Terminal ID: $ATMTerminalId in FX_TERM_GROUP table"
               Write-Log -Level "INFO" -Message "Exiting the script"
               $StatusValue="FX_TERM_GROUP table already has records for given Terminal ID $ATMTerminalId, Hence, ATM is already onboarded"
               $Global:ATMConfigFoundCount++
               Add-Content -Path $Global:ATMConfigFoundCSVFile -Value "$ATMTerminalId,$CardAcceptorId,$StatusValue"
           }Else{
                Write-Log -Level "INFO" -Message "No records found for the given ATM Terminal ID: $ATMTerminalId in in FX_TERM_GROUP table"
                Write-Log -Level "INFO" -Message "Proceeding with further actions" 
                $SqlQuery = "insert into fx_term_groups values ('ATMApp','$CardAcceptorId','$ATMTerminalId','036','MCWDCPRatesProf','MCWDCPCommProf','MCWDCPMarkupProf','MCWDCPSchRuleProf')"
                Write-Log -Level "INFO" -Message "Executing the SQL Query: $SqlQuery"
                Invoke-Sqlcmd -ServerInstance $DBHost -Database $DBName -Query $SqlQuery
                Write-Log -Level "INFO" -Message "SQL Insert Query executed successfully"
                
                $SqlQuery = "select top 10 * from fx_term_groups(nolock) where terminal_id in ('$ATMTerminalId')" 
                Write-Log -Level "INFO" -Message "Querying the Database. DBHost: $DBHost, DBName: $DBName. SqlQuery: $SqlQuery"
                $SqlResult = Invoke-Sqlcmd -ServerInstance $DBHost -Database $DBName -Query $SqlQuery
                $RowCount = $SqlResult.Count
                Write-Log -Level "INFO" -Message "Total Rows returned: $RowCount"
                If ($SqlResult){
                    Write-Log -Level "INFO" -Message "Records found for the given ATM Terminal ID: $ATMTerminalId"
                    Write-Log -Level "INFO" -Message "Script executed successfully"
                    $Global:IsInsertSuccess = $True
                    $DataRows = $SqlResult | Convertto-Csv -NoTypeinformation | Select-Object -Skip 1
					Add-Content -Path $Global:ATMConfigurationSuccess -Value $DataRows
                    $Global:SuccessCount++
                }Else{
                    Write-Log -Level "ERROR" -Message "No records found for the given ATM Terminal ID: $ATMTerminalId"
                    Write-Log -Level "ERROR" -Message "Script execution failed"
                }
           }
        }
    }Catch{
        Write-Log -Level "ERROR" -Message "Error while executing SQL query: $_"
        Throw $_
    }
}

Function Write-Log {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$False)]
		[ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
		[String]
		$Level = "INFO",

		[Parameter(Mandatory=$True)]
		[String]
		$Message,

		[Parameter(Mandatory=$False)]
		[String]
		$LogFile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogFile = $Global:LogFileName
    $Line = "$Stamp $Level $Message"
    If($LogFile) {
        if($Level -eq "INFO"){
            Add-Content $LogFile -Value $Line
			Write-Host $Line 
		}elseif($Level -eq "WARN"){
            Add-Content $LogFile -Value $Line
			Write-Host $Line -ForegroundColor Yellow
		}elseif($Level -eq "DEBUG"){
            Add-Content $LogFile -Value $Line
			Write-Host $Line -ForegroundColor Green
		}elseif($Level -eq "ERROR"){
            Add-Content $LogFile -Value $Line
			Write-Host $Line -ForegroundColor Red
		}elseif($Level -eq "FATAL" -and $Script:LogLevel -eq "FATAL"){
            Add-Content $LogFile -Value $Line
			Write-Host $Line -ForegroundColor Red
		}
    }
    Else {
        Write-Output $Line
    }
}


# Function to process files recursively
function Process-Files {
    Write-Log -Level "INFO" -Message "Processing files in $SourceCSVDir directory"
    # concatinate TargetENv to SourceCSVDir
    $SourceCSVDir = -join($SourceCSVDir,"\",$TargetEnv)
    $DestinationCSVDir = -join($SourceCSVDir,"\archive")
    # Get all .csv files in the current directory
    $files = Get-ChildItem -Path $SourceCSVDir -Filter *.csv

    # If csvFiles are not found in the current directory, exit the script
    If (-not $files) {
      Write-Log -Level "ERROR" -Message "No .csv files found in $SourceCSVDir directory"
      Exit
    }

    $FileCount = 0
    $BadFileCount = 0
    foreach ($file in $files) {
        
        # Read file content
        $fileContent = Get-Content -Path $file.FullName
        Write-Log -Level "INFO" -Message "Processing file: $($file.FullName)"
        Write-Log -Level "INFO" -Message "File content: $fileContent"
        
        $data = Import-Csv -Path $file.FullName
        Write-Log -Level "INFO" -Message "Data: $data"
        # ".\input.csv"
        # Find number of rows in te CSV file
        $CSVRowCount = $data.Count
        $HeaderText = Get-Content -Path $file.FullName -First 1
        #Conver MaxRecords to integer
        $MaxRecords = [int]$MaxRecords
        $ErrroDescription = "Unknown Error"
        Write-Log -Level "INFO" -Message "Header: $HeaderText"
        if ($HeaderText -notmatch "(?i)\bATMTERMINALID\b" -OR $CSVRowCount -gt $MaxRecords){ 
           if ($CSVRowCount -gt $MaxRecords){
               $ErrroDescription = "Max records exceeded. Max records allowed: $MaxRecords, Records in the file: $CSVRowCount"
               Write-Log -Level "ERROR" -Message "Error Description: $ErrorDescription"
           }else{
                $ErrroDescription = "Header ATMTERMINALID not found in the file. Actual Header found in the file: $HeaderText. Please correct this and re-submit."
                Write-Log -Level "ERROR" -Message "Error Description: $ErrorDescription"
           }
           $BadFileCount++
           Add-Content -Path $Global:BadFileErrorFile -Value "$BadFileCount,$file,$ErrroDescription"
        }else{
            $FileCount++
            $CurrentInputFileName=""
            $RecordsCount=0
            foreach ($row in $data) {
                $RecordsCount++    
                $CurrentInputFileName = Split-Path -Path $file.FullName -Leaf
                $ATMTerminalId = $row.atmterminalid
                $file.FullName
                Write-Log -Level "INFO" -Message "Processing ATM Terminal ID: $ATMTerminalId"
                Execute-Onboarding-Query

            }
            Add-Content -Path $Global:ConsolidatedOutput -Value "$FileCount,$CurrentInputFileName,$RecordsCount, $Global:SuccessCount, $Global:TerminalNotFoundCount, $Global:ATMConfigFoundCount"
            $Global:SuccessCount=0
            $Global:TerminalNotFoundCount=0
            $Global:ATMConfigFoundCount=0
        }
        # Print $fileContent
        

        # Create if Destination directory doesn't exist
        If (-not (Test-Path -Path $DestinationCSVDir)) {
            New-Item -Path $DestinationCSVDir -ItemType Directory
        }

        # Remove file extension from $file.Name
        $FileName = $file.Name -replace ".csv", ""

        # Destination file path
        $DestinationCSVFilePath = Join-Path -Path $DestinationCSVDir -ChildPath $FileName

        # append current date and timestamp in ddmmyyyyHHmmss format
        $TimeStamp = (Get-Date).toString("ddMMyyyyHHmmss")
        $DestinationCSVFilePath = -join($DestinationCSVFilePath,"_",$TimeStamp,".csv")

        # Write content to the destination
        Set-Content -Path $DestinationCSVFilePath -Value $fileContent

        # Delete Source file
        Remove-Item -Path $file.FullName
        Write-Host "Processed file: $($file.FullName) -> $DestinationCSVFilePath"
        Write-Log -Level "INFO" -Message "Processed file: $($file.FullName) -> $DestinationCSVFilePath"
    }
    # Copy result folder as result_timestamp to archive 
    $TimeStamp = (Get-Date).toString("ddMMyyyyHHmmss")
    New-Item -Path "$DestinationCSVDir/result_$TimeStamp" -ItemType Directory
    
    Copy-Item -Path "$Global:ResultDir/*.csv" -Destination "$DestinationCSVDir/result_$TimeStamp" -Recurse -Force
    Write-Log -Level "INFO" -Message "Result files copied to $DestinationCSVDir/result_$TimeStamp"
}

    
$SourceCSVDir = $SourceCSVDir.Replace("P:\","\\cuscalad.com\dfs\")
Debug-Input-Params
Create-Result-File
Process-Files



