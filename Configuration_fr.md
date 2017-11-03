# Configuration de archivist

[*Read this readme in english*](./Configuration.md)

*La Configuration de archivist se trouve dans le fichier Backup_list.conf*

* ### backup_dir=
Le dossier principal de sauvegarde, où seront stockées toutes vos sauvegardes.

* ### enc_backup_dir=
Le dossier où la version chiffrée des sauvegardes sera montée.

* ### encrypt=
*true or false*  
Chiffre les sauvegardes avant de les envoyer.  
Même si ce paramètre est activé, votre dossier principal de sauvegarde restera en clair. Seul les sauvegardes qui seront envoyées seront chiffrées.

* ### cryptpass=
Le fichier qui contient le mot de passe pour le chiffrage.  
Ce fichier devrait être réglé sur un chmod 400 pour restreindre sa lecture à root seulement.  
Pas nécessaire si encrypt n'est pas réglé à true.

* ### ynh_core_backup=
*true or false*  
Créer une sauvegarde du coeur de YunoHost avec `yunohost backup create --ignore-app`

* ### ynh_app_backup=
*Paramètre optionnel*  
Créer des sauvegardes des applications indiquées avec `yunohost backup create --ignore-system --apps`  
Ajoutez une ligne pour chaque application que vous voulez sauvegarder.  
Par exemple, pour 2 wordpress différents:
```
ynh_app_backup=wordpress
ynh_app_backup=wordpress__2
```
Vous pouvez lister toutes vos applications installées avec `sudo yunohost app list --installed | grep "id: "`

* ### max_size=
*Taille en Mo*  
Indiquer la taille maximale de chaque sauvegarde pour l'option suivante file_to_backup.  
Cette option est une limite douce, c'est à dire que le script va essayer de limiter chaque sauvegarde à cette taille maximale si il peut.  
Mais il y a 2 limitations, pour un seul dossier, il ne peut pas faire plus d'une sauvegarde, même si les fichiers dans ce répertoire dépasse cette limite de taille.  
Et, si il y a des fichiers à côté de sous répertoires, il ne fera qu'une seule sauvegarde pour ces fichiers.  
Donc cette limite va s'appliquer pour diviser les sauvegardes en fonction des sous dossiers pour éviter d'avoir une seule grosse sauvegarde.

* ### file_to_backup=
Permet d'ajouter un dossier ou un fichier à sauvegarder.  
Vous pouvez ajouter autant de ligne que vous le souhaitez.

* ### exclude_backup=
*Paramètre optionnel*  
Exclue des dossier ou des fichiers par rapport à la précédente option file_to_backup.  
Vous pouvez ajouter autant de ligne que vous le souhaitez.  
*Vous pouvez utiliser des regex pour sélectionner les fichiers ou dossiers à exclure.*

* ### > recipient name=
Ajoute un nouveau destinataire pour vos sauvegardes.  
Cette option est utilisée pour déclarer un nouveau destinataire, et pour lui donner un nom.  
Utiliser cette option pour déclarer un nouvel espace où envoyer vos sauvegardes.  
> *Si possible, vous devriez avoir au moins un destinataire distant pour garder vos sauvegardes dans un lieu sûr.*

  Chaque destinataire a ses propres options.  
  Voici les différentes options:

  * #### type=
  L'option type vous permet de choisir votre script d'envoi (nommé "sender") parmi ceux du dossier 'senders'.  
  Vous pouvez choisir entre *local* et *rsync_ssh*.

  * #### destination directory=
  Le répertoire où seront placées vos sauvegardes chez le destinataire.

  * #### encrypt=
  *true or false*  
  *Paramètre optionnel*  
  Remplace le paramètre général encrypt, si le paramètre général est réglé à true. Sinon, le dossier de sauvegarde principal ne sera pas chiffré et vous ne pourrez pas envoyer de version chiffré de vos sauvegardes.

  * #### exclude backup=
  *Paramètre optionnel*  
  Exclue un fichier de sauvegarde ou un dossier complet du dossier principal de sauvegarde pour ce destinataire.  
  Vous pouvez ajouter autant de ligne que vous le souhaitez.

  * #### include backup=
  *Paramètre optionnel*  
  Choisissez le seul fichier ou dossier qui sera envoyé à ce destinataire.  
  Vous pouvez ajouter autant de ligne que vous le souhaitez.

---

## Senders

Les scripts "senders" sont stockés dans le répertoire senders.  
Chaque "sender" peut avoir ses propres options.

* ### `local`
The "sender" local est simplement une sauvegarde locale utilisant rsync pour ne pas dupliquer les sauvegardes.  
Vous pouvez utiliser ce "sender" pour faire une sauvegarde sur un disque dur externe ou n'importe quel système de fichier monté.

  * #### Options spécifiques:
  Pas d'options spécifiques pour ce "sender".

* ### `rsync_ssh`
Envoi les sauvegardes sur un système de fichier distant via ssh avec rsync.
> Peut être utilisé avec les [Dossier ssh en chroot](https://github.com/YunoHost-Apps/ssh_chroot_dir_ynh)

  * #### Options spécifiques:
    * **ssh_host=**  
    Domaine ou IP du dossier ssh distant.
    * **ssh_user=**  
    Utilisateur de la connexion ssh.
    * **ssh_port=**  
    *Paramètre optionnel*  
    Port ssh pour la connexion, 22 par défaut.
    * **ssh_key=**  
    *Paramètre optionnel*  
    Clé privée à utiliser pour se connecter en ssh.
    * **ssh_pwd=**  
    *Paramètre optionnel*  
    Mot de passe de la connexion ssh.
    * **ssh_options=**  
    *Paramètre optionnel*  
    Toute autre option ssh.
