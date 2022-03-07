# Zappi2PVOutput.ps1 v1.4
# Last updated 07/03/2022
# Written by Neil Schofield (neil.schofield@sky.com)
#
# This powershell script takes status data stored on myenergi servers for their
# Zappi EV charger customers and uploads it to PVOutput.org,  a free service for
# sharing, comparing and monitoring live solar photovoltaic (PV) and energy
# consumption data.
#
# *** Important Note: It reiles on API calls to myenergi web services which are
# UNSUPPORTED, UNDOCUMENTED, and may stop working without notice.
#
# Thanks to the many members of the myenergi.info forum for their insights,
# especially twonk for his work (https://github.com/twonk/MyEnergi-App-Api)
# which forms the basis of this script.
#
# The script has been tested with Powershell v7.2
#
# SYNTAX:
# .\Zappi2PVOutput.ps1
#
# Use the Windows Task Scheduler to run the script at a frequency that matches
# the status interval of your system on PVOutput.org - eg every 5 mins.
#
# *** This script is provided 'as is' without any warranty of any kind ***

# ==============================================================================
# The following values should be modified according to your system:

    $PVOSystemId = "nnnn"                                      # Specify your pvoutput.org System Id (in quotes)
    $PVOApiKey = "123456789abcdef0123456789abcdef012345678"    # Specify the API Key (in quotes) for your system on pvoutput.org
    
    
    $MyEnergiUName = "10nnnnnn"                                # Username for authentication with myenergi.net (= serial number of MyEnergi Hub)
    $MyEnergiPW = "xxxxxxxxxx"                                 # Password for authentication with myenergi.net (= myenergi app password)
    $ZappiSerial = "1200nnnn"                                  # Serial number of Zappi EV charger
    $LogDir = "C\Users\Bob\Documents\"                         # Location to write log files
    
    $GetOWMTempData = $true                                    # Optionally obtain local temperature observations
    $OWMApiKey = "fedcba9876543210fedcba9876543210"            # Specify your openweathermap.org API key (in quotes)
    $OWMLocationID = "nnnnnnn"                                 # Specify your openweathermap.org location ID (in quotes)

# The following values should generally not be changed:

    $OWMResponseLog = "$LogDir\OWMResponse.log"                # Logs result of openweathermap web service calls
    $MEResponseLog = "$LogDir\MEResponse.log"                  # Logs result of myenergi.net web service calls
    $PVOResponseLog = "$LogDir\PVOResponse.log"                # Logs result of pvoutput.org service calls
    $UploadLog = "$LogDir\Zappi2PVOutput.log"                  # Logs diagnostic information and journal of statuses already uploaded
       
    $PVORequestHeaders = @{"X-Pvoutput-SystemID"=$PVOSystemId;"X-Pvoutput-Apikey"=$PVOApiKey}
    $PVORequestBody = @{}
    
    $MEDirectorURL = "https://director.myenergi.net"

# End of values
# ==============================================================================

    $ErrorActionPreference = "Stop"
    
    # If the log file doesn't exist create a blank one:
    if (!(Test-Path -Path $UploadLog))
    {
        Add-Content $UploadLog "$(Get-Date -format g) No previous log file found in this location. Creating new one ..."
    }
    
    if ($GetOWMTempData)
    {
        $Uri = New-Object System.Uri ("https://api.openweathermap.org/data/2.5/weather?units=metric&id=$OWMLocationID&appid=$OWMApiKey")
        try
        {
            # Get the current weather observations for this location from openweathermap.org
            $Response = Invoke-WebRequest -Uri $Uri.AbsoluteUri -OutFile $OWMResponseLog -PassThru
            $Weather = ConvertFrom-Json $Response.Content
            $TempNow = [int]$Weather.main.temp
            $PVORequestBody.v5 = $TempNow.ToString()
        }
        catch
        {
            Add-Content $UploadLog "$(Get-Date -format g) Getting weather information from $Uri failed: $($Error[0]). Continuing ..."
        }
    }

    # MyEnergi server name WAS previously determined by last digit of the MyEnergi *hub* serial number
    # $Uri = New-Object System.Uri ("https://s" + $MyEnergiUName[$MyEnergiUName.Length - 1] + ".myenergi.net/cgi-jstatus-Z" + $ZappiSerial + "/")
    # NOW it's provided by a call to the Director URL
    $SecPW = ConvertTo-SecureString $MyEnergiPW -AsPlainText -Force 
    $SecCred = New-Object System.Management.Automation.PSCredential ($MyEnergiUName, $SecPW)
    $Uri = New-Object System.Uri ($MEDirectorURL)
    
    try
    {
        # Call to the MyEnergi director to obtain the ASN information
        # Note the response will be a 401 error, so we have to ignore HTTP errors
        $Response = Invoke-WebRequest -Uri $Uri.AbsoluteUri -Credential $SecCred -OutFile $MEResponseLog -PassThru -SkipHttpErrorCheck
    }
    catch
    {
        Add-Content $UploadLog "$(Get-Date -format g) Getting ASN details from $Uri failed: $($Error[0]). Aborting ..."
        exit
    }

    # Validate we've got ASN in the response headers
    if ($null -eq $Response.Headers.'X_MYENERGI-asn')
    {
        Add-Content $UploadLog "$(Get-Date -format g) Failed to get ASN response headers from $Uri. Aborting..."
        exit
    }
    else {
        $MyASN = $Response.Headers.'X_MYENERGI-asn'
        $Uri = New-Object System.Uri ("https://$MyASN/cgi-jstatus-*")
    }
    
    try
    {
        # Get the current Zappi status info from the appropriate myenergi.net server
        $Response = Invoke-WebRequest -Uri $Uri.AbsoluteUri -Credential $SecCred -OutFile $MEResponseLog -PassThru
        $ZappiStatus = ConvertFrom-Json $Response.Content
    }
    catch
    {
        Add-Content $UploadLog "$(Get-Date -format g) Getting Zappi status information from $Uri failed: $($Error[0]). Aborting ..."
        exit
    }
 
    # Validate Zappi status data
    if ($ZappiStatus.zappi.sno -ne $ZappiSerial)
    {
        Add-Content $UploadLog "$(Get-Date -format g) Zappi status data is incomplete or does not match the serial number.  Aborting ..."
        exit
    }
    
    # Zero values are not returned from the myenergi web service calls, so we assume missing values are zero
    $PowerGen = 0
    if ($null -ne $ZappiStatus.zappi.gen)
    {
        $PowerGen = $ZappiStatus.zappi.gen
    }

    $PowerGrd = 0
    if ($null -ne $ZappiStatus.zappi.grd)
    {
        $PowerGrd = $ZappiStatus.zappi.grd
    }

    $SupplyVol = 0
    if ($null -ne $ZappiStatus.zappi.vol)
    {
        $SupplyVol = $ZappiStatus.zappi.vol
    }

    try
    {
        # Date and time returned from myenergi is (currently) UTC, so convert to local time
        $ZappiDateTime = [datetime]::ParseExact($ZappiStatus.zappi.dat+" "+$ZappiStatus.zappi.tim,"dd-MM-yyyy HH:mm:ss",$null).ToLocalTime()
        # Store date and time in a string format suitable for uploading to pvoutput.org
        $PVORequestBody.d = $ZappiDateTime.ToString("yyyyMMdd")
        $PVORequestBody.t = $ZappiDateTime.ToString("HH:mm")
    }
    catch
    {
        Add-Content $UploadLog "$(Get-Date -format g) Zappi status data does not contain a valid date/time. Aborting ..."
        exit
    }

    # Check the data returned is current:
    if ($ZappiDateTime -lt (Get-Date).AddMinutes(-10))
    {
        Add-Content $UploadLog "$(Get-Date -format g) Zappi status data is not current - $($ZappiDateTime.ToString()). Aborting ..."
        exit
    }
    
    # Current power being consumed is the sum of what is being generated and what is being drawn from the grid. NB: grid value can be negative.
    $PowerUsed = $PowerGen + $PowerGrd
    $PVORequestBody.v4 = $PowerUsed.ToString()

    # Supply voltage (in decivolts) is part of the data returned and is optional information to be uploaded, so include it:
    $PVORequestBody.v6 = ($SupplyVol/10).ToString()

    # First check we haven't uploaded a status with this timestamp before
    if (-not (select-string -Pattern "Uploading status data for $($ZappiDateTime.ToString()) succeeded" -Path $UploadLog))
    {
        $uri = New-Object System.Uri ("http://pvoutput.org/service/r2/addstatus.jsp")
        try
        {
            #Post the data to the pvoutput.org webs site
            $Response = invoke-webrequest -Uri $Uri.AbsoluteUri -Headers $PVORequestHeaders -Body $PVORequestBody -outfile $PVOResponseLog -PassThru
            Add-Content $UploadLog "$(Get-Date -format g) Uploading status data for $($ZappiDateTime.ToString()) succeeded: Consumed Power = $($PVORequestBody.v4)W, Temperature = $($PVORequestBody.v5) deg C, Supply Voltage = $($PVORequestBody.v6)V - $Response"
        }
        catch
        {
            Add-Content $UploadLog "$(Get-Date -format g) Uploading status data for $($ZappiDateTime.ToString()) failed: Consumed Power = $($PVORequestBody.v4)W, Temperature = $($PVORequestBody.v5) deg C, Supply Voltage = $($PVORequestBody.v6)V: $($Error[0])."
        }
    }
    else
    {
        Add-Content $UploadLog "$(Get-Date -format g) Status data for $($ZappiDateTime.ToString()) has already been uploaded"
    }
