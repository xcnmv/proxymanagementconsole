

[CmdletBinding(DefaultParameterSetName='Help')]
param (
	[Parameter(ParameterSetName='ConditionalStart')]
	[switch]$ConditionalStart,
	[Parameter(ParameterSetName='Start')]
	[switch]$Start,
	[Parameter(ParameterSetName='Restart')]
	[switch]$Restart,
	[Parameter(ParameterSetName='ConditionalRestart')]
	[switch]$ConditionalRestart,
	[Parameter(ParameterSetName='Stop')]
	[switch]$Stop,
	[Parameter(ParameterSetName='Status')]
	[switch]$Status,
	[Parameter(ParameterSetName='Help')]
	[switch]$Help,
	[Parameter(ParameterSetName='GUI')]
	[Switch]$GUI,
	[Parameter(mandatory=$true,ParameterSetName='ConditionalStart')]
	[Parameter(mandatory=$true,ParameterSetName='Start')]
	[Parameter(mandatory=$true,ParameterSetName='Restart')]
	[Parameter(mandatory=$true,ParameterSetName='ConditionalRestart')]
	[Parameter(mandatory=$true,ParameterSetName='GUI')]
	[String]$Url,
	[Parameter(mandatory=$true,ParameterSetName='ConditionalStart')]
	[Parameter(mandatory=$true,ParameterSetName='Start')]
	[Parameter(mandatory=$true,ParameterSetName='Restart')]
	[Parameter(mandatory=$true,ParameterSetName='ConditionalRestart')]
	[Parameter(mandatory=$true,ParameterSetName='GUI')]
	[String]$User
)

Begin{
	if($PSCmdlet.ParameterSetName -contains 'Help'){
		Get-Help $(Join-Path $PSScriptRoot $MyInvocation.MyCommand.Name) -Full
		EXIT 2
	}
	Function StopProxy{
		Write-Host "Killing all proxy connections" -ForegroundColor DarkGreen
		Get-Process *ssh* | Stop-Process -Force
	}
	Function StartProxy{
		param(
			[String]$Url,
			[String]$User
		)
		Write-Host "Starting Proxy Connection" -ForegroundColor DarkGreen
		ssh -D 1337 -q -C -N -f $($user)@$($url)
	}
	Function isProxyAlreadyRunning{
		if(Get-Process *ssh*){
			return $true
		}
	}
	Function GUI{
		param(
			[String]$Url,
			[String]$User
		)
		<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
		.NAME
		    Proxy Management Console
		#>

		Add-Type -AssemblyName System.Windows.Forms
		[System.Windows.Forms.Application]::EnableVisualStyles()

		$Form                            = New-Object system.Windows.Forms.Form
		$Form.ClientSize                 = New-Object System.Drawing.Point(224,61)
		$Form.text                       = "Proxy Management Console"
		$Form.TopMost                    = $false
		$Form.MaximizeBox				 = $false
		$Form.MinimizeBox				 = $false
		$Form.FormBorderStyle			 = 'FixedSingle'

		$CheckBox						 = New-Object system.Windows.Forms.CheckBox
		$CheckBox.Text					 = 'Always on top'
		$CheckBox.AutoSize				 = $false
		$CheckBox.Width					 = 205
		$CheckBox.Height				 = 20
		$CheckBox.location               = New-Object System.Drawing.Point(7,7)
		$CheckBox.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
		$CheckBox.Checked				 = $false

		$Button                          = New-Object system.Windows.Forms.Button
		$Button.text                     = "... checking ..."
		$Button.width                    = 100
		$Button.height                   = 30
		$Button.location                 = New-Object System.Drawing.Point(117,24)
		$Button.Font                     = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
	
		$StatuValue                      = New-Object system.Windows.Forms.Label
		$StatuValue.text                 = "... checking ..."
		$StatuValue.AutoSize             = $true
		$StatuValue.width                = 25
		$StatuValue.height               = 10
		$StatuValue.MaximumSize          = New-Object System.Drawing.Size(103,20)
		$StatuValue.location             = New-Object System.Drawing.Point(7,34)
		$StatuValue.Font                 = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
		
		$timer = New-Object System.Windows.Forms.Timer
		$timer.Interval = 500
		$timer.add_tick({
			$Form.TopMost = $CheckBox.Checked
			if(isProxyAlreadyRunning){
				$StatuValue.text = "Proxy is Active"
				$Button.text = 'Stop'
			}
			else{
				$StatuValue.text = "Proxy not found"
				$Button.text = 'Start'
			}
			})

		$Form.controls.AddRange(@($Button,$StatuValue,$CheckBox))

		$Button.Add_Click({ 
			if($Button.text -eq 'Start'){
				StartProxy -User $User -Url $Url
			}
			elseif($Button.text -eq 'Stop'){
				StopProxy
			}
		})

		$timer.start()
		[void]$Form.ShowDialog()
	}
	Function AutoUpdate{
		try{
			$loc = Get-Location | select -ExpandProperty Path
			Set-Location $PSScriptRoot
			if($(git status) -like "*master*"){
				Write-Host "...Updating..." -ForegroundColor DarkGray
				git pull origin master 1>$null 2>$null
				Write-Host "Update successful" -ForegroundColor DarkGray
			}
		}
		catch{
			Write-Host "Update failed" -ForegroundColor Red
		}
		Finally{
			Set-Location $loc
		}
	}
	$startProxyRequired=$false
}
Process{
	if(!$(get-command ssh -ErrorAction Ignore)){
		Write-Error "Missing dependencies. Install OpenSSH client and make sure it is available in the Path environmental variable"
	}
	if($(Get-Command Git -ErrorAction Ignore)){
		AutoUpdate
	}
	if($GUI -and $PSVersionTable.Platform -ne 'Unix'){
		Write-Host "Starting GUI" -ForegroundColor DarkGray
		GUI
	}
	else{
		$stopped=$null
		if($Status){
			if(isProxyAlreadyRunning){
				Write-Host "Proxy is already running" -ForegroundColor DarkGreen
			}
			else{
				Write-Host "Proxy is not detected" -ForegroundColor DarkGreen
			}
		}
		if(($Stop -or $Restart -or $ConditionalRestart) -and (isProxyAlreadyRunning)){
			StopProxy
			$stopped=$true
		}
		if($ConditionalStart -or $ConditionalRestart) {
			if($stopped){
				Write-Host "Proxy was stopped during this run.`r`nSleep 5 seconds before starting a new connection." -ForegroundColor DarkGray
				sleep 5
			}
			if (!(isProxyAlreadyRunning)){
				$Start=$true
			}
		}
		if($Start -or $Restart){
			if($stopped){
				Write-Host "Proxy was stopped during this run.`r`nSleep 5 seconds before starting a new connection." -ForegroundColor DarkGray
				sleep 5
			}
			StartProxy -User $User -Url $Url
		}
		Write-Host "All done, exiting..." -ForegroundColor DarkGray
		sleep 5
	}
}
End{
}