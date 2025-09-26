#!/usr/bin/env bash
set -euo pipefail

WORKDIR="/workspaces/skills-getting-started-with-github-copilot"
LOGFILE="$WORKDIR/mongodb.log"
DB="test"
HOST="127.0.0.1"
PORT="27017"

echo "=== Vérification processus mongod ==="
if pgrep -a mongod >/dev/null 2>&1; then
  pgrep -a mongod
else
  echo "mongod ne tourne pas (aucun processus trouvé)."
fi

echo
echo "=== Vérification écoute du port $PORT ==="
ss -ltnp | grep -E "LISTEN.+:${PORT}" || echo "Aucun listener sur $PORT"

echo
echo "=== Derniers logs mongod (si présents) ==="
if [ -f "$LOGFILE" ]; then
  tail -n 80 "$LOGFILE"
else
  echo "Log $LOGFILE introuvable."
fi

echo
echo "=== Tentative de connexion MongoDB (base: $DB) ==="
if command -v mongosh >/dev/null 2>&1; then
  mongosh "mongodb://$HOST:$PORT/$DB" --quiet --eval "db.getCollectionNames()" || echo "Échec de connexion via mongosh"
elif command -v mongo >/dev/null 2>&1; then
  mongo "mongodb://$HOST:$PORT/$DB" --quiet --eval "db.getCollectionNames()" || echo "Échec de connexion via mongo"
else
  echo "Aucun client mongo trouvé (mongosh/mongo). Installez 'mongosh' ou 'mongodb-clients'."
fi

echo
echo "=== Si 'Connection refused' : ==="
echo "- Vérifiez que mongod a bien démarré et qu'il écoute 127.0.0.1:27017"
echo "- Vérifiez le log pour erreurs de permission ou de dbpath (tail -n 200 $LOGFILE)"
echo "- Si SELinux/AppArmor présent, vérifiez les contraintes"
echo "- Pour redémarrer manuellement (non-systemd) :"
echo "  mongod --dbpath \"$WORKDIR/data/db\" --bind_ip 127.0.0.1 --port 27017 --logpath \"$LOGFILE\" --fork"
