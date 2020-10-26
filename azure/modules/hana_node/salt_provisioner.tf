resource "null_resource" "hana_node_provisioner" {
  count = var.common_variables["provisioner"] == "salt" ? var.hana_count : 0

  triggers = {
    cluster_instance_ids = join(",", azurerm_virtual_machine.hana.*.id)
  }

  connection {
    host        = element(local.provisioning_addresses, count.index)
    type        = "ssh"
    user        = var.admin_user
    private_key = var.common_variables["private_key"]

    bastion_host        = var.common_variables["bastion_host"]
    bastion_user        = var.admin_user
    bastion_private_key = var.common_variables["bastion_private_key"]
  }

  provisioner "file" {
    content     = <<EOF
role: hana_node
${var.common_variables["grains_output"]}
${var.common_variables["hana_grains_output"]}
name_prefix: vm${var.name}
hostname: vm${var.name}0${count.index + 1}
host_ips: [${join(", ", formatlist("'%s'", var.host_ips))}]
network_domain: "tf.local"
hana_inst_master: ${var.hana_inst_master}
hana_fstype: ${var.hana_fstype}
hana_data_disks_configuration: {${join(", ", formatlist("'%s': '%s'", keys(var.hana_data_disks_configuration), values(var.hana_data_disks_configuration), ), )}}
storage_account_name: ${var.storage_account_name}
storage_account_key: ${var.storage_account_key}
ha_enabled: ${var.ha_enabled}
fencing_mechanism: ${var.fencing_mechanism}
sbd_storage_type: ${var.sbd_storage_type}
sbd_lun_index: 0
iscsi_srv_ip: ${var.iscsi_srv_ip}
hana_cluster_vip: ${var.ha_enabled ? azurerm_lb.hana-load-balancer[0].private_ip_address : ""}
hana_cluster_vip_secondary: ${var.hana_cluster_vip_secondary}
cluster_ssh_pub:  ${var.cluster_ssh_pub}
cluster_ssh_key: ${var.cluster_ssh_key}
hwcct: ${var.hwcct}
EOF
    destination = "/tmp/grains"
  }
}

module "hana_provision" {
  source               = "../../../generic_modules/salt_provisioner"
  node_count           = var.common_variables["provisioner"] == "salt" ? var.hana_count : 0
  instance_ids         = null_resource.hana_node_provisioner.*.id
  user                 = var.admin_user
  private_key          = var.common_variables["private_key"]
  bastion_host         = var.common_variables["bastion_host"]
  bastion_private_key  = var.common_variables["bastion_private_key"]
  public_ips           = local.provisioning_addresses
  background           = var.common_variables["background"]
}
