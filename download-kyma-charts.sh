curl https://codeload.github.com/kyma-project/kyma/zip/master --output kyma-master.zip
unzip -qq kyma-master.zip kyma-master/resources/*
rm -rf ./resources
mv kyma-master/resources .
rm -Rf ./kyma-master*
