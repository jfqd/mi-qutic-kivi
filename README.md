# mi-qutic-kiwifrei

This repository is based on [Joyent mibe](https://github.com/jfqd/mibe).

## description

kiwifrei lx-brand ubuntu 24.04 image

## Build Image

```
cd /opt/mibe/repos
/opt/tools/bin/git clone https://github.com/jfqd/mi-qutic-kiwifrei.git
LXBASE_IMAGE_UUID=$(imgadm list | grep qutic-lx-base | tail -1 | awk '{ print $1 }')
TEMPLATE_ZONE_UUID=$(vmadm lookup alias='qutic-lx-template-zone')
../bin/build_lx $LXBASE_IMAGE_UUID $TEMPLATE_ZONE_UUID mi-qutic-kiwifrei && \
  imgadm install -m /opt/mibe/images/qutic-kiwifrei-*-imgapi.dsmanifest \ 
                 -f /opt/mibe/images/qutic-kiwifrei-*.zfs.gz
```

(c) 2019-2026 qutic development GmbH