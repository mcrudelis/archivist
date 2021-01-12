#!/bin/bash

#=================================================
# CHECK IF YUNOHOST IS INSTALLED
#=================================================

if [ -e /usr/bin/yunohost ]
then
	echo "YunoHost is installed on your server, you should have a look to the package Archivist_ynh. https://github.com/YunoHost-Apps/archivist_ynh"

	echo -n "Would you really continue ? (y/N): "
	read answer
	# Set the answer at lowercase only
	answer=${answer,,}
	if [ "${answer:0:1}" != "y" ]
	then
		echo "Cancelled..."
		exit 0
	fi
fi

#=================================================
# CLONE ARCHIVIST
#=================================================

final_path=/opt/archivist
sudo mkdir -p "$final_path"

sudo git clone https://github.com/maniackcrudelis/archivist "$final_path"

#=================================================
# INSTALL DEPENDENCIES
#=================================================

sudo apt-get install rsync encfs sshpass ccrypt lzop zstd lzip

#=================================================
# SETUP LOGROTATE
#=================================================

sudo mkdir -p /var/log/archivist

echo "/var/log/archivist/*.log {
		# Rotate if the logfile exceeds 100Mo
	size 100M
		# Keep 12 old log maximum
	rotate 12
		# Compress the logs with gzip
	compress
		# Compress the log at the next cycle. So keep always 2 non compressed logs
	delaycompress
		# Copy and truncate the log to allow to continue write on it. Instead of move the log.
	copytruncate
		# Do not do an error if the log is missing
	missingok
		# Not rotate if the log is empty
	notifempty
		# Keep old logs in the same dir
	noolddir
}" | sudo tee /etc/logrotate.d/archivist > /dev/null

#=================================================
# SET A DEFAULT CONFIGURATION
#=================================================

backup_dir="$final_path/backup"
enc_backup_dir="$final_path/encrypted_backup"

sudo mkdir -p "$backup_dir"

sudo cp "$final_path/Backup_list.conf.default" "$final_path/Backup_list.conf"

sudo sed -i "s@^backup_dir=.*@backup_dir=$backup_dir@" "$final_path/Backup_list.conf"
sudo sed -i "s@^enc_backup_dir=.*@enc_backup_dir=$enc_backup_dir@" "$final_path/Backup_list.conf"

sudo sed -i "s@^ynh_core_backup=.*@ynh_core_backup=false@" "$final_path/Backup_list.conf"

#=================================================
# SET THE CRON FILE
#=================================================

echo "0 2 * * * root nice -n10 $final_path/archivist.sh | tee -a /var/log/archivist/archivist.log 2>&1" \
	| sudo tee /etc/cron.d/archivist > /dev/null

#=================================================
# SET A PASSKEY
#=================================================

sudo touch "$final_path/passkey"
sudo chmod 400 "$final_path/passkey"

sudo sed -i "s@^encrypt=.*@encrypt=true@" "$final_path/Backup_list.conf"
sudo sed -i "s@^cryptpass=.*@cryptpass=$final_path/passkey@" "$final_path/Backup_list.conf"

echo ">> Please add a key for encryption in the file $final_path/passkey"
