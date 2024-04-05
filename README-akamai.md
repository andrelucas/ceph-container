# README for Akamai Ceph tweaks to ceph-container.

XXX WIP XXX

## Building

We have to override the base image: `centos:8` doesn't work any more, as Red
Hat have 'retired' it.

You need to have a Yum repository set up so the tools can download your Ceph RPMs. tooling XXX

```sh
make FLAVORS=reef,centos,8 \
    BASEOS_REGISTRY=quay.io/centos BASEOS_REPO=centos BASEOS_TAG=stream8 \
    CUSTOM_CEPH_YUM_REPO=http://SERVER:PORT/ \
    build
```

