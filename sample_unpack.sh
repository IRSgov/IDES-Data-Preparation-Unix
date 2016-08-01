#!/bin/bash
# @author Subir Paul (IT:ES:SE:PE)

FATCA_PKG_IN=theDataPacketYouReceived.zip
MY_PRIVATE_KEYSTORE_PKCS12_IN=yourPrivateKey.p12
MY_PRIVATE_KEYSTORE_PWD_IN=yourPrivateKeyPassword

# for signature validation - optional
SENDER_PUBLIC_CERT_IN=theSenderPublic.cer

export FATCA_PKG_IN MY_PRIVATE_KEYSTORE_PKCS12_IN MY_PRIVATE_KEYSTORE_PWD_IN SENDER_PUBLIC_CERT_IN

./fatca_unpack.sh
