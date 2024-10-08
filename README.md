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

## Part 3: K3d and Argo CD

