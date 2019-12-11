#!/bin/bash

#=================================================
# INFORMATIONS ABOUT SPECIFIC OPTIONS
#=================================================

# b2_bucket= The bucket to send the backups to

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

b2_bucket=$(get_option_value "b2_bucket")

#=================================================
# SPECIFIC POST-TREATMENT
#=================================================

# List all backup files
sudo find "$backup_source" -type f > "$script_dir/../liste"

# Cut the backup dir path at the beginning of each lines
sed --in-place "s|^$backup_source||" "$script_dir/../liste"

# Print only the lines which are not in the include list. That will build an exclude list
comm -23 <(sort "$script_dir/../liste") <(sort "$files_list") > "$script_dir/../exclude_list"

# Remove leading slash from files
sed --in-place "s|^/||" "$script_dir/../exclude_list"

# Read the exclude list into a regex string
exclude_list=""
while read l; do
  exclude_list="$exclude_list($l)|"
done <"$script_dir/../exclude_list"
exclude_list=${exclude_list::-1}

#=================================================
# SEND ARCHIVES TO THE RECIPIENT
#=================================================

echo "> Copy backups files to b2://$b2_bucket/$dest_directory."

b2 sync --noProgress --delete --excludeRegex "$exclude_list" $backup_source b2://$b2_bucket/$dest_directory

#=================================================
# SEND .ENCFS6.XML TO THE RECIPIENT
#=================================================

if [ "$(get_option_value "encrypt")" == "true" ]
then
    b2 sync --noProgress --delete "$(get_option_value "encfs6")" b2://$b2_bucket/$dest_directory
fi
