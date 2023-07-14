#!/usr/bin/with-contenv bash
scriptVersion="1.8"
scriptName="Video"

#### Import Settings
source /config/extended.conf
videoContainer=mkv

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

if [ "$enableVideo" != "true" ]; then
	log "Script is not enabled, enable by setting enableVideo to \"true\" by modifying the \"/config/extended.conf\" config file..."
	log "Sleeping (infinity)"
	sleep infinity
fi

if [ -z "$downloadPath" ]; then
	downloadPath="/config/extended/downloads"
fi

if [ -z "$videoPath" ]; then
	log "ERROR: videoPath is not configured via the \"/config/extended.conf\" config file..."
 	log "Updated your \"/config/extended.conf\" file with the latest options, see: https://github.com/RandomNinjaAtk/arr-scripts/blob/main/lidarr/extended.conf"
	log "Sleeping (infinity)"
	sleep infinity
fi


getArrAppInfo () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
    if [ "$arrUrlBase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
    fi
    arrName="$(cat /config/config.xml | xq | jq -r .Config.InstanceName)"
    arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
    arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ "$arrName" == "Sonarr" ] || [ "$arrName" == "Radarr" ]; then
      arrApiVersion="v3"
    elif [ "$arrName" == "Lidarr" ] || [ "$arrName" == "Readarr" ]; then
      arrApiVersion="v1"
    fi
    arrApiTest=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)
    if [ "$arrApiTest" == "$arrName" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}

if [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	sourcePreference=tidal
fi



# auto-clean up log file to reduce space usage
if [ -f "/config/logs/Video.txt" ]; then
	find /config/logs -type f -name "Video.txt" -size +5000k -delete
	sleep 0.01
fi
exec &> >(tee -a "/config/logs/Video.txt")
touch "/config/logs/Video.txt"
chmod 666 "/config/logs/Video.txt"

log "-----------------------------------------------------------------------------"
log "|~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
log "|~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
log " Presents: $scriptName ($scriptVersion)"
log " May the beats be with you!"
log "-----------------------------------------------------------------------------"
log "Donate: https://github.com/sponsors/RandomNinjaAtk"
log "Project: https://github.com/RandomNinjaAtk/arr-scripts"
log "Support: https://github.com/RandomNinjaAtk/arr-scripts/discussions"
log "-----------------------------------------------------------------------------"
sleep 5
log ""
log "Lift off in..."; sleep 0.5
log "5"; sleep 1
log "4"; sleep 1
log "3"; sleep 1
log "2"; sleep 1
log "1"; sleep 1


Configuration () {
	processdownloadid="$(ps -A -o pid,cmd|grep "Video.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processdownloadid"
	sleep 2
	
	verifyApiAccess

	downloadPath="$downloadPath/videos"
	log "CONFIG :: Download Location :: $downloadPath"
	log "CONFIG :: Music Video Location :: $videoPath"
	log "CONFIG :: Subtitle Language set to: $youtubeSubtitleLanguage"
	log "CONFIG :: Video container set to format: $videoContainer"
	if [ "$videoContainer" == "mkv" ]; then
		log "CONFIG :: yt-dlp format: $videoFormat"
	fi
	if [ "$videoContainer" == "mp4" ]; then
		log "CONFIG :: yt-dlp format: --format-sort ext:mp4:m4a --merge-output-format mp4"
	fi
	if [ -n "$videoDownloadTag" ]; then
		log "CONFIG :: Video download tag set to: $videoDownloadTag"
	fi
	if [ -f "/config/cookies.txt" ]; then
		cookiesFile="/config/cookies.txt"
		log "CONFIG :: Cookies File Found! (/config/cookies.txt)"
	    else
		log "CONFIG :: ERROR :: Cookies File Not Found!"
		log "CONFIG :: ERROR :: Add yt-dlp compatible cookies.txt to the following location: /config/cookies.txt"
		cookiesFile=""
	    fi
	log "CONFIG :: Complete"
}

ImvdbCache () {
    
    if [ -z "$artistImvdbSlug" ]; then
        return
    fi
    if [ ! -d "/config/extended/cache/imvdb" ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Creating Cache Folder..."
        mkdir -p "/config/extended/cache/imvdb"
        chmod 777 "/config/extended/cache/imvdb"
    fi
    
    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Caching Records..."

    if [ ! -f /config/extended/cache/imvdb/$artistImvdbSlug ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Recording Artist Slug into cache"
        echo -n "$lidarrArtistName" > /config/extended/cache/imvdb/$artistImvdbSlug
    fi
    artistImvdbVideoUrls=$(curl -s "https://imvdb.com/n/$artistImvdbSlug" | grep "$artistImvdbSlug" | grep -Eoi '<a [^>]+>' |  grep -Eo 'href="[^\"]+"' | grep -Eo '(http|https)://[^"]+' |  grep -i ".com/video/$artistImvdbSlug/" | sed "s%/[0-9]$%%g" | sort -u)
    artistImvdbVideoUrlsCount=$(echo "$artistImvdbVideoUrls" | wc -l)
    cachedArtistImvdbVideoUrlsCount=$(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--* 2>/dev/null | wc -l)

    if [ "$artistImvdbVideoUrlsCount" ==  "$cachedArtistImvdbVideoUrlsCount" ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Chache is already up-to-date, skipping..."
        return
    else 
    	if [ -f "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId" ]; then
		    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Removing Artist completed log file to allow artist re-processing..."
		    rm "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId"
	    fi
    fi
    

    sleep 0.5
    imvdbProcessCount=0
    for imvdbVideoUrl in $(echo "$artistImvdbVideoUrls"); do
        imvdbProcessCount=$(( $imvdbProcessCount + 1 ))
        imvdbVideoUrlSlug=$(basename "$imvdbVideoUrl")
        imvdbVideoData="/config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--$imvdbVideoUrlSlug.json"
        #echo "$imvdbVideoUrl :: $imvdbVideoUrlSlug :: $imvdbVideoId"
        
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Caching video data..."
        if [ -f "$imvdbVideoData" ]; then
            if [ ! -s "$imvdbVideoData"  ]; then # if empty, delete file
                rm "$imvdbVideoData"
            fi
        fi

        if [ -f "$imvdbVideoData" ]; then 
            if jq -e . >/dev/null 2>&1 <<<"$(cat "$imvdbVideoData")"; then # verify file is valid json
                log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Video Data already downloaded"
                continue
            fi
        fi

        if [ ! -f "$imvdbVideoData" ]; then
            count=0
            until false; do
                count=$(( $count + 1 ))
                #echo "$count"
                if [ ! -f "$imvdbVideoData" ]; then
                    imvdbVideoId=$(curl -s "$imvdbVideoUrl" | grep "<p>ID:" | grep -o "[[:digit:]]*")
                    imvdbVideoJsonUrl="https://imvdb.com/api/v1/video/$imvdbVideoId?include=sources,countries,featured,credits,bts,popularity"
                    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount ::  Downloading Video data"
                    curl -s "$imvdbVideoJsonUrl" -o "$imvdbVideoData"
                    sleep 0.5
                fi
                if [ -f "$imvdbVideoData" ]; then
                    if [ ! -s "$imvdbVideoData"  ]; then
                        rm "$imvdbVideoData"
                        if [ $count = 2 ]; then
                            log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Download Failed, skipping..."
                            break
                        fi
                    elif jq -e . >/dev/null 2>&1 <<<"$(cat "$imvdbVideoData")"; then
                        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Download Complete"
                        break
                    else
                        rm "$imvdbVideoData"
                    fi
                fi
            done
        fi
    done
}

DownloadVideo () {

    if [ -d "$downloadPath/incomplete" ]; then
        rm -rf "$downloadPath/incomplete"
    fi

    if [ ! -d "$downloadPath/incomplete" ]; then
        mkdir -p "$downloadPath/incomplete"
        chmod 777 "$downloadPath/incomplete"
    fi 

    if echo "$1" | grep -i "youtube" | read; then
        if [ $videoContainer = mkv ]; then
            if [ ! -z "$cookiesFile" ]; then
                yt-dlp -f "$videoFormat" --no-video-multistreams --cookies "$cookiesFile" -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --merge-output-format mkv --remux-video mkv --no-mtime --geo-bypass "$1"
            else
                yt-dlp -f "$videoFormat" --no-video-multistreams -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --merge-output-format mkv --remux-video mkv --no-mtime --geo-bypass "$1"
            fi
            if [ -f "$downloadPath/incomplete/${2}${3}.mkv" ]; then
                chmod 666 "$downloadPath/incomplete/${2}${3}.mkv"
                downloadFailed=false
            else
                downloadFailed=true
            fi
        else
            if [ ! -z "$cookiesFile" ]; then
                yt-dlp --format-sort ext:mp4:m4a --merge-output-format mp4 --no-video-multistreams --cookies "$cookiesFile" -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --no-mtime --geo-bypass "$1"
            else
                yt-dlp --format-sort ext:mp4:m4a --merge-output-format mp4 --no-video-multistreams -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --no-mtime --geo-bypass "$1"
            fi
            if [ -f "$downloadPath/incomplete/${2}${3}.mp4" ]; then
                chmod 666 "$downloadPath/incomplete/${2}${3}.mp4"
                downloadFailed=false
            else
                downloadFailed=true
            fi
        fi
    fi
    
    if echo "$1" | grep -i "tidal" | read; then
        TidalClientTest
        sleep 1
        TidaldlStatusCheck
        tidal-dl -o "$downloadPath/incomplete" -l "$1"
        find "$downloadPath/incomplete" -type f -exec mv "{}" "$downloadPath/incomplete"/ \;
        find "$downloadPath/incomplete" -mindepth 1 -type d -exec rm -rf "{}" \; &>/dev/null
        find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
            file="${video}"
            filenoext="${file%.*}"
            filename="$(basename "$video")"
            extension="${filename##*.}"
            filenamenoext="${filename%.*}"
            mv "$file" "$downloadPath/incomplete/${2}${3}.mp4"
        done
        if [ -f "$downloadPath/incomplete/${2}${3}.mp4" ]; then
            chmod 666 "$downloadPath/incomplete/${2}${3}.mp4"
            downloadFailed=false
        else
            downloadFailed=true
        fi
    fi

}

DownloadThumb () {

    curl -s "$1" -o "$downloadPath/incomplete/${2}${3}.jpg"
    chmod 666 "$downloadPath/incomplete/${2}${3}.jpg"

}

VideoProcessWithSMA () {
    find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
        count=$(($count+1))
        file="${video}"
        filenoext="${file%.*}"
        filename="$(basename "$video")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"

        if [[ $filenoext.$videoContainer == *.mkv ]]
        then

            if python3 /usr/local/sma/manual.py --config "/config/extended/sma.ini" -i "$file" -nt &>/dev/null; then
                sleep 0.01
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: Processed with SMA..."
                rm  /usr/local/sma/config/*log*
            else
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: ERROR: SMA Processing Error"
                rm "$video"
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: INFO: deleted: $filename"
            fi
        else
                if python3 /usr/local/sma/manual.py --config "/config/extended/sma-mp4.ini" -i "$file" -nt &>/dev/null; then
                sleep 0.01
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: Processed with SMA..."
                rm  /usr/local/sma/config/*log*
            else
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: ERROR: SMA Processing Error"
                rm "$video"
                log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: INFO: deleted: $filename"
            fi
        fi
    done

}

VideoTagProcess () {
    find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
        count=$(($count+1))
        file="${video}"
        filenoext="${file%.*}"
        filename="$(basename "$video")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        artistGenres=""
        OLDIFS="$IFS"
	IFS=$'\n'
	artistGenres=($(echo $lidarrArtistData | jq -r ".genres[]"))
	IFS="$OLDIFS"

        if [ ! -z "$artistGenres" ]; then
            for genre in ${!artistGenres[@]}; do
                artistGenre="${artistGenres[$genre]}"
                OUT=$OUT"$artistGenre / "
            done
            genre="${OUT%???}"
        else
            genre=""
        fi

        if [[ $filenoext.$videoContainer == *.mkv ]]; then
		mv "$filenoext.$videoContainer" "$filenoext-temp.$videoContainer"
		log "$processCount of $lidarrArtistIdsCount :: $4 :: $lidarrArtistName :: ${1}${2} $3 :: Tagging file"
		ffmpeg -y \
			-i "$filenoext-temp.$videoContainer" \
			-c copy \
			-metadata TITLE="${1}" \
			-metadata DATE_RELEASE="$3" \
			-metadata DATE="$3" \
			-metadata YEAR="$3" \
			-metadata GENRE="$genre" \
			-metadata ARTIST="$lidarrArtistName" \
			-metadata ALBUMARTIST="$lidarrArtistName" \
			-metadata ENCODED_BY="lidarr-extended" \
			-attach "$downloadPath/incomplete/${1}${2}.jpg" -metadata:s:t mimetype=image/jpeg \
			"$filenoext.$videoContainer" &>/dev/null
		rm "$filenoext-temp.$videoContainer"
		chmod 666 "$filenoext.$videoContainer"
        else
		mv "$filenoext.$videoContainer" "$filenoext-temp.$videoContainer"
		log "$processCount of $lidarrArtistIdsCount :: $4 :: $lidarrArtistName :: ${1}${2} $3 :: Tagging file"
		ffmpeg -y \
			-i "$filenoext-temp.$videoContainer" \
		 	-i "$downloadPath/incomplete/${1}${2}.jpg" \
			-map 1 \
			-map 0 \
			-c copy \
			-c:v:0 mjpeg \
			-disposition:0 attached_pic \
			-movflags faststart \
			-metadata TITLE="${1}" \
			-metadata ARTIST="$lidarrArtistName" \
			-metadata DATE="$3" \
			-metadata GENRE="$genre" \
			"$filenoext.$videoContainer" &>/dev/null
		rm "$filenoext-temp.$videoContainer"
		chmod 666 "$filenoext.$videoContainer"
        fi
    done
}

VideoNfoWriter () {
    log "$processCount of $lidarrArtistIdsCount :: $7 :: $lidarrArtistName :: ${3} :: Writing NFO"
    nfo="$downloadPath/incomplete/${1}${2}.nfo"
    if [ -f "$nfo" ]; then
        rm "$nfo"
    fi
    echo "<musicvideo>" >> "$nfo"
    echo "	<title>${3}${4}</title>" >> "$nfo"
    echo "	<userrating/>" >> "$nfo"
    echo "	<track/>" >> "$nfo"
    echo "	<studio/>" >> "$nfo"
    artistGenres=""
    OLDIFS="$IFS"
	IFS=$'\n'
	artistGenres=($(echo $lidarrArtistData | jq -r ".genres[]"))
	IFS="$OLDIFS"
    if [ ! -z "$artistGenres" ]; then
        for genre in ${!artistGenres[@]}; do
            artistGenre="${artistGenres[$genre]}"
            echo "	<genre>$artistGenre</genre>" >> "$nfo"
        done
    fi
    echo "	<premiered/>" >> "$nfo"
    echo "	<year>$6</year>" >> "$nfo"
    if [ "$5" = "musicbrainz" ]; then
        OLDIFS="$IFS"
        IFS=$'\n'
        for artistName in $(echo "$musicbrainzVideoArtistCreditsNames"); do 
            echo "	<artist>$artistName</artist>" >> "$nfo"
        done
        IFS="$OLDIFS"
    fi
    if [ "$5" = "imvdb" ]; then
        echo "	<artist>$lidarrArtistName</artist>" >> "$nfo"
        for featuredArtistSlug in $(echo "$imvdbVideoFeaturedArtistsSlug"); do
            if [ -f /config/extended/cache/imvdb/$featuredArtistSlug ]; then
                featuredArtistName="$(cat /config/extended/cache/imvdb/$featuredArtistSlug)"
                echo "	<artist>$featuredArtistName</artist>" >> "$nfo"
            fi
        done
    fi
    echo "	<albumArtistCredits>" >> "$nfo"
	echo "		<artist>$lidarrArtistName</artist>" >> "$nfo"
	echo "		<musicBrainzArtistID>$lidarrArtistMusicbrainzId</musicBrainzArtistID>" >> "$nfo"
	echo "	</albumArtistCredits>" >> "$nfo"
    echo "	<thumb>${1}${2}.jpg</thumb>" >> "$nfo"
    echo "	<source>$8</source>" >> "$nfo"
    echo "</musicvideo>" >> "$nfo"
    tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
    chmod 666 "$nfo"

}

LidarrTaskStatusCheck () {
	alerted=no
	until false
	do
		taskCount=$(curl -s "$arrUrl/api/v1/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			if [ "$alerted" = "no" ]; then
				alerted=yes
				log "STATUS :: LIDARR BUSY :: Pausing/waiting for all active Lidarr tasks to end..."
			fi
			sleep 2
		else
			break
		fi
	done
}

AddFeaturedVideoArtists () {
    if [ "$addFeaturedVideoArtists" != "true" ]; then
        log "-----------------------------------------------------------------------------"
        log "Add Featured Music Video Artists to Lidarr :: DISABLED"    
        log "-----------------------------------------------------------------------------"
        return
    fi
    log "-----------------------------------------------------------------------------"
    log "Add Featured Music Video Artists to Lidarr :: ENABLED"    
    log "-----------------------------------------------------------------------------"
    lidarrArtistsData="$(curl -s "$arrUrl/api/v1/artist?apikey=${arrApiKey}" | jq -r ".[]")"
    artistImvdbUrl=$(echo $lidarrArtistsData | jq -r '.links[] | select(.name=="imvdb") | .url')
    videoArtists=$(ls /config/extended/cache/imvdb/ | grep -Ev ".*--.*")
    videoArtistsCount=$(ls /config/extended/cache/imvdb/ | grep -Ev ".*--.*" | wc -l)
    if [ "$videoArtistsCount" == "0" ]; then
        log "$videoArtistsCount Artists found for processing, skipping..."
        return
    fi
    loopCount=0
    for slug in $(echo $videoArtists); do
        loopCount=$(( $loopCount + 1))
        artistName="$(cat /config/extended/cache/imvdb/$slug)"
        if echo "$artistImvdbUrl" | grep -i "imvdb.com/n/${slug}$" | read; then
            log "$loopCount of $videoArtistsCount :: $artistName :: Already added to Lidarr, skipping..."
            continue
        fi
        log "$loopCount of $videoArtistsCount :: $artistName :: Processing url :: https://imvdb.com/n/$slug"

		artistNameEncoded="$(jq -R -r @uri <<<"$artistName")"
		lidarrArtistSearchData="$(curl -s "$arrUrl/api/v1/search?term=${artistNameEncoded}&apikey=${arrApiKey}")"
		lidarrArtistMatchedData=$(echo $lidarrArtistSearchData | jq -r ".[] | select(.artist) | select(.artist.links[].url | contains (\"imvdb.com/n/${slug}\"))" 2>/dev/null)
							
		if [ ! -z "$lidarrArtistMatchedData" ]; then
	        data="$lidarrArtistMatchedData"		
			artistName="$(echo "$data" | jq -r ".artist.artistName")"
			foreignId="$(echo "$data" | jq -r ".foreignId")"
        else
            log "$loopCount of $videoArtistsCount :: $artistName :: ERROR : Musicbrainz ID Not Found, skipping..."
            continue
        fi
		data=$(curl -s "$arrUrl/api/v1/rootFolder" -H "X-Api-Key: $arrApiKey" | jq -r ".[]")
		path="$(echo "$data" | jq -r ".path")"
		qualityProfileId="$(echo "$data" | jq -r ".defaultQualityProfileId")"
		metadataProfileId="$(echo "$data" | jq -r ".defaultMetadataProfileId")"
		data="{
			\"artistName\": \"$artistName\",
			\"foreignArtistId\": \"$foreignId\",
			\"qualityProfileId\": $qualityProfileId,
			\"metadataProfileId\": $metadataProfileId,
			\"monitored\":true,
			\"monitor\":\"all\",
			\"rootFolderPath\": \"$path\",
			\"addOptions\":{\"searchForMissingAlbums\":false}
			}"

		if echo "$lidarrArtistIds" | grep "^${foreignId}$" | read; then
			log "$loopCount of $videoArtistsCount :: $artistName :: Already in Lidarr ($foreignId), skipping..."
			continue
		fi
		log "$loopCount of $videoArtistsCount :: $artistName :: Adding $artistName to Lidarr ($foreignId)..."
		LidarrTaskStatusCheck
		lidarrAddArtist=$(curl -s "$arrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw "$data")
    done

}

NotifyWebhook () {
	if [ "$webHook" ]
	then
		content="$1: $2"
		curl -X POST "{$webHook}" -H 'Content-Type: application/json' -d '{"event":"'"$1"'", "message":"'"$2"'", "content":"'"$content"'"}'
	fi
}

VideoProcess () {

  Configuration
  AddFeaturedVideoArtists
  
  log "-----------------------------------------------------------------------------"
  log "Finding Videos"    
  log "-----------------------------------------------------------------------------"
  if [ -z "$videoDownloadTag" ]; then
  	lidarrArtists=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist?apikey=$arrApiKey" | jq -r .[])
  	lidarrArtistIds=$(echo $lidarrArtists | jq -r .id)
  else
  	lidarrArtists=$(curl -s "$arrUrl/api/v1/tag/detail" -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" | jq -r -M ".[] | select(.label == \"$videoDownloadTag\") | .artistIds")
  	lidarrArtistIds=$(echo $lidarrArtists | jq -r .[])
  fi
  lidarrArtistIdsCount=$(echo "$lidarrArtistIds" | wc -l)
  processCount=0
  for lidarrArtistId in $(echo $lidarrArtistIds); do
  	processCount=$(( $processCount + 1))
      	lidarrArtistData=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist/$lidarrArtistId?apikey=$arrApiKey")
  	lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
  	lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
      
      if  [ "$lidarrArtistName" == "Various Artists" ]; then
          log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: Skipping, not processed by design..."
          continue
      fi
  
      lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
      lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
      lidarrArtistFolderNoDisambig="$(echo "$lidarrArtistFolder" | sed "s/ (.*)$//g" | sed "s/\.$//g")" # Plex Sanitization, remove disambiguation
      lidarrArtistNameSanitized="$(echo "$lidarrArtistFolderNoDisambig" | sed 's% (.*)$%%g')"
      log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: Checking for IMVDB Slug"
      artistImvdbUrl=$(echo $lidarrArtistData | jq -r '.links[] | select(.name=="imvdb") | .url')
      artistImvdbSlug=$(basename "$artistImvdbUrl")
  
      if [ ! -z "$artistImvdbSlug" ]; then
          log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: IMVDB Slug :: $artistImvdbSlug"
      else
      	log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: IMVDB Slug Not Found..."
  	continue
      fi
      
      ImvdbCache
      
      if [ -d /config/extended/logs/video/complete ]; then
          if [ -f "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId" ]; then
              log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: Music Videos previously downloaded, skipping..."
              continue            
          fi
      fi
  
      
  
      if [ -z "$artistImvdbSlug" ]; then
          log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: No IMVDB artist link found, skipping..."
          # Create log of missing IMVDB url...
          if [ ! -d "/config/extended/logs/video/imvdb-link-missing" ]; then
              mkdir -p "/config/extended/logs/video/imvdb-link-missing"
              chmod 777 "/config/extended/logs/video"
              chmod 777 "/config/extended/logs/video/imvdb-link-missing"
          fi
          if [ -d "/config/extended/logs/video/imvdb-link-missing" ]; then
              log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Logging missing IMVDB artist in folder: /config/extended/logs/video/imvdb-link-missing"
              touch "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}"
          fi       
      else
      	# Remove missing IMVDB log file, now that it is found...
      	if [ -f "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}" ]; then
  		rm "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}"
  	fi
  	
          imvdbArtistVideoCount=$(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--*.json 2>/dev/null | wc -l)
          if [ $imvdbArtistVideoCount = 0 ]; then
              log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: No videos found, skipping..."
              
          else
  
              log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Processing $imvdbArtistVideoCount Videos!"
              find /config/extended/cache/imvdb -type f -empty -delete # delete empty files
              
              imvdbProcessCount=0
              for imvdbVideoData in $(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--*.json); do
                  imvdbProcessCount=$(( $imvdbProcessCount + 1 ))
                  imvdbVideoTitle="$(cat "$imvdbVideoData" | jq -r .song_title)"
                  videoTitleClean="$(echo "$imvdbVideoTitle" | sed -e "s/[^[:alpha:][:digit:]$^&_+=()'%;{},.@#]/ /g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
                  imvdbVideoYear=""
  		imvdbVideoYear="$(cat "$imvdbVideoData" | jq -r .year)"
                  imvdbVideoImage="$(cat "$imvdbVideoData" | jq -r .image.o)"
                  imvdbVideoArtistsSlug="$(cat "$imvdbVideoData" | jq -r .artists[].slug)"
                  echo "$lidarrArtistName" > /config/extended/cache/imvdb/$imvdbVideoArtistsSlug
                  imvdbVideoFeaturedArtistsSlug="$(cat "$imvdbVideoData" | jq -r .featured_artists[].slug)"
                  imvdbVideoYoutubeId="$(cat "$imvdbVideoData" | jq -r ".sources[] | select(.is_primary==true) | select(.source==\"youtube\") | .source_data")"
                  #"/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
                  #echo "$imvdbVideoTitle :: $imvdbVideoYear :: $imvdbVideoYoutubeId :: $imvdbVideoArtistsSlug"
                  if [ -z "$imvdbVideoYoutubeId" ]; then
                      continue
                  fi
                  videoDownloadUrl="https://www.youtube.com/watch?v=$imvdbVideoYoutubeId"
                  plexVideoType="-video"
                  
                  if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                      if [ -f "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo" ]; then
                          if cat "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo" | grep "source" | read; then
                              sleep 0
                          else
                              sed -i '$d' "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo"
                              echo "	<source>youtube</source>" >> "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo"
                              echo "</musicvideo>" >> "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo"
                              tidy -w 2000 -i -m -xml "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.nfo" &>/dev/null
                          fi
                      fi
                      if [[ -n $(find "$videoPath/$lidarrArtistFolderNoDisambig" -maxdepth 1 -iname "${videoTitleClean}${plexVideoType}.mkv") ]] || [[ -n $(find "$videoPath/$lidarrArtistFolderNoDisambig" -maxdepth 1 -iname "${videoTitleClean}${plexVideoType}.mp4") ]]; then
                          log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: Previously Downloaded, skipping..."
                          continue
                      fi
                  fi
  
                  if [ ! -z "$imvdbVideoFeaturedArtistsSlug" ]; then
                      for featuredArtistSlug in $(echo "$imvdbVideoFeaturedArtistsSlug"); do
                          if [ -f /config/extended/cache/imvdb/$featuredArtistSlug ]; then
                              featuredArtistName="$(cat /config/extended/cache/imvdb/$featuredArtistSlug)"
                          fi
                          find /config/extended/cache/imvdb -type f -empty -delete # delete empty files
                          if [ -z "$featuredArtistName" ]; then
                              continue
                          fi
                      done
                  fi
  
                  
                  
                  if [ ! -z "$cookiesFile" ]; then
                      videoData="$(yt-dlp --cookies "$cookiesFile" -j "$videoDownloadUrl")"
                  else
                      videoData="$(yt-dlp -j "$videoDownloadUrl")"
                  fi
                  
                  videoThumbnail="$imvdbVideoImage"
  		if [ -z "$imvdbVideoYear" ]; then
                  	videoUploadDate="$(echo "$videoData" | jq -r .upload_date)"
                  	videoYear="${videoUploadDate:0:4}"
  		else
  			videoYear="$imvdbVideoYear"
  		fi
  		videoSource="youtube"
                  
                  log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: $videoDownloadUrl..."
                  DownloadVideo "$videoDownloadUrl" "$videoTitleClean" "$plexVideoType" "IMVDB"
                  if [ "$downloadFailed" = "true" ]; then
                      log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: Download failed, skipping..."
                      continue
                  fi
                  DownloadThumb "$imvdbVideoImage" "$videoTitleClean" "$plexVideoType" "IMVDB"
                  VideoProcessWithSMA "IMVDB" "$imvdbVideoTitle" 
                  VideoTagProcess "$videoTitleClean" "$plexVideoType" "$videoYear" "IMVDB"
                  VideoNfoWriter "$videoTitleClean" "$plexVideoType" "$imvdbVideoTitle" "" "imvdb" "$videoYear" "IMVDB" "$videoSource"
                      
                  if [ ! -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                      mkdir -p "$videoPath/$lidarrArtistFolderNoDisambig"
                      chmod 777 "$videoPath/$lidarrArtistFolderNoDisambig"
                  fi 
  
                  mv $downloadPath/incomplete/* "$videoPath/$lidarrArtistFolderNoDisambig"/
              done
  
          fi
  
      fi
  
      if [ ! -d /config/extended/logs/video ]; then
          mkdir -p /config/extended/logs/video
          chmod 777 /config/extended/logs/video
      fi
  
      if [ ! -d /config/extended/logs/video/complete ]; then
          mkdir -p /config/extended/logs/video/complete 
          chmod 777 /config/extended/logs/video/complete 
      fi
  
      touch "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId"
  
      # Import Artist.nfo file
      if [ -d "$lidarrArtistPath" ]; then
          if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
              if [ -f "$lidarrArtistPath/artist.nfo" ]; then
                  if [ ! -f "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo" ]; then
                      log "$processCount of $lidarrArtistIdsCount :: Copying Artist NFO to music-video artist directory"
                      cp "$lidarrArtistPath/artist.nfo" "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo"
                      chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo"
                  fi
              fi
          fi
      fi
  done
}

log "Starting Script...."
for (( ; ; )); do
	let i++
	getArrAppInfo
	verifyApiAccess
	VideoProcess
	log "Script sleeping for 15 minutes..."
	sleep 15m
done

exit
