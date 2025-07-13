for dir in logic_gates arithmetic_circuits multiplexers_demultiplexers encoders_decoders code_converters parity_error_detection shifters_rotators comparators_detectors alu_datapath_elements miscellaneous
do
    mkdir -p $dir/{docs,design,tb,sim}
    touch $dir/README.md
done
