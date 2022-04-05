#!/bin/bash
#
# This script manages the start of integration
# tests for Python core in AWS IoT Arduino Yun
# SDK. The tests should be able to run both in
# Brazil and ToD Worker environment.
# The script will perform the following tasks:
# 1. Retrieve credentials as needed from Odin
# 2. Obtain ZIP package and unzip it locally
# 3. Obtain Python executable
# 4. Start the integration tests and check results
# 5. Report any status returned.
# To start the tests as TodWorker:
# > run.sh <whichSDK> MutualAuth 1000 100 7
# or
# > run.sh <which SDK> Websocket 1000 100 7
# or
# > run.sh <which SDK> ALPN 1000 100 7
#
# To start the tests from desktop:
# > run.sh <which SDK> MutualAuthT 1000 100 7
# or
# > run.sh <which SDK> WebsocketT 1000 100 7
# or
# > run.sh <which SDK> ALPNT 1000 100 7
#
# 1000 MQTT messages, 100 bytes of random string
# in length and 7 rounds of network failure for 
# progressive backoff.
# Test mode (MutualAuth/Websocket) must be
# specified.
# Scale number must also be specified (see usage)

# Define const
USAGE="usage: run.sh <testMode> <NumberOfMQTTMessages> <LengthOfShadowRandomString> <NumberOfNetworkFailure>"

AWSMutualAuth_TodWorker_private_key="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestPrivateKey-vNUQU8"
AWSMutualAuth_TodWorker_certificate="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestCertificate-vTRwjE"
AWSMutualAuth_Desktop_private_key="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestDesktopPrivateKey-DdC7nv"
AWSMutualAuth_Desktop_certificate="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestDesktopCertificate-IA4xbj"

AWSGGDiscovery_TodWorker_private_key="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestGGDiscoveryPrivateKey-YHQI1F"
AWSGGDiscovery_TodWorker_certificate="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestGGDiscoveryCertificate-TwlAcS"

AWSSecretForWebsocket_TodWorker_KeyId="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestWebsocketAccessKeyId-1YdB9z"
AWSSecretForWebsocket_TodWorker_SecretKey="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestWebsocketSecretAccessKey-MKTSaV"
AWSSecretForWebsocket_Desktop_KeyId="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestWebsocketAccessKeyId-1YdB9z"
AWSSecretForWebsocket_Desktop_SecretKey="arn:aws:secretsmanager:us-east-1:123124136734:secret:V1IotSdkIntegrationTestWebsocketSecretAccessKey-MKTSaV"

RetrieveAWSKeys="./test-integration/Tools/retrieve-key.py"
CREDENTIAL_DIR="./test-integration/Credentials/"
TEST_DIR="./test-integration/IntegrationTests/"
CA_CERT_URL="https://www.amazontrust.com/repository/AmazonRootCA1.pem"
CA_CERT_PATH=${CREDENTIAL_DIR}rootCA.crt




# If input args not correct, echo usage
if [ $# -ne 4 ]; then
    echo ${USAGE}
else
# Description
    echo "[STEP] Start run.sh"
    echo "***************************************************"
    echo "About to start integration tests for IoTPySDK..."
    echo "Test Mode: $1"
# Determine the Python versions need to test for this SDK
    pythonExecutableArray=()
    pythonExecutableArray[0]="3"
# Retrieve credentials as needed from Odin
    TestMode=""
    echo "[STEP] Retrieve credentials from Odin"
    echo "***************************************************"
    if [ "$1"x == "MutualAuth"x -o "$1"x == "MutualAuthT"x ]; then
        AWSSetName_privatekey=${AWSMutualAuth_TodWorker_private_key}
    	AWSSetName_certificate=${AWSMutualAuth_TodWorker_certificate}
    	AWSDRSName_privatekey=${AWSGGDiscovery_TodWorker_private_key}
        AWSDRSName_certificate=${AWSGGDiscovery_TodWorker_certificate}
        TestMode="MutualAuth"
        if [ "$1"x == "MutualAuthT"x ]; then
            AWSSetName_privatekey=${AWSMutualAuth_Desktop_private_key}
    	    AWSSetName_certificate=${AWSMutualAuth_Desktop_certificate}
        fi
    	python ${RetrieveAWSKeys} ${AWSSetName_certificate} > ${CREDENTIAL_DIR}certificate.pem.crt
    	python ${RetrieveAWSKeys} ${AWSSetName_privatekey} > ${CREDENTIAL_DIR}privateKey.pem.key
        curl -s "${CA_CERT_URL}" > ${CA_CERT_PATH}
        echo -e "URL retrieved certificate data:\n$(cat ${CA_CERT_PATH})\n"
    	python ${RetrieveAWSKeys} ${AWSDRSName_certificate} > ${CREDENTIAL_DIR}certificate_drs.pem.crt
    	python ${RetrieveAWSKeys} ${AWSDRSName_privatekey} > ${CREDENTIAL_DIR}privateKey_drs.pem.key
    elif [ "$1"x == "Websocket"x -o "$1"x == "WebsocketT"x ]; then
    	ACCESS_KEY_ID_ARN=$(python ${RetrieveAWSKeys} ${AWSSecretForWebsocket_TodWorker_KeyId})
        ACCESS_SECRET_KEY_ARN=$(python ${RetrieveAWSKeys} ${AWSSecretForWebsocket_TodWorker_SecretKey})
        TestMode="Websocket"
        if [ "$1"x == "WebsocketT"x ]; then
            ACCESS_KEY_ID_ARN=$(python ${RetrieveAWSKeys} ${AWSSecretForWebsocket_Desktop_KeyId})
            ACCESS_SECRET_KEY_ARN=$(python ${RetrieveAWSKeys} ${AWSSecretForWebsocket_Desktop_SecretKey})
        fi
        echo ${ACCESS_KEY_ID_ARN}
        echo ${ACCESS_SECRET_KEY_ARN}
        export AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID_ARN}
        export AWS_SECRET_ACCESS_KEY=${ACCESS_SECRET_KEY_ARN}
        curl -s "${CA_CERT_URL}" > ${CA_CERT_PATH}
        echo -e "URL retrieved certificate data:\n$(cat ${CA_CERT_PATH})\n"
    elif [ "$1"x == "ALPN"x -o "$1"x == "ALPNT"x ]; then
        AWSSetName_privatekey=${AWSMutualAuth_TodWorker_private_key}
    	AWSSetName_certificate=${AWSMutualAuth_TodWorker_certificate}
    	AWSDRSName_privatekey=${AWSGGDiscovery_TodWorker_private_key}
        AWSDRSName_certificate=${AWSGGDiscovery_TodWorker_certificate}
        TestMode="ALPN"
        if [ "$1"x == "ALPNT"x ]; then
            AWSSetName_privatekey=${AWSMutualAuth_Desktop_private_key}
    	    AWSSetName_certificate=${AWSMutualAuth_Desktop_certificate}
        fi
        python ${RetrieveAWSKeys} ${AWSSetName_certificate} > ${CREDENTIAL_DIR}certificate.pem.crt
    	python ${RetrieveAWSKeys} ${AWSSetName_privatekey} > ${CREDENTIAL_DIR}privateKey.pem.key
        curl -s "${CA_CERT_URL}" > ${CA_CERT_PATH}
        echo -e "URL retrieved certificate data:\n$(cat ${CA_CERT_PATH})\n"
    	python ${RetrieveAWSKeys} ${AWSDRSName_certificate} > ${CREDENTIAL_DIR}certificate_drs.pem.crt
    	python ${RetrieveAWSKeys} ${AWSDRSName_privatekey} > ${CREDENTIAL_DIR}privateKey_drs.pem.key
    else
    	echo "Mode not supported"
    	exit 1
    fi
# Obtain ZIP package and unzip it locally
    echo ${TestMode}
    echo "[STEP] Obtain ZIP package"
    echo "***************************************************"
    ZIPLocation="./AWSIoTPythonSDK"
    if [ $? -eq "-1" ]; then
    	echo "Cannot find SDK ZIP package"
    	exit 2
    fi
    cp -R ${ZIPLocation} ./test-integration/IntegrationTests/TestToolLibrary/SDKPackage/
# Obtain Python executable

    echo "***************************************************"
    for file in `ls ${TEST_DIR}`
    do
        # if [ ${file}x == "IntegrationTestMQTTConnection.py"x ]; then
        if [ ${file##*.}x == "py"x ]; then
            echo "[SUB] Running test: ${file}..."

            Scale=10
            case "$file" in
                "IntegrationTestMQTTConnection.py") Scale=$2
                ;;
                "IntegrationTestShadow.py") Scale=$3
                ;;
                "IntegrationTestAutoReconnectResubscribe.py") Scale=""
                ;;
                "IntegrationTestProgressiveBackoff.py") Scale=$4
                ;;
                "IntegrationTestConfigurablePublishMessageQueueing.py") Scale=""
                ;;
                "IntegrationTestDiscovery.py") Scale=""
                ;;
                "IntegrationTestAsyncAPIGeneralNotificationCallbacks.py") Scale=""
                ;;
                "IntegrationTestOfflineQueueingForSubscribeUnsubscribe.py") Scale=""
                ;;
                "IntegrationTestClientReusability.py") Scale=""
                ;;
                "IntegrationTestJobsClient.py") Scale=""
            esac

            python ${TEST_DIR}${file} ${TestMode} ${Scale}
            currentTestStatus=$?
            echo "[SUB] Test: ${file} completed. Exiting with status: ${currentTestStatus}"
            if [ ${currentTestStatus} -ne 0 ]; then
                echo "!!!!!!!!!!!!!Test: ${file} in Python version ${iii}.x failed.!!!!!!!!!!!!!"
                exit ${currentTestStatus}
            fi
            echo ""
        fi
    done
    echo "All integration tests passed"
fi
