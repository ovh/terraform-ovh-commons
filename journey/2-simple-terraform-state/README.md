- [Disclaimer](#sec-1)
- [Objective](#sec-2)
- [Pre requisites](#sec-3)
- [In pratice: Terraform basics: terraform state 3/3](#sec-4)
- [Going Further](#sec-5)


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

This document is the third part of a [step by step guide](../0-simple-terraform/README.md) on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). It will help you create an openstack swift container on the region of your choice, but this time by introducing terraform state management.

# Pre requisites<a id="sec-3"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

# In pratice: Terraform basics: terraform state 3/3<a id="sec-4"></a>

We're getting to the last step of the basics of terraform on OVH public cloud. This step will show you how terraform handles and manages its state.

If you have paid attention to the directory structure of the lasts steps, you may have noticed a file name `terraform.tfstate`. It's a json file in which terraform tries to keep an up-to-date view of your current infrastructure.

Every time terraform computes what it has to do according to the infrastructure you have described in the `*.tf` files, it looks if a `tfstate` file is present and makes every API call it has to in order to compute eventual differences and proposes a "plan" of changes accordingly.

If the `tfstate` is absent, it will consider it has to deal with a brand new infrastructure and will create every resources.

You can understand easily how important this file is: delete it once you have applied your infrastructure and you'll have to go through a lot of manual interactions.

You can rebuild your state file from an existing infrastructure but it's a very tedious procedure.

Moreover, what happens if you're not the one and only maintainer of the infrastructure, but part of an SRE/Devops/Ops/&#x2026; team? You'd have to find a way to share your state files with your team mates, and be very careful not to apply a change at the same time.

Well here's how you can answer these question with terraform primitives such as terraform [remote backends](https://www.terraform.io/intro/getting-started/remote.html).

Add this snippet in a `.tf` file:

```terraform
terraform {
  backend "swift" {
    container = "demo-remote-state"
  }
}
```

then run terraform init:

```bash
source ~/openrc.sh
terraform init
```

    Initializing the backend...
    
    Successfully configured the backend "swift"! Terraform will automatically
    use this backend unless the backend configuration changes.
    ...

Alright. Now let's apply the script as usual:

```bash
source ~/openrc.sh
terraform apply -auto-approve
...
```

And look at the directory structure:

```bash
ls 
```

    main.tf  Makefile  outputs.tf  README.org  variables.tf

No `tfstate` file! Where could it be? Well it should be present in a swift container as defined in the `tf` file. So lets check this:

```bash
openstack container list
openstack object list demo-remote-state
```

    +-------------------------------+
    | Name                          |
    +-------------------------------+
    | demo-remote-state             |
    +-------------------------------+
    +------------+
    | Name       |
    +------------+
    | tfstate.tf |
    +------------+

Right where it should be. This means that anyone running the same script on another machine with credentials accessing the same project on the same openstack region should have access to this `tfstate` file.

Notice: terraform maintains a local copy of this file in the `.terraform` directory.

# Going Further<a id="sec-5"></a>

We're finished with terraform basics on OVH. Now we'll go deeper into bootstrapping real infrastructure, starting with a public cloud virtual machine.

See you on [the fourth step](../3-simple-public-instance/README.md) of our journey.
