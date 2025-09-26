#!/usr/bin/env bash
set -euo pipefail

DB="${1:-test}"  # base par défaut 'test'
HOST="127.0.0.1"
PORT="27017"

echo "Liste des collections pour la base: $DB sur $HOST:$PORT"

# Préférence pour mongosh, fallback sur mongo
if command -v mongosh >/dev/null 2>&1; then
  mongosh "mongodb://$HOST:$PORT/$DB" --quiet --eval "db.getCollectionNames()" || {
    echo "Erreur avec mongosh. Vérifiez que mongod est démarré et accessible."
    exit 1
  }
elif command -v mongo >/dev/null 2>&1; then
  mongo "mongodb://$HOST:$PORT/$DB" --quiet --eval "db.getCollectionNames()" || {
    echo "Erreur avec mongo. Vérifiez que mongod est démarré et accessible."
    exit 1
  }
else
  echo "Aucun client MongoDB trouvé (mongosh ou mongo). Installez 'mongodb-clients' ou 'mongosh'."
  exit 1
fi
