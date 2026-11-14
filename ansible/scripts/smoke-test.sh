#!/bin/bash
# Test de fumée après déploiement : l'environnement répond-il, avec la bonne version ?
# Usage : ./deploy/smoke-test.sh <projet_compose> <version_attendue>
set -euo pipefail
PROJECT=${1:?usage: $0 <projet_compose> <version>}
EXPECTED=${2:?usage: $0 <projet_compose> <version>}
NETWORK="${PROJECT}_default"

# Le conteneur curl est placé sur le réseau du projet : il joint le service "web" par son nom.
curl_net() {
    docker run --rm --network "$NETWORK" curlimages/curl:8.11.1 -sf --max-time 5 "$@"
}

curl_net --retry 10 --retry-connrefused --retry-delay 2 http://web:5000/ready >/dev/null
VERSION=$(curl_net http://web:5000/api/info | sed -E 's/.*"version": *"([^"]+)".*/\1/')

if [ "$VERSION" != "$EXPECTED" ]; then
    echo "❌ $PROJECT : version $VERSION au lieu de $EXPECTED"
    exit 1
fi
echo "✅ $PROJECT répond en version $VERSION"
