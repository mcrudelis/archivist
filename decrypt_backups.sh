#!/bin/bash

#=================================================
# INSTALL DEPENDENCIES
#=================================================

sudo apt-get update
sudo apt-get install encfs ccrypt

#=================================================
# ASK FOR THE BACKUP DIRECTORY
#=================================================

while true
do
    echo ""
    echo "Please enter the absolute path of the encrypted backup you're willing to decrypt"
    echo -n ": "
    read encrypted_backup_dir

    if [ ${encrypted_backup_dir:0:1} == '/' ]
    then
        if [ -e "$encrypted_backup_dir" ]
        then
            break
        else
            echo "This directory does not exist."
        fi
    else
        echo "This path is not absolute. Please enter an absolute path."
    fi
done
echo ""

#=================================================
# DECRYPT .ENCFS6.XML
#=================================================

echo "Please enter the password to decrypt encfs file"
ccrypt --decrypt "$encrypted_backup_dir/.encfs6.xml.encrypted.cpt"
mv "$encrypted_backup_dir/.encfs6.xml.encrypted" "$encrypted_backup_dir/.encfs6.xml"

#=================================================
# DECRYPT THE BACKUP DIRECTORY
#=================================================

echo ""
mkdir -p "${encrypted_backup_dir}_decrypted"
echo "Please enter the password to decrypt your backups (same as previous)"
encfs --idle=5 "$encrypted_backup_dir" "${encrypted_backup_dir}_decrypted"

echo ""
echo "Your backup are available in clear at ${encrypted_backup_dir}_decrypted"
echo "In will be unmount 5 minutes after you stop using it."
