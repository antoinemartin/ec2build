Forked version: 

Step 1: Compile linux-ec2 linux-ec2-headers and ec2arch

Step 2: Copy compiled packages to ./repo
        repo-add ec2.db.tar.gz *.pkg.*

Step 3: Make a New EBS volume and attach to /dev/xvd?

Step 4: run makeac2.sh

Step 5: Make snapshot of your finished EBS volume.

Step 6: Register your ami

 i386:
   ec2-register --region eu-west-1 --architecture i386 --kernel aki-47eec433 --root-device-name /dev/sda --snapshot snap-92cba0fa --name Archlinux-i386-3.0-20111221 

 x86_64:
   ec2-register -C cert-.pem -K pk-.pem -a x86_64 --root-device-name /dev/sda --kernel aki-4e7d9527 -n aminame -s snap-id
