# IoT

## Part 1: K3s and Vagrant
This project sets up a lightweight Kubernetes cluster using K3s on two virtual machines (VMs) provisioned by Vagrant. The setup consists of one server and one agent (worker) node, both running the debian/bookworm64 image.

### Vagrant setup
Vagrant setup two virtual machines using `debian/bookworm64` image.
Server node:
- hostname: `cpaluszeS`
- ip: `192.68.156.110`

Worker node:
- hostname: `cpaluszeSW`
- ip: `192.68.156.111`

### K3s config
Provisioning scripts are utilized to install and configure K3s on both the server and the agent. The server is provisioned first to generate the token required for the agent to join the cluster.

**Server**:
- Install `curl` using `apt-get`
- The `INSTALL_K3S_EXEC` environment variable is used to configure the installation:
    - `--write-kubeconfig-mode=644` - Sets permissions for the kubeconfig file to be readable by all users.
- Install `k3s` using `curl -sfL https://get.k3s.io | sh -`
- The script waits for the token file generation and copies it in the shared folder.

**Agent:**
- Install `curl` using `apt-get`
- `INSTALL_K3S_EXEC` environment variable is used to configure the installation:
    - `agent` indicate that this node will function as an agent.
    - `--token $K3S_TOKEN` specify the token value read from the shared folder.
    - `--server https://192.168.56.110:6443` specifies the K3s cluster URL

### Check the configuration
**Server:**
```
vagrant ssh cpaluszeS

vagrant@cpaluszeS:~$ sudo systemctl status k3s   # Check if the k3s.service is running

vagrant@cpaluszeS:~$ kubectl get nodes
NAME         STATUS   ROLES                  AGE     VERSION
cpaluszes    Ready    control-plane,master   6m54s   v1.30.5+k3s1
cpaluszesw   Ready    <none>                 2m46s   v1.30.5+k3s1
```
**Agent:**
```
vagrant ssh cpaluszeS

vagrant@cpaluszeSW:~$ sudo systemctl status k3s-agent   # Check if the k3s-agent.service is running
```

## Part 2: K3s and three simple applications
This project sets up a lightweight Kubernetes cluster using K3s on one virtual machines provisioned by Vagrant. The setup consists of one server running the debian/bookworm64 image.

### Vagrant setup
Server node:
- hostname: `cpaluszeS`
- ip: `192.68.156.110`

### K3s config
Provisioning scripts are utilized to install and configure K3s on both the server and the agent. The server is provisioned first to generate the token required for the agent to join the cluster.

**Server**:
- Install `curl` using `apt-get`
- The `INSTALL_K3S_EXEC` environment variable is used to configure the installation:
    - `--write-kubeconfig-mode=644` - Sets permissions for the kubeconfig file to be readable by all users.
- Install `k3s` using `curl -sfL https://get.k3s.io | sh -`
- The script waits for the token file generation and copies it in the shared folder.

### Kubernetes manifests
We setup 3 applications based on [hello-kubernetes docker image](https://github.com/paulbouwer/hello-kubernetes)

- [app1.yaml](./p2/app1.yaml)
- [app2.yaml](./p2/app2.yaml)
- [app3.yaml](./p2/app3.yaml)
- [ingress.yaml](./p2/ingress.yaml)

The 3 apps are identical, except the app2 which is replicated 3 times.
Ingress is used to make the apps accessible outside of the cluster.

The provisionning script apply these manifests after the dependencies installation.

### Test the websites
- [Header value extension firefox](https://addons.mozilla.org/fr/firefox/addon/modify-header-value/)

```sh
curl http://192.168.56.110  # app3
curl http://app1.com        # app1
curl http://app2.com        # app2 should have a different pod id each time
```

## Part 3: K3d and Argo CD

### K3d vs K3s
k3d is a lightweight wrapper to run k3s (Rancher Lab’s minimal Kubernetes distribution) in docker.

k3d makes it very easy to create single- and multi-node k3s clusters in docker, e.g. for local development on Kubernetes.

## Bonus
- [Install Gitlab](https://docs.gitlab.com/ee/install/index.html)

