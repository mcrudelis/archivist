#!/bin/bash

archive="$1"

if [ -z "$archive" ]
then
    echo "File $archive does not exist !"
    exit 1
fi

selection=0
echo "What to do with that backup file ?"
echo "1) Extract inplace for manual exploration (Run as root to restore permissions)."
echo "2) Restore a regular backup to its destination."
echo "3) Restore a YunoHost backup."
while [ $selection -lt 1 ] || [ $selection -gt 3 ]
do
    read -p "?: " selection
done

# Extract inplace for manual exploration
if [ $selection -eq 1 ]
then
    echo -e "\n\e[1mExtract the archive in the current directory...\e[0m"
    tar --extract --verbose --file="$archive"
fi

# Restore a regular backup to its destination
if [ $selection -eq 2 ]
then
    echo -e "\n\e[1mExtract the archive back to its origin...\e[0m"
    sudo tar --extract --verbose --absolute-names --file="$archive"
fi

# Restore a YunoHost backup
if [ $selection -eq 3 ]
then
    # Get the name of the backup file only
    backup_name="$(basename "$archive")"
    backup_name=${backup_name%%\.*}
    # Get the id of the app from the info.json file
    echo -e "\n\e[1mCheck if the app is still installed...\e[0m"
    app_id=$(tar --extract --file="$archive" /home/yunohost.backup/archives/$backup_name.info.json -O | sed 's/^.*apps.: {.\([[:alnum:]_]\)/\1/g' | cut -d'"' -f1)
    # Check if the app is already installed.
    if sudo yunohost app list | grep "id" | grep --quiet --word-regexp "$app_id"
    then
        echo -e "\n\e[1mThis app is still installed.\nWould you like to remove it before restoring ? (y/N)\e[0m"
        read -p "?: " selection
        selection=${selection:-n}
        if [ ${selection,,} == 'y' ]
        then
            echo -e "\n\e[1mRemove the app $app_id for its restoration...\e[0m"
            sudo yunohost app remove "$app_id"
        fi
    fi

    # Uncompress the archive file to its simple original tar file.
    echo -e "\n\e[1mUncompress the archive...\e[0m"
    tar -xf "$archive" -C "$(dirname "$archive")"
    # Copy the tar file itself back to yunohost.backup directory
    ynh_backup_file="$backup_name.tar"
    sudo mv "$(dirname "$archive")/home/yunohost.backup/archives/$ynh_backup_file" "/home/yunohost.backup/archives/"
    # Restore the YNH backup
    echo -e "\n\e[1mRestore the ynh backup...\e[0m"
    sudo yunohost backup restore --debug --force "$ynh_backup_file"

    # Clean up
    sudo rm "/home/yunohost.backup/archives/$ynh_backup_file"
    sudo rm "/home/yunohost.backup/archives/${ynh_backup_file%%.*}.info.json"
    sudo rm "$(dirname "$archive")/home/yunohost.backup/archives/${ynh_backup_file%%.*}.info.json"
fi
