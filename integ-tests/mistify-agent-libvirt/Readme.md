Verified only on Ubuntu 14.04

==Requirements==
librarian-ansible ruby gem
python-lxc python module
lxc linux package
ansible linux package

Execute the below command inside integ-tests/mistify-agent-libvirt/ if you have bundler (suggested)
```bundle install```

or use standard gem install
```gem install librarian-ansible```

To run the playbook
librarian-ansible install
ansible-playbook provision-container.yml