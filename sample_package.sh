#!/bin/bash
# @author       Subir Paul (IT:ES:SE:PE)

UNSIGNED_XML_IN = yourUnsignedPayload.xml
RECEIVER_PUBLIC_CERT_IN = theReceiverPublic.cer
MY_PRIVATE_KEYSTORE_PKCS12_IN = yourPrivateKey.p12
MY_PRIVATE_KEYSTORE_PWD_IN = yourPrivateKeyPassword
MY_PRIVATE_KEY_ALIAS=

# Metadata info
FATCAEntitySenderId = yourGIIN
FATCAEntityReceiverId = theReceiverGIIN
TaxYear = 2015
FATCAEntCommunicationTypeCd = RPT
FileRevisionInd = false
SenderContactEmailAddressTxt = yourEmail@yourDomain.com

export UNSIGNED_XML_IN RECEIVER_PUBLIC_CERT_IN MY_PRIVATE_KEYSTORE_PKCS12_IN MY_PRIVATE_KEYSTORE_PWD_IN MY_PRIVATE_KEY_ALIAS FATCAEntitySenderId FATCAEntityReceiverId TaxYear FATCAEntCommunicationTypeCd FileRevisionInd SenderContactEmailAddressTxt

./fatca_package.sh
