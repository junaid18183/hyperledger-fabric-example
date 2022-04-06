#! /bin/bash
# set -eu -o pipefail
mkdir -p target

echo "step0 - Installing Istio and HLF Operator"
while ! kustomize build base/ | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done
echo -ne "\n---------------------------------------------------------\n"
sleep 30

echo "Step1 - Deploying a Peer Organization"

echo "Step1a - Deploying a org1-ca"
kubectl apply -f base/peer-organization/org1-ca.yaml
kubectl wait --timeout=180s --for=condition=Running fabriccas org1-ca -n fabric
sleep 30
kubectl hlf ca register --namespace fabric --name=org1-ca --user=peer --secret=peerpw --type=peer  --enroll-id enroll --enroll-secret=enrollpw --mspid Org1MSP || true
# In above command the options need to match with added in base/peer-organization/org1-ca.yaml

echo "Step1b - Deploying a peer"
# kubectl apply -f base/peer-organization/org1-peer0.yaml
# Commenting as the CA cert changes each time and nodeport as well. So rathe using the direct command
kubectl hlf peer create --namespace fabric --image=quay.io/kfsoftware/fabric-peer --version=2.4.1-v0.0.3 --enroll-id=peer --mspid=Org1MSP --enroll-pw=peerpw --capacity=5Gi --name=org1-peer0 --ca-name=org1-ca.fabric --statedb=couchdb 
kubectl wait --timeout=180s --for=condition=Running fabricpeers --all -n fabric

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step2 - Deploying an Ordering Service"

echo "Step2a - Deploying a ord1-ca"
kubectl apply -f base/ordering-service/ord-ca.yaml
kubectl wait --timeout=180s --for=condition=Running fabriccas org1-ca -n fabric
sleep 30

kubectl hlf ca register --namespace fabric --name=ord-ca --user=orderer --secret=ordererpw --type=orderer --enroll-id enroll --enroll-secret=enrollpw --mspid=OrdererMSP || true 
# In above command the options need to match with added in base/ordering-service/ord-ca.yaml

echo "Step2b - Deploying the Orderer node"
# kubectl apply -f base/ordering-service/ord-node1.yaml
# Commenting as the CA cert changes each time and nodeport as well. So rathe using the direct command
kubectl hlf ordnode create --namespace fabric --image=hyperledger/fabric-orderer --version=2.4.1 --enroll-id=orderer --mspid=OrdererMSP --enroll-pw=ordererpw --capacity=2Gi --name=ord-node1 --ca-name=ord-ca.fabric
kubectl wait --timeout=180s --for=condition=Running fabricorderernodes.hlf.kungfusoftware.es --all -n fabric

echo "Step2c - Preparing a connection string for the ordering service"
kubectl hlf inspect --output target/ordservice.yaml -o OrdererMSP
kubectl hlf ca register --namespace fabric  --name=ord-ca --user=admin --secret=adminpw --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid=OrdererMSP
kubectl hlf ca enroll --namespace fabric --name=ord-ca --user=admin --secret=adminpw --mspid OrdererMSP --ca-name ca  --output target/admin-ordservice.yaml

kubectl hlf utils adduser --userPath=target/admin-ordservice.yaml --config=target/ordservice.yaml --username=admin --mspid=OrdererMSP


echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step3 - Creating a channel"
kubectl hlf channel generate --output=target/demo.block --name=demo --organizations Org1MSP --ordererOrganizations OrdererMSP
echo "enroll using the TLS CA"
kubectl hlf ca enroll --namespace=fabric --name=ord-ca  --user=admin --secret=adminpw --mspid OrdererMSP --ca-name tlsca  --output target/admin-tls-ordservice.yaml

kubectl hlf ordnode join --block=target/demo.block --name=ord-node1 --namespace=fabric --identity=target/admin-tls-ordservice.yaml

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step4 - Preparing a connection string for the peer"

kubectl hlf ca register --namespace fabric --name=org1-ca --user=admin --secret=adminpw --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid Org1MSP 
kubectl hlf ca enroll --namespace fabric --name=org1-ca --user=admin --secret=adminpw --mspid Org1MSP --ca-name ca  --output target/peer-org1.yaml
kubectl hlf inspect --output target/org1.yaml -o Org1MSP -o OrdererMSP
echo "add user key and cert to org1.yaml from admin-ordservice.yaml"
kubectl hlf utils adduser --userPath=target/peer-org1.yaml --config=target/org1.yaml --username=admin --mspid=Org1MSP

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step5 - Join channel"
kubectl hlf channel join --name=demo --config=target/org1.yaml --user=admin -p=org1-peer0.fabric

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step6 - Inspect the channel"
kubectl hlf channel inspect --channel=demo --config=target/org1.yaml --user=admin -p=org1-peer0.fabric > target/channel-demo.json
ls -l target/channel-demo.json

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step7 - Add anchor peer"
kubectl hlf channel addanchorpeer --channel=demo --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric 

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step8 - See ledger height."
#kubectl hlf channel top --channel=demo --config=target/org1.yaml --user=admin -p=org1-peer0.fabric
# This command does not terminate until you hit ctrl+c so commenting this out

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step9 - Install a chaincode. This can take 3-4 minutes"
kubectl hlf chaincode install --path=./sample_chaincodes/fabcar/go/ --config=target/org1.yaml --language=golang --label=fabcar --user=admin --peer=org1-peer0.fabric

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step10 - Query chaincodes installed"
kubectl hlf chaincode queryinstalled --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric

echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step11 - Approve chaincode"

PACKAGE_ID=$(kubectl hlf chaincode queryinstalled --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric | grep fabcar | awk '{print $1}')
kubectl hlf chaincode approveformyorg --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric --package-id=$PACKAGE_ID --version "1.0" --sequence 1 --name=fabcar --policy="OR('Org1MSP.member')" --channel=demo
echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step12 - Commit chaincode"
kubectl hlf chaincode commit --config=target/org1.yaml --user=admin --mspid=Org1MSP --version "1.0" --sequence 1 --name=fabcar --policy="OR('Org1MSP.member')" --channel=demo
echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step13 - Invoke a transaction in the ledger"
kubectl hlf chaincode invoke --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric --chaincode=fabcar --channel=demo --fcn=initLedger -a '[]'
echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Step14 - Query the ledger"
kubectl hlf chaincode query --config=target/org1.yaml --user=admin --peer=org1-peer0.fabric --chaincode=fabcar --channel=demo --fcn=QueryAllCars -a '[]'
echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo " With this now you have - 
- Ordering service with 3 nodes and a CA
- Peer organization with a peer and a CA
- A channel demo
- A fabcar chaincode install in peer0
- A chaincode approved and committed
"

kubectl get fabriccas -n fabric
kubectl get fabricpeers -n fabric
kubectl get fabricorderernodes -n fabric 
echo -ne "\n---------------------------------------------------------\n"
sleep 30
echo "Cleaning not needed files"
rm -rf msp keystore
