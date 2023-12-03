#!/bin/bash

#=================================================
# GET THE SCRIPT'S DIRECTORY
#=================================================

script_dir="$(dirname $(realpath $0))"

#=================================================
# LOAD MAIN VARIABLES
#=================================================

config_file="$script_dir/Backup_list.conf"
compression_modes="$script_dir/compression_modes"

backup_dir="$(grep -m1 "^backup_dir=" "$config_file" | cut -d'=' -f2)"
# Remove double quote, if there are.
backup_dir=${backup_dir//\"/}
enc_backup_dir="$(grep -m1 "^enc_backup_dir=" "$config_file" | cut -d'=' -f2)"
enc_backup_dir=${enc_backup_dir//\"/}
encrypt=$(grep -m1 "^encrypt=" "$config_file" | cut -d'=' -f2)
cryptpass="$(grep -m1 "^cryptpass=" "$config_file" | cut -d'=' -f2)"
cryptpass=${cryptpass//\"/}
max_size=$(grep -m1 "^max_size=" "$config_file" | cut -d'=' -f2)
ynh_compression_mode=$(grep -m1 "^ynh_compression_mode=" "$config_file" | cut -d'=' -f2)
files_compression_mode=$(grep -m1 "^files_compression_mode=" "$config_file" | cut -d'=' -f2)

date

#=================================================
# COMPRESSION FORMAT
#=================================================

# Get the previous compression formats
if [ -e "$compression_modes" ]
then
    previous_ynh_compression_mode=$(grep -m1 "^ynh_compression_mode=" "$compression_modes" | cut -d'=' -f2)
    previous_files_compression_mode=$(grep -m1 "^files_compression_mode=" "$compression_modes" | cut -d'=' -f2)
else
    previous_ynh_compression_mode=gzip
    previous_files_compression_mode=gzip
fi

ynh_force_backup=0
if [ "$ynh_compression_mode" == "gzip" ]; then
    ynh_compression_suffix=tar.gz
elif [ "$ynh_compression_mode" == "lzop" ]; then
    ynh_compression_suffix=tar.lzo
elif [ "$ynh_compression_mode" == "zstd" ]; then
    ynh_compression_suffix=tar.zst
elif [ "$ynh_compression_mode" == "bzip2" ]; then
    ynh_compression_suffix=tar.bz2
elif [ "$ynh_compression_mode" == "lzma" ]; then
    ynh_compression_suffix=tar.lzma
elif [ "$ynh_compression_mode" == "lzip" ]; then
    ynh_compression_suffix=tar.lz
elif [ "$ynh_compression_mode" == "xz" ]; then
    ynh_compression_suffix=tar.xz
elif [ "$ynh_compression_mode" == "none" ]; then
    ynh_compression_suffix=tar
elif [ "$ynh_compression_mode" == "symlink" ]; then
    ynh_compression_suffix=tar
else
    echo "Error: Compression format not recognized for ynh_compression_mode !"
    echo "Fall back to gzip."
    ynh_compression_mode=gzip
    ynh_compression_suffix=tar.gz
fi
echo "ynh_compression_mode=$ynh_compression_mode" > "$compression_modes"

# If the compression format has changed, force new backups
if [ "$previous_ynh_compression_mode" != "$ynh_compression_mode" ]
then
    echo "> WARNING: Compression format has been modified for YunoHost backups. All backups will be rebuilt"
    ynh_force_backup=1
fi

files_force_backup=0
if [ "$files_compression_mode" == "gzip" ]; then
    files_compression_suffix=tar.gz
elif [ "$files_compression_mode" == "lzop" ]; then
    files_compression_suffix=tar.lzo
elif [ "$files_compression_mode" == "zstd" ]; then
    files_compression_suffix=tar.zst
elif [ "$files_compression_mode" == "bzip2" ]; then
    files_compression_suffix=tar.bz2
elif [ "$files_compression_mode" == "lzma" ]; then
    files_compression_suffix=tar.lzma
elif [ "$files_compression_mode" == "lzip" ]; then
    files_compression_suffix=tar.lz
elif [ "$files_compression_mode" == "xz" ]; then
    files_compression_suffix=tar.xz
elif [ "$files_compression_mode" == "none" ]; then
    files_compression_suffix=tar
    files_compression_mode=""
else
    echo "Error: Compression format not recognized for files_compression_mode !"
    echo "Fall back to gzip."
    files_compression_mode=gzip
    files_compression_suffix=tar.gz
fi
echo "files_compression_mode=$files_compression_mode" >> "$compression_modes"

# If the compression format has changed, force new backups
if [ "$previous_files_compression_mode" != "$files_compression_mode" ]
then
    echo "> WARNING: Compression format has been modified for files and directories. All backups will be rebuilt"
    files_force_backup=1
fi

#=================================================
# EXEC PRE AND POST BACKUP
#=================================================

exec_pre_post_backup () {
    local exec_command="$1"
    local local_config_file="$2"
    local line_to_exec="$(grep -m1 "^$exec_command=" "$local_config_file" | cut -d'=' -f2)"
    eval $line_to_exec
}

#=================================================
# SPLIT THE DIRECTORIES
#=================================================

# List a directory recursively and split by the max size.
# Try to split directory to not keep a directory more large than the max size.
# But there 2 limitations:
# 	- It will never made more than 1 line for a single directory (Even if it's a real big directory without subdirectories)
# 	- And the same if there's files next to subdirectories, only 1 line will be made for all this files.
# So, the splitting is effective only for the subdirectories.
size_splitter () {
    local dir_to_list="$1"
    local dir=""

    # Check the size of the whole directory
    local size=$(du --apparent-size --block-size=1M --summarize --exclude-from="$script_dir/exclude_list" "$dir_to_list" | awk '{print $1}')
    if [ "$size" -le $max_size ]
    then
        # If the directory has a size inferior to the limit
        # Add the directory to the list
        echo "$dir_to_list"
    else
        # Check if there're any files in this directory
        if [ "$(find "$dir_to_list" -maxdepth 1 -type f | wc --lines)" -gt 0 ]
        then
            echo "files:$dir_to_list"
        fi

        # Then list all directories in the directory
        while read dir
        do
            if [ -n "$dir" ]	# If there's no sub directory, the list will be empty.
            then
                # Get only the directory, without the size.
                dir_only="/$(echo "$dir" | cut -d'/' -f2-)"
                if [ "$(echo "$dir" | awk '{print $1}')" -gt $max_size ]
                then
                    # If the directory has a size superior to the limit
                    # Check if there're any subdirectories
                    if [ "$(find "$dir_only" -maxdepth 1 -type d | wc --lines)" -gt 1 ]
                    then

                        # Check if there're any files in this directory
                        if [ "$(find "$dir_only" -maxdepth 1 -type f | wc --lines)" -gt 0 ]
                        then
                            echo "files:$dir_only"
                        fi

                        # Go deeper and list all directories in this directory too.
                        size_splitter  "$dir_only"
                        # Because, it's a recursive function, the current function will continue after the end of the next one.

                    # In case there's no subdirectory, keep the directory like is it.
                    else
                        echo "$dir_only"

                    fi
                else
                    echo "$dir_only"
                fi
            fi
        # Use tac to reverse the print out, then sed 1d to delete the first line, the directory itself.
        done <<< "$(du --apparent-size --block-size=1M --max-depth=1 --exclude-from="$script_dir/exclude_list" "$dir_to_list" | tac | sed 1d)"
    fi
}

echo "> Build list of files to backup"

# Build exclude list
> "$script_dir/exclude_list"
while read backup
do
    echo "${backup//\"/}" >> "$script_dir/exclude_list"
done <<< "$(grep "^exclude_backup=" "$config_file" | cut -d'=' -f2)"

# List all requested backups
> "$script_dir/dir_list"
while read backup
do
    if [ -n "$backup" ]; then
        size_splitter "${backup//\"/}" "$max_size" >> "$script_dir/dir_list"
    fi
done <<< "$(grep "^file_to_backup=" "$config_file" | cut -d'=' -f2)"

#=================================================
# CHECK PASSWORD CHANGE
#=================================================

enc_backup_list="$backup_dir/enc_backup_list"

# Verify the checksum of the password file.
if ! sudo md5sum --status --check "$cryptpass.md5" 2> /dev/null
then
    if [ -e "$cryptpass.md5" ]; then
        echo "> Password has been changed."
    fi
    # If the checksum is different, the password has been changed.
    # Store the new checksum
    sudo md5sum "$cryptpass" > "$cryptpass.md5"
    # Then, purge the $enc_backup_list to regenerate all the encrypted path
    > "$enc_backup_list"
fi

#=================================================
# LIST OF ENCRYPTED FILES
#=================================================

# Print the correspondances between clear file and encrypted file
print_clear_encrypted () {
    local backup="$1"
    # Print the clear name of this directory
    echo -n "$backup:" >> "$enc_backup_list"
    # Get the parent directory
    local parent_dir="$(dirname "$backup")"

    if [ "$parent_dir" != "/" ]
    then
        # Find the parent directory in the list.
        local enc_parent=$(grep -m1 "^$parent_dir:" "$enc_backup_list")
        # Get the encrypted path for this directory
        local enc_path="$(echo "$enc_parent" | cut -d':' -f2-)"
    fi

    # Print the complete encrypted path, then the encrypted name of the directory itself.
    echo "$enc_path/$(sudo encfsctl encode --extpass="cat \"$cryptpass\"" "$backup_dir" -- "$(basename "$backup")")" >> "$enc_backup_list"
}

print_encrypted_name () {
    local backup="$1"
    local mode="$2"

    # Remove the name of the backup dir in the path
    backup=${backup//"$backup_dir"/}

    # Do nothing if 'encrypt' is not set.
    if [ "${encrypt,,}" == "true" ]
    then
        # Add a new line to $enc_backup_list
        if [ "$mode" == "add" ]
        then
            # Add a new line only if there not already a line for this backup
            if ! grep --quiet "^$backup:" "$enc_backup_list"
            then
                print_clear_encrypted "$backup"
            fi
        # Remove a new line in $enc_backup_list
        elif [ "$mode" == "del" ]
        then
            sudo sed --in-place "\|^$backup:|d"  "$enc_backup_list"
        fi
    fi
}

#=================================================
# INIT AND USE ENCFS
#=================================================

mount_encrypt_directory () {
    # Mount the encrypted directory only if not yet mounted.
    if ! mount | grep --quiet "$enc_backup_dir"
    then
        # Encrypt the whole directory with encfs.
        sudo encfs --reverse --idle=5 --extpass="cat \"$cryptpass\"" --standard "$backup_dir" "$enc_backup_dir"
        # Here we will use the reverse mode of encfs, that means the directory will be encrypted only to be send via rsync.
    fi
}

if [ "${encrypt,,}" == "true" ]
then
    # If there no encfs config file. encfs has to be initialized.
    if [ ! -e "$backup_dir/.encfs6.xml" ]
    then
        mkdir -p "$enc_backup_dir"
        # Mount the directory for the first time
        mount_encrypt_directory
        # Then unmount the directory
        sudo umount "$enc_backup_dir"
    fi
fi

#=================================================
# COMPRESS FILES
#=================================================

# Create directories recursively and keep their attributes
directories_hierarchy () {
    local dir="$1"
    if echo "$dir" | grep --extended-regexp --quiet ".+/"
    then
        # Get the parent dir
        dir="$(dirname "$dir")"
        if [ ! -d "$backup_dir/$dir" ]
        then
            # If the directory doesn't exist in the backup dir
            # Recall the function to try the parent dir of the parent dir.
            directories_hierarchy "$dir"
            # Copy the directory only and keep its attributes
            sudo rsync -d -AgoptX "$dir" "$backup_dir$(dirname "$dir")"
            # And add the encrypted name of this directory in the list
            print_encrypted_name "$backup_dir$dir" add
            # Because, it's a recursive function, the current function will continue after the end of the next one.
        fi
    fi
}

echo "> Compress backups"

# Purge the list of backup files
> "$backup_dir/backup_list"
pre_backup=0

# Check each directory or files to backup from the list builded by size_splitter
# For each file/directory, verify the checksum then create a backup with tar.
while read backup
do
    if [ $pre_backup -eq 0 ]
    then
        exec_pre_post_backup "files_pre_backup" "$config_file"
        pre_backup=1
    fi

    echo -n "."
    # If the path is preceed by "files:", backup only the files in this directory
    if echo "$backup" | grep -q "files:"
    then
        # Remove files:, and keep only the directory
        backup=${backup#files:}
        # Build a list of files in this directory (only files, no directories)
        find "$backup" -maxdepth 1 -type f > "$script_dir/liste"

        # Build the global checksum by the checksum of the list of each checksum
        new_checksum=""
        while read <&3 files
        do
            # Concatenate the checksum of each file
            new_checksum="$new_checksum $(md5sum "$files")"
        done 3< "$script_dir/liste"
        # Then make a checksum of this concatenation
        new_checksum="$(echo "$new_checksum" | md5sum | cut -d' ' -f1)"

    # Else, backup the whole directory
    else
        # Create a "list" with only this directory
        echo "$backup" > "$script_dir/liste"

        # Make a checksum of each file in the directory, then a checksum of all these cheksums.
        # That give us a checksum for the whole directory
        new_checksum=$(find "$backup" -type f -exec md5sum {} \; | md5sum | cut -d' ' -f1)
    fi

    directories_hierarchy "$backup"

    # Build a list of each backup
    echo "$backup.$files_compression_suffix" >> "$backup_dir/backup_list"

    # Get the previous checksum
    old_checksum=$(cat "$backup_dir/$backup.md5" 2> /dev/null)
    # Then compare the 2 checksum
    if [ "$new_checksum" == "$old_checksum" ] && [ -e "$backup_dir/$backup.$files_compression_suffix" ] && [ $files_force_backup -eq 0 ] 
    then
        continue
    else
        echo -e "\n>> Create a new backup for $backup"
        # Update the checksum for this backup
        echo $new_checksum > "$backup_dir/$backup.md5"
        # Create a tarball from the list of files 'liste'
        tar --create --acls --preserve-permissions --xattrs --absolute-names \
            --exclude-from "$script_dir/exclude_list" \
            --file "$backup_dir/$backup.$files_compression_suffix" \
            --files-from "$script_dir/liste" \
            --$files_compression_mode
        # Then print the size of this archive.
        ls --size --human-readable "$backup_dir/$backup.$files_compression_suffix"

        # And add the encrypted name of this archive in the list
        print_encrypted_name "$backup_dir$backup.$files_compression_suffix" add
        echo ""
    fi

done < "$script_dir/dir_list"
echo ""

if [ $pre_backup -eq 1 ]
then
    exec_pre_post_backup "files_post_backup" "$config_file"
    pre_backup=0
fi

#=================================================
# YUNOHOST BACKUPS
#=================================================

echo "> Backup YunoHost core and apps"

# Make a temporary backup and compare the checksum with the previous backup.
backup_checksum () {
    local backup_cmd="$1"
    local temp_backup_dir="$backup_dir/ynh_backup/temp"
    # Make a temporary backup
    echo ""
    echo ">> Make a temporary backup for $backup_name"
    sudo rm -rf "$temp_backup_dir"
    if ! $backup_cmd --methods copy --output-directory "$temp_backup_dir" --name $backup_name.temp > /dev/null
    then
        # If the backup fail, do not make a real backup
        echo ">>> The temporary backup failed..."
        return 1
    fi
    # Remove the info.json file
    sudo rm "$temp_backup_dir/info.json"
    # Make a checksum of each file in the directory, then a checksum of all these cheksums.
    # That give us a checksum for the whole directory
    local new_checksum=$(sudo find "$temp_backup_dir" -type f -exec md5sum {} \; | md5sum | cut -d' ' -f1)
    sudo rm -rf "$temp_backup_dir"
    # Get the previous checksum
    local old_checksum=$(cat "$backup_dir/ynh_backup/$backup_name.md5" 2> /dev/null)
    # And compare the 2 checksum
    if [ "$new_checksum" == "$old_checksum" ] && [ $ynh_force_backup -eq 0 ]
    then
        echo ">>> This backup is the same than the previous one"
        return 1
    else
        echo ">>> This backup is different than the previous one"
        echo $new_checksum > "$backup_dir/ynh_backup/$backup_name.md5"
        return 0
    fi
}

    #=================================================
    # YUNOHOST CORE BACKUP
    #=================================================

    # Load the variable ynh_core_backup from the config file.
    ynh_core_backup=$(grep -m1 "^ynh_core_backup=" "$config_file" | cut -d'=' -f2)

    if [ "${ynh_core_backup,,}" == "true" ]
    then
        exec_pre_post_backup "ynh_core_pre_backup" "$config_file"

        mkdir -p "$backup_dir/ynh_backup"
        print_encrypted_name "$backup_dir/ynh_backup" add
        backup_name="ynh_core_backup"
        # Make a list of all backup hooks and exclude the home hook which may make huge backup.
        # We need here a dynamic list since those hooks are changing names at each upgrade !!!
        backup_hooks=($(ls /usr/share/yunohost/hooks/backup/ | grep --extended-regexp --invert-match "home|multimedia" | cut --delimiter=- --fields=2))
        echo "> Backup hooks used: ${backup_hooks[@]}"
        backup_command="sudo yunohost backup create --system ${backup_hooks[@]}"
        # If the backup is different than the previous one
        if backup_checksum "$backup_command"
        then
            echo ">> Make a real backup for $backup_name"
            # Make a real backup
            sudo yunohost backup delete "$backup_name" > /dev/null 2>&1
            $backup_command --name $backup_name > /dev/null

            if [ "$ynh_compression_mode" != "none" ] && [ "$ynh_compression_mode" != "symlink" ]
            then
                # Compress the backup
                tar --create --acls --preserve-permissions --xattrs --absolute-names \
                    --file "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix" \
                    --$ynh_compression_mode \
                    /home/yunohost.backup/archives/$backup_name.{tar,info.json}
            else
                if [ "$ynh_compression_mode" == "symlink" ]
                then
                    # Create a symbolic link instead of a copy of the backup
                    sudo ln --force --symbolic /home/yunohost.backup/archives/$backup_name.{tar,info.json} "$backup_dir/ynh_backup/"
                else # No compression
                    # Copy the backup
                    sudo cp --remove-destination /home/yunohost.backup/archives/$backup_name.{tar,info.json} "$backup_dir/ynh_backup/"
                fi
            fi

            # Add this backup to the list
            echo "/ynh_backup/$backup_name.$ynh_compression_suffix" >> "$backup_dir/backup_list"

            ls --size --human-readable "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix"

            # And add the encrypted name of this backup in the list
            print_encrypted_name "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix" add
        fi
        # Add this backup to the list
        echo "/ynh_backup/$backup_name.$ynh_compression_suffix" >> "$backup_dir/backup_list"

        exec_pre_post_backup "ynh_core_post_backup" "$config_file"
    fi

    #=================================================
    # YUNOHOST APPS BACKUPS
    #=================================================

    pre_backup=0
    while read app
    do
        if [ -n "$app" ]
        then
            if [ $pre_backup -eq 0 ]
            then
                exec_pre_post_backup "ynh_app_pre_backup" "$config_file"
                pre_backup=1
            fi

            # Handle 'do_not_backup_data' after the app name.
            if echo "$app" | grep --quiet "do_not_backup_data"
            then
                do_not_backup_data=1
            else
                do_not_backup_data=0
            fi
            # Remove 'do_not_backup_data' mention (if there are) after the app name
            app=${app%% *}

            mkdir -p "$backup_dir/ynh_backup/"
            print_encrypted_name "$backup_dir/ynh_backup" add
            backup_name="${app}_backup"
            backup_command="sudo BACKUP_CORE_ONLY=$do_not_backup_data yunohost backup create --apps"
            # If the backup is different than the previous one
            if backup_checksum "$backup_command $app"
            then
                echo ">>>> Make a real backup for $backup_name"
                # Make a real backup
                sudo yunohost backup delete "$backup_name" > /dev/null 2>&1
                $backup_command $app --name $backup_name > /dev/null

                if [ "$ynh_compression_mode" != "none" ] && [ "$ynh_compression_mode" != "symlink" ]
                then
                    # Compress the backup
                    tar --create --acls --preserve-permissions --xattrs --absolute-names \
                        --file "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix" \
                        --$ynh_compression_mode \
                        /home/yunohost.backup/archives/$backup_name.{tar,info.json}
                else
                    if [ "$ynh_compression_mode" == "symlink" ]
                    then
                        # Create a symbolic link instead of a copy of the backup
                        sudo ln --force --symbolic /home/yunohost.backup/archives/$backup_name.{tar,info.json} "$backup_dir/ynh_backup/"
                    else # No compression
                        # Copy the backup
                        sudo cp --remove-destination /home/yunohost.backup/archives/$backup_name.{tar,info.json} "$backup_dir/ynh_backup/"
                    fi
                fi
                ls --size --human-readable "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix"

                # And add the encrypted name of this backup in the list
                print_encrypted_name "$backup_dir/ynh_backup/$backup_name.$ynh_compression_suffix" add
            fi
            # Add this backup to the list
            echo "/ynh_backup/$backup_name.$ynh_compression_suffix" >> "$backup_dir/backup_list"
        fi
    done <<< "$(grep "^ynh_app_backup=" "$config_file" | cut -d'=' -f2)"

    if [ $pre_backup -eq 1 ]
    then
        exec_pre_post_backup "ynh_app_post_backup" "$config_file"
        pre_backup=0
    fi

#=================================================
# REMOVE OLD BACKUPS
#=================================================

echo "> Clean old backup files"

# Remove old backup files
while read backup
do
    backup=${backup#$backup_dir}
    # Remove an archive if it's not in the 'backup_list'
    if ! grep --quiet "$backup$" "$backup_dir/backup_list"
    then
        echo "Remove old archive $backup"
        sudo rm -f "$backup_dir/$backup"
        sudo rm -f "$backup_dir/$(dirname "$backup")/$(basename --suffix=.$ynh_compression_suffix "$backup").md5"
        sudo rm -f "$backup_dir/$(dirname "$backup")/$(basename --suffix=.$ynh_compression_suffix "$backup").info.json"
        sudo rm -f "$backup_dir/$(dirname "$backup")/$(basename --suffix=.$files_compression_suffix "$backup").md5"
        sudo rm -f "$backup_dir/$(dirname "$backup")/$(basename --suffix=.$files_compression_suffix "$backup").info.json"

        # And remove the encrypted name of this backup in the list
        print_encrypted_name "$backup_dir$backup" del
    fi
done <<< "$(sudo find $backup_dir -name "*.tar*")"

# Then remove empty directories
sudo find "$backup_dir" -type d -empty -delete -exec echo "Delete empty directory '{}'" \;

#=================================================
# ENCRYPT THE BACKUPS
#=================================================

if [ "${encrypt,,}" == "true" ]
then
    echo "> Encrypt backups"

    # Recreate the directory in case it doesn't exist anymore.
    mkdir -p "$enc_backup_dir"

    # Encrypt the whole directory with encfs.
    mount_encrypt_directory

    # Duplicate the .encfs6.xml file
    sudo cp "$backup_dir/.encfs6.xml" "$backup_dir/.encfs6.xml.encrypted"
    # And encrypt it with ccrypt.
    sudo ccrypt --encrypt --keyfile "$cryptpass" --force "$backup_dir/.encfs6.xml.encrypted"

fi

#=================================================
# SEND BACKUPS
#=================================================

config_file_per_recipient="$script_dir/recipient_config.conf"
backup_list_per_recipient="$script_dir/files_to_backup.list"

# Get the value of an option in the config file
get_option_value () {
    grep -m1 "^$1=" "$config_file_per_recipient" | cut -d'=' -f2
}

# Delete an option in the config file
delete_option () {
    local line_to_remove=$(grep -m1 "^$1=" "$config_file_per_recipient")
    sed --in-place "\|^$line_to_remove$|d" "$config_file_per_recipient"
}

# Read each recipient in the config file
# And keep only the line number for the line found
while read recipient
do

    if [ -n "$recipient" ]
    then
        #=================================================
        # BUILD CONFIG FILE FOR EACH RECIPIENT
        #=================================================

        # Build the config file for this recipient
        # Cut the line from the first line found by grep, until the end of the file
        tail --lines=+$recipient "$config_file" > "$config_file_per_recipient"
        # Ignore the first line, and try to find the next recipient name
        next_recipient=$(tail --lines=+2 "$config_file_per_recipient" | grep --line-number --max-count=1 "^> recipient name=" | cut -d':' -f1)
        # If there's another recipient
        if [ -n "$next_recipient" ]
        then
            # Delete the lines from this recipient to the end
            sed --in-place "$(( $next_recipient + 1 )),$ d" "$config_file_per_recipient"
        fi

        #=================================================
        # BUILD LIST OF FILES FOR EACH RECIPIENT
        #=================================================

        echo -e "\n-> Build the list of files for the recipient $(get_option_value "> recipient name")"

        include_files () {
            # Get the corresponding files
            if [ "${recipient_encrypt,,}" == "true" ]
            then
                # Keep only the encrypted names
                grep "$1.*.tar*" "$enc_backup_list" | sed "s/.*://"
            else
                # Or only the clear names
                grep "$1.*.tar*" "$backup_dir/backup_list"
            fi
        }

        get_encrypted_name ()
        {
            grep --max-count=1 "$1\.*:" "$enc_backup_list" | sed "s/.*://"
        }

        # Get the encrypt option for this recipient
        recipient_encrypt=$(get_option_value "encrypt")
        # Get the default value if there no specific option
        recipient_encrypt=${recipient_encrypt:-$encrypt}
        # Force the value of encrypt to be into the config file
        if [ -z "$(get_option_value "encrypt")" ]
        then
            echo "encrypt=$recipient_encrypt" >> "$config_file_per_recipient"
        fi

        if [ "$recipient_encrypt" == "true" ]
        then
            echo "encfs6=$backup_dir/.encfs6.xml.encrypted.cpt" >> "$config_file_per_recipient"
        fi

        # Include files in the list
        if grep --quiet "^include backup=" "$config_file_per_recipient"
        then
            > "$backup_list_per_recipient"
            # Add corresponding files for each include option
            while read include
            do
                delete_option "include backup"
                include_files "$include" >> "$backup_list_per_recipient"
            done <<< "$(grep "^include backup=" "$config_file_per_recipient" | cut -d'=' -f2)"
        else
            # If there's no include option, add all the files.
            include_files ".*" > "$backup_list_per_recipient"
        fi

        # Exclude files from the list
        # Remove corresponding files for each exclude option
        while read exclude
        do
            delete_option "exclude backup"
            if [ -n "$exclude" ]; then
                sed --in-place "\|$(get_encrypted_name "$exclude")|d" "$backup_list_per_recipient"
            fi
        done <<< "$(grep "^exclude backup=" "$config_file_per_recipient" | cut -d'=' -f2)"

        # Add backup source directory in the config file
        if [ "${recipient_encrypt,,}" == "true" ]
        then
            source_path="$enc_backup_dir"
            # Mount the encrypted directory
            mount_encrypt_directory
        else
            source_path="$backup_dir"
        fi
        echo "backup source=$source_path" >> "$config_file_per_recipient"

        type=$(get_option_value "type")
        delete_option "type"

        # Remove unused options in the config file
        sed --in-place "/^#/d" "$config_file_per_recipient"

        exec_pre_post_backup "pre_backup" "$config_file_per_recipient"

        # Call the script for given $type
        "$script_dir/senders/$type.sender.sh"

        exec_pre_post_backup "post_backup" "$config_file_per_recipient"
    fi

done <<< "$(grep --line-number "^> recipient name=" "$config_file" | cut -d':' -f1)"

date
