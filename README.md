# mi-qutic-kivi

This repository is based on [Joyent mibe](https://github.com/jfqd/mibe).

## description

kivi lx-brand ubuntu 22.04 image, with kivitendo version 3.8.0

For upgade notes please use the [documentation](https://github.com/kivitendo/kivitendo-erp/blob/master/doc/UPGRADE).

## Build Image

```
cd /opt/mibe/repos
/opt/tools/bin/git clone https://github.com/jfqd/mi-qutic-kivi.git
LXBASE_IMAGE_UUID=$(imgadm list | grep qutic-lx-base | tail -1 | awk '{ print $1 }')
TEMPLATE_ZONE_UUID=$(vmadm lookup alias='qutic-lx-template-zone')
../bin/build_lx $LXBASE_IMAGE_UUID $TEMPLATE_ZONE_UUID mi-qutic-kivi && \
  imgadm install -m /opt/mibe/images/qutic-kivi-*-imgapi.dsmanifest \ 
                 -f /opt/mibe/images/qutic-kivi-*.zfs.gz
```

## Known Issues

The systemd-service for the kivitendo-api is currently not working!

(c) 2019-2023 qutic development GmbH