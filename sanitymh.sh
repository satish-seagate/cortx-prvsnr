#!/bin/bash

set -e

############################
# Mero & Halon test script #
############################

dd if=/dev/urandom of=/tmp/128M bs=1M count=128

hctl mero status --json > mero_status.json
Profile=$(jq -r '.csrProfile' mero_status.json)
Fid=$(jq -r '.csrHosts[0][1].crnProcesses[0][0].r_fid' mero_status.json)
IPADDR=$(jq '.csrPrincipalRM.s_endpoints' mero_status.json | awk -F "@" '{if(NR==2) print $1}'| cut -c 4-)
cat <<EOF > sanity_io.yaml
CrateConfig_Sections: [MERO_CONFIG, WORKLOAD_SPEC]

MERO_CONFIG:
   MERO_LOCAL_ADDR: $IPADDR@tcp:12345:41:302
   MERO_HA_ADDR: $IPADDR@tcp:12345:34:101
   CLOVIS_PROF: <$Profile>  # Profile
   LAYOUT_ID: 1                     # Defines the UNIT_SIZE
   IS_OOSTORE: 1                    # Is oostore-mode?
   IS_READ_VERIFY: 0                # Enable read-verify?
   CLOVIS_TM_RECV_QUEUE_MIN_LEN: 16 # Minimum length of the receive queue
   CLOVIS_MAX_RPC_MSG_SIZE: 65536   # Maximum rpc message size
   CLOVIS_PROCESS_FID: <$Fid>
   CLOVIS_IDX_SERVICE_ID: 1

LOG_LEVEL: 4  # err(0), warn(1), info(2), trace(3), debug(4)

WORKLOAD_SPEC:               # Workload specification section
   WORKLOAD:                 # First Workload
      WORKLOAD_TYPE: 1       # Index(0), IO(1)
      WORKLOAD_SEED: tstamp  # SEED to the random number generator
      OPCODE: 3              # CREATE(0), DELETE(1), READ(2), WRITE(3)
      CLOVIS_IOSIZE: 4k      # Total Size of IO to perform per object
      BLOCK_SIZE: 4k         # In N+K conf set to (N * UNIT_SIZE) for max perf
      BLOCKS_PER_OP: 1       # Number of blocks per Clovis operation
      MAX_NR_OPS: 1          # Max concurrent operations per thread
      NR_OBJS: 1024           # Number of objects to create by each thread
      NR_THREADS: 1          # Number of threads to run in this workload
      RAND_IO: 1             # Random (1) or sequential (0) IO?
      MODE: 1                # Synchronous=0, Asynchronous=1
      THREAD_OPS: 0          # All threads write to the same object?
      NR_ROUNDS: 1           # Number of times this workload is run
      EXEC_TIME: unlimited   # Execution time (secs or "unlimited")
      SOURCE_FILE: /tmp/128M # Source data file
EOF

m0crate -S ./sanity_io.yaml -U
rm -f ./sanity_io.yaml
rm -f /tmp/128M