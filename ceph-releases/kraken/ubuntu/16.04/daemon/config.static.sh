#!/bin/bash
set -e

function get_admin_key {
   # No-op for static
   log "static: does not generate admin key"
}

function get_mon_config {
  # IPv4 is the default unless we specify it
  IP_LEVEL=${1:-4}

  if [ ! -e /etc/ceph/${CLUSTER}.conf ]; then
    local fsid=$(uuidgen)
    cat <<ENDHERE >/etc/ceph/${CLUSTER}.conf
[global]
fsid = $fsid
mon initial members = ${MON_NAME}
mon host = ${MON_IP}
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
public network = ${CEPH_PUBLIC_NETWORK}
cluster network = ${CEPH_CLUSTER_NETWORK}
osd journal size = ${OSD_JOURNAL_SIZE}
ENDHERE
    if [ $IP_LEVEL -eq 6 ]; then
      echo "ms bind ipv6 = true" >> /etc/ceph/${CLUSTER}.conf
    fi
  else
    # extract fsid from ceph.conf
    fsid=`grep "fsid" /etc/ceph/${CLUSTER}.conf |awk '{print $NF}'`
  fi

  if [ ! -e $ADMIN_KEYRING ]; then
    # Generate administrator key
    ceph-authtool $ADMIN_KEYRING --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
  fi

  if [ ! -e $MON_KEYRING ]; then
    # Generate the mon. key
    ceph-authtool $MON_KEYRING --create-keyring --gen-key -n mon. --cap mon 'allow *'
  fi

  if [ ! -e $OSD_BOOTSTRAP_KEYRING ]; then
    # Generate the OSD bootstrap key
    ceph-authtool $OSD_BOOTSTRAP_KEYRING --create-keyring --gen-key -n client.bootstrap-osd --cap mon 'allow profile bootstrap-osd'
  fi

  if [ ! -e $MDS_BOOTSTRAP_KEYRING ]; then
    # Generate the MDS bootstrap key
    ceph-authtool $MDS_BOOTSTRAP_KEYRING --create-keyring --gen-key -n client.bootstrap-mds --cap mon 'allow profile bootstrap-mds'
  fi

  if [ ! -e $RGW_BOOTSTRAP_KEYRING ]; then
    # Generate the RGW bootstrap key
    ceph-authtool $RGW_BOOTSTRAP_KEYRING --create-keyring --gen-key -n client.bootstrap-rgw --cap mon 'allow profile bootstrap-rgw'
  fi

    # Apply proper permissions to the keys
    chown ceph. $MON_KEYRING $OSD_BOOTSTRAP_KEYRING $MDS_BOOTSTRAP_KEYRING $RGW_BOOTSTRAP_KEYRING

  if [ ! -e $MONMAP ]; then
    if [ -e /etc/ceph/monmap ]; then
      # Rename old monmap
      mv /etc/ceph/monmap $MONMAP
    else
      # Generate initial monitor map
      monmaptool --create --add ${MON_NAME} "${MON_IP}:6789" --fsid ${fsid} $MONMAP
    fi
    chown ceph. $MONMAP
  fi

}

function get_config {
   # No-op for static
   log "static: does not generate config"
}
