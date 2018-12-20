#!/usr/bin/env bash
#Script pour WSO2 3.1.0

hostname="${1}"

if [ "${hostname}" == "" ]; then
    hostname='mdm.cyber.lan'
fi


# Perform tedious, in-place configuration changes
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'carbon.xml')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'wso2server.sh')  # IoT 3.0.0
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'iot-server.sh')  # IoT 3.1.0
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'sso-idp-config.xml')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'app-manager.xml')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'app-conf.json')
perl -pi -e "s/%iot.keymanager.host%/${hostname}/g" $(find . -name 'app-conf.json')
perl -pi -e "s/%iot.keymanager.https.port%/9443/g" $(find . -name 'app-conf.json')
perl -pi -e "s/%iot.manager.host%/${hostname}/g" $(find . -name 'app-conf.json')
perl -pi -e "s/%iot.manager.https.port%/9443/g" $(find . -name 'app-conf.json')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'site.json')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'designer.json')
perl -pi -e "s/%https.host%/https:\/\/${hostname}:9443/g" $(find . -name 'designer.json')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'admin--Android-Mutual-SSL*.xml')
perl -pi -e "s/localhost/${hostname}/g" $(find . -name 'mobile-config.xml')


rm -rf keystore.p12 public.cert *.jks

    echo "Generating certificates for '${hostname}'"

    alias='wso2carbon'

    keytool -genkey -alias ${alias} -keyalg RSA -keysize 4096 \
	    -keypass wso2carbon -keystore selfsigned.jks -storepass wso2carbon \
	    -dname "cn=${hostname}, ou=cyber, o=NTICCC, l=Paris, st=iledefrance, c=FR" \
	    -ext SAN=DNS:localhost,IP:127.0.0.1,IP:${hostname}


    keytool -export -alias ${alias} -keystore selfsigned.jks \
	        -rfc -storepass wso2carbon -file public.cert

    # Grab the existing keystores to be fixed (it is assumed that they're all the same)
    cp --verbose $(find wso2iot* -name 'client-truststore.jks' | head -1) .
    cp --verbose $(find wso2iot* -name 'wso2carbon.jks' | head -1) .

    # Clear out the existing entry for this alias
    keytool -delete -alias ${alias} -keystore client-truststore.jks \
	        -storepass wso2carbon

    # Re-add the new entry for this alias
    keytool -import -noprompt -trustcacerts -alias ${alias} -file public.cert \
	        -keystore client-truststore.jks -storepass wso2carbon

    # Clear out the existing entry for this alias
    keytool -delete -alias ${alias} \
	        -keystore wso2carbon.jks -storepass wso2carbon

    keytool -import -noprompt -trustcacerts -alias ${alias} -file public.cert \
	        -keystore wso2carbon.jks -storepass wso2carbon

    keytool -importkeystore -srckeystore selfsigned.jks -destkeystore keystore.p12 \
	        -deststoretype PKCS12 -deststorepass wso2carbon -srcstorepass wso2carbon
    keytool -importkeystore -noprompt \
	        -srckeystore keystore.p12 -srcstoretype PKCS12 -srcstorepass wso2carbon \
		    -destkeystore wso2carbon.jks -deststorepass wso2carbon

    # Make sure you paste the contents of ugh.txt into iot_default.xml
    cat public.cert | sed '1d;$d' | tr -d '\r\n' > ugh.txt

    # Put the keystores in the desired locations
    for target in $(find wso2iot* -name 'wso2carbon.jks'); do
	        cp --verbose wso2carbon.jks ${target}
    done
    for target in $(find wso2iot* -name 'client-truststore.jks'); do
		    cp --verbose client-truststore.jks ${target}
    done

echo "Noubliez pas de remplacer le certificat depuis le fichier iot_default.xml\n par le contenue du fichier ugh.txt"
find ./ -name 'iot_default.xml'

