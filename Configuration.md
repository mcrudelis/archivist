# Configuration of archivist

[*Lire ce readme en français*](./Configuration_fr.md)

*The Configuration of archivist is in the file Backup_list.conf*

* ### backup_dir=
The main backup directory, where all your backups will be stored.

* ### enc_backup_dir=
The directory where the backup will be mounted as a encrypted version.

* ### encrypt=
*true or false*  
Encrypt the backups before sending them.  
Even if this paramater is activate, your main backup will be keep clear. Only the backups send to the recipients will be encrypted.

* ### cryptpass=
The file which contains the password for encryption.  
This file should be set at chmod 400 to restrict the read access only to root.  
Not needed if encrypt is not set to true.

* ### ynh_core_backup=
*true or false*  
Make a backup of the core of YunoHost with `yunohost backup create --ignore-app`

* ### ynh_app_backup=
*Optionnal parameter*  
Make backups of specified apps with `yunohost backup create --ignore-system --apps`  
Add a line for each app you want to backup.  
For example, for 2 different wordpress:
```
ynh_app_backup=wordpress
ynh_app_backup=wordpress__2
```
You can list all your installed apps with `sudo yunohost app list --installed | grep "id: " | cut -d ':' -f2 | cut -c2-`

* ### max_size=
*Size in Mb*  
Specify the max size of each backup for the following option file_to_backup.  
This option is a soft limit, that means the script will try to limit each backup to this max size if it can.  
But there's 2 limitations, for a single directory, it can't makes more than one backup file, even if the files in this directory exceed this maximum size.  
And, if there's some files in a directory, next to subdirectories, it'll make only one backup for this files.  
So this limit will be applied to split the backup by its subdirectories to avoid to have only one big backup.

* ### file_to_backup=
Allow to add a directory or a file to your backup.  
You can add as many line as you want.

* ### exclude_backup=
*Optionnal parameter*  
Exclude directories or files from the previous file_to_backup options.  
You can add as many line as you want.  
*You can use regex to select files or directories to exclude.*

* ### > recipient name=
Add a new recipient for your backups.  
This option is used to declare a new recipient, and give it a name.  
Use this option to declare a new place where your backup will be send.  
> *If possible, you should at least have one distant recipient to keep your backup in a secured place.*

  Each recipient have its specific options.  
  Here the different options:

  * #### type=
  The type option allow you to choose your sender script in the 'senders' directory.  
  You can choose between *local* or *rsync_ssh*.

  * #### destination directory=
  The directory where the backup will be put in your recipient.

  * #### encrypt=
  *true or false*  
  *Optionnal parameter*  
  Override the main encrypt parameter, if the main parameter is set to true. Otherwise, the main backup will be not encrypted and you can't have a encrypted version of your backups.

  * #### exclude backup=
  *Optionnal parameter*  
  Exclude a backup file or a complete directory from the main backup directory for this recipient.  
  You can add as many line as you want.

  * #### include backup=
  *Optionnal parameter*  
  Choose the only file or directory which be send to this recipient.  
  You can add as many line as you want.

---
## Pre and post backup commands

Before and after each kind of backup, you can execute a command or a script.  
For example for the core of YunoHost, you can use these commands:
```
ynh_core_pre_backup=command to execute before the backup of the core.
ynh_core_post_backup=/path/to/a/script to execute after the backup of the core.
```

There're different pre and post instructions for each kind of backup.
- For core of YunoHost, use `ynh_core_pre_backup` and `ynh_core_post_backup`.
- For apps, use `ynh_app_pre_backup` and `ynh_app_post_backup`.
- For files and directories, use `files_pre_backup` and `files_post_backup`.
- And for each recipient, you can use `pre_backup` and `post_backup`.

---

## Senders

The senders scripts are stored in the senders directory.  
Each sender can have his own specific options.

* ### `local`
The local sender is simply a local backup which used rsync to not duplicate the backup.  
You can used this sender to make a backup in a external hard drive or any mounted filesystem.

  * #### Specific options:
  No specific options for this sender.

* ### `rsync_ssh`
Send the backups in a distant ssh filesystem by using rsync.
> Can be used with the [Chroot ssh directories](https://github.com/YunoHost-Apps/ssh_chroot_dir_ynh)

  * #### Specific options:
    * **ssh_host=**  
    Domain or ip of the distant ssh directory.
    * **ssh_user=**  
    User to connect to ssh.
    * **ssh_port=**  
    *Optionnal parameter*  
    Port to connect to ssh, default 22.
    * **ssh_key=**  
    *Optionnal parameter*  
    Private key to use to connect to ssh.
    * **ssh_pwd=**  
    *Optionnal parameter*  
    Password to use to connect to ssh.
    * **ssh_options=**  
    *Optionnal parameter*  
    Any other ssh options.
