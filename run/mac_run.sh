#!/bin/bash

simulation=" iverilog -o "tb.vvp" -f "../sim/filelist.f" | tee compile.log;
    vvp -n "tb.vvp" | tee simulate.log;"

# MAC_OSX cmd
waveform=" open -a "gtkwave" tb.vcd;"

    echo "*Use option for"
    echo "  -s: Simulation"
    echo "  -w: Waveform Viewer"
    echo "  -b: Both"
    echo "  (default: Simulation)"
    echo 

process_option() {
  case "$1" in
    -s) 
      command="$simulation"
      ;;
    -w)
      command="$waveform"
      ;;
    -b)
      command="$simulation $waveform"
      ;;
    *)
      echo "Invalid option: $1"
      exit 1
      ;;
  esac
}

if [ $# -eq 0 ]; then
    command="$simulation"
else
  for arg in "$@"; do
    process_option "$arg"
  done
fi

eval $command

