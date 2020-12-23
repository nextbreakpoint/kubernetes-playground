# kubernetes-playground

Create a standalone Kubernetes cluster with one master node and two worker nodes using Vagrant and Ansible.

Learn how to create a private Docker Registry and how to deploy Kafka, Zookeeper and Flink using Helm charts.

The installed version of Kubernetes is 1.20, but it can be changed in the Ansible script if needed.

## Before you start

Download and install Vagrant. I am using version 2.2.14.

Download and install VirtualBox (with extension pack). I am using version 6.1.16.

I tested my scripts on Mac, but the process should be the same on Linux. Not sure about Windows.

## Install plugins

Install the vagrant-disksize plugin:

    vagrant plugin install vagrant-disksize

## Create nodes

Create and start the nodes:

    vagrant up

Verify that the nodes are running:

    vagrant status k8s1 k8s2 k8s3

Open a shell on the master node:

    vagrant ssh k8s1

You will need the shell to complete the setup.

## Install CNI plugin (required)

Execute script on master node:

    start-calico

## Verify nodes are ready

Execute command on master node:

    kubectl get nodes -o wide

    NAME   STATUS   ROLES                  AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
    k8s1   Ready    control-plane,master   6m7s    v1.20.0   192.168.1.11   <none>        Ubuntu 16.04.7 LTS   4.4.0-197-generic   docker://20.10.0
    k8s2   Ready    <none>                 3m51s   v1.20.0   192.168.1.12   <none>        Ubuntu 16.04.7 LTS   4.4.0-197-generic   docker://20.10.0
    k8s3   Ready    <none>                 2m2s    v1.20.0   192.168.1.13   <none>        Ubuntu 16.04.7 LTS   4.4.0-197-generic   docker://20.10.0

## Create the default Storage Class

Execute script on master node:

    create-storage-class

A Storage Class is required in order to create Persistent Volumes which are mapped to directories of the node.

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

The persistent volume will be assigned to any pod running on node k8s1 which requests a volume with a Persistent Volume Claim.

## Verify pods are running

Execute command on master node:

    kubectl get pods --all-namespaces

    NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE
    kube-system            calico-kube-controllers-744cfdf676-m4s4s     1/1     Running   0          84s
    kube-system            calico-node-8gpcx                            1/1     Running   0          84s
    kube-system            calico-node-8m49s                            1/1     Running   0          84s
    kube-system            calico-node-bnkxn                            1/1     Running   0          84s
    kube-system            coredns-74ff55c5b-qzg58                      1/1     Running   0          5m29s
    kube-system            coredns-74ff55c5b-rjswg                      1/1     Running   0          5m29s
    kube-system            etcd-k8s1                                    1/1     Running   0          5m42s
    kube-system            kube-apiserver-k8s1                          1/1     Running   0          5m42s
    kube-system            kube-controller-manager-k8s1                 1/1     Running   0          5m42s
    kube-system            kube-proxy-k9cdk                             1/1     Running   0          100s
    kube-system            kube-proxy-mc7px                             1/1     Running   0          3m29s
    kube-system            kube-proxy-qbl7z                             1/1     Running   0          5m29s
    kube-system            kube-scheduler-k8s1                          1/1     Running   0          5m42s
    kube-system            metrics-server-bc4467d77-mh2zl               1/1     Running   0          5m29s
    kubernetes-dashboard   dashboard-metrics-scraper-79c5968bdc-kqvb6   1/1     Running   0          5m29s
    kubernetes-dashboard   kubernetes-dashboard-7448ffc97b-pj2cd        1/1     Running   0          5m29s

## Access Kubernetes cluster from host

Execute kubectl command passing kubeconfig:

    kubectl --kubeconfig=admin.conf get pods --all-namespaces

## Enable pods scheduling on Master node (optional)

Modify nodes taint to enable pods scheduling on master node:

    taint-nodes

## Get token for accessing Dashboard

Execute script on master node and get authentication token:

    dashboard-token

## Expose Dashboard on host

Execute script on host:

    kubectl --kubeconfig=admin.conf proxy

Use authentication token to access dashboard:

    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=default

## Stop nodes

Execute command on host:

    vagrant halt

## Resume nodes

Execute command on host:

    vagrant up

## Destroy nodes

Execute command on host:

    vagrant destroy -f

## Create local Docker Registry

Please enable pods scheduling on master node.

Execute script on master node:

    docker-registry-create

## Delete local Docker Registry

Execute script on master node:

    docker-registry-delete

## Push images to local Docker Registry

Add the self-signed certificate docker-registry.crt to your trusted CA list.

    // Linux
    cp docker-registry.crt /etc/docker/certs.d/192.168.1.11:30000/ca.crt

    // MacOS - Docker for Mac
    security add-trusted-cert -d -r trustRoot -k /Users/$USER/Library/Keychains/login.keychain docker-registry.crt

You will have to restart Docker for Mac to sync the certificates.

Push Docker image from host with commands:

    docker -t <image>:<version> 192.168.1.11:30000/<image>:<version>
    docker login --username test --password password 192.168.1.11:30000
    docker push 192.168.1.11:30000/<image>:<version>

## Create Pull Secrets for local Docker Registry

Create secrets for pulling images from local Docker Registry:

    kubectl --kubeconfig=admin.conf create secret docker-registry regcred --docker-server=192.168.1.11:30000 --docker-username=test --docker-password=password --docker-email=<your-email>

Configure pull secrets for default service account:

    kubectl --kubeconfig=admin.conf patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "regcred"}]}'

## Deploy Kafka, Zookeeper and Flink using Helm

The directory charts contains Helm charts for Kafka, Zookeeper, and Flink.

The charts depends on Docker images which must be created before installing the charts.

Create Docker images for Kafka, Zookeeper, and Flink:

    ./build-images.sh

Install Kafka, Zookeeper, and Flink charts:

    helm --kubeconfig=admin.conf install zookeeper charts/zookeeper
    helm --kubeconfig=admin.conf install kafka charts/kafka
    helm --kubeconfig=admin.conf install flink charts/flink

Delete Kafka, Zookeeper, and Flink charts:

    helm --kubeconfig=admin.conf uninstall zookeeper
    helm --kubeconfig=admin.conf uninstall kafka
    helm --kubeconfig=admin.conf uninstall flink

## Credits

This work is partially based on:
https://github.com/davidkbainbridge/k8s-playground
