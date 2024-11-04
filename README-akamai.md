# README for Akamai Ceph tweaks to ceph-container.

<!-- vscode-markdown-toc -->
* [Build changes](#Buildchanges)
	* [Overriding the base OS image](#OverridingthebaseOSimage)
	* [Using a separate Yum repository](#UsingaseparateYumrepository)
		* [Implementation](#Implementation)
* [Other configuration variables](#Otherconfigurationvariables)
* [Generating just the Docker source files](#GeneratingjusttheDockersourcefiles)

<!-- vscode-markdown-toc-config
	numbering=false
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

We've had to make a few tweaks to ceph-container to build standard-ish
container images in April 2024. Further (minor) changes were made in June 2024
to deal with Red Hat's retirement of CentOS Stream 8 at the end of May 2024.

## <a name='Buildchanges'></a>Build changes

### <a name='OverridingthebaseOSimage'></a>Overriding the base OS image

As of June 2024 the upstream standard builds has changed to CentOS stream 9.
We still are specific about the 'stream9' tag we specify.

```sh
make FLAVORS=reef,centos,9 \
    BASEOS_REGISTRY=quay.io/centos BASEOS_REPO=centos BASEOS_TAG=stream9 \
    build
```

This command alone will build a standard container, using upstream RPMs.
That's probably not what you want, though.

### <a name='UsingaseparateYumrepository'></a>Using a separate Yum repository

This is a more involved change. We have to change the location from which the
Ceph RPMs are pulled. The details of setting up a yum repository are handled
in the akceph-build tool, but the code in this git repository (ceph-container)
also needs changes to take a custom Yum repository on the Makefile command
line.

The effect we want is that:

```sh
make FLAVORS=reef,centos,9 \
    BASEOS_REGISTRY=quay.io/centos BASEOS_REPO=centos BASEOS_TAG=stream9 \
    CUSTOM_CEPH_YUM_REPO=http://SERVER:PORT/ \
    build
```

will use the specified Yum repository as its root. We can specify a single URL
because we're assuming a particular structure:

```text
<ROOT>
 |- RPMS
 |- |- noarch
 |     ... The architecture-neutral RPM packages
 |- |- x86_64
 |     ... The architecture-specific RPM packages
 |- SRPMS
 |     ... The source RPM packages
```

(This is, not coincidentally, the structure of an `rpmbuild` tree.)

#### <a name='Implementation'></a>Implementation

With the web server structure above assumed, the changes to the template
`ceph-releases/ALL/centos/9/daemon-base/__DOCKERFILE_INSTALL__` create
(rather laboriously using `echo` commands) a Yum repo into the container
looking like this:

```ini
[Ceph]
name=Ceph packages for $basearch
baseurl=http://SERVER:PORT/RPMS/$basearch
enabled=1
gpgcheck=0
type=rpm-md

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://SERVER:PORT/RPMS/noarch
enabled=1
gpgcheck=0
type=rpm-md

[ceph-source]
name=Ceph source packages
baseurl=http://SERVER:PORT/SRPMS
enabled=1
gpgcheck=0
type=rpm-md
```

(Where SERVER:PORT are substituted by the tools to the appropriate values.)

It's not intended that we'll support using `dnf update` to update packages
inside the running container. The repository we use to install is ephemeral.

The only other change is to disable the fetch and install of the
`ceph-release-1-<VERSION>` package. This is a fairly common Red Hat idiom,
providing a package that configures a Yum repository. We _could_ do that, and
if we switch to building the RPMs into an Artifactory repository it might make
more sense. Today we don't.

## <a name='Otherconfigurationvariables'></a>Other configuration variables

The akceph-build tool also changes a few other variables passed to `make(1)`.

| Variable | Default | New value | Description |
| - | - | - | - |
| `RELEASE` | The branch/tag of the ceph-container repo | A verbose release description[1]. | Upstream must create a per-release branch of ceph-container to make this useful. We're not going to do that unless we have to. |
| `TAG_REGISTRY` | `ceph` (meaning `docker.io/ceph`) | Our Docker base | This is the prefix to every image. ceph-container generates three images (`daemon-base`, `daemon` and `demo`), and the first of these would become `ceph/daemon-base` with the default TAG_REGISTRY. We want to change this. |


[1]  The concatenation of the Ceph release and the commit ID. This is generated using `git describe` and looks like a number followed by '-g' then a commit hash.

## <a name='GeneratingjusttheDockersourcefiles'></a>Generating just the Docker source files

If you want to see the `Dockerfile`s from which containers are built, which
you _will_ want to do when debugging, you canb do the above command and change
the target to `stage` (check this is the same list of options as above, the
doc could get out of sync):

```sh
make FLAVORS=reef,centos,9 \
    BASEOS_REGISTRY=quay.io/centos BASEOS_REPO=centos BASEOS_TAG=stream9 \
    CUSTOM_CEPH_YUM_REPO=http://SERVER:PORT/ \
    stage
```

The `Dockerfile`s you seek are in `staging/reef-centos-9-x86_64`. It's safest
to do `rm -rf staging/*` beforehand or it won't reliably regenerate the
files. You can also do `make clean.all`, but that will delete a load of Docker
images as well which might not be what you want.
