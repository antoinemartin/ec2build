Introduction
============

This little script builds an [Archlinux](http://www.archlinux.org) [AWS EC2] (http://aws.amazon.com/fr/ec2/) image 
on an EBS Volume.


Pre-requisites
==============

First you need to build the [linux-ec2](http://github.com/antoinemartin/linux-ec2) and 
[ec2arch](http://github.com/antoinemartin/ec2arch) packages. linux-ec2 is a modified
version of the stock Archlinux linux kernel with the required modifications to run on EC2. 
ec2arch is a small script to be run at instance startup to setup the instance.


Instructions
============


* Copy the compiled packages to ./repo
* Build the local repository database:

    repo-add ec2.db.tar.gz *.pkg.*

* Make a 15 GB EBS volume and attach it to the instance. It will be known to the instance as `/dev/xvd?`
* Run makearchec2.sh specifying the device

    ./makearchec2.sh /dev/xvd?
    
* Make a snapshot of your finished EBS volume
* Register your AMI

Example on i386 and region eu-west-1:

    ec2-register --region eu-west-1 --architecture i386 --kernel aki-47eec433 --root-device-name /dev/sda --snapshot snap-xxxx --name Archlinux-i386-3.0-20111221 

`aki-47eec433` is the kernel image name for the architecture and the region of the image. [This PDF](http://www.google.fr/url?sa=t&rct=j&q=ec2%20pv-grub%20kernel%20images&source=web&cd=1&ved=0CCIQFjAA&url=https%3A%2F%2Fforums.aws.amazon.com%2Fservlet%2FJiveServlet%2Fdownload%2F30-51562-194272-3595%2Fuser_specified_kernels.pdf&ei=ugQHT_u_BdKOsAaOlZWCDw&usg=AFQjCNEm7T6n0ZwyEQFm61CaufngXMEACw&cad=rja)
contains the names of all the kernels images depending on architecture and location.


TODO
====

This script is meant to be run on EC2. However, it can easily be adapted to produce a S3 based AMI.

The changes to be done are:

* Modify the disk layout of the image to adapt it to an S3 based AMI
* Add the commands to bundle the image and upload it to S3