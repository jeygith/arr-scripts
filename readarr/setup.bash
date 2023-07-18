#!/usr/bin/with-contenv bash
echo "************ install and update packages ************"
apk add -U --update --no-cache \
  jq \
  py3-pip
echo "************ install python packages ************"
pip install --upgrade --no-cache-dir -U yq

mkdir -p /custom-services.d
echo "Download AutoConfig service..."
curl https://raw.githubusercontent.com/jeygith/arr-scripts/main/readarr/AutoConfig.bash -o /custom-services.d/AutoConfig
echo "Done"

echo "Download QueueCleaner service..."
curl https://raw.githubusercontent.com/jeygith/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner
echo "Done"

mkdir -p /config/extended
echo "Download PlexNotify script..."
curl https://raw.githubusercontent.com/jeygith/arr-scripts/main/readarr/PlexNotify.bash -o /config/extended/PlexNotify.bash 
echo "Done"

echo "Download AutoConfig config..."
curl https://raw.githubusercontent.com/jeygith/arr-scripts/main/readarr/AutoConfig.json -o /config/extended/AutoConfig.json
echo "Done"

chmod 777 -R /config/extended

if [ ! -f /config/extended.conf ]; then
	echo "Download Extended config..."
	curl https://raw.githubusercontent.com/jeygith/arr-scripts/main/readarr/extended.conf -o /config/extended.conf
	chmod 777 /config/extended.conf
	echo "Done"
fi

exit
