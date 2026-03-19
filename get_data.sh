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
	# source: https://data.iledefrance.fr/explore/dataset/histo-validations-reseau-surface/export/?sort=annee
	hashes=(
		# 2016
		"c14c733e65e57a0f7aa918903f41055b"
		# 2017
		"9c6b0ae07fb8476b58d76f9c5c5f149c"
		# 2018
		"4c9abf782ec17616bcbcd68faa45ec99"
		# 2019
		"6dd37a6a90a476a1090a751ea3e0d78c"
		# 2020
		"41adcbd4216382c232ced4ccbf60187e"
		# 2021
		"68cac32e8717f476905a60006a4dca26"
		# 2022
		"fa7ac9a106a1ce78d4158101a17404bd"
		# 2023
		"3c86c4b775bf17334108d4c0325478c2"
		# 2024
		"73c8353c8431e192a1c561e38487b963"
	)
	for h in "${hashes[@]}"; do
		get_rs_data_unit $h && unzip "$DATA_DIR/$h" -d "$DATA_DIR" && rm "$DATA_DIR/$h"
	done
	# cleaning data
	mkdir "data/data-rs-2023"
	mv data/2023*.txt "data/data-rs-2023"
	ls data/data-rs-*/*PROFIL*.txt &> /dev/null && rm data/data-rs-*/*PROFIL*.txt
	cp data/data-rs-2024/2024_T4_NB_SURFACE.txt data/data-rs-2024/2024_T4_NB_SURFACE.txt.old
	cat data/data-rs-2024/2024_T4_NB_SURFACE.txt.old | cut -f1,5- > data/data-rs-2024/2024_T4_NB_SURFACE.txt
	rm data/data-rs-2024/2024_T4_NB_SURFACE.txt.old 
	cp data/data-rs-2022/2022_T4_NB_SURFACE.txt data/data-rs-2022/2022_T4_NB_SURFACE.txt.old
	cat data/data-rs-2022/2022_T4_NB_SURFACE.txt.old | tr ";" "\t" > data/data-rs-2022/2022_T4_NB_SURFACE.txt
	rm data/data-rs-2022/2022_T4_NB_SURFACE.txt.old 
	cp data/data-rs-2022/2022_T3_NB_SURFACE.txt data/data-rs-2022/2022_T3_NB_SURFACE.txt.old
	cat data/data-rs-2022/2022_T3_NB_SURFACE.txt.old | tr ";" "\t" > data/data-rs-2022/2022_T3_NB_SURFACE.txt
	rm data/data-rs-2022/2022_T3_NB_SURFACE.txt.old 
	cp data/data-rs-2024/2024_T4_NB_SURFACE.txt data/data-rs-2024/2024_T4_NB_SURFACE.txt.old
	awk '{ sub("\/24", "/2024"); print}' data/data-rs-2024/2024_T4_NB_SURFACE.txt.old > data/data-rs-2024/2024_T4_NB_SURFACE.txt
	rm data/data-rs-2024/2024_T4_NB_SURFACE.txt.old 
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
	for i in $(seq 2016 2024); do
		get_weather_data_unit $1 $i
	done

}

main() {
	ls $DATA_DIR &> /dev/null || mkdir $DATA_DIR
	get_weather_data ${1?"Please provide the Météo France API key as first argument to this script."} || exit
	get_rs_data
}

main $1
