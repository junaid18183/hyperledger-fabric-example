kubectl hlf ca create --capacity=2Gi --name=org1-ca --enroll-id=enroll --enroll-pw=enrollpw --namespace fabric -o > org1-ca.yaml
kubectl hlf ca register --namespace fabric --name=org1-ca --user=peer --secret=peerpw --type=peer  --enroll-id enroll --enroll-secret=enrollpw --mspid Org1MSP

kubectl hlf peer create --namespace fabric --image=quay.io/kfsoftware/fabric-peer --version=2.4.1-v0.0.3 --enroll-id=peer --mspid=Org1MSP --enroll-pw=peerpw --capacity=5Gi --name=org1-peer0 --ca-name=org1-ca.fabric --statedb=couchdb  -o > org1-peer0.yaml