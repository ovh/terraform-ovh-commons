- [Disclaimer](#sec-1)
- [Objective](#sec-2)
- [Pre requisites <code>[9/9]</code>](#sec-3)
- [In pratice: Terraform basics: a very first step](#sec-4)
- [Going Further](#sec-5)
- [<a id="orgfec8a66"></a> Get an OVH API Consumer key](#sec-6)


# Disclaimer<a id="sec-1"></a>

This [document](unikernels.md) is written in org mode within emacs, then exported in various format such as markdown or html. As such, you may copy/paste code snippets in a shell terminal.

But if you're editing this document within emacs, you can use it as a runnable notebook. You just have to hit `C-c C-c` on src blocks and code will be executed & outputted within the document, along with a shell buffer named `*journey*`.

Don't forget to load babel support for shell lang by hitting `C-c C-c` on the following block:

```emacs-lisp
(org-babel-do-load-languages 'org-babel-load-languages '((shell . t)))
```

& then try it:

```bash
echo 'vi vi vi is the editor of the Beast!'
```

<span class="underline">Tip</span>: you can hit `Tab` or `Shift-Tab` multiple times to collapse/uncollapse paragraphs.

# Objective<a id="sec-2"></a>

This document is the first part of an 8 parts journey that will provide you a step by step guide on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). It will guide you through a very simple terraform script that creates an object storage swift container to a full multi region HA setup using terraform modules provided by OVH.

In the end, it can help you better understand complex terraform modules such as the [Consul](https://registry.terraform.io/modules/ovh/publiccloud-consul/ovh/0.1.3) or the [Kubernetes](https://registry.terraform.io/modules/ovh/publiccloud-k8s/ovh) modules and thus serve as an introduction to those modules.

It will also covers the very basic features of the [terraform](https://www.terraform.io/downloads.html) tool, such as terraform scripts, managing state, modules, &#x2026;

According to your level of knowledge of our platform and the [terraform](https://www.terraform.io/downloads.html) tool, feel free to skip the first steps.

# Pre requisites <code>[9/9]</code><a id="sec-3"></a>

Please make sure before going any further that all the following pre requisites are met on your side: ,

-   [X] register an ovh account
-   [X] order a public cloud project
-   [X] create an openstack user
-   [X] download openrc in keystone v3 format
-   [X] install the [terraform binary](https://www.terraform.io/downloads.html) (version >= 0.10.3) according to your OS
-   [X] install the openstack cli on your target host (`pip install python-openstackclient`) (optional but very useful as we'll see in the examples)
-   [X] order a vrack (starting step 6)
-   [X] attach your vrack to your openstack project (starting step 6)
-   [X] get an [ovh api consumer key](#orgfec8a66) (required for the multiregion setup on step 8)

# In pratice: Terraform basics: a very first step<a id="sec-4"></a>

The first 3 steps of the journey are pure [terraform](https://www.terraform.io/downloads.html) basic reminders. This step will help you create an openstack swift container on the region of your choice.

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

You should see a directory with a single `main.tf` file.

A "tf" file is a script that terraform will take as input to apply the configuration you have described in it. Let's see how it looks:

```terraform
resource "openstack_objectstorage_container_v1" "backend" {
  region         = "SBG3"
  name           = "demo-simple-terraform" 
}
```

The script describes a single resource of type `openstack\_objectstorage\_container\_v1` with the id `backend`. It has 2 attributes: a name and a region.

We will apply this script in a few minutes but first, lets look at what Openstack Swift containers we already have on the `SBG3` region.

```bash
source ~/openrc.sh
openstack --os-region-name SBG3 container list
```

Result is empty. Good. If it's not then you should see your existing containers listed.

Notice the `source` command above which will load your Openstack credentials in your shell environment. This line will be headed in all the following code snippets as a reminder. You may want to make it point to your openrc.sh file path.

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
openstack --os-region-name SBG3 container list
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
openstack --os-region-name SBG3 container list
```

Result is empty, as expected. And that's it!

OH! One more thing! Have you noticed the `terraform.tfstate*` files in your directory? Well, we shall talk about these in the next chapter.

# Going Further<a id="sec-5"></a>

You can now jump to the [second step](../1-simple-terraform-vars/README.md) of our journey introducing vars and outputs.

Of course, if you want to deep dive into terraform, you can also read the official [guides](https://www.terraform.io/guides/index.html) & [docs](https://www.terraform.io/docs/index.html).

# <a id="orgfec8a66"></a> Get an OVH API Consumer key<a id="sec-6"></a>

To be able to make API calls against the OVH API, you have to get credentials. To do so, you have to go through the following steps

-   Register an app on ovh api You first have to create an app on the following [page](https://eu.api.ovh.com/createApp/).
-   Then you can, after having replaced `myapplicationkey` by your actual key, generate a consumer key by running the following command:
    
    ```bash
    curl -XPOST -H"X-Ovh-Application: myapplicationkey" -H "Content-type: application/json" \
    https://eu.api.ovh.com/1.0/auth/credential  -d '{
      "accessRules": [
          { "method": "GET", "path": "/*" },
          { "method": "PUT", "path": "/*" },
          { "method": "POST", "path": "/*" },
          { "method": "DELETE", "path": "/*" }
      ]
    }'
    ```
    
        {"validationUrl":"https://eu.api.ovh.com/auth/?credentialToken=xxxyyyyzzzz","consumerKey":"myconsumerkey","state":"pendingValidation"}

-   The last command will output a JSON document containing your consumer key and a url you have to visit to activate the consumer key.
-   Once you have validated your consumer key, you can edit an `~/ovhrc` file and fill it by replacing the according values:
    
    ```bash
    export OVH_ENDPOINT="ovh-eu"
    export OVH_APPLICATION_KEY="myapplicationkey"
    export OVH_APPLICATION_SECRET="myapplicationsecret"
    export OVH_CONSUMER_KEY="myconsumerkey"
    ```
