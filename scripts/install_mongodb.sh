#!/usr/bin/env bash
set -euo pipefail

# Emplacement du workspace
WORKDIR="/workspaces/skills-getting-started-with-github-copilot"
DBDIR="$WORKDIR/data/db"
LOGFILE="$WORKDIR/mongodb.log"

echo "1) Mise à jour des paquets..."
sudo apt-get update -y

echo "2) Installation de MongoDB depuis les sources officielles (mongodb-org)..."

# Detecter la distribution (ID et version codename)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID="$ID"
  DISTRO_CODENAME="$(lsb_release -cs 2>/dev/null || echo "${VERSION_CODENAME:-}")"
else
  echo "Impossible de déterminer la distribution. Abandon."
  exit 1
fi

echo "Distribution détectée: $DISTRO_ID $DISTRO_CODENAME"

# Installer paquets nécessaires pour gérer les clés et dépôts
echo "Installation des paquets requis: curl, gnupg, lsb-release, ca-certificates"
sudo apt-get install -y curl gnupg lsb-release ca-certificates

# Seules Debian/Ubuntu officiellement supportées par ce script
if [ "$DISTRO_ID" != "ubuntu" ] && [ "$DISTRO_ID" != "debian" ]; then
  echo "Ce script prend en charge Ubuntu/Debian uniquement. Installez mongod/mongosh manuellement depuis les sources officielles pour votre distribution."
  exit 1
fi

# Ajouter le dépôt officiel MongoDB (exemple pour MongoDB 6.0) ; ajustez la version si nécessaire
MONGO_VERSION="6.0"
echo "Ajout du dépôt MongoDB $MONGO_VERSION..."

# Importer la clé GPG
curl -fsSL https://pgp.mongodb.com/server-${MONGO_VERSION}.asc | sudo gpg --dearmour -o /usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg

# Écrire le fichier sources.list.d
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg] https://repo.mongodb.org/apt/${DISTRO_ID} ${DISTRO_CODENAME}/mongodb-org/${MONGO_VERSION} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list >/dev/null

sudo apt-get update -y

echo "Installation du paquet 'mongodb-org' (inclut mongod et mongosh)..."
if sudo apt-get install -y mongodb-org; then
  echo "mongodb-org installé avec succès."
else
  echo "Échec d'installation de 'mongodb-org'. Tentative d'installation de 'mongosh' seule..."
  if sudo apt-get install -y mongodb-mongosh || sudo apt-get install -y mongosh; then
    echo "mongosh installé. Vous pouvez démarrer votre propre instance mongod manuellement ou via systemd si disponible."
  else
    echo "Échec d'installation des paquets MongoDB depuis le dépôt officiel. Vérifiez la connectivité réseau et la compatibilité de la distribution."
    exit 1
  fi
fi

echo "3) Création du dossier de données si nécessaire: $DBDIR"
sudo mkdir -p "$DBDIR"
sudo chown -R "$(id -u):$(id -g)" "$DBDIR"
sudo chmod 700 "$DBDIR"

# Si systemd/service disponible, tenter de l'utiliser
if command -v systemctl >/dev/null 2>&1 && sudo systemctl list-units --type=service | grep -q -E 'mongodb|mongod'; then
  echo "4) Tentative de démarrage via systemd..."
  sudo systemctl enable --now mongodb || sudo systemctl enable --now mongod || true
  sleep 1
fi

# Si aucun service n'écoute, démarrer mongod en fork
if ! ss -ltnp 2>/dev/null | grep -q 27017; then
  if command -v mongod >/dev/null 2>&1; then
    echo "5) Démarrage de mongod en arrière-plan (fork)..."
    # Stop any existing mongod using same dbpath
    pkill -f "mongod.*--dbpath" || true
    mongod --dbpath "$DBDIR" --bind_ip 127.0.0.1 --port 27017 --logpath "$LOGFILE" --fork
    # Attendre que le port soit ouvert (max 10s)
    for i in {1..10}; do
      if ss -ltnp 2>/dev/null | grep -q 27017; then
        echo "mongod écoute sur le port 27017."
        break
      fi
      sleep 1
    done
    if ! ss -ltnp 2>/dev/null | grep -q 27017; then
      echo "Attention: mongod ne semble pas écouter sur 27017. Vérifiez le log: $LOGFILE"
      tail -n 50 "$LOGFILE" || true
      exit 1
    fi
  else
    echo "mongod introuvable après installation. Vérifiez le package installé."
    exit 1
  fi
else
  echo "Un processus écoute déjà sur 27017."
fi

echo "Installation/démarrage terminé. Logs : $LOGFILE"