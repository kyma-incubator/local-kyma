curl https://codeload.github.com/kyma-project/kyma/zip/master --output kyma-master.zip
unzip kyma-master.zip kyma-master/resources/*
mv kyma-master/resources .
rm -Rf ./kyma-master*
# This file will be created by cert-manager (not needed anymore):
rm resources/core/charts/gateway/templates/kyma-gateway-certs.yaml

