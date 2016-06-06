# Kubernetes-on-Fedora-Atomic-on-KVM

This Howto is an attempt to replicate a would-be bare-metal installation. This is done on KVM (not on AWS or GCE).

* Our domain for infrastructure hosts: example.com
* kube-master 192.168.124.10
* kube-node1: 192.168.124.11
* kube-node2: 192.168.124.12


Following : [http://www.projectatomic.io/docs/quickstart/](http://www.projectatomic.io/docs/quickstart/)

## Login problem
The login to console still does not work properly, even though we have password stored in the user-data file in cloud-init. However since I put my SSH key in it, it is able to login through SSH. Though I have to find the IP address it obtained from the network.

TODO: Improve console login, using: 
* [https://coreos.com/os/docs/latest/cloud-config.html](https://coreos.com/os/docs/latest/cloud-config.html)
* [https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting](https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting)

```
[root@kworkhorse ~]# nmap -sP 192.168.124.0/24

Starting Nmap 7.12 ( https://nmap.org ) at 2016-06-02 14:09 CEST
Nmap scan report for 192.168.124.58
Host is up (0.00019s latency).
MAC Address: 52:54:00:05:BB:EA (QEMU virtual NIC)
Nmap scan report for 192.168.124.1
Host is up.
Nmap done: 256 IP addresses (2 hosts up) scanned in 2.54 seconds
[root@kworkhorse ~]# 
```

```
[kamran@kworkhorse fedora-atomic-cloud-init]$ ssh fedora@192.168.124.58
The authenticity of host '192.168.124.58 (192.168.124.58)' can't be established.
ECDSA key fingerprint is SHA256:Z619UHp/qO+N6Fk9AFumxaKtt9G0VV8peFzTu+yyzyQ.
ECDSA key fingerprint is MD5:af:a7:66:84:aa:8b:8f:9d:3a:fb:4a:dd:c6:b0:28:c6.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.124.58' (ECDSA) to the list of known hosts.
[fedora@localhost ~]$ 
``` 

After, logging in through SSH, I notice that the password to fedora is not assigned:

```
[fedora@localhost ~]$ sudo -i
-bash-4.3# cat /etc/shadow

root:!locked::0:99999:7:::
bin:*:16854:0:99999:7:::
daemon:*:16854:0:99999:7:::
adm:*:16854:0:99999:7:::
lp:*:16854:0:99999:7:::
sync:*:16854:0:99999:7:::
shutdown:*:16854:0:99999:7:::
halt:*:16854:0:99999:7:::
mail:*:16854:0:99999:7:::
operator:*:16854:0:99999:7:::
games:*:16854:0:99999:7:::
ftp:*:16854:0:99999:7:::
nobody:*:16854:0:99999:7:::
fedora:!!:16954:0:99999:7:::
-bash-4.3# 
```

Anyway, moving on.

# Prepare host:
* Assign proper hostname (kube-master.example.com)
* Assign proper IP (192.168.124.10)
* Disable SELinux (/etc/selinux/config)
* Setup SSH key in root user's authorized_keys file. (This is not necessary if you plan to setup the cluster by hand). Also not necessary if you are happy to include a "sudo" with every command you want to execute on the cluster nodes.

```
[fedora@kube-master ~]$ sudo cp /home/fedora/.ssh/authorized_keys /root/.ssh/authorized_keys
```
* Update OS (# rpm-ostree upgrade)
* Optional: Change boot order in KVM. (Not necessary). Note: DO NOT remove CDROM device. (This will result in the node taking too long to boot - at all !)
* Reboot




# Setup Kubernetes related services on Master and worker nodes
Reference: [http://www.projectatomic.io/docs/gettingstarted/](http://www.projectatomic.io/docs/gettingstarted/)
Also: [https://github.com/Praqma/LearnKubernetes/blob/master/kamran/Kubernetes-Atomic-on-Amazon-VPC.md](https://github.com/Praqma/LearnKubernetes/blob/master/kamran/Kubernetes-Atomic-on-Amazon-VPC.md)


## Create Local Docker Registry on Master:
TODO: Fill up here from the other Howto.


# Setup etcd on Master
Todo: fill up from other howto.

## Setup Kubernetes sub-components on master:

* config
* apiserver


## Enable and start the Kubernetes services on Master

## Configure flanel overlay network on Master

## Configure SkyDNS on Master

Reference: [https://github.com/kubernetes/kubernetes/blob/release-1.2/cluster/addons/dns/README.md#how-do-i-configure-it](https://github.com/kubernetes/kubernetes/blob/release-1.2/cluster/addons/dns/README.md#how-do-i-configure-it)

You will need to modify the kubelet config on each node to add the cluster DNS settings and restart before setting up any of your pods/deployments/services.

The easiest way to use DNS is to use a supported kubernetes cluster setup, which should have the required logic to read some config variables and plumb them all the way down to kubelet.

Supported environments offer the following config flags, which are used at cluster turn-up to create the SkyDNS pods and configure the kubelets. For example, see cluster/gce/config-default.sh.

```
ENABLE_CLUSTER_DNS="${KUBE_ENABLE_CLUSTER_DNS:-true}"
DNS_SERVER_IP="10.254.0.10"
DNS_DOMAIN="cluster.local"
DNS_REPLICAS=1
``` 

Note: Our ServiceAddresses are in the range 10.254.0.0/16 . So I changed the IP of the DNS from 10.0.0.10 (from example) to 10.254.0.10 to use in this cluster.

This enables DNS with a DNS Service IP of 10.254.0.10 and a local domain of cluster.local, served by a single copy of SkyDNS.

If you are not using a supported cluster setup, you will have to replicate some of this yourself. First, each kubelet needs to run with the following flags set (in config file):

```
--cluster-dns=<DNS service ip>
--cluster-domain=<default local domain>
```

Second, you need to start the DNS server ReplicationController and Service. 

We will use the example files (ReplicationController and Service), but keep in mind that these are templated for Salt. You will need to replace the {{ <param> }} blocks with your own values for the config variables mentioned above. Other than the templating, these are normal kubernetes objects, and can be instantiated with kubectl create.

Try not to mess with apiversion v1 and the kind ReplicationContoller. I tried to convert it to a Deployment, but did not success. This needs to be attended in future.

Also, May be we can change the namespace from kube-system to default. It is very easy to forget to include all namespaces in the kubectl commands and then panicing! 

```
[fedora@kube-master ~]$ cat skydns-rc.yaml 
apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v11
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    version: v11
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-dns
    version: v11
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v11
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: etcd
        image: gcr.io/google_containers/etcd-amd64:2.2.1
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 50Mi
        command:
        - /usr/local/bin/etcd
        - -data-dir
        - /var/etcd/data
        - -listen-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -advertise-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -initial-cluster-token
        - skydns-etcd
        volumeMounts:
        - name: etcd-storage
          mountPath: /var/etcd/data
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            # Kube2sky watches all pods.
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain= "cluster.local"
      - name: skydns
        image: gcr.io/google_containers/skydns:2015-10-13-8c72f8c
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/skydns"
        - -machines=http://127.0.0.1:4001
        - -addr=0.0.0.0:53
        - -ns-rotate=false
        - -domain="cluster.local."
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
      - name: healthz
        image: gcr.io/google_containers/exechealthz:1.0
        resources:
          # keep request = limit to keep this container in guaranteed class
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
        args:
        - -cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
        - -port=8080
        ports:
        - containerPort: 8080
          protocol: TCP
      volumes:
      - name: etcd-storage
        emptyDir: {}
      dnsPolicy: Default  # Don't use cluster DNS.
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ cat skydns-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP:  10.254.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
[fedora@kube-master ~]$ 
```

Now create the SkyDNS ReplicationController and Service. 

```
[fedora@kube-master ~]$ kubectl create -f ./skydns-rc.yaml 
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$

[fedora@kube-master ~]$ kubectl get rc --namespace=kube-system
NAME           DESIRED   CURRENT   AGE
kube-dns-v11   1         1         28s
[fedora@kube-master ~]$ 



```


```
[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system
NAME                        READY     STATUS    RESTARTS   AGE
kube-dns-v11-8k61o          3/4       Running   1          2m
[fedora@kube-master ~]$ 
```

Create the service fr skyDNS:

```
[fedora@kube-master ~]$ kubectl create -f ./skydns-svc.yaml 
service "kube-dns" created
[fedora@kube-master ~]$ 
``` 

```
[fedora@kube-master ~]$ kubectl get service  --namespace=kube-system
NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
kube-dns     10.254.0.10     <none>        53/UDP,53/TCP   4s
[fedora@kube-master ~]$ 
```


Alternate way (from CoreOS guide):

Create the file dns-addon-coreos.yaml:
(It is actually creating 2 different Kubernetes objects, separated by ---.)

```
[fedora@kube-master ~]$ cat dns-addon-coreos.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.254.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP

---

apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v11
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    version: v11
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-dns
    version: v11
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v11
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: etcd
        image: gcr.io/google_containers/etcd-amd64:2.2.1
        resources:
          limits:
            cpu: 100m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 50Mi
        command:
        - /usr/local/bin/etcd
        - -data-dir
        - /var/etcd/data
        - -listen-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -advertise-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -initial-cluster-token
        - skydns-etcd
        volumeMounts:
        - name: etcd-storage
          mountPath: /var/etcd/data
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain=cluster.local
      - name: skydns
        image: gcr.io/google_containers/skydns:2015-10-13-8c72f8c
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/skydns"
        - -machines=http://127.0.0.1:4001
        - -addr=0.0.0.0:53
        - -ns-rotate=false
        - -domain=cluster.local.
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
      - name: healthz
        image: gcr.io/google_containers/exechealthz:1.0
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
        args:
        - -cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
        - -port=8080
        ports:
        - containerPort: 8080
          protocol: TCP
      volumes:
      - name: etcd-storage
        emptyDir: {}
      dnsPolicy: Default
[fedora@kube-master ~]$ 

```


```
[fedora@kube-master ~]$ kubectl create -f dns-addon-coreos.yaml 
service "kube-dns" created
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system | grep kube-dns-v11
kube-dns-v11-7gjrz   3/4       Running   2          3m
[fedora@kube-master ~]$ 
```
There should be total of four containers running in the kube-dns-v11 pod, whereas there are only 3/4 running.There seems to be a problem.


Test by running a busybox container:
```
[fedora@kube-master ~]$ kubectl exec busybox -i -t -- sh


/ # nslookup kubernetes
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes'
/ # 



/ # nslookup yahoo.com
Server:    10.254.0.10
Address 1: 10.254.0.10

Name:      yahoo.com
Address 1: 2001:4998:c:a06::2:4008 ir1.fp.vip.gq1.yahoo.com
Address 2: 2001:4998:44:204::a7 ir1.fp.vip.ne1.yahoo.com
Address 3: 2001:4998:58:c02::a9 ir1.fp.vip.bf1.yahoo.com
Address 4: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 5: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
Address 6: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
/ # 

```
There seems to be some problem. resolving yahoo.com takes forever. While the name kubernetes does not resolv at all! 




## Modify kubectl (config) to use skyDNS:

On all worker nodes:
```
-bash-4.3# vi /etc/kubernetes/kubelet 
KUBELET_ADDRESS="--address=192.168.124.11"
KUBELET_HOSTNAME="--hostname-override=192.168.124.11"
KUBELET_API_SERVER="--api-servers=http://192.168.124.10:8080"
KUBELET_ARGS="--cluster-dns=10.254.0.10  --cluster-domain=cluster.local"
```


Restart the kubelet service on each worker node:

```
service kubelet restart
``` 

Check status of the service. Look for the parameters/arguments you specified in the kubelet config file. They should appear in the output.

```
-bash-4.3# service kubelet status -l
Redirecting to /bin/systemctl status  -l kubelet.service
● kubelet.service - Kubernetes Kubelet Server
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2016-06-06 12:16:43 UTC; 24s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 20702 (kubelet)
   Memory: 13.1M
      CPU: 429ms
   CGroup: /system.slice/kubelet.service
           ├─20702 /usr/bin/kubelet --logtostderr=true --v=0 --api-servers=http://192.168.124.10:8080 --address=192.168.124.11 --hostname-override=192.168.124.11 --allow-privileged=false --cluster-dns=10.254.0.10 --cluster-domain=cluster.local
           └─20738 journalctl -k -f

Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.658991   20702 server.go:109] Starting to listen on 192.168.124.11:10250
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.905557   20702 kubelet.go:1150] Node 192.168.124.11 was previously registered
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.976992   20702 factory.go:233] Registering Docker factory
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.977742   20702 factory.go:97] Registering Raw factory
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.100328   20702 manager.go:1003] Started watching for new ooms in manager
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.102218   20702 oomparser.go:182] oomparser using systemd
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.102584   20702 manager.go:256] Starting recovery of all containers
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.209300   20702 manager.go:261] Recovery completed
-bash-4.3# 
```

You need to recreate your pods after you setup SkyDNS, because they (pods) still don't know abot the new DNS service. Since kubelet service is restarted on the nodes, when new pods are created, kubelet will inject the DNS information in the pods (so to speak).



Now lets login to a container and see if it can see and use our DNS:

```
[fedora@kube-master ~]$ kubectl exec my-nginx-3800858182-3fs4y -i -t -- bash
```

Notice that our DNS is the first one listed in the container's /etc/resolv.conf:
```
root@my-nginx-3800858182-3fs4y:/# cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local example.com
nameserver 10.254.0.10
nameserver 192.168.124.1
options ndots:5
root@my-nginx-3800858182-3fs4y:/#
```


## Problem running skydns and solution:

SkyDNS is not working properly. So troubleshooting is as follows:

I see the following:


First, the state of RC, SVC and pods:


```
[fedora@kube-master ~]$ kubectl logs  kube-dns-v11-7gjrz kube2sky  --namespace=kube-system 
I0606 14:42:29.609875       1 kube2sky.go:462] Etcd server found: http://127.0.0.1:4001
I0606 14:42:30.691607       1 kube2sky.go:529] Using http://localhost:8080 for kubernetes master
I0606 14:42:30.692206       1 kube2sky.go:530] Using kubernetes API <nil>
I0606 14:42:30.692584       1 kube2sky.go:598] Waiting for service: default/kubernetes
I0606 14:42:30.693686       1 kube2sky.go:604] Ignoring error while waiting for service default/kubernetes: yaml: mapping values are not allowed in this context. Sleeping 1s before retrying.
```

May be the container is expecting kubernetes master to be on localhost, whereas it is on 192.168.124.10 ! (I was right! See below!) 



I modified the kube2sky section in dns-addon-coreos.yaml by adding `--kube-master-url=http://192.168.124.10:8080` as an additional **args**.

```
[snipped]
. . . 
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain=cluster.local
        - --kube-master-url=http://192.168.124.10:8080
. . . 
[snipped]
```


, and I got the following in logs:

```
[fedora@kube-master ~]$ kubectl create -f dns-addon-coreos.yaml 
service "kube-dns" created
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$ 

[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system
NAME                 READY     STATUS    RESTARTS   AGE
kube-dns-v11-5ndxj   4/4       Running   0          2m
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl logs kube-dns-v11-5ndxj kube2sky --namespace=kube-system
I0606 19:16:35.170516       1 kube2sky.go:462] Etcd server found: http://127.0.0.1:4001
I0606 19:16:36.172404       1 kube2sky.go:529] Using http://192.168.124.10:8080 for kubernetes master
I0606 19:16:36.172870       1 kube2sky.go:530] Using kubernetes API v1
I0606 19:16:36.173259       1 kube2sky.go:598] Waiting for service: default/kubernetes
I0606 19:16:36.227287       1 kube2sky.go:660] Successfully added DNS record for Kubernetes service.
[fedora@kube-master ~]$ 
``` 
Looks great!

Lets test:
Reference: [https://github.com/kubernetes/kubernetes/tree/release-1.2/cluster/addons/dns#how-do-i-test-if-it-is-working](https://github.com/kubernetes/kubernetes/tree/release-1.2/cluster/addons/dns#how-do-i-test-if-it-is-working)
```
[fedora@kube-master ~]$ kubectl create -f busybox.yaml 
pod "busybox" created
[fedora@kube-master ~]$ 

[fedora@kube-master ~]$ kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
busybox   1/1       Running   0          4m
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ kubectl exec busybox -i -t  -- sh

/ # nslookup yahoo.com
Server:    10.254.0.10
Address 1: 10.254.0.10

Name:      yahoo.com
Address 1: 2001:4998:58:c02::a9 ir1.fp.vip.bf1.yahoo.com
Address 2: 2001:4998:c:a06::2:4008 ir1.fp.vip.gq1.yahoo.com
Address 3: 2001:4998:44:204::a7 ir1.fp.vip.ne1.yahoo.com
Address 4: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 5: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
Address 6: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
/ #
```

This time the reponse is instantaneous. Still it cannot resolve kubernetes!

```
/ # nslookup kubernetes
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes'
/ # nslookup kubernetes.default
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes.default'
/ # nslookup kubernetes.cluster.local
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes.cluster.local'
/ # 
```

SkyDNS has something in the logs:
```
[fedora@kube-master ~]$ kubectl logs kube-dns-v11-5ndxj skydns --namespace=kube-system
2016/06/06 19:16:36 skydns: falling back to default configuration, could not read from etcd: 100: Key not found (/skydns/config) [15]
2016/06/06 19:16:36 skydns: ready for queries on cluster.local. for tcp://0.0.0.0:53 [rcache 0]
2016/06/06 19:16:36 skydns: ready for queries on cluster.local. for udp://0.0.0.0:53 [rcache 0]
[fedora@kube-master ~]$ 
```

Also the Healthz container:

```
2016/06/06 19:49:33 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:35 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:37 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:39 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:41 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:42 Client ip 172.16.18.1:58812 requesting /healthz probe servicing cmd nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:43 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:45 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
[fedora@kube-master ~]$ 
``` 


# Configure Worker nodes
## Configuring Docker to use the cluster registry cache


## Configuring Docker to use the Flannel overlay

## Configure Docker to use DNS too

## enable services on nodes:


Result:
```
[fedora@kube-master ~]$ sudo kubectl get nodes
NAME             STATUS    AGE
192.168.124.11   Ready     1m
192.168.124.12   Ready     1m
[fedora@kube-master ~]$ 
```



---- 

# Basic communication tests:
Run some containers and do basic network testing / pod reachability, etc.

On the master node, create a file: run-my-nginx.yaml with the following contents:

```
[fedora@kube-master ~]$ cat run-my-nginx.yaml 
# From: http://kubernetes.io/docs/user-guide/connecting-applications/ 
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: my-nginx
spec:
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
```


Create the deployment with two pods, defined in the file above.

```
[fedora@kube-master ~]$ kubectl create -f ./run-my-nginx.yaml 
```

This may take a couple of minutes untill the pods are running on nodes. This is because each worker node needs to pull a local copy of the docker image needed for the pods, mentioned in the deployment config file (above).

```
[fedora@kube-master ~]$ kubectl get deployments
NAME       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
my-nginx   2         2         2            2           1h
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl get pods
NAME                        READY     STATUS    RESTARTS   AGE
my-nginx-3800858182-fcglh   1/1       Running   0          1m
my-nginx-3800858182-lx5i2   1/1       Running   0          1m
[fedora@kube-master ~]$
```



Lets check the IPs of these pods and the nodes they are created on.

```
[fedora@kube-master ~]$ kubectl describe pods  -l run=my-nginx| egrep "Name:|Node:|IP:"
Name:		my-nginx-3800858182-fcglh
Node:		192.168.124.12/192.168.124.12
IP:		172.16.18.2

Name:		my-nginx-3800858182-lx5i2
Node:		192.168.124.11/192.168.124.11
IP:		172.16.39.2
[fedora@kube-master ~]$ 
```

Note the following:
* One pod is on node1 and the other is on node2. 
* The pod on node1 has the IP 172.16.18.2
* The pod on node2 has teh IP 172.16.39.2 

## Ping from master:
Lets ping these pods from Master node, and each worker node. 

From the master you can only ping the IPs of the worker nodes, because all cluster machines are on the same subnet (192.168.124.0/24) . 
You cannot ping pods from the master node, becuase master node does not have flannel interface. This is shown below.

```
[fedora@kube-master ~]$ ping -c1 192.168.124.11
PING 192.168.124.11 (192.168.124.11) 56(84) bytes of data.
64 bytes from 192.168.124.11: icmp_seq=1 ttl=64 time=0.220 ms

--- 192.168.124.11 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.220/0.220/0.220/0.000 ms


[fedora@kube-master ~]$ ping -c1 192.168.124.12
PING 192.168.124.12 (192.168.124.12) 56(84) bytes of data.
64 bytes from 192.168.124.12: icmp_seq=1 ttl=64 time=0.297 ms

--- 192.168.124.12 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.297/0.297/0.297/0.000 ms
[fedora@kube-master ~]$ 
```

Lets ping the IP of pods, from master node. This WILL NOT work.

```
[fedora@kube-master ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
^C
--- 172.16.18.2 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

[fedora@kube-master ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
^C
--- 172.16.39.2 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

[fedora@kube-master ~]$ 
```

So the pods are not pingable from the master node, becuase the master node does not have the flannel network setup on it. It's routing table does not have information about the subnets belonging to the pods (the flannel network). And since you cannot ping the pods, you cannot reach their services either, such as getting the web page from nginx pods.

Here is some network information from master node:
```
[fedora@kube-master ~]$ ip addr sh
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:05:bb:ea brd ff:ff:ff:ff:ff:ff
    inet 192.168.124.10/24 brd 192.168.124.255 scope global ens3
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe05:bbea/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:93:8f:1a:a4 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:93ff:fe8f:1aa4/64 scope link 
       valid_lft forever preferred_lft forever
23: vethe5a10d2@if22: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 32:11:f3:06:4b:bf brd ff:ff:ff:ff:ff:ff link-netnsid 0
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.124.1   0.0.0.0         UG    100    0        0 ens3
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.124.0   0.0.0.0         255.255.255.0   U     100    0        0 ens3
[fedora@kube-master ~]$ 
```

## Accessing pods from within the nodes:

You can see that the pods are accessible from both worker nodes:
```
[fedora@kube-node1 ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
64 bytes from 172.16.18.2: icmp_seq=1 ttl=63 time=0.356 ms

--- 172.16.18.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.356/0.356/0.356/0.000 ms
[fedora@kube-node1 ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
64 bytes from 172.16.39.2: icmp_seq=1 ttl=64 time=0.077 ms

--- 172.16.39.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.077/0.077/0.077/0.000 ms
[fedora@kube-node1 ~]$ 
```


```
[fedora@kube-node2 ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
64 bytes from 172.16.39.2: icmp_seq=1 ttl=63 time=0.730 ms

--- 172.16.39.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.730/0.730/0.730/0.000 ms
[fedora@kube-node2 ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
64 bytes from 172.16.18.2: icmp_seq=1 ttl=64 time=0.040 ms

--- 172.16.18.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.040/0.040/0.040/0.000 ms
[fedora@kube-node2 ~]$ 
```


```
[fedora@kube-node1 ~]$ curl http://172.16.18.2
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>


[fedora@kube-node1 ~]$ curl http://172.16.39.2
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node1 ~]$ 
```

Same results are achieved when I access these pods from the second node.


# Creating and accessing the service:
We now have pods running nginx in a flat, cluster wide, address space. In theory, you could talk to these pods directly, but what happens when a node dies? The pods die with it, and the Deployment will create new ones, with different IPs. This is the problem a Service solves.

A Kubernetes Service is an abstraction which defines a logical set of Pods running somewhere in your cluster, that all provide the same functionality. When created, each Service is assigned a unique IP address (also called clusterIP). This address is tied to the lifespan of the Service, and will not change while the Service is alive. Pods can be configured to talk to the Service, and know that communication to the Service will be automatically load-balanced out to some pod that is a member of the Service.

The above deployement can simply be "exposed" using the following command:

```
kubectl expose deployment my-nginx
```

The above command is equivalent of the following service definition:
```
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    run: my-nginx
spec:
  ports:
  - port: 80
    protocol: TCP
  selector:
    run: my-nginx
```




```
[fedora@kube-master ~]$ kubectl expose deployment/my-nginx 
service "my-nginx" exposed
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl get services
NAME         CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.254.0.1       <none>        443/TCP   3d
my-nginx     10.254.122.172   <none>        80/TCP    23s
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl describe service my-nginx
Name:			my-nginx
Namespace:		default
Labels:			run=my-nginx
Selector:		run=my-nginx
Type:			ClusterIP
IP:			10.254.122.172
Port:			<unset>	80/TCP
Endpoints:		172.16.18.2:80,172.16.39.2:80
Session Affinity:	None
No events.

[fedora@kube-master ~]$ 
```

Whenever a services is created without specifying a "type", then kubernetes uses "ClusterIP" as the default type. This creates an IP from the ServiceAddresses directive in apiserver (configured on master) and attaches it to the newly created service. (Other two types are NodeIP and LoadBalancer) .


## Accessing the cluster IP from master and worker nodes:

Master node is still not able to communicate directly with the cluster IP. Worker nodes can access/communicate with the ClusterIP. This is shown below:

```
[fedora@kube-master ~]$ curl http://10.254.122.172
^C
[fedora@kube-master ~]$ 
```


```
[fedora@kube-node1 ~]$ curl http://10.254.122.172
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node1 ~]$ 
```


[fedora@kube-node2 ~]$ curl http://10.254.122.172
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node2 ~]$ 
```

Note: I noticed some lag (and indefinite wait) sometimes with I tried to communicate with the cluster IP from the worker nodes.


Please note that this clusterIP is mapped against a particular port. This means, the trying to access this ClusterIP over other protocols, etc, WILL NOT work. e.g. ping to cluster IP will ALWAYS fail.

```[fedora@kube-node1 ~]$ ping 10.254.217.10
PING 10.254.217.10 (10.254.217.10) 56(84) bytes of data.
^C
--- 10.254.217.10 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 999ms

[fedora@kube-node1 ~]$
```


 




