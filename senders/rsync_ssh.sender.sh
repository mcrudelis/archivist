#!/bin/bash

#=================================================
# INFORMATIONS ABOUT SPECIFIC OPTIONS
#=================================================

# ssh_host= ssh host
# ssh_user= ssh user
# ssh_port= (Optionnal) ssh port, 22 by default
# ssh_key= (Optionnal) Path of the private ssh key
# ssh_pwd= (Optionnal) Password for the ssh user
# You have to specify either an ssh key or a password.
# but it's hightly recommend to use an ssh key instead of a clear password.

# ssh_options= (Optionnal) Any other options you want to add

#=================================================
# GET THE SCRIPT'S DIRECTORY
#=================================================

script_dir="$(dirname $(realpath $0))"

#=================================================
# GENERIC VARIABLES
#=================================================

# Config file, build for this operation
config="$script_dir/../recipient_config.conf"

# List of files to send
files_list="$script_dir/../files_to_backup.list"

# These 2 files can be modified by this script, as they have been build only for the usage of this one.

#=================================================
# GET STANDARD VARIABLES FROM CONFIG FILE
#=================================================

# Get the value of an option in the config file
get_option_value () {
	grep -m1 "^$1=" "$config" | cut -d'=' -f2
}

# Get the name of the recipient
recipient_name=$(get_option_value "> recipient name")
# Get the destination directory
dest_directory=$(get_option_value "destination directory")
# Get the backup directory
backup_source=$(get_option_value "backup source")

#=================================================
# GET SPECIFIC VARIABLES FROM CONFIG FILE
#=================================================

ssh_host=$(get_option_value "ssh_host")
ssh_user=$(get_option_value "ssh_user")
ssh_port=$(get_option_value "ssh_port")
ssh_port=${ssh_port:-22}
ssh_key=$(get_option_value "ssh_key")
ssh_pwd=$(get_option_value "ssh_pwd")
ssh_options=$(get_option_value "ssh_options")
ssh_options="-p $ssh_port $ssh_options"

#=================================================
# SPECIFIC POST-TREATMENT
#=================================================

if [ -n "$ssh_key" ]
then
	# Use an ssh key if available
	ssh_options="$ssh_options -i $ssh_key"
	ssh_command="ssh"
else
	# Or use sshpass to give the password to ssh.
	if [ -e /usr/bin/sshpass ]
	then
		ssh_command="sshpass -p $ssh_pwd ssh"
	else
		echo "! If you want to use ssh without a key, please install 'sshpass'"
		exit 1
	fi
fi

# Because rsync can't remove files if it's using a files list.
# We're going to build an exlude list instead of an include list.

# List all backup files
sudo find "$backup_source" -type f > "$script_dir/../liste"
# Cut the backup dir path at the beginning of each lines
sed --in-place "s|^$backup_source||" "$script_dir/../liste"
# Print only the lines which are not in the include list. That will build a exclude list
comm -23 <(sort "$script_dir/../liste") <(sort "$files_list") > "$script_dir/../exclude_list"

#=================================================
# SEND ARCHIVES TO THE RECIPIENT
#=================================================

echo "> Copy backups files in $dest_directory."

sudo rsync --archive --verbose --human-readable --stats --itemize-changes \
	--delete-excluded --prune-empty-dirs --exclude-from="$script_dir/../exclude_list" \
	"$backup_source/" --rsh="$ssh_command $ssh_options" $ssh_user@$ssh_host:"$dest_directory"

# There some unusual options in this rsync command.
# Because rsync can't remove files if it's usinga file list.
# We're using a standard rsync with a --exclude-from list.
# And, in addition, we're using --delete-excluded to remove all exluded files, and --prune-empty-dirs to remove also empty directories.

#=================================================
# SEND .ENCFS6.XML TO THE RECIPIENT
#=================================================

if [ "$(get_option_value "encrypt")" == "true" ]
then
    sudo rsync "$(get_option_value "encfs6")" --rsh="$ssh_command $ssh_options" $ssh_user@$ssh_host:"$dest_directory"
fi
