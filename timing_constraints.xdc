create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk_in]
set_input_jitter clk 0.200