# CLK, control btn, uart, and LEDs
set_property PACKAGE_PIN L5 [get_ports clk_in]
set_property PACKAGE_PIN F11 [get_ports btn_in]                 
set_property PACKAGE_PIN H12 [get_ports uart_tx_out]            
set_property PACKAGE_PIN D14 [get_ports {red_led}]
set_property PACKAGE_PIN M14 [get_ports {external_red_led}]     
set_property PACKAGE_PIN C14 [get_ports {green_led}]
set_property PACKAGE_PIN J12 [get_ports {external_green_led}]   

# PPM signal
set_property PACKAGE_PIN K12 [get_ports {ppm_in}]   
set_property PACKAGE_PIN M12 [get_ports {ppm_out}]  

# ESCs
set_property PACKAGE_PIN L14 [get_ports {esc1_in}]  
set_property PACKAGE_PIN L12 [get_ports {esc2_in}]  
set_property PACKAGE_PIN J13 [get_ports {esc3_in}]  
set_property PACKAGE_PIN H13 [get_ports {esc4_in}]  

# Telemetry
set_property PACKAGE_PIN E11 [get_ports {tele_rx_in}]   
set_property PACKAGE_PIN D12 [get_ports {tele_cts_in}]  
set_property PACKAGE_PIN C10 [get_ports {tele_tx_in}]   
set_property PACKAGE_PIN F14 [get_ports {tele_tx_out}]  
set_property PACKAGE_PIN E13 [get_ports {tele_rts_in}]  
set_property PACKAGE_PIN E12 [get_ports {tele_rts_out}] 

set_property IOSTANDARD LVCMOS33 [get_ports clk_in]
set_property IOSTANDARD LVCMOS33 [get_ports {red_led}]
set_property IOSTANDARD LVCMOS33 [get_ports {external_red_led}]
set_property IOSTANDARD LVCMOS33 [get_ports {green_led}]
set_property IOSTANDARD LVCMOS33 [get_ports {external_green_led}]
set_property IOSTANDARD LVCMOS33 [get_ports btn_in]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_out]

set_property IOSTANDARD LVCMOS33 [get_ports ppm_in]
set_property IOSTANDARD LVCMOS33 [get_ports ppm_out]
set_property IOSTANDARD LVCMOS33 [get_ports esc1_in]
set_property IOSTANDARD LVCMOS33 [get_ports esc2_in]
set_property IOSTANDARD LVCMOS33 [get_ports esc3_in]
set_property IOSTANDARD LVCMOS33 [get_ports esc4_in]
set_property IOSTANDARD LVCMOS33 [get_ports tele_rx_in]
set_property IOSTANDARD LVCMOS33 [get_ports tele_cts_in]
set_property IOSTANDARD LVCMOS33 [get_ports tele_tx_in]
set_property IOSTANDARD LVCMOS33 [get_ports tele_tx_out]
set_property IOSTANDARD LVCMOS33 [get_ports tele_rts_in]
set_property IOSTANDARD LVCMOS33 [get_ports tele_rts_out]

set_property SLEW FAST [get_ports ppm_out]
set_property SLEW FAST [get_ports tele_tx_out]
set_property SLEW FAST [get_ports tele_rts_out]
set_property SLEW FAST [get_ports data_out]

set_property PULLUP     TRUE     [get_ports clk_in]
set_property PULLUP     TRUE     [get_ports btn_in]

#The following line disable error because we do not use a clock pin for clock input!!
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_in_IBUF]