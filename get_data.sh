#!/usr/bin/env bash

DATA_DIR="data"

get_rs_data_unit() {
	curl 'https://data.iledefrance.fr/explore/dataset/histo-validations-reseau-surface/files/'$1'/download/' \
	  -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:148.0) Gecko/20100101 Firefox/148.0' \
	  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
	  -H 'Accept-Language: en-GB,en;q=0.9' \
	  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
	  -H 'Referer: https://data.iledefrance.fr/explore/dataset/histo-validations-reseau-surface/table/?sort=annee' \
	  -H 'Connection: keep-alive' \
	  -H 'Upgrade-Insecure-Requests: 1' \
	  -H 'Sec-Fetch-Dest: document' \
	  -H 'Sec-Fetch-Mode: navigate' \
	  -H 'Sec-Fetch-Site: same-origin' \
	  -H 'Sec-Fetch-User: ?1' \
	  -H 'Priority: u=0, i' \
	  --output "$DATA_DIR/$1"
}

get_rs_data() {
	hashes=("866c6a8c7d6729673dcd9ef040f06baa")
	for h in "${hashes[@]}"; do
		get_rs_data_unit $h && unzip "$DATA_DIR/$h" -d "$DATA_DIR" && rm "$DATA_DIR/$h"
	done
}

get_weather_data_unit() {
	local API_KEY=$1
	local YEAR=$2
	CMD_ID=$(echo $(curl -X 'GET' \
	  'https://public-api.meteofrance.fr/public/DPClim/v1/commande-station/quotidienne?id-station=75106001&date-deb-periode='$YEAR'-01-01T00%3A00%3A00Z&date-fin-periode='$YEAR'-12-31T23%3A59%3A59Z' \
	  -H 'accept: */*' \
	  -H 'Authorization: Bearer '$API_KEY) | jq '.["elaboreProduitAvecDemandeResponse"]["return"]' | tr -d '"')
	sleep 2
	curl -X 'GET' \
	  'https://public-api.meteofrance.fr/public/DPClim/v1/commande/fichier?id-cmde='$CMD_ID \
	  -H 'accept: */*' \
	  -H 'Authorization: Bearer '$API_KEY --output "$DATA_DIR/meteo-$YEAR"
}

get_weather_data() {
	id_station_luxembourg="75106001"
	for i in $(seq 2015 2024); do
		get_weather_data_unit $1 $i
	done

}

main() {
	ls $DATA_DIR &> /dev/null || mkdir $DATA_DIR
	get_weather_data ${1?"Please provide the Météo France API key as first argument to this script."} || exit
	exit
	get_rs_data
}

main $1
