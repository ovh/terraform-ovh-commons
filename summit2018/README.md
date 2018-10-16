- [Objective](#sec-1)
- [Pre-requisites](#sec-2)
- [In practice](#sec-4)
- [Going Further](#sec-5)


# Objective<a id="sec-1" name="sec-1"></a>

This document is the fourth part of a [step by step guide](../0-simple-terraform/README.md) on how to use 
the [Hashicorp Terraform](https://terraform.io) tool with [OVH Public Cloud](https://www.ovh.com/world/public-cloud/instances/). 
Previously we created a Public Cloud instance to host a static blog based on [hugo](https://gohugo.io/getting-started/quick-start/) working with post-boot scripts.
Now we'll go a bit further adding TLS security and redundency across regions using Roud Robin DNS. We'll start our first high availability infrastructure. For that, we'll see:
- how to generate a TLS certificate with terraform
- how to manage two instances in two regions
- how to live manage the DNS using the OVH provider in terraform in order to round robin DNS across regions.

Every documented part here should be considered as an addition of the previous steps.

# Pre-requisites<a id="sec-2" name="sec-2"></a>

Please refer to the pre-requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

In addition of the previous pre-requisites, we need to introduce the ACME Let's Encrypt provider to manage the TLS certificate. The ACME provider is not already merged in the upstream terraform code, so you have to install it as a side plugin.

## Register your OVH products

For this demo, you shall order

- an ip loadbalancer
- an openstack project
- a domain name

## Setup your creds 

```
cat > ~/.secrets.env <<EOF
# retrieve your metrics insight token from ovh api /me/insight endpoint
TF_VAR_metrics_insight_token="..."
# create an api token on your  https://grafana.metrics.ovh.net account
TF_VAR_grafana_api_token="...="
# insert your IP loadbalancer service name 
TF_VAR_iplb="loadbalancer-..."
# insert your domain name here (ex: foobar.ovh)
TF_VAR_zone="..."
# insert your email here, it will be used for the letsencrypt certs generation
TF_VAR_email="..."
EOF

export $(cat ~/.secrects.env | grep -v '^#' | xargs)
```

## Setup your OVH API creds

To set your OVH API credentials, please refer to the [documentation](https://www.terraform.io/docs/providers/ovh/index.html#configuration-reference).

## Setup your OVH Openstack API creds

Download your `openrc.sh` file from the OVH Manager & run it. 

# In practice<a id="sec-4" name="sec-4"></a>


```bash
$ eval $(ssh-agent)
$ ssh-add
$ terraform init
$ terraform apply 
```
