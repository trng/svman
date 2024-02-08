#!/bin/bash

temp_dir='/run'
this_dir=`pwd`
configs_dir="${this_dir}/srt-to-somewhere-configs"
YEL='\033[1;33m' # Yellow
CYA='\033[1;36m' # Cyan
NC='\033[0m'     # No Color


trap CtrlCandCtrlBreak SIGINT
CtrlCandCtrlBreak() {
   exit
}

execute_ffmpeg() {
  trap CtrlCandCtrlBreak SIGINT
  CtrlCandCtrlBreak() {
     exit
  }

  while true; do
    #    FFREPORT=file=/run/ffmpeg-cmd-line-parsed.txt:level=-8 ffmpeg ${ffmpeg_cmd_line}
    FFREPORT=file=/run/${config_description}.ffmpegpid:level=-8 \
    ffmpeg ${string_in} ${string_transform} ${string_out}
  done
}
export -f execute_ffmpeg







echo "###########################################################"
echo "#  Wrapper for ffmpeg srt inputs                          #"
echo "#  v.0.0.1                                                #"
echo "###########################################################"


while true; do

  # Garbage clean
  for f in ${temp_dir}/*.ffmpegpid.* ; do
    screen_pid=${f##*.}
    screen_name=`basename "${f%.ffmpegpid*}"`
    linecount=`screen -ls "${screen_name}" | wc -l`
    if [[ ${linecount} -le 2 ]] ; then
      # not runnig
      rm $f
    fi
  done

  # Build file list
  i=0
  for f in ${configs_dir}/*.conf ; do
    tmpfname=`basename "$f" .conf` #  ${f%.*}
    files[i]="$f"
    linecount=`screen -ls "${tmpfname}" | wc -l`
    if [[ ${linecount} -le 2  ]] ; then
      files[i+1]="( NOT RUNING )  ${tmpfname}"
    else
      files[i+1]="(   RUNING   )  ${tmpfname}"
    fi
    (( i+=2  ))
  done


  # Show dialogue
  whiptail_result=$(whiptail --title "Configs availible / running" --backtitle "Wrapper for ffmpeg srt inputs v.0.0.1"  --notags --menu "Please select config" 26 98 7 "${files[@]}" 3>&2 2>&1 1>&3- )

  if [[ ! ${whiptail_result}  ]] ; then
    echo -e "\n${YEL}File not selected. Exiting...${NC}\n"
    exit
  fi

  set -a
  . "${whiptail_result}"
  config_description=`basename "${whiptail_result}" .conf`
  set +a

  if [[ ! ${vars_needed} ]]; then
      echo "'vars_needed' empty or not set. Cannot continiue. Exiting..."
      exit
  fi
  echo -e "\n${CYA}CONFIG LOADED:${NC}\n"
  printf '%-30s = %s\n' "Config file name" "${whiptail_result}"

  for var_name in ${vars_needed}; do
    if [[ ! ${!var_name} ]]; then
      echo "'$var_name' empty or not set. Cannot continue."
      exiting=true
    fi
    printf '%-30s = %s\n' "${var_name}" "${!var_name}"
  done
  if [[ $exiting ]] ; then echo "Exiting..." ; exit 1 ; fi

  # Check port in use
  port_in_use=`ss -Hlnp src ${srt_in_ip} sport ${srt_in_port}`
  if [[ ${port_in_use} ]]; then
      echo -e "\n${YEL}WARNING!!! Port '${srt_self_port}' in use!!!${NC}\n"
  fi


  config_in_one_string="ffmpeg ${string_in} ${string_transform} ${string_out}"

  # Check script with this description already running
  linecount=`screen -ls "${config_description}" | wc -l`
  if [[ ${linecount} -gt 2 ]] ; then
    # File with this description in use by screen session
    ffmpeg_pid=$(screen -S "${config_description}" -Q echo '$PID')
    ffmpeg_parsed_line_file=/run/${config_description}.ffmpegpid.${ffmpeg_pid}
    ffmpeg_str_inuse=`grep ffmpeg ${ffmpeg_parsed_line_file}`
    choices=( 1 "Dive into screen session" )
    whiptail_result=$(whiptail --title "'${config_description}'" --backtitle "${ffmpeg_parsed_line}" --notags --menu "\n\nIN USE:\n\n\n${ffmpeg_str_inuse}\n\n\n" 20 98 3 "${choices[@]}" 3>&2 2>&1 1>&3- )
    if [[ ${whiptail_result}  ]] ; then
	screen -x "${config_description}"
    fi
  else
    # File with this description not in use by screen session
    choices=( 1 "Wrap script to screen session" 2 "Run script here" )
    whiptail_result=$(whiptail --title "'${config_description}'" --backtitle "${ffmpeg_parsed_line}" --notags --menu "\n\n\n${config_in_one_string}\n\n\n" 20 98 3 "${choices[@]}" 3>&2 2>&1 1>&3- )
    if [[ ${whiptail_result}  ]] ; then
        if [[ ${whiptail_result} -eq 1  ]] ; then
            #screen -d -m -S "${config_description}" "${this_dir}/srt-to-somewhere-exec.sh"
    	    screen -d -m -S "${config_description}" bash -c "execute_ffmpeg"
	    ffmpeg_pid=$(screen -S "${config_description}" -Q echo '$PID')
	    if [ $? -eq 0 ] ; then
		sleep 2
		ffmpeg_parsed_line_file=/run/${config_description}.ffmpegpid
		mv ${ffmpeg_parsed_line_file} ${ffmpeg_parsed_line_file}.${ffmpeg_pid}
		ffmpeg_parsed_line_file=${ffmpeg_parsed_line_file}.${ffmpeg_pid}
		echo -e "\n${CYA}\nffmpeg parsed line:\n\n\n"
		grep ffmpeg ${ffmpeg_parsed_line_file}
		echo -e "\n${NC}\n\n\n"
		sleep 3
	    fi

        else
            #("${this_dir}/srt-to-somewhere-exec.sh") #`${script_temp_name}`
    	    execute_ffmpeg
	fi
    fi
  fi

done
