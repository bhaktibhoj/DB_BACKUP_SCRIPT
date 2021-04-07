#!/bin/bash

#################################################################
##############LOAD CONFIG FILE###################################
#################################################################

while [ $# -gt 0 ]; do
        case $1 in
                -c)
                        if [ -r "$2" ]; then
                                source "$2"
                                shift 2
                        else
                                ${ECHO} "Unreadable config file \"$2\"" 1>&2
                                exit 1
                        fi
                        ;;
                *)
                        ${ECHO} "Unknown Option \"$1\"" 1>&2
                        exit 2
                        ;;
        esac
done
 
if [ $# = 0 ]; then
        SCRIPTPATH=$(cd ${0%/*} && pwd -P)
            echo $SCRIPTPATH
        source "$SCRIPTPATH/pg_backup.config"
fi;

#######################################################################
################PRE-BACKUP CHECKS######################################
#######################################################################
# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
        echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
        exit 1;
fi;


########################################################################
#####################BACKUPS DIRECTORY CHECKS###########################
########################################################################

FINAL_BACKUP_DIRECTORY=$BACKUP_DIRECTORY"`date +%Y%m%d%H`"

echo "Backup will be reside in $FINAL_BACKUP_DIRECTORY"


#######################################################################
#########################FUNCTIONS#####################################
#######################################################################

sending_mail()
{
ssmtp bhakti.bhoj@triarqhealth.com -F Jenkins_Notification <<EOF
Cc: madhura.mahajan@triarqhealth.com , aniket.tamhane@triarqhealth.com
Subject: Warning! Production DB backup Failure : DB Name: $SINGLE_DB
Content-Type: text/html; charset="utf8"

        <html>
        <body>
        Hey There! This is system generated mail. Please do not reply this mail.
        </body>
        </html>
EOF
}


db_backup()
{
for SINGLE_DB in ${DB_ONLY_LIST//,/ }
    do

    echo -e "\n\nPerforming database backups"
    echo -e "--------------------------------------------\n"
    #if ! pg_dump -Fp -h "$HOSTNAME" -U "$USERNAME" -d "$SINGLE_DB" --no-password | bzip2 | openssl smime -encrypt -aes256 -binary -outform DEM -out "$FINAL_BACKUP_DIRECTORY$SINGLE_DB.bz2.ssl" backup_key.pem.pub ; then
    if ! /usr/bin/pg_dump -Fp -h "$SINGLE_HOST" -U "$USERNAME" -d "$SINGLE_DB" --no-password | gzip > "$FINAL_BACKUP_DIRECTORY$SINGLE_DB.gz" ; then
        echo "[!!ERROR!!] Failed to backup of $SINGLE_DB" && sending_mail 1>&2
    else
        echo "Database $SINGLE_DB backup taken successfully!!" 
        gsutil mv "$FINAL_BACKUP_DIRECTORY$SINGLE_DB.gz" gs://prod_databases_backups/"$SINGLE_DB"/ &&
        echo "Backup has been copied to bucket at path gs://prod_databases_backups/$SINGLE_DB"
    fi
    done


}

#######################################################################
#########################DB BACKUP#####################################
#######################################################################



for SINGLE_HOST in $HOSTNAME
do
    echo $SINGLE_HOST
    if [ "$SINGLE_HOST" == "104.198.241.110" ]
    then
        DB_ONLY_LIST="$DB_ONLY_LIST_COMMON_DB_PROD"
        db_backup
    else DB_ONLY_LIST="$DB_ONLY_LIST_RXMEDS_PROD_DB"
   	db_backup
    fi
done


find $BACKUP_DIRECTORY -maxdepth 1 -mtime +2 -name "*${FILE_SUFFIX}.gz" -exec rm -rf '{}' ';'

