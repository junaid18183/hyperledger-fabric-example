#! /bin/bash

echo "Deleting CAs,Peers and OrdererNodes"
kubectl delete fabricorderernodes. --all-namespaces --all
kubectl delete fabricpeers. --all-namespaces --all
kubectl delete fabriccas. --all-namespaces --all

echo "UnInstalling Istio and HLF Operator"
kustomize build base/ | kubectl delete -f -
rm -rf msp keystore