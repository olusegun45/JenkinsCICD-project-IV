# the following are meta argument with terraform
Count

depend on:

provisioner: 1. to perform certain action remotely in a maachine and also local system.e.g to capture the ip of an ec2 machine w/o going through mgt console. it can be apply at creation or destroying time. It can be use to bootrap metadata along with the machine userdata.Type: File provisioner, Remote exec provisioner, local exec provisioner; 
File provisioner can be use to copy files or directories from a certain location to a certain remote system. Remote exec provisioneri use to run or boostrap any comand in the system. local exec provisioner is use to capture any metadata or atribute of any machine e.g dns, network interface, ip address etc and store it locally.
Provisioner authentication: Connection block manages terraform authentication to the remote system. for ssh we need to provide the private key path and specific username e.g ubuntu, centos, or ec2-user for ubuntu, centos and amazon linux 2 machine respectively.


For each
lifcycle

#  To replace all same phrase at once with a new phrase ~~~>>> Ctrl + Shift + L  and paste the new phrase.