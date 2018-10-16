output "yes" {
  value = <<EOF

visit your brand new website at:

   https://${var.name}.${var.zone}

You can also check your metrics at:

   https://grafana.metrics.ovh.net/dashboard/db/${var.name}

and generate simple http load with:

ab -c 10 -n 1000 https://${var.name}.${var.zone}/index.html

  Enjoy !!!
EOF
}
