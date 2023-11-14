#!/bin/bash

cp src/bmm deb/bmm/bin/bmm
cd deb
rm changelog.Debian.gz
gedit changelog.Debian
cp changelog.Debian changelog2.Debian
gzip --best -n changelog.Debian
cp changelog.Debian.gz bmm/usr/share/doc/bmm/
mv changelog2.Debian changelog.Debian
gedit bmm/DEBIAN/control
dpkg-deb --root-owner-group --build bmm
lintian bmm.deb
sudo apt install ./bmm.deb
cd ..
