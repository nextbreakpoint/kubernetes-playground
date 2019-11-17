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
    k8s1   Ready    master   66m   v1.16.2
    k8s2   Ready    <none>   60m   v1.16.2
    k8s3   Ready    <none>   58m   v1.16.2

## Install Tiller (optional, required for using Helm)

Execute script on master node:

    start-tiller

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
    kube-system            calico-kube-controllers-6d85fdfbd8-vj8h4     1/1     Running   0          54m
    kube-system            calico-node-95lgg                            1/1     Running   0          54m
    kube-system            calico-node-b4mww                            1/1     Running   0          54m
    kube-system            calico-node-kmj9p                            1/1     Running   0          54m
    kube-system            coredns-5644d7b6d9-hdjdn                     1/1     Running   0          63m
    kube-system            coredns-5644d7b6d9-thlbt                     1/1     Running   0          63m
    kube-system            etcd-k8s1                                    1/1     Running   0          62m
    kube-system            kube-apiserver-k8s1                          1/1     Running   0          62m
    kube-system            kube-controller-manager-k8s1                 1/1     Running   0          62m
    kube-system            kube-proxy-ncn8b                             1/1     Running   0          56m
    kube-system            kube-proxy-p5tnv                             1/1     Running   0          63m
    kube-system            kube-proxy-pkf9w                             1/1     Running   0          58m
    kube-system            kube-scheduler-k8s1                          1/1     Running   0          62m
    kube-system            metrics-server-7777f7fc4c-bg72x              1/1     Running   0          21m
    kube-system            tiller-deploy-684c9f98f5-wmdm8               1/1     Running   0          52m
    kubernetes-dashboard   dashboard-metrics-scraper-566cddb686-q5n78   1/1     Running   0          63m
    kubernetes-dashboard   kubernetes-dashboard-7b5bf5d559-tgvck        1/1     Running   0          63m

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

    helm install --name zookeeper charts/zookeeper
    helm install --name kafka charts/kafka
    helm install --name flink charts/flink

Delete Kafka, Zookeeper, and Flink charts:

    helm delete --purge zookeeper
    helm delete --purge kafka
    helm delete --purge flink

## Credits

https://github.com/davidkbainbridge/k8s-playground
