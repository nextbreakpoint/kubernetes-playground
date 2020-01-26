# kubernetes-playground

Create a standalone Kubernetes cluster with one master node and two worker nodes using Vagrant and Ansible.

Learn how to create a private Docker Registry and how to deploy Kafka, Zookeeper and Flink using Helm charts.

## Before you start

Download and install Vagrant. I am using version 2.2.6.

Download and install VirtualBox (with extension pack). I am using version 6.0.14.

I tested my scripts on Mac, but the process should be the same on Linux. Not sure about Windows.

## Install plugins (optional)

Install the vagrant-disksize plugin if you want to configure the disk size (default is 20Gb):

    vagrant plugin install vagrant-disksize

## Create nodes

Create and start the nodes:

    vagrant up

Verify that the nodes are running:

    vagrant status k8s1 k8s2 k8s3

## Connect to master node

Open a shell on the master node:

    vagrant ssh k8s1

## Install CNI plugin (required)

Execute script on master node:

    start-calico

## Verify nodes are ready

Execute command on master node:

    kubectl get nodes

    NAME   STATUS   ROLES    AGE     VERSION
    k8s1   Ready    master   66m     v1.17.0
    k8s2   Ready    <none>   60m     v1.17.0
    k8s3   Ready    <none>   58m     v1.17.0

## Create the default Storage Class

Execute script on master node:

    create-storage-class

A Storage Class is required in order to create Persistent Volumes which live on cluster nodes.

A Persistent Volume configuration for creating a volume on node k8s1 looks like:

    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: local-pv-k8s1-1
    spec:
      capacity:
        storage: 5Gi
      accessModes:
      - ReadWriteOnce
      persistentVolumeReclaimPolicy: Retain
      storageClassName: hostpath
      local:
        path: /var/tmp/disk1
      nodeAffinity:
        required:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
              - k8s1

Create the volume with the command:

    kubectl create -f pv-k8s1-1.yaml

The persistent volume will be assigned to any pod requesting a volume with a Persistent Volume Claim and running on node k8s1.

## Verify pods are running

Execute command on master node:

    kubectl get pods --all-namespaces

    NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE
    kube-system            calico-kube-controllers-7489ff5b7c-dqq85     1/1     Running   0          70s
    kube-system            calico-node-lxvr2                            1/1     Running   0          70s
    kube-system            calico-node-skn8v                            1/1     Running   0          70s
    kube-system            calico-node-txsmg                            1/1     Running   0          70s
    kube-system            coredns-6955765f44-42vtc                     1/1     Running   0          4m55s
    kube-system            coredns-6955765f44-b5265                     1/1     Running   0          4m55s
    kube-system            etcd-k8s1                                    1/1     Running   0          5m12s
    kube-system            kube-apiserver-k8s1                          1/1     Running   0          5m12s
    kube-system            kube-controller-manager-k8s1                 1/1     Running   0          5m12s
    kube-system            kube-proxy-9klvv                             1/1     Running   0          83s
    kube-system            kube-proxy-b249l                             1/1     Running   0          4m55s
    kube-system            kube-proxy-ncdx2                             1/1     Running   0          3m5s
    kube-system            kube-scheduler-k8s1                          1/1     Running   0          5m12s
    kube-system            metrics-server-577d4c46bb-n99rg              1/1     Running   0          4m55s
    kubernetes-dashboard   dashboard-metrics-scraper-566cddb686-hfmxd   1/1     Running   0          4m55s
    kubernetes-dashboard   kubernetes-dashboard-7b5bf5d559-xxbqb        1/1     Running   0          4m55s

## Get token for accessing Dashboard

Execute script on master node and get token from output:

    dashboard-token

## Expose Dashboard on host

Execute script on host:

    kubectl --kubeconfig=admin.conf proxy

Open browser at address and login using dashboard token:

    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=default

## Enable pods scheduling on Master node (optional)

Execute script on master node to run pods on master node:

    taint-nodes

## Stop nodes

Execute command on host:

    vagrant halt

## Resume nodes

Execute command on host:

    vagrant up

## Remove nodes (if not required anymore)

Execute command on host:

    vagrant destroy -f

## Create local Docker Registry

Execute script on master node:

    docker-registry-create

## Delete local Docker Registry

Execute script on master node:

    docker-registry-delete

## Push images to local Docker Registry

Add the self-signed certificate docker-registry.crt to your trusted CA list.

    // Linux
    cp docker-registry.crt /etc/docker/certs.d/192.168.1.11:30000/ca.crt

    // MacOS - Restart Docker for Mac after adding the certificate!!!
    sudo security add-trusted-cert -d -r trustRoot -k /Users/$USER/Library/Keychains/login.keychain docker-registry.crt

Push Docker image from host with commands:

    docker -t <image>:<version> 192.168.1.11:30000/<image>:<version>
    docker login --username test --password password 192.168.1.11:30000
    docker push 192.168.1.11:30000/<image>:<version>

## Create Pull Secrets for local Docker Registry

Create secrets for pulling images from local Docker Registry:

    kubectl create secret docker-registry regcred --docker-server=192.168.1.11:30000 --docker-username=test --docker-password=password --docker-email=<your-email>

## Deploy Kafka, Zookeeper and Flink using Helm

The directory charts contains Helm charts for Kafka, Zookeeper, and Flink.

The charts depends on Docker images which must be created before installing the charts.

Create Docker images for Kafka, Zookeeper, and Flink:

    ./build-images.sh

Install Kafka, Zookeeper, and Flink charts:

    helm install zookeeper charts/zookeeper
    helm install kafka charts/kafka
    helm install flink charts/flink

Delete Kafka, Zookeeper, and Flink charts:

    helm uninstall zookeeper
    helm uninstall kafka
    helm uninstall flink

## Credits

https://github.com/davidkbainbridge/k8s-playground
