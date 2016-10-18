#!/bin/bash

# Written and maintained by Anders Kvist <anderskvist@gmail.com>

# Requirements for this script to work
for R in fakeroot alien dpkg-deb; do
    command -v ${R} >/dev/null 2>&1 || { echo >&2 "Command '${R}' is required."; exit 1; }
done

# Hardcoded URL for the first tests
URL='http://downloads.dell.com/FOLDER02413874M/1/dell-dset-lx64-3.7.0.219.bin'

# The filename
FILE=$(echo ${URL}|rev|cut -d"/" -f1|rev)

TMP=/tmp/Dell-DSET-deb-creator_$(date +%s%N|sha256sum|awk '{print $1}')

# Create our temporary directories
mkdir ${TMP}
mkdir ${TMP}/extract # where we extract the origial binary
mkdir ${TMP}/dell-dset-for-debian # where we'll extract the deb files
mkdir ${TMP}/dell-dset-for-debian/DEBIAN # Debian control files for re-packaging

cd ${TMP}
wget ${URL}

# Grabbed from dell-dset-lx64-3.7.0.219.bin (might need updating later on) but modified to use ${FILE} instead of ${0}
ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' ${FILE}`
tail -n+$ARCHIVE ${FILE} | tar xzv -C extract > /dev/null 2>&1

# Convert rpm to deb with alien
fakeroot alien --scripts extract/rpms/dell-dset-collector-3.7.0.219-1.x86_64.rpm extract/rpms/dell-dset-common-3.7.0.219-1.x86_64.rpm extract/rpms/dell-dset-provider-3.7.0.219-1.x86_64.rpm

# Extract the content of our newly created deb files
dpkg -x dell-dset-collector_3.7.0.219-2_amd64.deb dell-dset-for-debian/
dpkg -x dell-dset-common_3.7.0.219-2_amd64.deb dell-dset-for-debian/
dpkg -x dell-dset-provider_3.7.0.219-2_amd64.deb dell-dset-for-debian/

# Grabbed and merged from postinst in all 3 packages
cat <<EOF > dell-dset-for-debian/DEBIAN/postinst
#!/bin/bash
ln -sf /opt/dell/advdiags/dset/bin/collector.sh /usr/sbin/dellsysteminfo
ln -sf /opt/dell/advdiags/dset/uninstall.sh /usr/sbin/dsetuninstall
ldconfig

# OUR OWN TO SUPPORT UBUNTU! We will not remove them again as we don't know if anything else have created them :/
if [ ! -e /bin/awk ]; then
  ln -s /usr/bin/awk /bin/
fi

if [ ! -e /bin/basename ]; then
  ln -s /usr/bin/basename /bin/
fi

if [ ! -e /bin/sort ]; then
  ln -s /usr/bin/sort /bin/
fi

if [ ! -e /bin/rpm ]; then
  ln -s /usr/bin/rpm /bin/
fi

if [ ! -e /etc/omreg.cfg ]; then
  ln -s /opt/dell/advdiags/dset/bin/omsa/etc/omreg.cfg /etc/
fi
EOF

chmod +x dell-dset-for-debian/DEBIAN/postinst

# Grabbed and merged from postrm in all 3 packages
cat <<EOF > dell-dset-for-debian/DEBIAN/postrm
#!/bin/bash
rm -rf /usr/sbin/dellsysteminfo
rm -rf /usr/sbin/dsetuninstall
ldconfig
EOF

chmod +x dell-dset-for-debian/DEBIAN/postrm

# Grabbed and merged from triggers in all 3 packages
cat <<EOF > dell-dset-for-debian/DEBIAN/triggers
activate-noawait ldconfig
EOF

# Inspired by control in all 3 packages
cat <<EOF > dell-dset-for-debian/DEBIAN/control
Package: dell-dset-for-debian
Version: 3.7.0.219-2
Depends: rpm, sfcb
Architecture: amd64
Maintainer: https://github.com/anderskvist/Dell-DSET-deb-creator <anderskvist@gmail.com>
Section: alien
Priority: extra
Description: Dset common files
 Dell DSET package for debian based systems
EOF

# Create GOD package - MUHAHAHAHA ;)
dpkg-deb --build dell-dset-for-debian/ ..

# Remove our temporary directory
rm -rf ${TMP}
