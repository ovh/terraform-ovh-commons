# OVH Summit 2018 terraform tech lab

- [Pre-requisites](#sec-2)
- [In practice](#sec-4)
- [Going Further](#sec-5)


# Pre-requisites<a id="sec-2" name="sec-2"></a>

Please refer to the pre-requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

In addition of the previous pre-requisites, we need to mention that this tech lab uses the last terraform OVH provider features
that may not have been released officialy by Hashicorp at the time of this demo. You can build the OVH provider and make
the proper terraform setup in order to use it if you don't want to wait for the official release.

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
$ eval $(ssh-agent) && ssh-add
$ git clone https://github.com/ovh/terraform-ovh-commons && cd terraform-ovh-commons/
$ terraform init
$ terraform apply 
```
