#!/bin/sh
#
# This shell will make and install these four libs in order:
#     libfastcommon
#     libserverframe
#     fastDIR
#     faststore
#
# If no source code in build path, it will git clone from:
#     https://github.com/happyfish100/libfastcommon.git
#     https://github.com/happyfish100/libserverframe.git
#     https://github.com/happyfish100/fastDIR.git
#     https://github.com/happyfish100/faststore.git
#

# FastCFS modules and repositores
COMMON_LIB="libfastcommon"
COMMON_LIB_URL="https://github.com/happyfish100/libfastcommon.git"
FRAME_LIB="libserverframe"
FRAME_LIB_URL="https://github.com/happyfish100/libserverframe.git"
FDIR_LIB="fastDIR"
FDIR_LIB_URL="https://github.com/happyfish100/fastDIR.git"
STORE_LIB="faststore"
STORE_LIB_URL="https://github.com/happyfish100/faststore.git"

DEFAULT_CLUSTER_SIZE=3
DEFAULT_HOST=127.0.0.1
DEFAULT_BIND_ADDR=

# fastDIR config default properties
FDIR_DEFAULT_BASE_PATH=/usr/local/fastdir
FDIR_DEFAULT_CLUSTER_PORT=11011
FDIR_DEFAULT_SERVICE_PORT=21011

# faststore config default properties
FSTORE_DEFAULT_BASE_PATH=/usr/local/faststore
FSTORE_DEFAULT_CLUSTER_PORT=31011
FSTORE_DEFAULT_SERVICE_PORT=41011
FSTORE_DEFAULT_REPLICA_PORT=51011
FSTORE_DEFAULT_STORE_PATH_COUNT=2

# fuse config default properties
FUSE_DEFAULT_BASE_PATH=/usr/local/fuse

BUILD_PATH="build"
mode=$1    # pull, make, install or clean 
make_shell=make.sh
same_host=false

pull_source_code() {
  if [ $# != 2 ]; then
    echo "$0: fatal error: pull_source_code() function need repository name and url!"
    exit 1
  fi

  module_name=$1
  module_url=$2
  if ! [ -d $module_name ]; then
    echo "The $module_name local repository does not exist!"
    echo "=====Begin to clone $module_name , it will take some time...====="
    git clone $module_url
  else
    echo "The $module_name local repository have existed."
    cd $module_name
    echo "=====Begin to pull $module_name, it will take some time...====="
    git pull
    cd ..
  fi
}

make_op() {
  if [ $# != 2 ]; then
    echo "$0: fatal error: make_clean() function need repository name and mode!"
    exit 1
  fi

  module_name=$1
  make_mode=$2

  if ! [ -d $BUILD_PATH/$module_name ]; then
    echo "$0: fatal error: module repository {$module_name} does not exist!"
    echo "You must checkout from remote repository first!"
    exit 1
  else  
    cd $BUILD_PATH/$module_name/
    echo "=====Begin to $make_mode module $module_name...====="
    command="./$make_shell $make_mode"
    echo "Execute command=$command,path=$PWD"
    if [ $make_mode = "make" ]; then
        result=`./$make_shell`
      else
        result=`./$make_shell $make_mode`
    fi
    cd -
  fi
}

sed_replace()
{
    sed_cmd=$1
    filename=$2
    echo "sed_cmd in sed_replace:{$sed_cmd}"
    echo "filename in sed_replace:{$filename}"
    if [ "$uname" = "FreeBSD" ] || [ "$uname" = "Darwin" ]; then
       sed -i "" "$sed_cmd" "$filename"
    else
       sed -i "$sed_cmd" "$filename"
    fi
}

split_to_array() {
  IFS=',' read -ra $2 <<< "$1"
}

placeholder_replace() {
  filename=$1
  placeholder=$2
  value=$3
  echo "arg 1 in placeholder_replace:$filename"
  sed_replace "s#\${$placeholder}#$value#g" $filename
}

validate_fastdir_params() {
  # Validate fastDIR cluster size
  if [[ $dir_cluster_size -le 0 ]]; then
    echo "--dir-cluster-size not specified, would use default size: $DEFAULT_CLUSTER_SIZE"
    dir_cluster_size=$DEFAULT_CLUSTER_SIZE
  fi
  # Validate fastDIR base_path
  if [[ ${#dir_pathes[*]} -eq 0 ]]; then
    echo "--dir-path not specified, would use default path: $FDIR_DEFAULT_BASE_PATH"
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_pathes[$i]="$FDIR_DEFAULT_BASE_PATH/server-$(( $i + 1 ))"
    done
  elif [[ ${#dir_pathes[*]} -eq 1 ]] && [[ ${#dir_pathes[*]} -lt $dir_cluster_size ]]; then
    tmp_base_path=${dir_pathes[0]}
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_pathes[$i]="$tmp_base_path/server-$(( $i + 1 ))"
    done
  elif [[ ${#dir_pathes[*]} -ne $dir_cluster_size ]]; then
    echo "--dir-path must be one base path, or number of it equal to --dir-cluster-size!"
    exit 1
  fi
  # Validate fastDIR host
  if [[ ${#dir_hosts[*]} -eq 0 ]]; then
    echo "--dir-host not specified, would use default host: $DEFAULT_HOST"
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_hosts[$i]=$DEFAULT_HOST
    done
    same_host=true
  elif [[ ${#dir_hosts[*]} -eq 1 ]] && [[ ${#dir_hosts[*]} -lt $dir_cluster_size ]]; then
    tmp_host=${dir_hosts[0]}
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_hosts[$i]=$tmp_host
    done
    same_host=true
  elif [[ ${#dir_hosts[*]} -ne $dir_cluster_size ]]; then
    echo "--dir-host must be one IP, or number of it equal to --dir-cluster-size!"
    exit 1
  fi
  # Validate fastDIR cluster port
  if [[ ${#dir_cluster_ports[*]} -eq 0 ]]; then
    echo "--dir-cluster-port not specified, would use default port: $FDIR_DEFAULT_CLUSTER_PORT,+1,+2..."
    for (( i=0; i < $dir_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        dir_cluster_ports[$i]=$(( $FDIR_DEFAULT_CLUSTER_PORT + $i ))
      else
        dir_cluster_ports[$i]=$FDIR_DEFAULT_CLUSTER_PORT
      fi
    done
  elif [[ ${#dir_cluster_ports[*]} -eq 1 ]] && [[ ${#dir_cluster_ports[*]} -lt $dir_cluster_size ]]; then
    tmp_port=${dir_cluster_ports[0]}
    for (( i=0; i < $dir_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        dir_cluster_ports[$i]=$tmp_port+$i
      else
        dir_cluster_ports[$i]=$tmp_port
      fi
    done
  elif [[ ${#dir_cluster_ports[*]} -ne $dir_cluster_size ]]; then
    echo "--dir-cluster-port must be one port, or number of it equal to --dir-cluster-size!"
    exit 1
  fi
  # Validate fastDIR service port
  if [[ ${#dir_service_ports[*]} -eq 0 ]]; then
    echo "--dir-service-port not specified, would use default port: $FDIR_DEFAULT_SERVICE_PORT,+1,+2..."
    for (( i=0; i < $dir_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        dir_service_ports[$i]=$(( $FDIR_DEFAULT_SERVICE_PORT + $i ))
      else
        dir_service_ports[$i]=$FDIR_DEFAULT_SERVICE_PORT
      fi
    done
  elif [[ ${#dir_service_ports[*]} -eq 1 ]] && [[ ${#dir_service_ports[*]} -lt $dir_cluster_size ]]; then
    tmp_port=${dir_service_ports[0]}
    for (( i=0; i < $dir_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        dir_service_ports[$i]=$tmp_port+$i
      else
        dir_service_ports[$i]=$tmp_port
      fi
    done
  elif [[ ${#dir_service_ports[*]} -ne $dir_cluster_size ]]; then
    echo "--dir-service-port must be one port, or number of it equal to --dir-cluster-size!"
    exit 1
  fi

  for (( i=0; i < $dir_cluster_size; i++ )); do
    if [[ ${dir_cluster_ports[$i]} -eq ${dir_service_ports[$i]} ]]; then
      echo "You must specify different port for --dir-cluster-port and --dir-service-port at same host!"
      exit 1
    fi
  done
  # Validate fastDIR bind_addr
  if [[ ${#dir_bind_addrs[*]} -eq 0 ]]; then
    echo "--dir-bind-addr not specified, would use default host: $DEFAULT_BIND_ADDR"
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_bind_addrs[$i]=$DEFAULT_BIND_ADDR
    done
  elif [[ ${#dir_bind_addrs[*]} -eq 1 ]] && [[ ${#dir_bind_addrs[*]} -lt $dir_cluster_size ]]; then
    tmp_bind_addr=${dir_bind_addrs[0]}
    for (( i=0; i < $dir_cluster_size; i++ )); do
      dir_bind_addrs[$i]=$tmp_host
    done
  elif [[ ${#dir_bind_addrs[*]} -ne $dir_cluster_size ]]; then
    echo "--dir-bind-addr must be one IP, or number of it equal to --dir-cluster-size!"
    exit 1
  fi
}

validate_faststore_params() {
  # Validate faststore cluster size
  if [[ $store_cluster_size -le 0 ]]; then
    echo "--store-cluster-size not specified, would use default size: $DEFAULT_CLUSTER_SIZE"
    store_cluster_size=$DEFAULT_CLUSTER_SIZE
  fi
  # Validate faststore base_path
  if [[ ${#store_pathes[*]} -eq 0 ]]; then
    echo "--store-path not specified, would use default path: $FSTORE_DEFAULT_BASE_PATH"
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_pathes[$i]="$FSTORE_DEFAULT_BASE_PATH/server-$(( $i + 1 ))"
    done
  elif [[ ${#store_pathes[*]} -eq 1 ]] && [[ ${#store_pathes[*]} -lt $store_cluster_size ]]; then
    tmp_base_path=${store_pathes[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_pathes[$i]="$tmp_base_path/server-$(( $i + 1 ))"
    done
  elif [[ ${#store_pathes[*]} -ne $store_cluster_size ]]; then
    echo "--store-path must be one base path, or number of it equal to --store-cluster-size!"
    exit 1
  fi
  # Validate faststore host
  if [[ ${#store_hosts[*]} -eq 0 ]]; then
    echo "--store-host not specified, would use default host: $DEFAULT_HOST"
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_hosts[$i]=$DEFAULT_HOST
    done
    same_host=true
  elif [[ ${#store_hosts[*]} -eq 1 ]] && [[ ${#store_hosts[*]} -lt $store_cluster_size ]]; then
    tmp_host=${store_hosts[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_hosts[$i]=$tmp_host
    done
    same_host=true
  elif [[ ${#store_hosts[*]} -ne $store_cluster_size ]]; then
    echo "--store-host must be one IP, or number of it equal to --store-cluster-size!"
    exit 1
  fi
  # Validate faststore cluster port
  if [[ ${#store_cluster_ports[*]} -eq 0 ]]; then
    echo "--store-cluster-port not specified, would use default port: $FSTORE_DEFAULT_CLUSTER_PORT,+1,+2..."
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_cluster_ports[$i]=$(( $FSTORE_DEFAULT_CLUSTER_PORT + $i ))
      else
        store_cluster_ports[$i]=$FSTORE_DEFAULT_CLUSTER_PORT
      fi
    done
  elif [[ ${#store_cluster_ports[*]} -eq 1 ]] && [[ ${#store_cluster_ports[*]} -lt $store_cluster_size ]]; then
    tmp_port=${store_cluster_ports[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_cluster_ports[$i]=$tmp_port+$i
      else
        store_cluster_ports[$i]=$tmp_port
      fi
    done
  elif [[ ${#store_cluster_ports[*]} -ne $store_cluster_size ]]; then
    echo "--store-cluster-port must be one port, or number of it equal to --store-cluster-size!"
    exit 1
  fi
  # Validate faststore service port
  if [[ ${#store_service_ports[*]} -eq 0 ]]; then
    echo "--store-service-port not specified, would use default port: $FSTORE_DEFAULT_SERVICE_PORT,+1,+2..."
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_service_ports[$i]=$(( $FSTORE_DEFAULT_SERVICE_PORT + $i ))
      else
        store_service_ports[$i]=$FSTORE_DEFAULT_SERVICE_PORT
      fi
    done
  elif [[ ${#store_service_ports[*]} -eq 1 ]] && [[ ${#store_service_ports[*]} -lt $store_cluster_size ]]; then
    tmp_port=${store_service_ports[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_service_ports[$i]=$tmp_port+$i
      else
        store_service_ports[$i]=$tmp_port
      fi
    done
  elif [[ ${#store_service_ports[*]} -ne $store_cluster_size ]]; then
    echo "--store-service-port must be one port, or number of it equal to --store-cluster-size!"
    exit 1
  fi

  for (( i=0; i < $store_cluster_size; i++ )); do
    if [[ ${store_cluster_ports[$i]} -eq ${store_service_ports[$i]} ]]; then
      echo "You must specify different port for --store-cluster-port and --store-service-port at same host!"
      exit 1
    fi
  done
  # Validate faststore replica port
  if [[ ${#store_replica_ports[*]} -eq 0 ]]; then
    echo "--store-replica-port not specified, would use default port: $FSTORE_DEFAULT_REPLICA_PORT,+1,+2..."
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_replica_ports[$i]=$(( $FSTORE_DEFAULT_REPLICA_PORT + $i ))
      else
        store_replica_ports[$i]=$FSTORE_DEFAULT_REPLICA_PORT
      fi
    done
  elif [[ ${#store_replica_ports[*]} -eq 1 ]] && [[ ${#store_replica_ports[*]} -lt $store_cluster_size ]]; then
    tmp_port=${store_replica_ports[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      if [[ $same_host = true ]]; then
        store_replica_ports[$i]=$tmp_port+$i
      else
        store_replica_ports[$i]=$tmp_port
      fi
    done
  elif [[ ${#store_replica_ports[*]} -ne $store_cluster_size ]]; then
    echo "--store-replica-port must be one port, or number of it equal to --store-cluster-size!"
    exit 1
  fi

  for (( i=0; i < $store_cluster_size; i++ )); do
    if [[ ${store_cluster_ports[$i]} -eq ${store_replica_ports[$i]} ]]; then
      echo "You must specify different port for --store-cluster-port and --store-replica-port at same host!"
      exit 1
    fi
  done
  # Validate faststore bind_addr
  if [[ ${#store_bind_addrs[*]} -eq 0 ]]; then
    echo "--store-bind-addr not specified, would use default host: $DEFAULT_BIND_ADDR"
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_bind_addrs[$i]=$DEFAULT_BIND_ADDR
    done
  elif [[ ${#store_bind_addrs[*]} -eq 1 ]] && [[ ${#store_bind_addrs[*]} -lt $store_cluster_size ]]; then
    tmp_bind_addr=${store_bind_addrs[0]}
    for (( i=0; i < $store_cluster_size; i++ )); do
      store_bind_addrs[$i]=$tmp_host
    done
  elif [[ ${#store_bind_addrs[*]} -ne $store_cluster_size ]]; then
    echo "--store-bind-addr must be one IP, or number of it equal to --store-cluster-size!"
    exit 1
  fi
  # Validate fuse path and mount point
  if [[ -z "$fuse_path" ]]; then
    echo "--fuse-path not specified, would use default path: $FUSE_DEFAULT_BASE_PATH"
    fuse_path=$FUSE_DEFAULT_BASE_PATH
  fi
  if [[ -z "$fuse_mount_point" ]]; then
    echo "--fuse-mount-point not specified, would use default point: $FUSE_DEFAULT_BASE_PATH/fuse1"
    fuse_mount_point=$FUSE_DEFAULT_BASE_PATH/fuse1
  fi
}

parse_init_arguments() {
  for arg do
    echo "{$arg}"
    case "$arg" in
      --dir-path=*)
        split_to_array ${arg#--dir-path=} dir_pathes
      ;;
      --dir-cluster-size=*)
        dir_cluster_size=${arg#--dir-cluster-size=}
      ;;
      --dir-host=*)
        split_to_array ${arg#--dir-host=} dir_hosts
      ;;
      --dir-cluster-port=*)
        split_to_array ${arg#--dir-cluster-port=} dir_cluster_ports
      ;;
      --dir-service-port=*)
        split_to_array ${arg#--dir-service-port=} dir_service_ports
      ;;
      --dir-bind-addr=*)
        split_to_array ${arg#--dir-bind-addr=} dir_bind_addrs
      ;;
      --store-path=*)
        split_to_array ${arg#--store-path=} store_pathes
      ;;
      --store-cluster-size=*)
        store_cluster_size=${arg#--store-cluster-size=}
      ;;
      --store-host=*)
        split_to_array ${arg#--store-host=} store_hosts
      ;;
      --store-cluster-port=*)
        split_to_array ${arg#--store-cluster-port=} store_cluster_ports
      ;;
      --store-service-port=*)
        split_to_array ${arg#--store-service-port=} store_service_ports
      ;;
      --store-replica-port=*)
        split_to_array ${arg#--store-replica-port=} store_replica_ports
      ;;
      --store-bind-addr=*)
        split_to_array ${arg#--store-bind-addr=} store_bind_addrs
      ;;
      # --fuse-path=*)
      #   split_to_array ${arg#--store-bind-addr=} store_bind_addrs
      # ;;
      --fuse-path=*)
        fuse_path=${arg#--fuse-path=}
      ;;
      --fuse-mount-point=*)
        fuse_mount_point=${arg#--fuse-mount-point=}
      ;;
    esac
  done
  validate_fastdir_params
  validate_faststore_params
}

check_config_file() {
  if ! [ -f $1 ]; then
    echo "$1 does not exist, can't init config from templates!"
    exit 1
  fi
}

init_fastdir_config() {
  # if [[ ${#dir_pathes[*]} -le 0 ]] || [[ $dir_cluster_size -le 0 ]]; then
  #   echo "Parameters --dir-path and dir-cluster-size not specified, would not config $FDIR_LIB"
  #   exit 1
  # fi
  # Init config fastDIR to target path.
  echo "Will initialize $dir_cluster_size instances for $FDIR_LIB..."

  SERVER_TPL="./conf/fastDIR/server.template"
  CLUSTER_TPL="./conf/fastDIR/cluster_servers.template"
  CLIENT_TPL="./conf/fastDIR/client.template"

  check_config_file $SERVER_TPL
  check_config_file $CLUSTER_TPL
  check_config_file $CLIENT_TPL

  for (( i=0; i < $dir_cluster_size; i++ )); do
    target_dir=${dir_pathes[$i]}/conf
    if [ -d $target_dir ]; then
      echo "The $ith $FDIR_LIB instance conf path \"$target_dir\" have existed, skip!"
      echo "If you want to reconfig it, you must delete it first."
      continue
    fi

    if ! mkdir -p $target_dir; then
      echo "Create target conf path failed:$target_dir!"
      exit 1
    fi

    t_server_conf=$target_dir/server.conf
    if cp -f $SERVER_TPL $t_server_conf; then
      # Replace placeholders with reality in server template
      echo "Begin config $t_server_conf..."
      placeholder_replace $t_server_conf BASE_PATH "${dir_pathes[$i]}"
      placeholder_replace $t_server_conf CLUSTER_BIND_ADDR "${dir_bind_addrs[$i]}"
      placeholder_replace $t_server_conf CLUSTER_PORT "${dir_cluster_ports[$i]}"
      placeholder_replace $t_server_conf SERVICE_BIND_ADDR "${dir_bind_addrs[$i]}"
      placeholder_replace $t_server_conf SERVICE_PORT "${dir_service_ports[$i]}"
    else
      echo "Create server.conf from $SERVER_TPL failed!"
    fi

    t_cluster_conf=$target_dir/cluster_servers.conf
    if cp -f $CLUSTER_TPL $t_cluster_conf; then
      # Replace placeholders with reality in cluster_servers template
      echo "Begin config $t_cluster_conf..."
      placeholder_replace $t_cluster_conf CLUSTER_PORT "${dir_cluster_ports[0]}"
      placeholder_replace $t_cluster_conf SERVICE_PORT "${dir_service_ports[0]}"
      placeholder_replace $t_cluster_conf SERVER_HOST "${dir_hosts[0]}"
      for (( j=1; j < $dir_cluster_size; j++ )); do
        #增加服务器section
        #[server-2]
        #cluster-port = 11013
        #service-port = 11014
        #host = myhostname
        echo "[server-$(( $j + 1 ))]" >> $t_cluster_conf
        echo "cluster-port = ${dir_cluster_ports[$j]}" >> $t_cluster_conf
        echo "service-port = ${dir_service_ports[$j]}" >> $t_cluster_conf
        echo "host = ${dir_hosts[$j]}" >> $t_cluster_conf
        echo "" >> $t_cluster_conf
      done
    else
      echo "Create cluster_servers.conf from $CLUSTER_TPL failed!"
    fi

    t_client_conf=$target_dir/client.conf
    if cp -f $CLIENT_TPL $t_client_conf; then
      # Replace placeholders with reality in client template
      echo "Begin config $t_client_conf..."
      placeholder_replace $t_client_conf BASE_PATH "${dir_pathes[$i]}"
      #替换fastDIR服务器占位符
      #dir_server = 192.168.0.196:11012
      t_dir_servers=""
      for (( j=0; j < $dir_cluster_size; j++ )); do
        t_dir_servers=$t_dir_servers"dir_server = ${dir_hosts[$j]}:${dir_service_ports[$j]}\n"
      done
      placeholder_replace $t_client_conf DIR_SERVERS "$t_dir_servers"
    else
      echo "Create client.conf from $CLIENT_TPL failed!"
    fi
  done
}

init_faststore_config() {
  # if [[ ${#store_pathes[*]} -le 0 ]] || [[ $store_cluster_size -le 0 ]]; then
  #   echo "Parameters --store-path and store-cluster-size not specified, would not config $FSTORE_LIB"
  #   exit 1
  # fi
  # Init config faststore to target path.
  echo "Will initialize $store_cluster_size instances for $FSTORE_LIB..."

  S_SERVER_TPL="./conf/faststore/server.template"
  S_CLUSTER_TPL="./conf/faststore/cluster.template"
  S_CLIENT_TPL="./conf/faststore/client.template"
  S_SERVERS_TPL="./conf/faststore/servers.template"
  S_STORAGE_TPL="./conf/faststore/storage.template"
  S_FUSE_TPL="./conf/faststore/fuse.template"

  check_config_file $S_SERVER_TPL
  check_config_file $S_CLUSTER_TPL
  check_config_file $S_CLIENT_TPL
  check_config_file $S_SERVERS_TPL
  check_config_file $S_STORAGE_TPL
  check_config_file $S_FUSE_TPL

  for (( i=0; i < $store_cluster_size; i++ )); do
    target_path=${store_pathes[$i]}/conf
    if [ -d $target_path ]; then
      echo "The $ith $FSTORE_LIB instance conf path \"$target_path\" have existed, skip!"
      echo "If you want to reconfig it, you must delete it first."
      continue
    fi

    if ! mkdir -p $target_path; then
      echo "Create target conf path failed:$target_path!"
      exit 1
    fi

    t_server_conf=$target_path/server.conf
    if cp -f $S_SERVER_TPL $ts_server_conf; then
      # Replace placeholders with reality in server template
      echo "Begin config $t_server_conf..."
      placeholder_replace $t_server_conf BASE_PATH "${store_pathes[$i]}"
      placeholder_replace $t_server_conf CLUSTER_BIND_ADDR "${store_bind_addrs[$i]}"
      placeholder_replace $t_server_conf CLUSTER_PORT "${store_cluster_ports[$i]}"
      placeholder_replace $t_server_conf SERVICE_BIND_ADDR "${store_bind_addrs[$i]}"
      placeholder_replace $t_server_conf SERVICE_PORT "${store_service_ports[$i]}"
      placeholder_replace $t_server_conf REPLICA_BIND_ADDR "${store_bind_addrs[$i]}"
      placeholder_replace $t_server_conf REPLICA_PORT "${store_replica_ports[$i]}"
    else
      echo "Create server.conf from $S_SERVER_TPL failed!"
    fi

    t_servers_conf=$target_path/servers.conf
    if cp -f $S_SERVERS_TPL $t_servers_conf; then
      # Replace placeholders with reality in servers template
      echo "Begin config $t_servers_conf..."
      placeholder_replace $t_servers_conf CLUSTER_PORT "${store_cluster_ports[0]}"
      placeholder_replace $t_servers_conf REPLICA_PORT "${store_replica_ports[0]}"
      placeholder_replace $t_servers_conf SERVICE_PORT "${store_service_ports[0]}"
      placeholder_replace $t_servers_conf SERVER_HOST "${store_hosts[0]}"
      for (( j=1; j < $store_cluster_size; j++ )); do
        #增加服务器section
        #[server-2]
        #cluster-port = 11013
        #replica-port = 21017
        #service-port = 11014
        #host = myhostname
        echo "[server-$(( $j + 1 ))]" >> $t_servers_conf
        echo "cluster-port = ${store_cluster_ports[$j]}" >> $t_servers_conf
        echo "replica-port = ${store_replica_ports[$j]}" >> $t_servers_conf
        echo "service-port = ${store_service_ports[$j]}" >> $t_servers_conf
        echo "host = ${store_hosts[$j]}" >> $t_servers_conf
        echo "" >> $t_servers_conf
      done
    else
      echo "Create servers.conf from $S_SERVERS_TPL failed!"
    fi

    t_client_conf=$target_path/client.conf
    if cp -f $S_CLIENT_TPL $t_client_conf; then
      # Replace placeholders with reality in client template
      echo "Begin config $t_client_conf..."
      placeholder_replace $t_client_conf BASE_PATH "${store_pathes[$i]}"
    else
      echo "Create client.conf from $S_CLIENT_TPL failed!"
    fi

    t_cluster_conf=$target_path/cluster.conf
    if cp -f $S_CLUSTER_TPL $t_cluster_conf; then
      # Replace placeholders with reality in cluster template
      echo "Begin config $t_storage_conf..."
      placeholder_replace $t_cluster_conf SERVER_GROUP_COUNT "1"
      placeholder_replace $t_cluster_conf DATA_GROUP_COUNT "16"
      placeholder_replace $t_cluster_conf SERVER_GROUP_1_SERVER_IDS "[1, 3]"
      placeholder_replace $t_cluster_conf DATA_GROUP_IDS "data_group_ids = [1, 8]\ndata_group_ids = [9, 16]"
    fi

    t_storage_conf=$target_path/storage.conf
    if cp -f $S_STORAGE_TPL $t_storage_conf; then
      # Replace placeholders with reality in storage template
      echo "Begin config $t_storage_conf..."
      placeholder_replace $t_storage_conf DATA1_PATH "${store_pathes[$i]}/storage_data1"
      placeholder_replace $t_storage_conf DATA2_PATH "${store_pathes[$i]}/storage_data2"
      placeholder_replace $t_storage_conf CACHE_PATH "${store_pathes[$i]}/storage_cache"
    fi

    if [[ $same_host = false ]] || [[ $i -eq 1 ]]; then
      t_fuse_conf=$target_path/fuse.conf
      if cp -f $S_FUSE_TPL $t_fuse_conf; then
        # Replace placeholders with reality in fuse template
        echo "Begin config $t_fuse_conf..."
        placeholder_replace $t_fuse_conf BASE_PATH "$fuse_path"
        placeholder_replace $t_fuse_conf FUSE_MOUNT_POINT "$fuse_mount_point"
        #替换fastDIR服务器占位符
        #dir_server = 192.168.0.196:11012
        t_dir_servers=""
        for (( j=0; j < $dir_cluster_size; j++ )); do
          t_dir_servers=$t_dir_servers"dir_server = ${dir_hosts[$j]}:${dir_service_ports[$j]}\n"
        done
        placeholder_replace $t_fuse_conf DIR_SERVERS "$t_dir_servers"
      else
        echo "Create fuse.conf from $S_FUSE_TPL failed!"
      fi
    fi
  done
}

case "$mode" in
  'pull')
    # Clone or pull source code from github.com if not exists.

    echo "Begin to pull source codes..."
    # Create build path if not exists.
    if ! [ -d $BUILD_PATH ]; then
      mkdir -m 775 $BUILD_PATH
      echo "Build path: {$BUILD_PATH} not exist, created."
    fi
    cd $BUILD_PATH
    
    # Pull libfastcommon
    pull_source_code $COMMON_LIB $COMMON_LIB_URL 

    # Pull libserverframe
    pull_source_code $FRAME_LIB $FRAME_LIB_URL

    # Pull fastDIR
    pull_source_code $FDIR_LIB $FDIR_LIB_URL

    # Pull faststore
    pull_source_code $STORE_LIB $STORE_LIB_URL
    cd ..
  ;;

  'makeinstall')
    # Make and install all lib repositories sequentially.
    make_op $COMMON_LIB make
    make_op $COMMON_LIB install
    make_op $FRAME_LIB make
    make_op $FRAME_LIB install
    make_op $FDIR_LIB make
    make_op $FDIR_LIB install
    make_op $STORE_LIB make
    make_op $STORE_LIB install
  ;;

  'init')
    # Config FastDIR and faststore cluster.
    echo "param count:$#"
    if [[ $# -lt 3 ]]; then 
      basename=`basename "$0"`
      echo "Usage: $basename init \\"
      echo "	--dir-path=/usr/local/fastcfs2/fastdir \\"
      echo "	--dir-cluster-size=3 \\"
      echo "	--dir-host=192.168.142.137,192.168.142.137,192.168.142.137 \\"
      echo "	--dir-cluster-port=11011,11012,11013 \\"
      echo "	--dir-service-port=21011,21012,21013 \\"
      echo "	--dir-bind-addr=192.168.142.137 \\"
      echo "	--store-path=/usr/local/fastcfs2/faststore \\"
      echo "	--store-cluster-size=3 \\"
      echo "	--store-host=192.168.142.137,192.168.142.137,192.168.142.137 \\"
      echo "	--store-cluster-port=31011,31012,31013 \\"
      echo "	--store-service-port=41011,41012,41013 \\"
      echo "	--store-replica-port=51011 \\"
      echo "	--store-bind-addr=192.168.142.137 \\"
      echo "	--fuse-path=/usr/local/fuse \\"
      echo "	--fuse-mount-point=/usr/local/fuse/fuse1"
    else
      parse_init_arguments $*
      init_fastdir_config
      init_faststore_config
    fi
  ;;

  'clean')
    # Clean all lib repositories
    make_op $COMMON_LIB clean
    make_op $FRAME_LIB clean
    make_op $FDIR_LIB clean
    make_op $STORE_LIB clean
  ;;

  *)
    # usage
    basename=`basename "$0"`
    echo "Usage: $basename {pull|makeinstall|init|clean} [options]"
    exit 1
  ;;
esac

exit 0