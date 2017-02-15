#!/bin/bash

GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

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

echo -e "\n${GREEN}Select alias in keystore: ${LIGHT_BLUE}$SRCKEYSTORE${NC}\n"
ks_alias=($(keytool -list -v -keystore $SRCKEYSTORE -storepass $SRCPASSWD | sed -n -e 's/^.*Alias name: //p'))

for ((i=0; i<${#ks_alias[@]}; i++))
do
	echo "($i) Alias name: ${ks_alias[$i]}"
done

trap 'printf "\n"' DEBUG
read -p 'Insert alias number: ' alias_choosed

echo -e "${GREEN}Export both private key and public certificate pairs in: ${LIGHT_BLUE}$HOSTNAME-keystore.p12${NC}"
keytool -importkeystore -srckeystore $SRCKEYSTORE -srcalias ${ks_alias[$alias_choosed]} -destkeystore $HOSTNAME-keystore.p12 -deststoretype PKCS12

echo -e "${GREEN}Export public certificate in: ${LIGHT_BLUE}$HOSTNAME.pem${NC}"
openssl pkcs12 -in $HOSTNAME-keystore.p12 -nokeys -out $HOSTNAME.pem

echo -e "${GREEN}Export private-key in: $HOSTNAME.key${NC}"
openssl pkcs12 -in $HOSTNAME-keystore.p12 -nocerts -out $HOSTNAME.key

echo -e "${GREEN}Signing private key with new public certificate in: ${LIGHT_BLUE}$HOSTNAME.p12${NC}"
openssl pkcs12 -export -in $PUBLICCER -inkey $HOSTNAME.key -out $HOSTNAME.p12

echo -e "${GREEN}Import signed certificate in keystore with alias: ${LIGHT_BLUE}${ks_alias[$alias_choosed]}${NC}"
keytool -importkeystore  -srckeystore $HOSTNAME.p12 -srcstoretype PKCS12 -destkeystore keystore.jks -alias 1 -destalias ${ks_alias[$alias_choosed]}

echo -e "${GREEN}Enjoy! New certitifcate imported in default keystore (keystore.jks) with alias: ${LIGHT_BLUE}${ks_alias[$alias_choosed]}${NC}\n"