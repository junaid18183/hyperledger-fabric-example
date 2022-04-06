
# This repo installs the HyperLedger Fabric on existing kubernetes.

Check the deploy.sh for steps.
Make sure your cluster has default storage class, otherwise the installation will fail.

Once you run the `deploy.sh` you will have have
- Ordering service with 3 nodes and a CA
- Peer organization with a peer and a CA
- A channel demo
- A fabcar chaincode install in peer0
- A chaincode approved and committed

