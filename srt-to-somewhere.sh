#!/bin/bash

temp_dir='/run'
this_dir=`pwd`
configs_dir="${this_dir}/srt-to-somewhere-configs"
YEL='\033[1;33m' # Yellow
CYA='\033[1;36m' # Cyan
NC='\033[0m'     # No Color
backtitle_global='Wrapper for ffmpeg srt inputs v.0.1.1'


trap trap_ctrl_c SIGINT SIGTERM
trap_ctrl_c() { exit 1 }


execute_config() {
  trap trap_ctrl_C_in_func SIGINT SIGTERM
  trap_ctrl_C_in_func() { ctrl_C_pressed=1  }
  while true; do
    echo ${string_in} ${string_transform} ${string_out}
    `${string_in} ${string_transform} ${string_out}`
    [[ ${ctrl_C_pressed} ]] && break
    sleep 1
  done
}
export -f execute_config


config_processing() {
  set -a
  . "${whiptail_result}"
  config_description=`basename "${whiptail_result}" .conf`
  set +a

  if [[ ! ${vars_needed} ]]; then
      echo "'vars_needed' empty or not set. Cannot continiue. Exiting..."
      exit
  fi
  for var_name in ${vars_needed}; do
    if [[ ! ${!var_name} ]]; then
      echo "'$var_name' empty or not set. Cannot continue."
      exiting=true
    fi
    # printf '%-30s = %s\n' "${var_name}" "${!var_name}"
  done
  if [[ $exiting ]] ; then echo "Exiting..." ; exit 1 ; fi

  # Check script with this description already running
  linecount=`screen -ls "${config_description}" | wc -l`
  if [[ ${linecount} -gt 2 ]] ; then
      #
      # File with this description in use by screen session
      #
      pid_of_screen=$(screen -S "${config_description}" -Q echo '$PID')
      ffmpeg_str_inuse=`ps --ppid ${pid_of_screen} -o pid  --no-headers | xargs ps -o args  --no-headers --ppid`
      choices=( 1 "Dive into screen session" )
      whiptail_result=$(whiptail --title "'${config_description}'" --backtitle "${backtitle_global}" --notags --menu "\n\nIN USE - command line from 'ps' output:\n\n\n${ffmpeg_str_inuse}\n\n\n" 20 98 3 "${choices[@]}" 3>&2 2>&1 1>&3- )
      if [[ ${whiptail_result}  ]] ; then
          screen -x ${pid_of_screen} # "${config_description}"
      fi
  else
      #
      # File with this description not in use by any screen session
      #

      # Check port in use (remote host іs also checked but this isn't problem - ss just retrun nothing)
      [[ ${srt_in_ip} ]] && [[ ${srt_in_port} ]] && port_in_use=`ss -Hlnp src ${srt_in_ip} sport ${srt_in_port}`
      warning_str='\n\nSELECTED CONFIGURATION:\n\n'
      [[ ${port_in_use} ]] && warning_str="\n\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n  !!   WARNING!!!!  Port $( printf %-7s "'${srt_in_port}'") in use!   !!!!\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"

      choices=( 1 "Wrap script to screen session" 2 "Run script here" )
      whiptail_result=$(whiptail --title "'${config_description}'" --backtitle "${backtitle_global}" --notags --menu "${warning_str} ${string_in} ${string_transform} ${string_out}\n\n\n\n\n" 22 98 3 "${choices[@]}" 3>&2 2>&1 1>&3- )
      if [[ ${whiptail_result} ]] ; then
          [[ ${whiptail_result} -eq 1 ]] && screen -d -m -S "${config_description}" bash -c "execute_config" || execute_config
      fi
  fi

} # end of config_processing()




######################################################################
#                                                                    #
# Main loop                                                          #
#                                                                    #
######################################################################

while true; do

    # Build config files list
    i=0
    active_srt_in_ports=()
    #for f in ${configs_dir}/*.conf ; do
    for f in `LC_ALL=C ls --format='single-column' ${configs_dir}/*.conf`; do
      tmpfname=`basename "$f" .conf` #  ${f%.*}
      files[i]="$f"
      linecount=`screen -ls "${tmpfname}" | wc -l`
      if [[ ${linecount} -le 2  ]] ; then
          files[i+1]="( NOT RUNNING )  ${tmpfname}"
      else
          files[i+1]="(   RUNNING   )  ${tmpfname}"
          set -a
          . "${f}"
          set +a
          active_srt_in_ports+=( $srt_in_port  )
      fi
      (( i+=2  ))
    done

    # list of used srt listen ports (selected config will be checked with this list)
    str=${active_srt_in_ports[*]}
    str='port '${str// / or port\ }
    [[ ${#active_srt_in_ports[*]} -eq 1 ]] && active_srt_in_ports=${str} || active_srt_in_ports='( '$str' )'

    # Show dialogue
    export NEWT_COLORS='
      root=,blue
      textbox=blue,
    '
    whiptail_result=$(whiptail --title "Configs availible / running" --backtitle "${backtitle_global}"  --notags --menu "Please select config" 26 98 12 "${files[@]}" 3>&2 2>&1 1>&3- )
    if [[ ! ${whiptail_result}  ]] ; then echo -e "\n${YEL}Config not selected. Exiting...${NC}\n"; exit ; fi

    config_processing

done
