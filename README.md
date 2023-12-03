# Archivist for YunoHost

Archivist is an automatic backup system for servers.  
Mainly designed to be used with a YunoHost server with the dedicated app, [archivist_ynh](https://github.com/YunoHost-Apps/archivist_ynh).

Archivist can automatically create backup for YunoHost core and apps using the internal backup system of YunoHost. It can also create backup of specific files and directories.  
Backups can then be send to many other places, local or distant.  


### Configuration

The configuration of archivist can be changed in the file Backup_list.conf  
Please read the [documentation](https://github.com/maniackcrudelis/archivist/blob/master/Configuration.md) about the configuration of archivist for more information.

### Additional scripts

Archivist comes with some addionnal scripts:

- quick_install.sh
This script is to be used in case you don't have YunoHost installed on your server.  
This script will clone the repository, install the required dependencies and configure Archivist to be ready to work.

- decrypt_backups.sh
This script is a simple decoding tool to use in case your encrypted backup should be explored.  
It use ccrypt and encfs to decode your `encfs6.xml` and mount a readable version of your backup.

- Archivist_restorer.sh
This script is intended to explore compressed backups and/or to restore a backup in place.
