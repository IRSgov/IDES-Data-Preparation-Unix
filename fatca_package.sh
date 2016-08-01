#!/bin/bash
# @author Subir Paul (IT:ES:SE:PE)

###########################################################
# this script assume 'zip' and 'xmlsec1' is in the path. 
# for 'xmlsec1' see https://www.aleksey.com/xmlsec
###########################################################

echo "****************************************************"
echo "ENVIRONMENT VARIABLES FOR METADATA AND OTHER INPUTES"
echo "****************************************************"

echo UNSIGNED_XML_IN=$UNSIGNED_XML_IN
echo RECEIVER_PUBLIC_CERT_IN=$RECEIVER_PUBLIC_CERT_IN
echo MY_PRIVATE_KEYSTORE_PKCS12_IN=$MY_PRIVATE_KEYSTORE_PKCS12_IN
echo MY_PRIVATE_KEYSTORE_PWD_IN=$MY_PRIVATE_KEYSTORE_PWD_IN
echo MY_PRIVATE_KEY_ALIAS=$MY_PRIVATE_KEY_ALIAS
echo
echo FATCAEntitySenderId=$FATCAEntitySenderId 
echo FATCAEntityReceiverId=$FATCAEntityReceiverId 
echo TaxYear=$TaxYear 
echo FATCAEntCommunicationTypeCd=$FATCAEntCommunicationTypeCd 
echo FileRevisionInd=$FileRevisionInd 
echo SenderContactEmailAddressTxt=$SenderContactEmailAddressTxt

echo "**********************************************"

if [[ -z $UNSIGNED_XML_IN || -z $RECEIVER_PUBLIC_CERT_IN || -z $MY_PRIVATE_KEYSTORE_PKCS12_IN || -z $MY_PRIVATE_KEYSTORE_PWD_IN || -z $FATCAEntitySenderId || -z $FATCAEntityReceiverId || -z $TaxYear || -z $FATCAEntCommunicationTypeCd || -z $FileRevisionInd || -z $SenderContactEmailAddressTxt ]]; then 
    echo "please see sample_package.sh....set all these variables FATCAEntitySenderId, FATCAEntityReceiverId, TaxYear, FATCAEntCommunicationTypeCd, FileRevisionInd, SenderContactEmailAddressTxt"
    exit 1
fi

if [[ ! -f $UNSIGNED_XML_IN || ! -f $RECEIVER_PUBLIC_CERT_IN || ! -f $MY_PRIVATE_KEYSTORE_PKCS12_IN ]]; then
    echo "ERROR: either $UNSIGNED_XML_IN or $RECEIVER_PUBLIC_CERT_IN or $MY_PRIVATE_KEYSTORE_PKCS12_IN does not exit"
    exit 1
fi

###########################################################
# file names
###########################################################

# BSD/MAC OS X don't support %N (millisec)
#SenderFileId=`date -u +%Y%m%dT%H%M%S%3NZ`
SenderFileId=`date -u +%Y%m%dT%H%M%S000Z`
FileCreateTs=`date -u +%Y-%m-%dT%H:%M:%SZ`

payload_file="${FATCAEntitySenderId}"_Payload
key_file="${FATCAEntityReceiverId}"_Key
pkg_file="${SenderFileId}"_"${FATCAEntitySenderId}".zip
metadata_file=`echo "${FATCAEntitySenderId}"_Metadata.xml`

signed_xml=`echo "${payload_file}".xml`
pre_sign_tmplt=`echo "${signed_xml}".tmplt`
compressed_signed_xml=`echo "${UNSIGNED_XML_IN}".signed.zip`

if [[ -f $signed_xml ]]; then
    echo "ERROR: ${signed_xml} already exists"
    exit 1
fi

###########################################################
# sign xml using xmlsec1. http://www.aleksey.com/xmlsec/
#   - embed $UNSIGNED_XML_IN within $tmplt_prefix and $tmplt_suffix
#   - Resulting file $signed_xml would have structure <Object Id="FATCA">[XML]</Object>.
#   - Use $signed_xml and sign using 'xmlsec1'
###########################################################

echo;echo "creating signature template file '$pre_sign_tmplt' for xmlsec signing...."

# create signatutre template file after embedding xml
if [[ -f $pre_sign_tmplt ]]; then
    rm -f $pre_sign_tmplt
fi

tmplt_prefix='<?xml version="1.0" encoding="UTF-8" standalone="no"?><Signature xmlns="http://www.w3.org/2000/09/xmldsig#" Id="SignatureId"><SignedInfo><CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/><SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/><Reference URI="#FATCA"><Transforms><Transform Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/></Transforms><DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/><DigestValue/></Reference></SignedInfo><SignatureValue/><KeyInfo><X509Data><X509Certificate/></X509Data></KeyInfo><Object Id="FATCA">'

tmplt_suffix='</Object></Signature>'

echo -n "$tmplt_prefix" >> $pre_sign_tmplt

is_newline_needed=0
xml_decl_checked=0
line=
while IFS= read -r line
do
if [[ $xml_decl_checked -eq 0 ]]; then
    xml_decl_checked=1
    line=`echo ${line#<?xml*?>}`
    if [[ ! -z "$line" ]]; then
        echo -n "$line" >> $pre_sign_tmplt
        is_newline_needed=1
    fi
else
    if [[ is_newline_needed -eq 1 ]]; then echo >> $pre_sign_tmplt; fi
    echo -n "$line" >> $pre_sign_tmplt
    is_newline_needed=1
fi
done < $UNSIGNED_XML_IN

#take care last line
line=`echo -n "$line"|xargs`
if [[ ! -z "$line" ]]; then
    if [[ is_newline_needed -eq 1 ]]; then echo >> $pre_sign_tmplt; fi
    echo -n "$line" >> $pre_sign_tmplt
fi

if [[ "$?" -ne 0 ]]; then echo "ERROR: last command failed"; exit $?; fi

echo -n "$tmplt_suffix" >> $pre_sign_tmplt

echo;echo "creating signature template file '$pre_sign_tmplt' for xmlsec signing....done"

###########################################################

echo;echo "signing '$pre_sign_tmplt' to create signed xml '$signed_xml'...."

# sign with xmlsec
if [[ $MY_PRIVATE_KEY_ALIAS -eq "" ]]; then
    CMD="xmlsec1 --sign --pkcs12 $MY_PRIVATE_KEYSTORE_PKCS12_IN --pwd $MY_PRIVATE_KEYSTORE_PWD_IN --output $signed_xml $pre_sign_tmplt"
else
    CMD="xmlsec1 --sign --pkcs12:$MY_PRIVATE_KEY_ALIAS $MY_PRIVATE_KEYSTORE_PKCS12_IN --pwd $MY_PRIVATE_KEYSTORE_PWD_IN --output $signed_xml $pre_sign_tmplt"
fi

echo;echo $CMD;$CMD


if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml 
    exit 1
fi

echo; echo "signing '$pre_sign_tmplt' to create signed xml '$signed_xml'....done"; echo

###########################################################
# compress $signed_xml to $compressed_signed_xml
###########################################################

echo "compressing '$signed_xml' to create '$compressed_signed_xml'...."

CMD="zip -q $compressed_signed_xml $signed_xml"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml
    exit 1
fi

echo; echo "compressing '$signed_xml' to create '$compressed_signed_xml'....done"; echo

###########################################################
# encrypt $compressed_signed_xml
#    - create 32 bytes AES key, AESKEY
#    - create 16 bytes Initialization Vector, IV, used for CBC encryption
#    - encrypt $compressed_signed_xml using CBC with $AESKEY, $IV. encrypted file output is $payload_file
#    - append $IV to $AESKEY and encrypt resulting $AESKEYIVBIN with receiver's PKI public key, $RECEIVER_PUBLIC_CERT_IN. output file is $key_file
###########################################################

echo "encrypting '$compressed_signed_xml'...."

# Create 32 bytes random AES key
TMP=`openssl rand 32 -hex`
AESKEY=`echo ${TMP:0:64}`

# Create 16 bytes random Initialization Vector (IV)
TMP=`openssl rand 16 -hex`
IV=`echo ${TMP:0:32}`

echo; echo "AESKEY=$AESKEY"; echo "IV=$IV"; 

# Encrypt payload with key AESKEY and iv IV
CMD="openssl enc -e -aes-256-cbc -in $compressed_signed_xml -out $payload_file -K $AESKEY -iv $IV"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml $payload_file
    exit 1
fi

# Concatenate 32 bytes AESKEY and 16 bytes IV
AESKEYIV=`echo -n "$AESKEY$IV"`

# Convert AESKEY+IV hex to binary
AESKEYIVBIN=`echo ${key_file}.aeskeyivbin`

#echo;echo "echo -n $AESKEYIV|perl -pe '\$_=pack(\"H*\",\$_)' > $AESKEYIVBIN"
#echo -n $AESKEYIV|perl -pe '$_=pack("H*",$_)' > $AESKEYIVBIN
echo;echo "echo -n $AESKEYIV|xxd -r -p > $AESKEYIVBIN"
echo -n $AESKEYIV|xxd -r -p > $AESKEYIVBIN

# Encrypt aeskey_iv.bin with receiver's RSA PKI public key
CMD="openssl rsautl -encrypt -out $key_file -certin -inkey $RECEIVER_PUBLIC_CERT_IN -keyform DER -in $AESKEYIVBIN"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml $payload_file $AESKEYIVBIN $key_file
    exit 1
fi

echo; echo "encrypting '$compressed_signed_xml'....done"; echo

###########################################################
# create Metadata file, $metadata_file
###########################################################

echo "writing metadata '$metadata_file'...."

# create metadata file
MD='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'
MD="${MD}"'<FATCAIDESSenderFileMetadata xmlns="urn:fatca:idessenderfilemetadata">\r\n' 
MD="${MD}"'\t<FATCAEntitySenderId>'"${FATCAEntitySenderId}"'</FATCAEntitySenderId>\r\n'
MD="${MD}"'\t<FATCAEntityReceiverId>'"${FATCAEntityReceiverId}"'</FATCAEntityReceiverId>\r\n'
MD="${MD}"'\t<FATCAEntCommunicationTypeCd>'"${FATCAEntCommunicationTypeCd}"'</FATCAEntCommunicationTypeCd>\r\n'
MD="${MD}"'\t<SenderFileId>'"${SenderFileId}"'.zip</SenderFileId>\r\n'
MD="${MD}"'\t<FileCreateTs>'"${FileCreateTs}"'</FileCreateTs>\r\n'
MD="${MD}"'\t<TaxYear>'"${TaxYear}"'</TaxYear>\r\n'
MD="${MD}"'\t<FileRevisionInd>'"${FileRevisionInd}"'</FileRevisionInd>\r\n'
MD="${MD}"'\t<SenderContactEmailAddressTxt>'"${SenderContactEmailAddressTxt}"'</SenderContactEmailAddressTxt>\r\n'
MD="$MD"'</FATCAIDESSenderFileMetadata>\r\n'

echo;printf "echo -e $MD > $metadata_file"
echo -e $MD > $metadata_file

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml $payload_file $AESKEYIVBIN $key_file $metadata_file
    exit 1
fi

echo; echo "writing metadata '$metadata_file'....done"; echo

###########################################################
# create IDES $pkg_file which contains following files compressed
#    - $payload_file
#    - $key_file
#    - $mtadata_file
###########################################################

echo "creating pkg '$pkg_file'......."

CMD="zip -q $pkg_file $payload_file $key_file $metadata_file"

echo;echo $CMD;$CMD

if [[ "$?" -ne 0 ]]; then
    echo "!!!! please fix the error !!!!";echo $CMD;echo
    rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml $payload_file $AESKEYIVBIN $key_file $metadata_file $pkg_file
    exit 1
fi

echo; echo "creating pkg '$pkg_file'.......done"; echo

###########################################################
# remove all temporary files (comment for  debugging/verification)
###########################################################

rm -f $pre_sign_tmplt $signed_xml $compressed_signed_xml $payload_file $AESKEYIVBIN $key_file $metadata_file