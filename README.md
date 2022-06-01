# kubernetes-playground

This repository contains the scripts for creating a standalone Kubernetes cluster with one master node and multiple worker nodes. The cluster is not meant to be used for production, but to test distributed applications which require multiple nodes. The cluster is provisioned using Vagrant, VirtualBox, and Ansible.


## Requirements

You will need a Linux or Mac machine with 8 cores and 16Gb RAM.

Install the following tools (you will need admin privileges):

- Docker version 20.10.14 or later

- Vagrant version 2.2.19 or later

- VirtualBox (with extension pack) version 6.1.34 or later

Install the vagrant-disksize plugin:

    vagrant plugin install vagrant-disksize


## Create nodes

Create the nodes of the Kubernetes cluster with the command:

    vagrant --nodes=2 --cpus=2 --memory=4096 --disk=10 up

Wait until the machine are provisioned. You can grab a coffee.

Verify that the nodes are running:

    vagrant status

    Current machine states:

    k8s-master                running (virtualbox)
    k8s-worker-1              running (virtualbox)
    k8s-worker-2              running (virtualbox)

If your host machine has enough resources, you can try with more nodes, cpus, and memory:

    vagrant --nodes=3 --cpus=4 --memory=16384 --disk=40 up


## Install CNI plugin (required)

Open a shell on the master node:

    vagrant ssh k8s-master

Intall Calico with the command:

    calico --install

Wait until Calico has started. Time for a second coffee?

Verify that the nodes are ready:

    kubectl get nodes -o wide

    NAME           STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
    k8s-master     Ready    control-plane   20m     v1.24.1   192.168.56.10   <none>        Ubuntu 20.04.4 LTS   5.4.0-113-generic   cri-o://1.24.0
    k8s-worker-1   Ready    <none>          18m     v1.24.1   192.168.56.11   <none>        Ubuntu 20.04.4 LTS   5.4.0-113-generic   cri-o://1.24.0
    k8s-worker-2   Ready    <none>          10m     v1.24.1   192.168.56.12   <none>        Ubuntu 20.04.4 LTS   5.4.0-113-generic   cri-o://1.24.0

Verify that all pods are running:

    kubectl get pods --all-namespaces

    NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE
    calico-apiserver       calico-apiserver-6d79f588b-5m7ft             1/1     Running   0          39s
    calico-apiserver       calico-apiserver-6d79f588b-7gm49             1/1     Running   0          39s
    calico-system          calico-kube-controllers-68884f975d-22vb2     1/1     Running   0          4m11s
    calico-system          calico-node-cqgng                            1/1     Running   0          4m11s
    calico-system          calico-node-hzcd7                            1/1     Running   0          4m11s
    calico-system          calico-node-szcr9                            1/1     Running   0          4m11s
    calico-system          calico-node-wc88d                            1/1     Running   0          4m11s
    calico-system          calico-typha-8588f6986-t9mz7                 1/1     Running   0          4m11s
    calico-system          calico-typha-8588f6986-wfnbw                 1/1     Running   0          4m2s
    kube-system            coredns-6d4b75cb6d-44sqj                     1/1     Running   0          20m
    kube-system            coredns-6d4b75cb6d-sv7lg                     1/1     Running   0          20m
    kube-system            etcd-k8s-master                              1/1     Running   0          20m
    kube-system            kube-apiserver-k8s-master                    1/1     Running   0          20m
    kube-system            kube-controller-manager-k8s-master           1/1     Running   0          20m
    kube-system            kube-proxy-465fh                             1/1     Running   0          18m
    kube-system            kube-proxy-gbtfv                             1/1     Running   0          10m
    kube-system            kube-proxy-kltht                             1/1     Running   0          20m
    kube-system            kube-proxy-ms5gq                             1/1     Running   0          7m54s
    kube-system            kube-scheduler-k8s-master                    1/1     Running   0          20m
    kube-system            metrics-server-559ddb567b-q24zh              1/1     Running   0          20m
    kubernetes-dashboard   dashboard-metrics-scraper-7bfdf779ff-gtjfh   1/1     Running   0          20m
    kubernetes-dashboard   kubernetes-dashboard-6cdd697d84-797vv        1/1     Running   0          20m
    tigera-operator        tigera-operator-5fb55776df-8849z             1/1     Running   0          4m29s


## Access Kubernetes from any machine

Execute the kubectl command passing the generated kubeconfig:

    kubectl --kubeconfig=admin.conf get pods --all-namespaces


## Enable pods scheduling on Master node (optional)

You will have to modify the node taint to schedule pods on the master node.

Execute this command on the master node:

    schedule-pods --enable


## Expose Kubernetes Dashboard on the Host

Execute this command on the host:

    kubectl --kubeconfig=admin.conf proxy

Execute this command on the master node to get an authentication token:

    dashboard-token

Use the authentication token to access the dashboard:

    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=_all


## Stop nodes

Execute this command on the host to stop the nodes:

    vagrant --nodes=2 halt


## Resume nodes

Execute this command on the host to resume the nodes:

    vagrant --nodes=2 up


## Destroy nodes

Execute this command on the host to destroy the nodes:

    vagrant --nodes=2 destroy -f


## Create the default Storage Class (optional)

You will need a Storage Class to create Persistent Volumes which are mapped to directories of the node.

Create the required resources with the command:

    storage-class --install

The Persistent Volume configuration for a volume on node k8s-worker-1 looks like:

    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: disk1
    spec:
      capacity:
        storage: 5Gi
      accessModes:
      - ReadWriteOnce
      persistentVolumeReclaimPolicy: Retain
      storageClassName: hostpath
      local:
        path: /volumes/disk1
      nodeAffinity:
        required:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
              - k8s-worker-1

Create the volume with the command:

    kubectl create -f volumes.yaml

The persistent volume will be assigned to any pod running on node k8s-worker-1 which has a valid Persistent Volume Claim.


## Deploy the Docker Registry (optional)

You might want to install a Docker Registry if you don't have a registry already that you can use for storing your images.

### Install the Docker Registry

Open a shell on the worker node 1:

    vagrant ssh k8s-worker-1

Install the Docker Registry with the command:

    docker-registry --install

### Push images to the Docker Registry

Add the self-signed certificate docker-registry.crt to your trusted CA list:

    // Linux
    cp docker-registry.crt /etc/docker/certs.d/192.168.56.10:30000/ca.crt

    // MacOS
    security add-trusted-cert -d -r trustRoot -k /Users/$USER/Library/Keychains/login.keychain docker-registry.crt

* You will have to restart Docker for Mac to sync the certificates.

Push a Docker image from the host to the registry:

    docker -t <image>:<version> 192.168.56.10:30000/<image>:<version>
    docker login --username test --password password 192.168.56.10:30000
    docker push 192.168.56.10:30000/<image>:<version>

### Create pull secrets for the Docker Registry

Create secrets for pulling images from the registry:

    kubectl --kubeconfig=admin.conf create secret docker-registry regcred --docker-server=192.168.56.10:30000 --docker-username=test --docker-password=password --docker-email=<your-email>

Configure pull secrets for the default service account:

    kubectl --kubeconfig=admin.conf patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "regcred"}]}'


## Documentation

- https://www.vagrantup.com
- https://www.virtualbox.org
- https://docs.ansible.com/ansible/latest/index.html
- https://docs.ansible.com/ansible/latest/user_guide/playbooks_intro.html
- https://kubernetes.io/docs/home/
