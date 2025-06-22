#!/bin/bash

echo "🧹 Cleaning simulation and synthesis artifacts..."

rm -rf \
  sim/ \
  xsim.dir \
  .Xil \
  *.log \
  *.jou \
  *.pb \
  *.wdb \
  *.vcd \
  *.dcp \
  *.edf \
  *.txt \
  synth.tcl

echo "✅ Cleanup complete."
