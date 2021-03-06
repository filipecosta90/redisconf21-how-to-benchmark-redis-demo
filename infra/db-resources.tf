
resource "aws_instance" "server" {
  count                  = var.server_instance_count
  ami                    = var.instance_ami
  instance_type          = var.server_instance_type
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = var.key_name

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    iops                  = var.instance_volume_iops
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Name           = "ebs_block_device-${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
  }

  tags = {
    Name           = "${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection 
  ################################################################################
  provisioner "remote-exec" {
    script = "./../scripts/wait_for_instance.sh"
    connection {
      host        = self.public_ip # The `self` variable is like `this` in many programming languages
      type        = "ssh"          # in this case, `self` is the resource (the server).
      user        = var.ssh_user
      private_key = file(var.private_key)
      #need to increase timeout to larger then 5m for metal instances
      timeout = "5m"
      agent   = "false"
    }
  }

  ################################################################################
  # Deployment related
  ################################################################################

  #########################
  # Install node exporter #
  #########################
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.ssh_user} --private-key ${var.private_key} ./playbooks/common/node-exporter.yml -i ${self.public_ip},"
  }
}
