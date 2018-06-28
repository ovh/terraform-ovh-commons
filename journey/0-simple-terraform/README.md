- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice: Terraform basics: a very first step](#sec-3)
- [Going Further](#sec-4)


# Objective<a id="sec-1"></a>

This document is the first part of a multi-parts journey that will provide you a step by step guide on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Public Cloud](https://www.ovh.com/world/public-cloud/instances/). It will guide you through a very simple terraform script that creates an object storage Swift container to a full multi region HA setup using terraform modules provided by OVH. 

It will also covers the very basic features of the [Terraform](https://www.terraform.io/downloads.html) tool, such as terraform scripts, managing state, modules, &#x2026;

In the end, you'll have learnt:
- the Terraform best practices
- how to use the OpenStack resources on OVH Public Cloud
- how to use OVH specific resources such as domains
- how to design and build a moderne infrastructure

According to your level of knowledge of our platform and the [Terraform](https://www.terraform.io/downloads.html) tool, feel free to skip the first steps.

# Pre requisites<a id="sec-2"></a>

Please make sure before going any further that all the following pre requisites are met on your side:

- Register an [OVH account](https://www.ovh.com/world/support/new_nic.xml)
- Order a Public Cloud project
- Create an [OpenStack user](https://www.youtube.com/watch?v=BIMb0iR1YhY)
- Download openrc
- Install the [Terraform binary](https://www.terraform.io/downloads.html) (version >= 0.10.3) according to your OS
- Install the openstack cli on your target host (`pip install python-openstackclient`) (optional but very useful as we'll see in the examples)

# In pratice: Terraform basics: a very first step<a id="sec-3"></a>

The first 3 steps of the journey are pure [Terraform](https://www.terraform.io/downloads.html) basic reminders. This step will help you to create an OpenStack Swift container on the region of your choice.

First, if it hasn't already been done, download the terraform binany for your platform of choice:

```bash
curl -fLs -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.3/terraform_0.11.3_linux_amd64.zip
(cd /tmp && unzip terraform.zip)
sudo mv /tmp/terraform /usr/local/bin
sudo chmod +x /usr/local/bin/terraform
rm /tmp/terraform.zip
```

This last step is mandatory for the rest of the journey and we'll assume from there it has been done as mentioned in the pre requisites.

Now you can `cd` in the first step directory and have a look at the directory structure.

```bash
cd 0-simple-terraform
find .
```

    .
    ./main.tf

A "tf" file is a script that terraform will take as input to apply the configuration you have described in it. Let's see how it looks:

```terraform
provider "openstack" {
  auth_url  = "https://auth.cloud.ovh.net/v2.0/" 
}

resource "openstack_objectstorage_container_v1" "backend" {
  name           = "demo-simple-terraform" 
}
```

The script describes a **provider**, here it's OpenStack with the authentication URL and a single **resource** of type `openstack\_objectstorage\_container\_v1` with the id `backend`.

We will apply this script in a few minutes but first, lets look at what OpenStack Swift containers we already have.

```bash
source ~/openrc.sh
openstack container list
```

Result is empty. Good. If it's not then you should see your existing containers listed.

Notice the `source` command above which will load your OpenStack credentials in your shell environment. The OpenStack provider entry should contain much more information, those which are missing are taken from the environment variables. This line will be headed in all the following code snippets as a reminder. You may want to make it point to your openrc.sh file path.

We can apply our configuration

```bash
source ~/openrc.sh
terraform apply
```

    ...
    Terraform will perform the following actions:
    
      + openstack_objectstorage_container_v1.backend
          id:     <computed>
          name:   "demo-simple-terraform"
          region: "SBG3"
    
    
    Plan: 1 to add, 0 to change, 0 to destroy.
    
    Do you want to perform these actions?
    ...

Great! Terraform wants to create a new resource of type "openstact<sub>objectstorage</sub><sub>container</sub><sub>v1</sub>". Let's do it by typing "yes".

    
      Enter a value: yes
    
    openstack_objectstorage_container_v1.backend: Creating...
      name:   "" => "demo-simple-terraform"
      region: "" => "SBG3"
    openstack_objectstorage_container_v1.backend: Creation complete after 1s (ID: demo-simple-terraform)
    
    Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Great, the container seems to have been created. Let's check this by listing our containers again:

```bash
source ~/openrc.sh
openstack container list
```

    +-----------------------+
    | Name                  |
    +-----------------------+
    | demo-simple-terraform |
    +-----------------------+

Now that we have seen how to create a resource with terraform, let's see how to destroy it. Actually, it's pretty simple and straight forward:

```bash
source ~/openrc.sh
terraform destroy
```

    ...
    Terraform will perform the following actions:
    
      - openstack_objectstorage_container_v1.backend
    
    
    Plan: 0 to add, 0 to change, 1 to destroy.
    
    Do you really want to destroy?
    ...

It seems to be correct. Let's type 'yes' and see what happens.

```bash
Do you really want to destroy?
Terraform will destroy all your managed infrastructure, as shown above.
There is no undo. Only 'yes' will be accepted to confirm.

Enter a value: yes
```

    
    openstack_objectstorage_container_v1.backend: Destroying... (ID: demo-simple-terraform)
    openstack_objectstorage_container_v1.backend: Destruction complete after 1s
    
    Destroy complete! Resources: 1 destroyed.

Now let's check our containers again:

```bash
source ~/openrc.sh
openstack container list
```

Result is empty, as expected. And that's it!

OH! One more thing! Have you noticed the `terraform.tfstate*` files in your directory? Well, we shall talk about these in the [next chapter](../1-simple-terraform-vars).

