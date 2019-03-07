# ElasticKnowBe4
![](https://github.com/wwalker0307/ElasticKnowBe4/blob/master/Dashboard.png?raw=true)
## Overview
KnowBe4's pre-baked report templates leave a bit to be desired.  Using their API, you can grab the same data and build your own using the ElasticStack.

## PowerShell Script
The powershell script is responsible for making the necessary API calls, stitching the records together and making a cohesive user report, and then shipping the data to an ElasticStack.  With minor modification, you could configure it to be used with anything that can read JSON.

## Setup
#### KnowBe4LogPull.ps1
* Line 3: Enter your API auth token inside the double quotes
* Line 9: If you intend to push the data to an Elastic Stack instance, enter the ingest folder path (or UNC path if accessible).
* Line 71 (Optional):  The script is configured to only pull campaigns from the last 30 days.  If you'd like to adjust this period, change line 71 where it says `-30`, to however many days you want to go back.  NOT RECOMMENDED:  You can remove this line to collect all campaigns from the beginning of time (or as far back as KnowBe4 allows you).  However, repeatedly doing this will only increase resource usage and record processing.
* Lines 5, 7, and 12 can be modified to make the script unattended.

#### knowbe4pipeline.yml
* Line 4:  Enter ingest folder path leaving `/*.log` at the end.
* Line 25-26, 28-29:  These lines can be used to convert the numeric group IDs to their text form.  For example, if your group name is `marketing` and the numeric ID is `123456`, change one of these lines/add an entry that says `"[user][groups]", "123456", "marketing",`.  **Note:**  Line 27 and 30 are used to strip all numbers from the given field.  This is to remove smart groups from being listed.
* Line 139: Enter the file path the knowbe4template.json
* Line 141: Enter your Elasticsearch Hostname/IP:Port number here.

#### knowbe4template.json
No modifications necessary to this file, just stick it somewhere that Logstash has read access to.
