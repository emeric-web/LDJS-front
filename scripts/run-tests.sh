#!/usr/bin/env bash
set -euo pipefail

# Vérification des dépendances
for dependency in node npm jq; do
    if ! command -v "$dependency" > /dev/null 2>&1; then
        echo "Erreur : $dependency n'est pas installé."
        exit 1
    fi
done

# Vérification des dépendances du projet
if [ ! -x "node_modules/.bin/jest" ]; then
    echo "Erreur : Jest n'est pas installé localement."
    echo "Exécutez npm ci avant de relancer ce script."
    exit 1
fi

echo "Toutes les dépendances sont disponibles."

RESULTS_DIR="test-results"
JEST_RESULTS_FILE="$RESULTS_DIR/jest-results.json"
JUNIT_FILE="$RESULTS_DIR/junit.xml"


# Créer le répertoire s'il n'existe pas
mkdir -p "$RESULTS_DIR"
    
# Supprimer les anciens résultats
rm -f "$JEST_RESULTS_FILE" "$JUNIT_FILE"
    
# Exécuter les tests tout en conservant leur code de sortie
test_exit_code=0

npm test -- --json --outputFile="$JEST_RESULTS_FILE" || test_exit_code=$?

# Vérifier le JSON
if [ ! -s "$JEST_RESULTS_FILE" ] || ! jq empty "$JEST_RESULTS_FILE" 2>/dev/null; then
    echo "Erreur : fichier de résultats Jest absent, vide ou invalide."
    exit 1
fi

# Fonction pour échapper les caractères XML
escape_xml() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&apos;}"
    printf '%s' "$value"
}

# Générer le rapport JUnit XML
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'

    jq -r '
      "<testsuites tests=\"\(.numTotalTests)\" failures=\"\(.numFailedTests)\" skipped=\"\(.numPendingTests)\">"
    ' "$JEST_RESULTS_FILE"

    # Parcourir chaque suite
    while IFS= read -r suite; do
        suite_name=$(jq -r '.name' <<< "$suite")
        tests=$(jq '.assertionResults | length' <<< "$suite")
        failures=$(jq '[.assertionResults[] | select(.status == "failed")] | length' <<< "$suite")
        skipped=$(jq '[.assertionResults[] | select(.status == "pending" or .status == "disabled" or .status == "todo")] | length' <<< "$suite")

        printf '  <testsuite name="%s" tests="%s" failures="%s" skipped="%s">\n' \
            "$(escape_xml "$suite_name")" "$tests" "$failures" "$skipped"

        # Parcourir chaque test
        while IFS= read -r test; do
            name=$(jq -r '.fullName' <<< "$test")
            status=$(jq -r '.status' <<< "$test")
            duration=$(jq -r '(.duration // 0) / 1000' <<< "$test")

            printf '    <testcase name="%s" time="%s">' \
                "$(escape_xml "$name")" "$duration"

            case "$status" in
                failed)
                    message=$(jq -r '.failureMessages | join("\n")' <<< "$test")
                    printf '<failure>%s</failure>' "$(escape_xml "$message")"
                    ;;
                pending|disabled|todo)
                    printf '<skipped/>'
                    ;;
            esac

            printf '</testcase>\n'
        done < <(jq -c '.assertionResults[]' <<< "$suite")

        echo '  </testsuite>'
    done < <(jq -c '.testResults[]' "$JEST_RESULTS_FILE")

    echo '</testsuites>'
} > "$JUNIT_FILE"

# Supprimer le fichier JSON intermédiaire
rm -f "$JEST_RESULTS_FILE"

echo "Rapport JUnit XML généré : $JUNIT_FILE"

exit "$test_exit_code"