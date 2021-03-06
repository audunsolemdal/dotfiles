#!/bin/bash
PREVIOUS_PWD="$1"
if [ "$(jq -r '.configurations.debug' "${PREVIOUS_PWD}"/bootstrap/unix-settings.json)" == true ]; then
	set +e
else
	set -e
fi
if [ "$(jq -r '.configurations.purge' "${PREVIOUS_PWD}"/bootstrap/unix-settings.json)" == y ]; then
	sudo apt -y purge docker*
fi
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -; then
	echo "Docker Download failed! Skipping."
	kill $$
fi
RELEASE_VERSION="$(lsb_release -cs)"
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${RELEASE_VERSION} stable"
sudo apt-key fingerprint 0EBFCD88
sudo apt -qq update
sudo apt -y install docker-ce
dpkg --get-selections | grep docker
