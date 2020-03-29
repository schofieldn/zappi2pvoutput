# zappi2pvoutput
Powershell script to download Zappi status data from myenergi servers and upload it to PVOutput.org

# Background
Following previous investigations by [twonk](https://github.com/twonk/MyEnergi-App-Api) and others, I was keen to understand what data from my myenergi zappi 2.0 EV charger (and available via calls to the myenergi web services) could be used for. As a proof-of-concept, I have written the `Zappi2PVOutput.ps1` powershell script to gather power consumption data and some other bits and pieces, and to upload this to the PVOutput.org website.

## myenergi
[myenergi](myenergi.com) is an award-winning British designer and manufacturer of renewable energy products that increase the self-consumption of green energy. I've had one of their [zappi](https://myenergi.com/product/zappi) EV charging units installed since September 2019. The zappi integrates brilliantly with my existing solar PV system, so I can choose to charge the EV only when the sun is shining!

myenergi provide a neat (Android or iOS) app for monitoring consumption & generation data relating to your system. This requires a myenergi hub device which sits between the Zappi charger and the myenergi servers that host the data. You must register your hub in the app and set up credentials to authenticate with the myenergi servers.

## PVOutput.org
[PVOutput.org](https://pvoutput.org) is a free service for sharing, comparing and monitoring live solar photovoltaic (PV) and energy consumption data. I've been collating my PV generation data on their site since it was installed in 2011. The zappi2pvoutput.ps1 script is complementary to [another script](https://github.com/schofieldn/sma2pvoutput) I use to upload the PV generation data to that site.

While it is possible to use PVOutput.org to record **only** consumption data, this script is primarily aimed at those who already have a PV system registered and are currently uploading generation data but not consumption data.

## Warning - Danger - Caution Required
The script makes use of undocumented and unsupported calls direct to web services on the myenergi servers. Myenergi may change these APIs at any time without warning. Just because the script works today does not mean it will work tomorrow!

The script is provided 'as is' without any warranty of any kind.

# Purpose
The script will send web service requests to the myenergi server to query the latest status information from the Zappi charger. This information includes details of the power being generated, the power being imported from the grid and the power being diverted to charge a currently connected EV. It also includes information such as the supply voltage.

This information is collated and power consumption figures are derived. Optionally, temperature information is obtained before the status data is then uploaded to PVOutput.org.

# Script Requirements
The script Zappi2PVOutput.org should be downloaded and run from a local device on your Windows system. Internet access is required, but the volume of data transferred is relatively small.

## Software Requirements
The script has been tested with Powershell 5, but doesn't depend on any particularly exotic features of Powershell so should have good compatibility with other supported versions.

### Configuring the Windows Powershell environment
By default, the Windows PowerShell execution policy is set to `Restricted` which means scripts cannot be run! To check your execution policy, run the `Get-ExecutionPolicy` cmdlet from a Windows PowerShell prompt.

To weaken the Windows Powershell execution policy to allow scripts you have written yourself to run, along with downloaded scripts that have been signed by a trusted publisher, open a Windows PowerShell prompt as an Administrator and run `Set-ExecutionPolicy RemoteSigned`. However you should first run `Get-Help About_Signing` to determine whether this execution policy meets your security requirements.

Because the `Zappi2PVOutput.ps1` script has not been signed by a trusted publisher, if the execution policy is set to `RemoteSigned` you will then need to run the cmdlet `unblock_file` with the full path to the `Zappi2PVOutput.ps1` script as a parameter to allow the script to be invoked.

## Script Variables
There are no parameters that can be passed to the script, but at the top of the script are a number of variables which must be modified to suit your individual environment.

### Your PVOutput.org system ID and API key (`$PVOSystemId` and `$PVOApiKey`)
You will first need to register with PVOutput.org and create a system which will have a unique ID. You will also need to enable API access in the [account settings](http://www.pvoutput.org/account.jsp) page and generate your API key.

Depending on how frequently you wish to upload status information to PVOutput.org, you may wish to reconfigure the [Status Interval](https://pvoutput.org/help.html#live-settings-status-interval) for your system.

For more details refer to [http://www.pvoutput.org/help.html](http://www.pvoutput.org/help.html)

### Your myenergi app account credentials (`$MyEnergiUName` and `$MyEnergiPW`)
Your myenergi app username is the serial number of your hub device and is typically a string of 8 digits. The password will have been set when you first registered it in the myenergi app.

### Your zappi EV charger serial number (`$ZappiSerial`)
This is typically a string of 8 digits and is available from the menus on your zappi charger.

### A location for the log files (`$LogDir`)
This should be a writable location on your device. The script sends diagnostic information, by default, to a file called Zappi2PVOutput.log located in this directory. In addition to providing diagnostic information, the log also serves as a journal to ensure that the same statuses are not repeatedly posted to PVOutput.

The log file Zappi2PVOutput.log can be manually pruned or deleted periodically to save disk space.

A number of other log files are generated to report the responses to different web requests.

### Open Weather Map configuration (`$GetOWMTempData`, `$OWMApiKey` and `$OWMLocationID`)
The script can optionally download weather data for the local area from openweathermap.org. This is then used to estimate the current temperature and provide this information in the status update to PVOutput.org.

If this functionality is required, register on the openweathermap.org site and obtain an API key (for free!) Follow the instructions on the site to obtain the ID of the location closest to you.

# Scheduling

The script is intended to be run periodically at a frequency determined by the status interval configured for the system on PVOutput.org - eg every 5 minutes. Scheduling functionality is not part of the script. As an example, the Windows Task Scheduler provides a very capable method for providing this. In this case, the scheduled action would look something like:

`powershell.exe -command "& \"C:\Users\Bob\Downloads\Zappi2PVOutput.ps1\""`
