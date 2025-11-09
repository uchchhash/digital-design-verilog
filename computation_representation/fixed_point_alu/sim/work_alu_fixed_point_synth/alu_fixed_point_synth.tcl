# Auto-generated Vivado TCL for synth
read_verilog ../design/alu_fixed_point.sv
synth_design -top alu_fixed_point -part xc7a12tcpg238-3
write_checkpoint alu_fixed_point_synth.dcp
report_utilization -file alu_fixed_point_utilization.rpt
report_timing_summary -file alu_fixed_point_timing.rpt
quit
