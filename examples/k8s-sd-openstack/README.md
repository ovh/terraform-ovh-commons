# Description

This is a simple terraform recipe which demonstrates how to manage OVH Dedicated servers and OVH Cloud Virtual
Machines in the same network, through the Vrack service.

In the end we use ansible kubespray roles to provision a Kubernetes cluster on the nodes.

# Requirements

This example requires:
- go > 1.13
- git 
- terraform > 0.12
- python3+pip
- kubectl 

This example also requires the following OVH services attached to your nic:

- an OVH Public Cloud project
- a Vrack 
- a Dedicated Server

# Step 1: setup the vrack 

It's important that your vrack network is managed in a serapate terraform plan

Before applying your terraform plan, edit the `./vrack/terraform.tfvars` accordingly:

```
cp ./vrack/terraform.tfvars.sample ./vrack/terraform.tfvars
vi ./vrack/terraform.tfvars
...
```

then apply your terraform plan:

```
cd vrack
terraform init
terraform apply
```

__NOTE__: if your cloud project or your Ip Loadbalancing service are already 
attached to your vRack, either edit the plan to comment the attachment resources
or import them in the terraform state:

```
cd vrack
terraform import ovh_vrack_cloudproject.vrack_openstack VRACKID/CLOUDPROJECTID
terraform import ovh_vrack_iploadbalancing.vrack_iplb VRACKID/IPLBID
```

# Step 2: setup the infrastructure

First run terraform init

```sh
cd vrack
terraform init
terraform apply
```

__NOTE__: Coffee break warning. This step can take several minutes as
the Dedicated servers install tasks can take up to 45 minutes and the 
ansible kubespray provisioning around 15 minutes.


Once it's done, you can apply the rest of the recipe

```sh
# having a running ssh-agent is mandatory
eval $(ssh-agent)
terraform apply
```

# Use k8s

```
export KUBECONFIG=./mycluster/artifacts/admin.con
kubectl get nodes
NAME                     STATUS   ROLES    AGE     VERSION
bm-host-0                Ready    <none>   3m23s   v1.16.3
sd-os-demo-000           Ready    <none>   3m23s   v1.16.3
sd-os-demo-masters-000   Ready    master   5m19s   v1.16.3
sd-os-demo-masters-001   Ready    master   4m31s   v1.16.3
sd-os-demo-masters-002   Ready    master   4m31s   v1.16.3
```
