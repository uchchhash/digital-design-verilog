#!/bin/bash

set -e

# Default values
MODE="batch"
ACTION=""
TOP=""
FILELIST=""
PART="xc7a12tcpg238-3"
DUMP_WDB=false
OPEN_GUI=false
TIMESCALE="1ns/1ps"
CLEAN=false
DEEP_CLEAN=false

usage() {
    echo "Usage:"
    echo "  $0 -a [sim|synth|impl] -f filelist.f -t top_module [-m gui|batch] [-p part] [-s timescale] [--dump-wdb] [--open-gui]"
    echo "  $0 -clean"
    echo "  $0 -deep-clean"
    echo ""
    echo "Options:"
    echo "  -a            Action: sim (simulation) | synth (synthesis) | impl (implementation)"
    echo "  -f            Path to filelist with one source file per line"
    echo "  -t            Top module name"
    echo "  -m            Mode: gui or batch (default: batch)"
    echo "  -p            FPGA part number (default: $PART)"
    echo "  -s            Timescale to enforce (default: $TIMESCALE)"
    echo "  --dump-wdb    Enable waveform dump (.wdb)"
    echo "  --open-gui    Open Vivado simulator GUI after simulation"
    echo "  -clean        Remove Vivado intermediate junk files (.Xil, xsim.dir, *.jou, *.pb, *.str, webtalk.log)"
    echo "  -deep-clean   Remove everything generated (work_*, *.log, *.rpt, *.dcp, *.wdb)"
    exit 1
}

# Parse args
if [[ "$1" == "-clean" ]]; then
    CLEAN=true
fi
if [[ "$1" == "-deep-clean" ]]; then
    DEEP_CLEAN=true
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a) ACTION="$2"; shift 2 ;;
        -f) FILELIST="$2"; shift 2 ;;
        -t) TOP="$2"; shift 2 ;;
        -m) MODE="$2"; shift 2 ;;
        -p) PART="$2"; shift 2 ;;
        -s) TIMESCALE="$2"; shift 2 ;;
        --dump-wdb) DUMP_WDB=true; shift ;;
        --open-gui) OPEN_GUI=true; shift ;;
        -clean) CLEAN=true; shift ;;
        -deep-clean) DEEP_CLEAN=true; shift ;;
        -h|--help) usage ;;
        *) echo "❌ Unknown argument: $1"; usage ;;
    esac
done

if [[ "$CLEAN" == true ]]; then
    echo "🧹 Running clean: removing intermediate Vivado junk files…"
    rm -rf .Xil xsim.dir *.jou *.pb *.str webtalk.log usage_statistics_webtalk.xml *.wdb
    echo "✅ Clean complete. Logs, reports, and work_* remain."
    exit 0
fi

if [[ "$DEEP_CLEAN" == true ]]; then
    echo "🔥 Running deep-clean: removing all generated artifacts…"
    rm -rf .Xil xsim.dir *.jou *.pb *.str webtalk.log usage_statistics_webtalk.xml *.wdb
    rm -rf work_*
    rm -f *.log *.dcp *.rpt
    echo "✅ Deep-clean complete. Only source files and scripts remain."
    exit 0
fi

if [[ -z "$ACTION" || -z "$FILELIST" || -z "$TOP" ]]; then
    usage
fi

if [[ ! -f "$FILELIST" ]]; then
    echo "❌ Filelist $FILELIST not found!"
    exit 1
fi

WORKDIR="work_${TOP}_${ACTION}"
mkdir -p "$WORKDIR"

LOG="${WORKDIR}/${TOP}_${ACTION}.log"

echo "⚙️ Starting $ACTION for $TOP…"
echo "🔷 Enforcing timescale: $TIMESCALE"

# Enforce timescale in all files (ignoring comments & blank lines)
while read -r file; do
    [[ -z "$file" || "$file" =~ ^// ]] && continue

    if [[ ! -f "$file" ]]; then
        echo "❌ Source file not found: $file"
        exit 1
    fi

    if ! grep -q '`timescale' "$file"; then
        echo "📝 Inserting \`timescale $TIMESCALE into $file"
        sed -i "1i \`timescale $TIMESCALE" "$file"
    fi
done < "$FILELIST"

if [[ "$ACTION" == "sim" ]]; then

    echo "🔷 Compiling sources…"
    xvlog -sv -f "$FILELIST" | tee -a "$LOG"

    echo "🔷 Elaborating design…"
    SNAPSHOT="$TOP"
    ELAB_ARGS="-debug typical"
    if [[ "$DUMP_WDB" == true ]]; then
        ELAB_ARGS="$ELAB_ARGS --wdb $WORKDIR/${SNAPSHOT}.wdb"
    fi
    xelab work.$TOP -s $SNAPSHOT $ELAB_ARGS | tee -a "$LOG"

    echo "🔷 Running simulation…"
    if [[ "$OPEN_GUI" == true ]]; then
        xsim $SNAPSHOT --gui
    else
        xsim $SNAPSHOT --runall | tee -a "$LOG"
    fi

    echo ""
    echo "✅ Simulation complete. Log: $(pwd)/$LOG"
    if [[ "$DUMP_WDB" == true ]]; then
        echo "📄 Waveform: $(pwd)/$WORKDIR/${SNAPSHOT}.wdb"
    fi

else

    TCL="${WORKDIR}/${TOP}_${ACTION}.tcl"
    echo "⚙️ Generating $TCL …"

    echo "# Auto-generated Vivado TCL for $ACTION" > "$TCL"

    while read -r file; do
        [[ -z "$file" || "$file" =~ ^// ]] && continue
        echo "read_verilog $file" >> "$TCL"
    done < "$FILELIST"

    case "$ACTION" in
        synth)
            cat >> "$TCL" <<EOF
synth_design -top $TOP -part $PART
write_checkpoint ${TOP}_synth.dcp
report_utilization -file ${TOP}_utilization.rpt
report_timing_summary -file ${TOP}_timing.rpt
quit
EOF
            ;;
        impl)
            cat >> "$TCL" <<EOF
synth_design -top $TOP -part $PART
opt_design
place_design
route_design
write_checkpoint ${TOP}_impl.dcp
report_utilization -file ${TOP}_impl_utilization.rpt
report_timing_summary -file ${TOP}_impl_timing.rpt
quit
EOF
            ;;
        *)
            echo "❌ Unknown action: $ACTION"
            exit 1
            ;;
    esac

    echo "✅ TCL script generated: $TCL"

    if [[ "$MODE" == "gui" ]]; then
        echo "🚀 Launching Vivado in GUI mode…"
        vivado -source "$TCL"
    else
        echo "🚀 Running Vivado in batch mode…"
        vivado -mode batch -source "$TCL" | tee "$LOG"
        echo ""
        echo "✅ Log file: $(pwd)/$LOG"
        echo "📄 Reports (if any) in: $(pwd)/$WORKDIR"
    fi

fi
