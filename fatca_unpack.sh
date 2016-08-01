#!/bin/bash
# @author Subir Paul (IT:ES:SE:PE)

##########################################
# this script assume 'zip' is in the path. 
##########################################

# *************************************
# SET FOLLOWING VARIABLES APPROPRIATELY
# *************************************

echo "**********************"
echo "ENVIRONMENT VARIABLES"
echo "*********************"

echo FATCA_PKG_IN=$FATCA_PKG_IN
echo MY_PRIVATE_KEYSTORE_PKCS12_IN=$MY_PRIVATE_KEYSTORE_PKCS12_IN
echo MY_PRIVATE_KEYSTORE_PWD_IN=$MY_PRIVATE_KEYSTORE_PWD_IN
echo SENDER_PUBLIC_CERT_IN=$SENDER_PUBLIC_CERT_IN

echo "*********************"

if [[ -z $FATCA_PKG_IN || -z $MY_PRIVATE_KEYSTORE_PKCS12_IN || -z MY_PRIVATE_KEYSTORE_PWD_IN ]]; then
    echo "please see sample_unpack.sh....set all these variables FATCA_PKG_IN, MY_PRIVATE_KEYSTORE_PKCS12_IN, MY_PRIVATE_KEYSTORE_PWD_IN, SENDER_PUBLIC_CERT_IN (optional - for signature validation)"
    exit 1
fi

####################
# unzip FATCA_PKG_IN
####################

if [[ ! -f $FATCA_PKG_IN || ! -f $MY_PRIVATE_KEYSTORE_PKCS12_IN ]]; then
    echo "ERROR: either $FATCA_PKG_IN or $MY_PRIVATE_KEYSTORE_PKCS12_IN does not exit"
    exit 1
fi

echo "unzipping '$FATCA_PKG_IN'...."

declare -a arr=(`unzip -Z1 ${FATCA_PKG_IN}`)

i=0
while true; do
    echo ${arr[$i]}
    tmp=${arr[$i]#*_}
    if [[ ${tmp} = Payload ]]; then
        payload_file=${arr[$i]}
    elif [[ ${tmp} = Metadata.xml ]]; then
        metadata_file=${arr[$i]}
    elif [[ ${tmp} = Key ]]; then
        key_file=${arr[$i]}
    fi
    i=$[$i+1]
    if [[ $i -eq ${#arr[@]} ]]; then
        break;
    fi
done

if [[ -z $payload_file || -z $metadata_file || -z $key_file ]]; then
    echo "invalid $FATCA_PKG_IN - one or more file missing"
    exit 1
fi

CMD="unzip -oq $FATCA_PKG_IN"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $metadata_file $key_file $payload_file
    exit 1
fi

echo;echo "unzipping '$FATCA_PKG_IN'....done"
echo;echo "extracting private key from keystore '$MY_PRIVATE_KEYSTORE_PKCS12_IN'...."

# Decrypt encrypted AESKEY+IV using receiver's RSA PKI private key
private_key_pem_file=`echo ${key_file}.pem`

CMD="openssl pkcs12 -in $MY_PRIVATE_KEYSTORE_PKCS12_IN -nocerts -passin pass:$MY_PRIVATE_KEYSTORE_PWD_IN -nodes" > $private_key_pem_file

echo;echo "$CMD > $private_key_pem_file";$CMD > $private_key_pem_file

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";
    echo;echo "$CMD > $private_key_pem_file";$CMD > $private_key_pem_file
    rm -f $metadata_file $key_file $payload_file $private_key_pem_file
    exit 1
fi

echo;echo "extracting private key from keystore '$MY_PRIVATE_KEYSTORE_PKCS12_IN'....done"
echo;echo "decrypting '$key_file' using private key from '$private_key_pem_file'...."

CMD="TMP=\`openssl rsautl -decrypt -in $key_file -inkey $private_key_pem_file | perl -pe '\$_=unpack("H*",\$_)'\`"

echo;echo $CMD;

TMP=`openssl rsautl -decrypt -in $key_file -inkey $private_key_pem_file|perl -pe '$_=unpack("H*", $_)'`

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $metadata_file $key_file $payload_file $private_key_pem_file
    exit 1
fi

# Extract 32 bytes AESKEY and 16 bytes IV
AESKEY2DECRYPT=`echo ${TMP:0:64}`
IV2DECRYPT=`echo ${TMP:64:96}`

# Decrypt payload using D_AESKEY and D_IV
payload_zip_file=`echo ${payload_file}.zip`
CMD="openssl enc -d -aes-256-cbc -in $payload_file -out $payload_zip_file -K $AESKEY2DECRYPT -iv $IV2DECRYPT"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $metadata_file $key_file $payload_file $private_key_pem_file
    exit 1
fi

# Check if payload_zip_file are created
if [[ ! -f $payload_zip_file ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $metadata_file $key_file $payload_file $private_key_pem_file
    exit 1
fi

echo;echo "decrypting '$key_file' using private key from '$private_key_pem_file'....done"
echo;echo "unzipping '$payload_zip_file'...."

CMD="unzip -oq $payload_zip_file"

echo;echo $CMD;$CMD

payload_xml_file=${payload_file}.xml

# Check if $payload_xml_file is created
if [[ "$?" -ne 0 || ! -f $payload_xml_file ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $metadata_file $key_file $payload_file $private_key_pem_file
    exit 1
fi

echo;echo "unzipping '$payload_zip_file'....done"

error_flag=0

# check if SENDER_PUBLIC_CERT_IN non empty; if so verify signature
if [[ ! -z $SENDER_PUBLIC_CERT_IN && -f $SENDER_PUBLIC_CERT_IN ]]; then
    echo;echo "verifying signature of '$payload_xml_file'...."

    CMD="xmlsec1 --verify --pubkey-cert-der $SENDER_PUBLIC_CERT_IN $payload_xml_file" 

    echo;echo $CMD;$CMD 2>&1

    if [[ "$?" -eq 0 ]]; then
        echo;echo "'$payload_xml_file' signature verification succeed"
    else
        echo;echo "ERROR: '$payload_xml_file' signature verification failed"
        error_flag=1
    fi

    echo;echo "verifying signature of '$payload_xml_file'....done"
fi

if [[ error_flag -eq 0 ]]; then
    echo;echo "success!!!! unpacked $payload_xml_file and $metadata_file"
fi

rm -f $key_file $payload_file $private_key_pem_file $payload_zip_file