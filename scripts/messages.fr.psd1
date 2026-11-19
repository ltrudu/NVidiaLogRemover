# Textes affichés par NettoyageNvidia.ps1 (français).
# Les {0}, {1}... sont remplacés par des valeurs (taille, version...).
@{
    CultureName           = 'fr-FR'   # format des nombres (11,5 Go)
    Title                 = 'Réparation NVIDIA'
    Header                = 'Réparation du pilote NVIDIA'

    # --- État de l'ordinateur ---
    LogPresent            = 'Fichier journal NVIDIA : présent - taille actuelle {0}'
    LogPresentBig         = 'Fichier journal NVIDIA : TRÈS GROS - taille actuelle {0}'
    LogAbsent             = 'Fichier journal NVIDIA : absent (taille 0)'
    NoNvidiaGpu           = 'Carte graphique NVIDIA : introuvable sur cet ordinateur'
    DriverNone            = 'Pilote NVIDIA : aucun pilote installé pour le moment'
    DriverBad             = 'Pilote NVIDIA : {0} - c''est le MAUVAIS pilote'
    DriverGood            = 'Pilote NVIDIA : {0} - c''est le bon pilote'
    DriverOther           = 'Pilote NVIDIA : {0} - pas concerné par le problème'
    InstallerReady        = 'Bon pilote {0} : déjà téléchargé'
    InstallerIncomplete   = 'Bon pilote {0} : téléchargement incomplet'
    InstallerAbsent       = 'Bon pilote {0} : pas encore téléchargé'
    SizeGB                = '{0:N1} Go'
    SizeMB                = '{0:N0} Mo'
    SizeKB                = '{0:N0} Ko'

    # --- Pendant la vérification ({0} = petits points animés) ---
    CheckingLog           = 'Fichier journal NVIDIA : je vérifie{0}'
    CheckingDriver        = 'Pilote NVIDIA : je vérifie{0}'
    CheckingInstaller     = 'Bon pilote {1} : je vérifie{0}'
    CheckingStartup       = 'Nettoyage auto du fichier journal : je vérifie{0}'
    CheckingNext          = 'Je regarde l''état de l''ordinateur{0}   Patiente un petit peu, ça peut prendre quelques secondes !'

    # --- Prochaine étape conseillée ---
    Next_Log              = 'À faire maintenant : clique sur le bouton jaune pour vider le gros fichier journal.'
    Next_Uninstall        = 'À faire maintenant : clique sur le bouton jaune pour enlever le mauvais pilote.'
    Next_Reboot           = 'À faire maintenant : redémarre l''ordinateur (bouton jaune), puis relance ce programme.'
    Next_Download         = 'À faire maintenant : clique sur le bouton jaune pour télécharger le bon pilote (environ 1 Go).'
    Next_Install          = 'À faire maintenant : clique sur le bouton jaune pour installer le bon pilote.'
    Next_Cleanup          = 'À faire maintenant : clique sur le bouton jaune pour supprimer le fichier téléchargé.'
    Next_Done             = 'Tout est réparé ! Tu peux fermer ce programme.'
    Next_NoNvidia         = 'Pas de carte NVIDIA : il n''y a rien d''autre à faire.'
    Next_Busy             = 'Patiente... je travaille. Ne ferme pas cette fenêtre.'

    # --- Boutons ---
    StepsLabel            = 'Clique sur le bouton JAUNE : c''est la prochaine étape.'
    BtnLog                = '1. Vider le fichier journal'
    BtnUninstall          = '2. Enlever le mauvais pilote'
    BtnDownload           = '3. Télécharger le bon pilote'
    BtnInstall            = '4. Installer le bon pilote'
    BtnCleanup            = '5. Supprimer le fichier téléchargé'
    BtnReboot             = 'Redémarrer l''ordinateur'
    BtnRefresh            = 'Vérifier à nouveau'
    BtnClose              = 'Fermer'

    # --- Messages pendant le travail ---
    Welcome               = 'Bonjour ! Je regarde l''état de l''ordinateur...'
    NotAdmin              = 'Ce programme doit être lancé avec le fichier EXECUTE_MOI_Français.bat (il demande les droits administrateur).'
    ServiceStopping       = 'J''arrête le service NVIDIA...'
    ServiceStarting       = 'Je redémarre le service NVIDIA...'
    ServiceNotFound       = 'Service NVIDIA introuvable : je supprime seulement le fichier.'
    ServiceTimeout        = 'Le service NVIDIA ne répond pas (état attendu : {0}).'
    LogRemoved            = 'Fichier journal supprimé : {0} libérés.'
    LogAlreadyAbsent      = 'Le fichier journal n''existe pas : rien à vider.'
    LogLocked             = 'Le fichier est bloqué, je ferme les programmes NVIDIA et je réessaie...'
    UninstallStarting     = 'Je lance la désinstallation du mauvais pilote...'
    UninstallInstructions = @'
Une fenêtre NVIDIA va s'ouvrir.

Clique sur « Désinstaller » et attends la fin.
Si elle te demande de redémarrer, choisis « plus tard », puis reviens ici.
'@
    UninstallManual       = 'Je n''ai pas trouvé le désinstalleur NVIDIA. Dans la liste qui s''ouvre, choisis « Pilote graphique NVIDIA » puis « Désinstaller ».'
    UninstallCancelled    = 'Le mauvais pilote est toujours là (désinstallation annulée ?).'
    UninstallDone         = 'Mauvais pilote désinstallé.'
    UninstallNeedsReboot  = 'Mauvais pilote désinstallé. Il faut redémarrer l''ordinateur, puis relancer ce programme.'
    DownloadStarting      = 'Je télécharge le bon pilote {0}... environ 1 Go, ça peut prendre plusieurs minutes.'
    DownloadProgress      = 'Téléchargement : {0} sur {1} ({2} %)'
    DownloadProgressShort = 'Téléchargement : {0}'
    DownloadAlready       = 'Le bon pilote est déjà téléchargé.'
    DownloadRetry         = 'Première méthode de téléchargement en échec ({0}), j''essaie une autre méthode...'
    DownloadNoInternet    = 'Pas de connexion Internet ? Le téléchargement est bloqué.'
    DownloadFailed        = 'Le téléchargement a échoué (code {0}).'
    DownloadInvalid       = 'Le fichier téléchargé est abîmé ou n''est pas signé par NVIDIA. Recommence le téléchargement.'
    DownloadNoTool        = 'Aucun outil de téléchargement disponible sur cet ordinateur.'
    DownloadDone          = 'Téléchargement terminé, fichier vérifié (signé par NVIDIA).'
    InstallNeedDownload   = 'Il faut d''abord télécharger le bon pilote (étape 3).'
    InstallInstructions   = @'
Le programme d'installation NVIDIA va s'ouvrir.

1. Clique sur « OK » pour le dossier.
2. Accepte, puis clique sur « Suivant » à chaque fois.
3. Attends la fin, puis clique sur « Fermer ».

L'écran peut devenir noir quelques secondes : c'est normal !
'@
    InstallStarting       = 'Je lance l''installation du bon pilote...'
    InstallDone           = 'Bon pilote {0} installé !'
    InstallNotConfirmed   = 'Installation terminée, mais je ne vois pas encore le pilote {0}. Redémarre l''ordinateur puis relance ce programme pour vérifier.'
    CleanupRemoved        = 'Supprimé : {0}'
    CleanupNothing        = 'Rien à supprimer.'
    RebootConfirm         = @'
L'ordinateur va redémarrer.

As-tu bien enregistré tes jeux et fermé tes programmes ?
Après le redémarrage, relance « EXECUTE_MOI_Français.bat ».
'@
    RebootStarting        = 'Redémarrage de l''ordinateur...'
    ErrorMessage          = 'Oups, un problème : {0}'
    ErrorHelp             = 'Demande de l''aide à un adulte et montre-lui cette fenêtre.'
    CloseWhileBusy        = 'Je suis en train de travailler. Fermer quand même ?'

    # --- Nettoyage automatique (tâche planifiée, 2 modes) ---
    StartupHeader          = 'Nettoyage auto du fichier journal (s''il dépasse {0} Mo) :'
    StartupMode_Off        = 'Désactivé'
    StartupMode_Session    = 'À l''ouverture et à la fermeture de Windows (conseillé)'
    StartupMode_Every3h    = 'Toutes les {0} heures (attention : peut faire planter un jeu en cours)'
    StartupEnabled_Session = 'Nettoyage auto activé : à l''ouverture et à la fermeture de Windows, le fichier journal sera supprimé s''il dépasse {0} Mo.'
    StartupEnabled_Every3h = 'Nettoyage auto activé : au démarrage puis toutes les {1} heures, le fichier journal sera supprimé s''il dépasse {0} Mo.'
    StartupDisabled        = 'Nettoyage auto désactivé.'
    StartupTaskDescription_Session = 'Supprime le fichier journal NVIDIA (nvlog.nvlgstg) s''il dépasse la taille limite : au démarrage, à l''ouverture de session et à l''arrêt ou au redémarrage de Windows. Créé par NVidiaLogRemover.'
    StartupTaskDescription_Every3h = 'Supprime le fichier journal NVIDIA (nvlog.nvlgstg) s''il dépasse la taille limite : au démarrage puis toutes les {0} heures. Créé par NVidiaLogRemover.'
    StartupEvery3hWarning  = @'
Attention : toutes les {0} heures, le nettoyage peut arriver PENDANT une partie de jeu.

Pour vider le journal, le service NVIDIA est arrêté puis relancé.
Si un jeu tourne à ce moment-là, il peut se figer, clignoter ou même planter.

Le choix « À l'ouverture et à la fermeture de Windows » est plus sûr.

Choisir quand même « toutes les {0} heures » ?
'@
    StartupCheckAbsent     = 'Vérification auto : fichier journal absent, rien à faire.'
    StartupCheckOk         = 'Vérification auto : fichier journal de {0} (limite {1} Mo), rien à faire.'
    StartupCleaned         = 'Vérification auto : fichier journal de {0} supprimé (limite {1} Mo).'
    StartupError           = 'Vérification auto : erreur pendant le nettoyage : {0}'
}
