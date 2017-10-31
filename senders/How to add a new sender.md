To add a new sender available for archivist, make a copy of local.sender.sh and begin to build your new sender.

- First, your sender have to be name with this syntax:
TYPE.sender.sh where TYPE is the name of your sender.

- Then, if you need specific options for your sender in the conf file Backup_list.conf
Add all the informations about these options in the 'INFORMATIONS ABOUT SPECIFIC OPTIONS' section
These informations are designed to be understable by the users who want to use this sender.

- In case of specific options.
Use the section 'GET SPECIFIC VARIABLES FROM CONFIG FILE' to load these options from the config file.

- If you have to work on the list of files or something else.
Use the section 'SPECIFIC POST-TREATMENT' to do the work you have to.

- In any case
Use the section 'SEND ARCHIVES TO THE RECIPIENT' to send the data with your tool.

To use this sender, you have just to define the type as the name of this sender.
And add the requested options
