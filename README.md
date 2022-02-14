# mi-qutic-kivi

This repository is based on [Joyent mibe](https://github.com/jfqd/mibe).

## description

kivi lx-brand image, with kivitendo version 3.5.7

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

The service for the kivitendo-api is currently not working!
