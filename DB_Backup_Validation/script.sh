#!/bin/bash

gsutil ls gs://prod_databases_backups/ | awk -F'[/]' '{print $4}' > /opt/DB_Backup_script/DB_Backup_Validation/ALL_DBS

#cat /opt/DB_Backup_script/DB_Backup_Validation/ALL_DBS

sending_mail()
{
ssmtp bhakti.bhoj@triarqhealth.com -F Jenkins_Notification <<EOF
#Cc: madhura.mahajan@triarqhealth.com , aniket.tamhane@triarqhealth.com
Subject: Warning! Production DB backup Failure : DB Name: $line
Content-Type: text/html; charset="utf8"

        <html>
        <body>
        Hey There! This is system generated mail. Please do not reply this mail.
        </body>
        </html>
EOF
}

while read line 
do
 echo $line; 
echo $(gsutil ls gs://prod_databases_backups/$line | wc -l)
COUNT=$(gsutil ls gs://prod_databases_backups/$line | wc -l)
echo $COUNT
if [ "$COUNT" -lt 22 ];then 
echo "backups are not proper"
#sending_mail
else
echo "proper"
fi
done < /opt/DB_Backup_script/DB_Backup_Validation/ALL_DBS;
