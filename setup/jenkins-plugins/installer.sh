#!/bin/bash

set -eo pipefail

JENKINS_URL='http://localhost:8080'
JENKINS_USER='admin'
JENKINS_PASSWORD='admin'
COOKIES_FILE='/tmp/cookies'

# Function to exit with an error message
exit_with_error() {
    echo "Error: $1"
    exit 1
}

# Get Jenkins crumb
JENKINS_CRUMB=$(curl -s --cookie-jar ${COOKIES_FILE} -u ${JENKINS_USER}:${JENKINS_PASSWORD} "${JENKINS_URL}/crumbIssuer/api/json" | jq -r .crumb)
if [[ -z "$JENKINS_CRUMB" ]]; then
    exit_with_error "Failed to retrieve Jenkins crumb. Check Jenkins URL or credentials."
fi

# Generate Jenkins API token
JENKINS_TOKEN=$(curl -s -X POST -H "Jenkins-Crumb:${JENKINS_CRUMB}" --cookie ${COOKIES_FILE} \
    "${JENKINS_URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=demo-token66" \
    -u ${JENKINS_USER}:${JENKINS_PASSWORD} | jq -r .data.tokenValue)

if [[ -z "$JENKINS_TOKEN" ]]; then
    exit_with_error "Failed to retrieve Jenkins API token. Check credentials or crumb."
fi

# Print values for debugging
echo "JENKINS_URL: $JENKINS_URL"
echo "JENKINS_CRUMB: $JENKINS_CRUMB"
echo "JENKINS_TOKEN: $JENKINS_TOKEN"

# Install plugins listed in plugins.txt
if [[ ! -f "plugins.txt" ]]; then
    exit_with_error "plugins.txt not found."
fi

while read -r plugin; do
   echo "........Installing ${plugin} .."
   curl -s -X POST --data "<jenkins><install plugin='${plugin}' /></jenkins>" \
       -H 'Content-Type: text/xml' "${JENKINS_URL}/pluginManager/installNecessaryPlugins" \
       --user "${JENKINS_USER}:${JENKINS_TOKEN}" \
       -H "Jenkins-Crumb:${JENKINS_CRUMB}"
done < plugins.txt

# Script to list installed Jenkins plugins
cat <<EOL
#### To check all installed plugins in Jenkins, you can run this Groovy script in the Script Console:
# http://localhost:8080/script
Jenkins.instance.pluginManager.plugins.each{
    plugin ->
      println ("${plugin.getDisplayName()} (${plugin.getShortName()}): ${plugin.getVersion()}")
}
#### Check for updates/errors: http://${JENKINS_URL}/updateCenter
EOL
