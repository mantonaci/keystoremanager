#!/bin/bash

GREEN='\033[0;32m'
LIGHT_CYAN='\033[0;96m'
RED='\033[0;31m'
NC='\033[0m'

set -e

while [ $# -gt 0 ]
do
	opt="$1";
	case "$opt" in
		-srcpasswd)
    	SRCPASSWD="$2"
    	shift
    	;;
    	-srckeystore)
    	SRCKEYSTORE="$2"
    	shift
    	;;
    	-hostname)
    	HOSTNAME="$2"
    	shift
    	;;
    	-publiccer)
    	PUBLICCER="$2"
    	shift
    	;;
    	*) shift;;
	esac
done

declare -a ks_alias=($(keytool -list -v -keystore $SRCKEYSTORE -storepass $SRCPASSWD | sed -n -e 's/^.*Alias name: //p'))
declare -a ks_entrytype=($(keytool -list -v -keystore $SRCKEYSTORE -storepass $SRCPASSWD | sed -n -e 's/^.*Entry type: //p'))
declare -a ks_alias_privatekeyentry=()

for ((i=0; i<${#ks_alias[@]}; i++))
do
    if [ ${ks_entrytype[$i]} = "PrivateKeyEntry" ]
    then
        ks_alias_privatekeyentry+=("${ks_alias[$i]}")
    fi
done

if [[ ${#ks_alias_privatekeyentry[@]} -eq 0 ]]
then
    echo -e "${LIGHT_CYAN}Sorry, not a valid keystore!!!${NC}"
    exit 0;
fi

echo -e "\n${GREEN}Select alias in keystore: ${LIGHT_CYAN}$SRCKEYSTORE${NC}\n"
for ((i=0; i<${#ks_alias_privatekeyentry[@]}; i++))
do
    echo "($i) Alias name (PrivateKeyEntry): ${ks_alias_privatekeyentry[$i]}"
done

read -p $'\x0aInsert alias number: ' alias_choosed
read -p 'Do you want export also the public certificate? [Y/n] ' export_pubcer

echo -e "${GREEN}\nExport both private key and public certificate pairs in: ${LIGHT_CYAN}$HOSTNAME-keystore.p12${NC}\n"
keytool -importkeystore -srckeystore $SRCKEYSTORE -srcalias ${ks_alias_privatekeyentry[$alias_choosed]} -destkeystore $HOSTNAME-keystore.p12 -deststoretype PKCS12

if [[ $export_pubcer =~ [yY](es)* ]]
then
    echo -e "${GREEN}\nExport public certificate in: ${LIGHT_CYAN}$HOSTNAME.pem${NC}\n"
    openssl pkcs12 -in $HOSTNAME-keystore.p12 -nokeys -out $HOSTNAME.pem
fi

echo -e "${GREEN}\nExport private-key in: $HOSTNAME.key${NC}\n"
openssl pkcs12 -in $HOSTNAME-keystore.p12 -nocerts -out $HOSTNAME.key

echo -e "${GREEN}\nSigning private key with new public certificate in: ${LIGHT_CYAN}$HOSTNAME.p12${NC}\n"
openssl pkcs12 -export -in $PUBLICCER -inkey $HOSTNAME.key -out $HOSTNAME.p12

echo -e "${GREEN}\nImport signed certificate in keystore with alias: ${LIGHT_CYAN}${ks_alias_privatekeyentry[$alias_choosed]}${NC}\n"
keytool -importkeystore  -srckeystore $HOSTNAME.p12 -srcstoretype PKCS12 -destkeystore keystore.jks -alias 1 -destalias ${ks_alias_privatekeyentry[$alias_choosed]}

echo -e "${GREEN}\nEnjoy! New certitifcate imported in default keystore (keystore.jks) with alias: ${LIGHT_CYAN}${ks_alias_privatekeyentry[$alias_choosed]}${NC}\n"