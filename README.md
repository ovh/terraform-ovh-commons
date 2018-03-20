# Terraforming OVH Public Cloud 

This repo contains commons resources to interact with [OVH Public Cloud](https://ovhcloud.com/) using [Terraform](https://www.terraform.io/). 

# Journey

We provide a step-by-step guide on how to use [Terraform](https://www.terraform.io/) with [OVH Public Cloud](https://ovhcloud.com/).

- [intro: terraform basics part 1](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/0-simple-terraform/README.md)
- [terraform basics part 2](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/1-simple-terraform-vars/README.md)
- [terraform basics part 3](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/2-simple-terraform-state/README.md)
- [OVH public cloud instances](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/3-simple-public-instance/README.md)
- [Advanced OVH public cloud instances](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/4-advanced-public-instances/README.md)
- [OVH private instances](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/5-private-instances/README.md)
- [OVH terraform modules](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/6-intro-modules/README.md)
- [OVH multi region infrastructure](https://github.com/ovh/terraform-ovh-commons/tree/master/journey/7-multiregion/README.md)

# ORG Mode READMEs

Most READMEs are written in org mode within emacs, then exported in various format such as markdown or html. As such, you may copy/paste code snippets in a shell terminal.

But if you're editing the source `org` documents within emacs, you can use them as runnable notebooks. You just have to hit `C-c C-c` on src blocks and code will be executed & outputted within the document, along with a shell buffer named `*journey*`.

Don't forget to load babel support for shell lang by hitting `C-c C-c` on the following block:

```emacs-lisp
(org-babel-do-load-languages 'org-babel-load-languages '((shell . t)))
```

& then try it:

```bash
echo 'vi vi vi is the editor of the Beast!'
```

<span class="underline">Tip</span>: you can hit `Tab` or `Shift-Tab` multiple times to collapse/uncollapse paragraphs.

## License

The 3-Clause BSD License. See [LICENSE](https://github.com/ovh/terraform-ovh-commons/tree/master/LICENSE) for full details.

