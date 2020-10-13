#!/bin/bash
set -o errexit

case `uname` in
    "Darwin")
        curl -L https://github.com/istio/istio/releases/download/1.5.10/istioctl-1.5.10-osx.tar.gz --output istioctl-1.5.10-osx.tar.gz
        tar xvzf istioctl-1.5.10-osx.tar.gz
        rm istioctl-1.5.10-osx.tar.gz
        ;;
    "Linux")
        curl -L https://github.com/istio/istio/releases/download/1.5.10/istioctl-1.5.10-linux.tar.gz --output istioctl-1.5.10-linux.tar.gz
        tar xvzf istioctl-1.5.10-linux.tar.gz
        rm istioctl-1.5.10-linux.tar.gz
        ;;
esac