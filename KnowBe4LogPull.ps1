####Configurable Settings####
#API Auth Token
$AuthToken = ""
#Where to save json output to
$LocalPath = Read-Host "Folder path to save reports to"
#Upload json file to ElasticStack
$Upload = Read-Host "Upload to Elastic?(y|n)"
#Logstash ingest folder for ElasticStack
$Ingest = ""
#Delete local copy after upload
if ($Upload -eq "y") {
  $Dlocal = Read-Host "Delete local copy after upload?(y|n)"
}

####Base Settings####
#Base URL
$Base = "https://us.api.knowbe4.com"
#Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
#Set Required Headers
$auth =@{
  "ContentType" = 'application/json'
  "Method" = 'GET'
  "Headers" = @{
    "Authorization" = "Bearer $AuthToken"
    "Accept" = "application/json"
  }
}
$date = Get-Date -UFormat %Y%m%d%_%H%M%S


####Verify Connectivity to API####
Clear-Host
Try {
  Write-Host `n`n`n`n`n
  $Account = Invoke-RestMethod @auth -Uri "$Base/v1/account"
  $Account | Format-List name, type, domains, subscription*,current_risk_score
} Catch {
  $ReqError = $_
}
If ($ReqError -ne $null) {
  $ReqError.Exception,$ReqError.InvocationInfo,$ReqError.TargetObject | Out-File $LocalPath\APIConnectivityFail_$date -append
  Exit
}


####Pull User Information####
$users = @()
$uepage = [Math]::Truncate($Account.number_of_seats/250)+1
For($i=1;$i -le $uepage; $i++) {
  Write-Progress -Activity "Collecting User Info..." -Status "Page $i" -PercentComplete ($i/$uepage*100)
  $users += Invoke-RestMethod @auth -Uri "$Base/v1/users?per_page=250&page=$i"
  Start-Sleep -Seconds 1
}


####Pull Group Information####
$groups = Invoke-RestMethod @auth -Uri "$Base/v1/groups"


####Pull Phishing Campaigns####
$PCam = Invoke-RestMethod @auth -Uri "$Base/v1/phishing/campaigns"
#Convert create_date field from string to DateTime for comparison.
Foreach ($cam in $pcam) {
  $tz = Get-TimeZone
  [DateTime]$tdate = $cam.create_date
  [DateTime]$cam.create_date = (Get-Date($tdate).AddHours(($tz.BaseUtcOffset.Hours)*-1) -UFormat %Y-%m-%dT%T)
}
#Get campaigns from last 30 days
$PCam = $PCam | Where-Object {$_.Create_Date -gt ((Get-Date).AddDays(-30))}


####Generate results####
Foreach ($Camp in $PCam) {
#Collect phishing campaign results
  Remove-Variable PRes -ErrorAction SilentlyContinue
  $PRes = @()
  $phepage = [Math]::Truncate($camp.psts.users_count/250)+1
  For($i=1;$i -le $phepage; $i++) {
    Write-Progress -Activity "Collecting campaign results..." -Status "Page $i" -PercentComplete ($i/$phepage*100)
    $uri = "$Base/v1/phishing/security_tests/"+$Camp.psts.pst_id+"/recipients?per_page=250&page=$i"
    $PRes += Invoke-RestMethod @auth -Uri $uri
    Start-Sleep -Seconds 1
  }
#Associate user with phishing campaign results
  Foreach ($user in $users) {
    Remove-Variable upres -ErrorAction SilentlyContinue
    $upres = $pres | where {$_.user.id -eq $user.id}
    if ($upres -ne $null) {
      $username = $user.first_name+", "+$user.last_name
      $campname = $camp.name
      Write-Progress -Activity "'Generating results for campaign, '$campname'" -Status "$username"
#Generate JSON
      $json = [ordered]@{
        "campaign" = @{
          "create_date" = $camp.create_date.ToString("yyyy-MM-ddTHH:mm:ss")
          "difficulty" = $camp.difficulty_filter
          "email_template" = @{
              "name" = $upres.template.name
              "id" = $upres.template.id
          }
          "name" = $camp.name
          "status" = $camp.status
          "target_groups" = $camp.groups.name
        }
        "results" = @{
          "attachment_opened" = $upres.attachment_opened_at
          "bounced" = $upres.bounced_at
          "clicked" = $upres.clicked_at
          "data_entered" = $upres.data_entered_at
          "delivered" = $upres.delivered_at
          "exploited" = $upres.exploited_at
          "macro_enabled" = $upres.macro_enabled_at
          "opened" = $upres.opened_at
          "replied" = $upres.replied_at
          "reported" = $upres.reported_at
          "vulnerable_plugins" = $upres.vulnerable_plugins_at
        }
        "user" = @{
          "browser" = $upres.browser
          "browser_version" = $upres.browser_version
          "dept" = $user.department
          "first" = $user.first_name
          "groups" = $user.groups
          "ip" = $upres.ip
          "job_title" = $user.job_title
          "last" = $user.last_name
          "os" = $upres.os
          "phish_prone" = $user.phish_prone_percentage/100
        }
      }
#Export JSON results to local path
      $json | ConvertTo-Json -Depth 5 -Compress | Out-File $LocalPath\Results_$date.log -Append -Encoding UTF8
    }
  }
}

####Upload to Elastic####
If ($Upload -eq "y") {
  If ($DLocal -eq "y") {
    Move-Item -Path $LocalPath\Results_$date.log -Destination $Ingest\Results_$date.log
  } else {
    Copy-Item -Path $LocalPath\Results_$date.log -Destination $Ingest\Results_$date.log
  }
}

Write-Host "Process Complete..."
Start-Sleep -Seconds 3
Exit