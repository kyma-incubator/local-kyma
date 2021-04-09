REPO=${1:-kyma-project/kyma}
BRANCH=${2:-main}
curl -s https://codeload.github.com/${REPO}/zip/${BRANCH} --output kyma-src.zip
unzip --qq -d ./tmp kyma-src.zip
rm -rf ./resources
mv ./tmp/*/resources ./
rm -rf ./tests
mkdir ./tests
mv ./tmp/*/tests/fast-integration ./tests
rm -rf ./tmp
