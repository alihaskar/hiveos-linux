#!/usr/bin/env bash

#!/usr/bin/env bash

[[ `ps aux | grep "./noncerpro-cuda" | grep -v grep | wc -l` != 0 ]] &&
  echo -e "${RED}$MINER_NAME miner is already running${NOCOLOR}" &&
  exit 1

cd $MINER_DIR/$MINER_VER

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MINER_DIR}/${MINER_VER}

./noncerpro-cuda $(< ./miner.conf) --api=true --apiport=${MINER_API_PORT} 2>&1 | tee --append $MINER_LOG_BASENAME.log
