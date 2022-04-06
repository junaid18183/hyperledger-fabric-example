kubectl hlf ca create --namespace fabric --capacity=2Gi --name=ord-ca --enroll-id=enroll --enroll-pw=enrollpw -o > ord-ca.yaml

kubectl hlf ca register --namespace fabric --name=ord-ca --user=orderer --secret=ordererpw --type=orderer --enroll-id enroll --enroll-secret=enrollpw --mspid=OrdererMSP

kubectl hlf ordnode create --namespace fabric --image=hyperledger/fabric-orderer --version=2.4.1 --enroll-id=orderer --mspid=OrdererMSP --enroll-pw=ordererpw --capacity=2Gi --name=ord-node1 --ca-name=ord-ca.fabric  -o > ord-node1.yaml

kubectl wait --timeout=180s --for=condition=Running fabricorderernodes.hlf.kungfusoftware.es --all -n fabric

hlf inspect --output ordservice.yaml -o OrdererMSP
kubectl hlf ca register --namespace fabric  --name=ord-ca --user=admin --secret=adminpw --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid=OrdererMSP
kubectl hlf ca enroll --namespace fabric --name=ord-ca --user=admin --secret=adminpw --mspid OrdererMSP --ca-name ca  --output target/admin-ordservice.yaml
kubectl hlf utils adduser --userPath=target/admin-ordservice.yaml --config=target/ordservice.yaml --username=admin --mspid=OrdererMSP