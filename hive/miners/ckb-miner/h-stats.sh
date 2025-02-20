#!/usr/bin/env bash

#######################
# Functions
#######################

#. /hive-config/wallet.conf

get_hashes(){
  #Eaglesong-Worker-GPU-0 [01:15:19] hash rate: 157081456.621 / seals found:         89
  hs=''
  khs=0
  local t_hs=0
  #get gpus hashes
  [[ $CKB_MINER_OPENCL -eq 1 ]] && local platform="CL" || platform="CU"
  if [[ $gpu_count -gt 0 ]]; then
    for t_gpu in `echo $gpu_indexes_array | tr "," " "`; do
      t_hs=`cat $log_name | tail -n 100 | grep "\-GPU\-${platform}\-$t_gpu" | tail -1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | tr -cd "[:print:]\n" | egrep -o '*hash\ rate: ([0-9\.])+' | awk '{ print $3 }'`
      hs+="$t_hs "
      khs=`echo $khs $t_hs | awk '{ printf("%.6f", $1 + $2/1000) }'`
      bus_numbers+=`echo $gpu_detect_json | jq -r '.['$t_gpu'].busid' | awk '{printf("%d\n", "0x"$1)}'`" "
    done
  fi
  #get cpu hashes
  if [[ $cpu_count -gt 0 ]]; then
    for (( t_cpu=0; t_cpu < $cpu_count; t_cpu++ )); do
      t_hs=`cat $log_name | tail -n 100 | grep "\-Worker\-CPU\-$t_cpu" | tail -1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | tr -cd "[:print:]\n" | egrep -o '*hash\ rate: ([0-9\.])+' | awk '{ print $3 }'`
      hs+="$t_hs "
      khs=`echo $khs $t_hs | awk '{ printf("%.6f", $1 + $2/1000) }'`
      bus_numbers+="null "
    done
  fi
}

get_miner_uptime(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $1`
  echo $a
}

get_log_time_diff(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $log_name`
  echo $a
}

get_cpu_temps(){
  local i=0
  local tcore=`cpu-temp`
  local l_num_cores=$1
  local l_temp=

  if [[ ! -z tcore ]]; then
    for (( i=0; i < ${l_num_cores}; i++ )); do
      l_temp+="$tcore "
    done
    echo $l_temp
  fi
}

#######################
# MAIN script body
#######################

local rig_conf_str=`cat /hive-config/rig.conf | grep $MINER_NAME`
index=${rig_conf_str:5:1}
[[ $index == "=" ]] && index=1

local log_name="/run/hive/miner.$index"
local ver=`miner_ver`

local bus_numbers=

local conf_name="/run/hive/miners/$MINER_NAME/$MINER_NAME.toml"

gpu_indexes_array=`cat $conf_name | grep gpu_ids | tr -d " " | sed 's/gpu_ids=//' | egrep -o '([0-9\,])+'`
gpu_count=`echo $gpu_indexes_array | tr "," " " | wc -w`

local temp_l=`jq '.temp' <<< $gpu_stats`
local fan_l=`jq '.fan' <<< $gpu_stats`

#[[ -z $GPU_COUNT_NVIDIA ]] &&
#  GPU_COUNT_NVIDIA=`gpu-detect NVIDIA`

if [[ $gpu_count -gt 0 ]]; then
#   if [[ $CKB_MINER_OPENCL -eq 1 ]]; then
#     local temp=`jq -c "[.temp$amd_indexes_array]" <<< $gpu_stats`
#     local fan=`jq -c "[.fan$amd_indexes_array]" <<< $gpu_stats`
#   else
#     local temp=`jq -c "[.temp$nvidia_indexes_array]" <<< $gpu_stats`
#     local fan=`jq -c "[.fan$nvidia_indexes_array]" <<< $gpu_stats`
#   fi

  temp_l=`jq -c "[.[$gpu_indexes_array]]" <<< $temp_l`
  fan_l=`jq -c "[.[$gpu_indexes_array]]" <<< $fan_l`
fi

cpu_count=`cat $conf_name | grep cpus | tr -d " " | sed 's/cpus=//'`

if [[ $cpu_count -gt 0 ]]; then
  local cpu_temp=`get_cpu_temps $cpu_count`
  cpu_temp=`echo ${cpu_temp[@]} | tr " " "\n" | jq -cs '.'`

  temp_l=`jq -s '.[0] + .[1]' <<< "$temp $cpu_temp"`
fi

# Calc log freshness
local diffTime=`get_log_time_diff`
local maxDelay=120

# echo $diffTime

local algo="eaglesong"

# If log is fresh the calc miner stats or set to null if not
if [ "$diffTime" -lt "$maxDelay" ]; then
  get_hashes # hashes array
  local hs_units='hs' # hashes utits
  local uptime=`get_miner_uptime $conf_name` # miner uptime
  local acc=`cat $log_name | tail -n 100 | grep "Total seals found: " | tail -1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | tr -cd "[:print:]\n" | awk '{ print $4 }'`
  [[ -z $acc ]] && acc=0

# make JSON
#--argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \

  stats=$(jq -nc \
        --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
        --arg hs_units "$hs_units" \
        --argjson temp "$temp_l" \
        --argjson fan "$fan_l" \
        --arg uptime "$uptime" \
        --arg acc "$acc" \
        --arg algo "$algo" \
        --arg ver "$ver" \
        --argjson bus_numbers "`echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.'`" \
       '{$hs, $hs_units, ar: [$acc,0], $temp, $fan, $uptime, $algo, $bus_numbers, $ver}')
else
  stats=""
  khs=0
fi

# debug output
##echo temp:  $temp
##echo fan:   $fan
#echo stats: $stats
#echo khs:   $khs
