#!/bin/bash

# ========== Default Config ==========
MODE="batch"
DESIGN=""
TB=""
TOP=""
PART="xc7a35tcpg236-1"
TCL="synth.tcl"
OUT="sim"
FILELIST=""

# ========== Help ==========
show_help() {
  echo "Usage: ./run.sh <command> [options]"
  echo
  echo "Commands:"
  echo "  compile       Compile Verilog and testbench files"
  echo "  elaborate     Elaborate testbench for simulation"
  echo "  simulate      Run simulation using xsim"
  echo "  synth         Synthesize design using Vivado"
  echo "  help          Show this help message"
  echo
  echo "Options:"
  echo "  --design <path>     Single design file"
  echo "  --tb <path>         Single testbench file"
  echo "  --top <name>        Top module name"
  echo "  --part <fpga_part>  Target FPGA part (default: $PART)"
  echo "  --filelist <path>   Filelist (.f) with design + tb files"
  echo "  --gui               Use GUI mode (default is batch mode)"
  echo
  echo "Examples:"
  echo "  ./run.sh compile --filelist filelist.f"
  echo "  ./run.sh simulate --top tb_top"
  echo "  ./run.sh synth --design ../design/foo.v --top foo"
}

# ========== Parse Options ==========
COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --design) DESIGN="$2"; shift ;;
    --tb) TB="$2"; shift ;;
    --top) TOP="$2"; shift ;;
    --part) PART="$2"; shift ;;
    --filelist) FILELIST="$2"; shift ;;
    --gui) MODE="gui" ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
  esac
  shift
done

# ========== Input Validation ==========
require_top() {
  [[ -z "$TOP" ]] && {
    echo "❌ Missing --top"; show_help; exit 1;
  }
}

require_design_or_filelist() {
  if [[ -z "$DESIGN" && -z "$FILELIST" ]]; then
    echo "❌ You must provide either --design or --filelist"
    show_help; exit 1
  fi
}

# ========== Execute Command ==========
case "$COMMAND" in
  compile)
    echo "📦 Compiling..."
    if [[ -n "$FILELIST" ]]; then
      xvlog --sv -f "$FILELIST"
    else
      require_design_or_filelist
      xvlog --sv "$DESIGN" "$TB"
    fi
    ;;

  elaborate)
    require_top
    echo "⚙️ Elaborating $TOP..."
    xelab "$TOP" -debug typical
    ;;

  simulate)
    require_top
    echo "🧪 Running simulation for $TOP in $MODE mode..."
    if [[ "$MODE" == "gui" ]]; then
      xsim "$TOP"
    else
      xsim "$TOP" -runall
    fi
    ;;

  synth)
    require_top
    require_design_or_filelist
    echo "🏗️   Synthesizing $TOP for $PART in $MODE mode..."
    mkdir -p "$OUT"

    echo "🔧 Generating synthesis Tcl script..."

    {
      echo "set_part $PART"
      if [[ -n "$FILELIST" ]]; then
        while IFS= read -r line || [ -n "$line" ]; do
          [[ -z "$line" || "$line" =~ ^# ]] && continue
          if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            abs_path=$(cygpath -m "$line")
          else
            abs_path="$(cd "$(dirname "$line")"; pwd)/$(basename "$line")"
          fi
          echo "read_verilog \"${abs_path}\""
        done < "$FILELIST"
      else
        echo "read_verilog \"$DESIGN\""
      fi
      echo "synth_design -top $TOP -part $PART"
      echo "report_timing_summary -file $OUT/timing.txt"
      echo "report_utilization -file $OUT/utilization.txt"
      echo "write_edif $OUT/${TOP}.edf"
      echo "write_checkpoint -force $OUT/${TOP}.dcp"
      echo "exit"
    } > "$TCL"

    vivado -mode "$MODE" -source "$TCL"
    ;;

  help|"")
    show_help
    ;;

  *)
    echo "❌ Unknown command: $COMMAND"
    show_help
    exit 1
    ;;
esac
