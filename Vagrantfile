$bootstrap_ansible = <<-SHELL
echo "Installing Ansible..."
sudo apt-get update -y
sudo apt-get install -y software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update -y
sudo apt-get install -y ansible apt-transport-https
SHELL

$restart_kubelet = <<-SHELL
echo "Restarting Kubelet..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet
SHELL

require 'getoptlong'

opts = GetoptLong.new(
  [ '--memory', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--disk', GetoptLong::OPTIONAL_ARGUMENT ]
)

opts.ordering=(GetoptLong::REQUIRE_ORDER)

memory='4096'
disk='40GB'

opts.each do |opt, arg|
  case opt
    when '--memory'
      memory=arg
    when '--disk'
      disk=arg
  end
end

Vagrant.configure(2) do |config|
  unless Vagrant.has_plugin?("vagrant-disksize")
    raise Vagrant::Errors::VagrantError.new, "vagrant-disksize plugin is missing. Please install it using 'vagrant plugin install vagrant-disksize' and rerun 'vagrant up'"
  end

  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = "#{disk}"
  end

  config.vm.define "k8s-master" do |s|
    s.ssh.forward_agent = true
    s.vm.box = "ubuntu/focal64"
    s.vm.hostname = "k8s-master"
    s.vm.provision :shell,
      inline: $bootstrap_ansible
    s.vm.provision :shell,
      inline: "PYTHONUNBUFFERED=1 ansible-playbook /vagrant/ansible/master.yml -c local --extra-vars 'network=192.168.56 kubernetes_version=1.24.1'"
    s.vm.provision :shell,
      inline: "echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.56.10' | sudo tee /etc/default/kubelet"
    s.vm.provision :shell,
      inline: $restart_kubelet
    s.vm.network "private_network",
      ip: "192.168.56.10",
      netmask: "255.255.255.0",
      auto_config: true
      #virtualbox__intnet: "k8s-net"
    s.vm.provider "virtualbox" do |v|
      v.name = "k8s-master"
      v.cpus = 2
      v.memory = 4096
      v.gui = false
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      #v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
  end

  (1..3).each do |i|
    config.vm.define "k8s-worker-#{i}" do |s|
      s.ssh.forward_agent = true
      s.vm.box = "ubuntu/focal64"
      s.vm.hostname = "k8s-worker-#{i}"
      s.vm.provision :shell,
        inline: $bootstrap_ansible
      s.vm.provision :shell,
        inline: "PYTHONUNBUFFERED=1 ansible-playbook /vagrant/ansible/worker.yml -c local --extra-vars 'network=192.168.56 kubernetes_version=1.24.1'"
      s.vm.provision :shell,
        inline: "echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.56.#{i+10}' | sudo tee /etc/default/kubelet"
      s.vm.provision :shell,
        inline: $restart_kubelet
      s.vm.network "private_network",
        ip: "192.168.56.#{i+10}",
        netmask: "255.255.255.0",
        auto_config: true
        #virtualbox__intnet: "k8s-net"
      s.vm.provider "virtualbox" do |v|
        v.name = "k8s-worker-#{i}"
        v.cpus = 2
        v.memory = "#{memory}"
        v.gui = false
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        #v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end
    end
  end

end
