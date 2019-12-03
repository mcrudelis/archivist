#!/bin/bash

#=================================================
# INFORMATIONS ABOUT SPECIFIC OPTIONS
#=================================================

# No specific options for this sender.

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

# spec_var1=$(get_option_value "specific option for type")

#=================================================
# SPECIFIC POST-TREATMENT
#=================================================

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
	"$backup_source/" "$dest_directory"

# There some unusual options in this rsync command.
# Because rsync can't remove files if it's usinga file list.
# We're using a standard rsync with a --exclude-from list.
# And, in addition, we're using --delete-excluded to remove all exluded files, and --prune-empty-dirs to remove also empty directories.

#=================================================
# SEND .ENCFS6.XML TO THE RECIPIENT
#=================================================

if [ "$(get_option_value "encrypt")" == "true" ]
then
    sudo rsync "$(get_option_value "encfs6")" "$dest_directory"
fi
