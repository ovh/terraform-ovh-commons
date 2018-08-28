- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice: Terraform basics: vars and outputs](#sec-3)
- [Going Further](#sec-4)


# Objective<a id="sec-1"></a>

This document is the second part of a [step by step guide](../0-simple-terraform/README.md) on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Public Cloud](https://www.ovh.com/world/public-cloud/instances/). It will help you create an OpenStack Swift container on the region of your choice, but this time with more advanced features of terraform, such as multiple `tf` files, variables, interpolation and outputs.

# Pre requisites<a id="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

# In pratice: Terraform basics: vars and outputs<a id="sec-3"></a>

You can `cd` in the second step directory and have a look at the directory structure.

```bash
cd 1-simple-terraform-vars
find .
```

    .
    ./outputs.tf
    ./variables.tf
    ./main.tf

You should now see a directory with a multiple `.tf` files. Terraform takes a directory as input and concatenate all the `.tf` files it can find.

By convention, we put all variables in a `variables.tf` file, all outputs in a `outputs.tf` file, and the rest in the `main.tf` files.

Here's the content of the `variables.tf`:

```terraform
variable "region" {
  description = "The id of the OpenStack region"
  default = "GRA3"
}

variable "name" {
  description = "The name of the Swift container for the terraform backend remote state"
  default = "demo-journey"
}
```

Alright. So now we know how to declare variables with default values and adding documentation. Now lets look at how to use them in the `main.tf` file:

```terraform
provider "openstack" {
  auth_url  = "https://auth.cloud.ovh.net/v2.0/"
  region = "${var.region}"
}

resource "openstack_objectstorage_container_v1" "container" {
  region         = "${var.region}"
  name           = "${var.name}"
}
```

Here we can see basic "interpolation" features of terraform. Full documentation is available [here](https://www.terraform.io/docs/configuration/interpolation.html).

Here we force the target region to the input variable `region`. We consider this as a best practice because relying on the openrc `OS_REGION_NAME` exported environment variable is error prone.

Lastly, terraform can generate outputs that can be used in various ways. We'll have a look at it in the next steps.

Here's how outputs look like:

```terraform
output "helper" {
  description = "human friendly helper"
  value = <<DESC
You can now use your swift container as a terraform remote state backend, such as:
---
terraform {
  backend "swift" {
    container = "${openstack_objectstorage_container_v1.container.name}"
  }
}
---

and reference state outputs with:
---
data "terraform_remote_state" "foo" {
  backend = "swift"
  config {
    container = "${openstack_objectstorage_container_v1.container.name}"
  }
}
---
DESC
}
```

Here we have a human friendly output, defined by a multi lined value which references resources attributes with interpolation syntax, thus creating dependencies within the terraform depencendy tree between the output and the resources it references.

Now that we've looked at the source code, let's apply it:

```bash
source ~/openrc.sh
terraform init
terraform apply
```

    openstack_objectstorage_container_v1.container: Creating...
      name:   "" => "demo-journey"
      region: "" => "GRA3"
    openstack_objectstorage_container_v1.container: Creation complete after 0s (ID: demo-journey)
    
    Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    helper = You can now use your swift container as a terraform remote state backend, such as:
    ---
    terraform {
      backend "swift" {
        container = "demo-journey"
      }
    }
    ---
    
    and reference state outputs with:
    ---
    data "terraform_remote_state" "foo" {
      backend = "swift"
      config {
        container = "demo-journey"
      }
    }
    ---

Ooops! I didn't want to create my container on the GRA3 region but on SBG3. No problem, let's re apply our plan:

```bash
source ~/openrc.sh
terraform apply -var region=SBG3
```

    openstack_objectstorage_container_v1.container: Refreshing state... (ID: demo-spark)
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
    -/+ destroy and then create replacement
    
    Terraform will perform the following actions:
    
    -/+ openstack_objectstorage_container_v1.container (new resource required)
          id:     "demo-journey" => <computed> (forces new resource)
          name:   "demo-journey" => "demo-journey"
          region: "GRA3" => "SBG3" (forces new resource)
    
    
    Plan: 1 to add, 0 to change, 1 to destroy.
    
    Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.
    
      Enter a value:

OH OH! Terraform will destroy one resource and create a new one on the right region. Which is exactly what i want. So let's go:

      Enter a value: yes
    
    openstack_objectstorage_container_v1.container: Destroying... (ID: demo-journey)
    openstack_objectstorage_container_v1.container: Destruction complete after 0s
    openstack_objectstorage_container_v1.container: Creating...
      name:   "" => "demo-journey"
      region: "" => "SBG3"
    openstack_objectstorage_container_v1.container: Creation complete after 1s (ID: demo-journey)
    
    Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
    
    Outputs:
    
    helper = You can now use your swift container as a terraform remote state backend, such as:
    ---
    terraform {
      backend "swift" {
        container = "demo-journey"
      }
    }
    ---
    
    and reference state outputs with:
    ---
    data "terraform_remote_state" "foo" {
      backend = "swift"
      config {
        container = "demo-journey"
      }
    }
    ---

Ok. We're done with this step. See you on step 3.

But before don't forget to clean up your infrastructure.

```bash
source ~/openrc.sh
terraform destroy -var region=SBG3
```

    openstack_objectstorage_container_v1.container: Refreshing state... (ID: demo-journey)
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      - destroy
    
    Terraform will perform the following actions:
    
      - openstack_objectstorage_container_v1.container
    
    
    Plan: 0 to add, 0 to change, 1 to destroy.
    
    Do you really want to destroy?
      Terraform will destroy all your managed infrastructure, as shown above.
      There is no undo. Only 'yes' will be accepted to confirm.
    
      Enter a value: yes
    
    openstack_objectstorage_container_v1.container: Destroying... (ID: demo-journey)
    openstack_objectstorage_container_v1.container: Destruction complete after 1s
    
    Destroy complete! Resources: 1 destroyed.

# Going Further<a id="sec-4"></a>

You can now jump to the [third step](../2-simple-terraform-state/README.md) of our journey introducing terraform state.

Of course, if you want to deep dive into terraform, you can also read the official [guides](https://www.terraform.io/guides/index.html) & [docs](https://www.terraform.io/docs/index.html).
