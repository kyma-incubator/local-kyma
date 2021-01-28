REPO=${1:-kyma-project/kyma}
BRANCH=${2:-master}
curl -s https://codeload.github.com/${REPO}/zip/${BRANCH} --output kyma-src.zip
unzip --qq -d ./tmp kyma-src.zip
rm -rf ./resources
mv ./tmp/*/resources ./
rm -rf ./fast-integration
mv ./tmp/*/tests/fast-integration ./
rm -rf ./tmp
