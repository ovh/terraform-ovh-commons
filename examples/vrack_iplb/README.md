# Description
 
This example setups an IP Loabalancing service with cloud instances backends
in a vrack.

# Requirements

This example requires terraform > 0.12.

This example requires the following OVH services attached to your nic:

- an OVH Public Cloud project
- a Vrack 
- an IP Loadbalancing service with Vrack capability

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

The plan will create the following resources:

- iplb: vrack network, http frontends/farms/servers on ports 80 and 443
- openstack: a keypair, a subnet with a NAT/Bastion instance, 2 instances with a 
python3 http server on port 80 for demo purpose


Before applying your terraform plan, edit the `./vrack/terraform.tfvars` accordingly:

```
cp ./infra/terraform.tfvars.sample ./infra/terraform.tfvars
vi ./infra/terraform.tfvars
...
```
then apply your terraform plan:

```
cd infra
terraform init
terraform apply
```

Once the infrastructure is up. you can ping your IP Loadloabalancing public IP:

```
 while sleep 1; do curl http://PUBIP:80; done
 Hello world from node 0
 Hello world from node 0
 Hello world from node 0
 Hello world from node 0
 Hello world from node 0
 Hello world from node 1
 Hello world from node 0
 Hello world from node 1
 Hello world from node 0
 Hello world from node 0
 ...
```
