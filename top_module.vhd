----------------------------------------------------------------------------------
-- MIT License
-- 
-- Copyright (c) 2022 Martin Skriver
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
----------------------------------------------------------------------------------
-- Company: University of Southern Denmark
-- Engineer: Martin Skriver
-- Contact: maskr@mmmi.sdu.dk
--
-- Description: 
-- HEIST top module
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

-----------------------------------------------------------------------------------------------------
-- Ports for top module
-----------------------------------------------------------------------------------------------------
entity top_module is
    generic 
    (
        SLOW_BLICK_TICKS            : integer := 50000000; --50000000;
        FAST_BLICK_TICKS            : integer := 10000000; --10000000;
        BTN_DB_TIME                 : integer := 15000000;
        UART_TICKS_PR_BIT           : integer := 1302;                                  -- 1302 for 115200 @ 150MHz clk
        SAMPLE_DELAY_TICKS          : integer := 600000000;                             -- Define a delay for FSM

        BRAM_ADDR_WIDTH             : integer := 12;
        BRAM_DATA_WIDTH             : integer := 8;
        LAST_DATA_ADDR              : std_logic_vector(11 downto 0) := "111111111111"; -- BRAM limit
        PULSE_BREAK_VECTOR          : std_logic_vector(7 downto 0) := "10101010";
        TIMER_BREAK_VECTOR          : std_logic_vector(7 downto 0) := "01010101";

        SHIFT_REG_X8_LEN            : integer := 20;
        SIG_STEADY_X8_TICKS_MIN     : integer := 16

    );
    Port
    ( 
        clk_in                      : in std_logic;
        btn_in                      : in std_logic;
        red_led                     : out std_logic;
        external_red_led            : out std_logic;
        external_green_led          : out std_logic;
        green_led                   : out std_logic;
        uart_tx_out                 : out std_logic;
        
        ppm_in                      : in std_logic;
        ppm_out                     : out std_logic;
        
        esc1_in                     : in std_logic;
        esc2_in                     : in std_logic;
        esc3_in                     : in std_logic;
        esc4_in                     : in std_logic;
        
        tele_rx_in                  : in std_logic;
        tele_cts_in                 : in std_logic;

        tele_tx_in                  : in std_logic;
        tele_tx_out                 : out std_logic;

        tele_rts_in                 : in std_logic;
        tele_rts_out                : out std_logic
    );
end top_module;

architecture Behavioral of top_module is

-----------------------------------------------------------------------------------------------------
-- For btn debounce
-----------------------------------------------------------------------------------------------------
signal btn_reg : std_logic := '1';
signal pr_btn_in : std_logic := '1';
signal btn_cnt : integer range 0 to BTN_DB_TIME := 0;

-----------------------------------------------------------------------------------------------------
-- For FSM
-----------------------------------------------------------------------------------------------------
    type log_fsm is (IDLE_STATE, SAMPLE_DELAY_STATE, SAMPLE_STARTED_STATE, SAMPLE_STATE, BTN_WAIT_STATE, POST_SAMPLE_DELAY_STATE, SAMPLE_DONE_STATE, UPLOAD_STATE);
    signal pr_state, nx_state: log_fsm;
    signal timer_reg                    : integer range 0 to SAMPLE_DELAY_TICKS+1;
    signal nx_timer_val_reg             : integer range 0 to SAMPLE_DELAY_TICKS+1;
    signal sample_en                    : std_logic := '0';
    signal sample_done                  : std_logic := '0';
    signal uart_tx_reg                  : std_logic;
    
    signal read_all_data_finised        : std_logic := '0';
    
    signal signal_nr_reg                : std_logic_vector(7 downto 0) := (others => '0');
-----------------------------------------------------------------------------------------------------
-- For led indication
-----------------------------------------------------------------------------------------------------
    type led_signal_types is (READY, START_DELAY, SAMPLER_STARTED, EMI_DETECTED, STOPED, DATA_TRANSFER);
    signal led_status: led_signal_types := READY;
    signal led_timer_reg                : integer range 0 to SLOW_BLICK_TICKS+1;
    
    signal green_led_buf                : std_logic := '0';
    signal red_led_buf                  : std_logic := '0';
-----------------------------------------------------------------------------------------------------
-- Signal for modules connection
-----------------------------------------------------------------------------------------------------
    signal clk_reg              : std_logic := '0';
    signal print_read_ram_addr_reg            : std_logic_vector(11 downto 0) := (others => '0');
    signal print_read_ram_data_reg            : std_logic := '0';
    signal print_ram_data_reg                 : std_logic_vector(7 downto 0) := (others => '0');

    signal print_last_ram_addr_reg            : STD_LOGIC_VECTOR(11 downto 0) := LAST_DATA_ADDR;
    signal print_en                           : std_logic := '0';
    type print_log_fsm is (PRINT_IDLE_STATE, PRINT_PPM_STATE, PPM_DONE_STATE, WAIT_PPM_STATE, PRINT_ESC1_STATE, ESC1_DONE_STATE, WAIT_ESC1_STATE, PRINT_ESC2_STATE, ESC2_DONE_STATE, WAIT_ESC2_STATE, PRINT_ESC3_STATE, ESC3_DONE_STATE, WAIT_ESC3_STATE, PRINT_ESC4_STATE, ESC4_DONE_STATE, WAIT_ESC4_STATE, PRINT_TELE_RX_STATE, TELE_RX_DONE_STATE, WAIT_TELE_RX_STATE, PRINT_TELE_CTS_STATE, TELE_CTS_DONE_STATE, WAIT_TELE_CTS_STATE, PRINT_TELE_TX_STATE, TELE_TX_DONE_STATE, WAIT_TELE_TX_STATE, PRINT_TELE_RTS_STATE, TELE_RTS_DONE_STATE, WAIT_TELE_RTS_STATE);
    signal pr_print_state, nx_print_state: print_log_fsm := PRINT_IDLE_STATE;

    
    signal clk_x4_reg                   : std_logic := '0';
    signal clk_x4_inv_reg               : std_logic := '0';
    signal clk_x4_gen                   : std_logic := '0';
    signal clk_locked                   : std_logic := '0';
    signal reset_out_ser                : std_logic := '1';
    signal reset_out_ser_buf            : std_logic := '0';
    signal reset_clk_div                : std_logic := '0';
    
    signal print_log_en                 : std_logic := '0';
    signal read_finised                 : std_logic := '0';
    signal bram_clk                     : std_logic;
    
-----------------------------------------------------------------------------------------------------
-- For ppm interconnect
-----------------------------------------------------------------------------------------------------
    signal ppm_sample_done              : STD_LOGIC := '0';
    signal ppm_emi_det                  : STD_LOGIC := '0';
    
    signal ppm_last_addr                : std_logic_vector(11 downto 0) := (others => '0');
    signal ppm_ram_data                 : std_logic_vector(7 downto 0) := (others => '0');

-----------------------------------------------------------------------------------------------------
-- For escs interconnect
-----------------------------------------------------------------------------------------------------
    signal esc1_sample_done              : STD_LOGIC := '0';
    signal esc2_sample_done              : STD_LOGIC := '0';
    signal esc3_sample_done              : STD_LOGIC := '0';
    signal esc4_sample_done              : STD_LOGIC := '0';

    signal esc1_emi_det                  : STD_LOGIC := '0';
    signal esc2_emi_det                  : STD_LOGIC := '0';
    signal esc3_emi_det                  : STD_LOGIC := '0';
    signal esc4_emi_det                  : STD_LOGIC := '0';
    
    signal esc1_last_addr                : std_logic_vector(11 downto 0) := (others => '0');
    signal esc2_last_addr                : std_logic_vector(11 downto 0) := (others => '0');
    signal esc3_last_addr                : std_logic_vector(11 downto 0) := (others => '0');
    signal esc4_last_addr                : std_logic_vector(11 downto 0) := (others => '0');

    signal esc1_ram_data                 : std_logic_vector(7 downto 0) := (others => '0');
    signal esc2_ram_data                 : std_logic_vector(7 downto 0) := (others => '0');
    signal esc3_ram_data                 : std_logic_vector(7 downto 0) := (others => '0');
    signal esc4_ram_data                 : std_logic_vector(7 downto 0) := (others => '0');

-----------------------------------------------------------------------------------------------------
-- For telematry radio interconnect
-----------------------------------------------------------------------------------------------------
    signal tele_rx_sample_done          : STD_LOGIC := '0';
    signal tele_cts_sample_done         : STD_LOGIC := '0';
    signal tele_tx_sample_done          : STD_LOGIC := '0';
    signal tele_rts_sample_done         : STD_LOGIC := '0';

    signal tele_rx_emi_det              : STD_LOGIC := '0';
    signal tele_cts_emi_det             : STD_LOGIC := '0';
    signal tele_tx_emi_det              : STD_LOGIC := '0';
    signal tele_rts_emi_det             : STD_LOGIC := '0';
    
    signal tele_rx_last_addr            : std_logic_vector(11 downto 0) := (others => '0');
    signal tele_cts_last_addr           : std_logic_vector(11 downto 0) := (others => '0');
    signal tele_tx_last_addr            : std_logic_vector(11 downto 0) := (others => '0');
    signal tele_rts_last_addr           : std_logic_vector(11 downto 0) := (others => '0');

    signal tele_rx_ram_data             : std_logic_vector(7 downto 0) := (others => '0');
    signal tele_cts_ram_data            : std_logic_vector(7 downto 0) := (others => '0');
    signal tele_tx_ram_data             : std_logic_vector(7 downto 0) := (others => '0');
    signal tele_rts_ram_data            : std_logic_vector(7 downto 0) := (others => '0');

-----------------------------------------------------------------------------------------------------
-- For timer process
-----------------------------------------------------------------------------------------------------
    signal timestamp_cnt_reg            : std_logic_vector(39 downto 0) := (others => '0');

-----------------------------------------------------------------------------------------------------
-- Signal logger module
-----------------------------------------------------------------------------------------------------
component signal_log_top is
    generic 
    ( 
        SHIFT_REG_X8_LEN                : integer := 20;
        SIG_STEADY_X8_TICKS_MIN         : integer := 16;
        
        BRAM_ADDR_WIDTH                 : integer := 12;
        BRAM_DATA_WIDTH                 : integer := 8;
        LAST_DATA_ADDR                  : std_logic_vector(11 downto 0) := "111111111111";
        PULSE_BREAK_VECTOR              : std_logic_vector := "10101010";
        TIMER_BREAK_VECTOR              : std_logic_vector := "01010101"
        
    );
    
    Port 
    (
        sys_clk_in                      : in STD_LOGIC;
        clk_x4_in                       : in STD_LOGIC;
        clk_x4_inv_in                   : in STD_LOGIC;
        reset_in                        : in STD_LOGIC;
        
        data_in                         : in STD_LOGIC;
        data_out                        : out STD_LOGIC;

        time_in                         : in std_logic_vector(39 downto 0);
        sample_en_in                    : in STD_LOGIC;
        sample_done_out                 : out STD_LOGIC;
        emi_sig_det_out                 : out STD_LOGIC;

        last_ram_addr_out               : out STD_LOGIC_VECTOR(11 downto 0);
        read_ram_addr_in                : in std_logic_vector(11 downto 0);
        ram_data_out                    : out std_logic_vector(7 downto 0)
    );
end component;

-----------------------------------------------------------------------------------------------------
-- Clock MMCM high speed clk
-----------------------------------------------------------------------------------------------------
component my_clk is
    Port 
    ( 
        clk_in                      : in STD_LOGIC;
        clk_high_speed_out          : out STD_LOGIC;
        clk_locked_out              : out STD_LOGIC
    );
end component;

-----------------------------------------------------------------------------------------------------
-- Print log component
-----------------------------------------------------------------------------------------------------
component log_print is
    generic(
            uart_clks_pr_bit        : integer --:= 325 --1302
    );
    Port ( 
            clk_in                  : in STD_LOGIC;
            uart_tx_out             : out STD_LOGIC;
            print_log_en_in         : in STD_LOGIC;
            
            read_ram_data           : out STD_LOGIC;
            read_ram_addr           : out STD_LOGIC_VECTOR(11 downto 0);
            ram_data_in             : in STD_LOGIC_VECTOR(7 downto 0);
            last_ram_addr           : in STD_LOGIC_VECTOR(11 downto 0);
            signal_nr_in            : in STD_LOGIC_VECTOR(7 downto 0);
            log_finish_out          : out STD_LOGIC

    ); 
end component;

-----------------------------------------------------------------------------------------------------
begin

-----------------------------------------------------------------------------------------------------
-- PPM EMI signal logger
-----------------------------------------------------------------------------------------------------
PPM_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => ppm_in,
        data_out                        => ppm_out,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => ppm_sample_done,
        emi_sig_det_out                 => ppm_emi_det,

        last_ram_addr_out               => ppm_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => ppm_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- ESC1 EMI signal logger
-----------------------------------------------------------------------------------------------------
ESC1_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => esc1_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => esc1_sample_done,
        emi_sig_det_out                 => esc1_emi_det,

        last_ram_addr_out               => esc1_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => esc1_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- ESC2 EMI signal logger
-----------------------------------------------------------------------------------------------------
ESC2_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => esc2_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => esc2_sample_done,
        emi_sig_det_out                 => esc2_emi_det,

        last_ram_addr_out               => esc2_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => esc2_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- ESC3 EMI signal logger
-----------------------------------------------------------------------------------------------------
ESC3_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => esc3_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => esc3_sample_done,
        emi_sig_det_out                 => esc3_emi_det,

        last_ram_addr_out               => esc3_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => esc3_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- ESC4 EMI signal logger
-----------------------------------------------------------------------------------------------------
ESC4_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => esc4_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => esc4_sample_done,
        emi_sig_det_out                 => esc4_emi_det,

        last_ram_addr_out               => esc4_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => esc4_ram_data
    );


-----------------------------------------------------------------------------------------------------
-- Telemetry rx EMI signal logger
-----------------------------------------------------------------------------------------------------
TELE_RX_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => tele_rx_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => tele_rx_sample_done,
        emi_sig_det_out                 => tele_rx_emi_det,

        last_ram_addr_out               => tele_rx_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => tele_rx_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- Telemetry cts EMI signal logger
-----------------------------------------------------------------------------------------------------
TELE_CTS_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => tele_cts_in,
        data_out                        => open,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => tele_cts_sample_done,
        emi_sig_det_out                 => tele_cts_emi_det,

        last_ram_addr_out               => tele_cts_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => tele_cts_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- Telemetry tx EMI signal logger
-----------------------------------------------------------------------------------------------------
TELE_TX_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => tele_tx_in,
        data_out                        => tele_tx_out,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => tele_tx_sample_done,
        emi_sig_det_out                 => tele_tx_emi_det,

        last_ram_addr_out               => tele_tx_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => tele_tx_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- Telemetry rts EMI signal logger
-----------------------------------------------------------------------------------------------------
TELE_RTS_LOG_INST: signal_log_top
    generic map
    ( 
        SHIFT_REG_X8_LEN                => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN         => SIG_STEADY_X8_TICKS_MIN,
        
        BRAM_ADDR_WIDTH                 => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH                 => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR                  => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR              => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR              => TIMER_BREAK_VECTOR
    )
    
    Port map 
    (
        sys_clk_in                      => clk_reg,
        clk_x4_in                       => clk_x4_reg,
        clk_x4_inv_in                   => clk_x4_inv_reg,
        reset_in                        => reset_clk_div,

        data_in                         => tele_rts_in,
        data_out                        => tele_rts_out,

        time_in                         => timestamp_cnt_reg,
        sample_en_in                    => sample_en,
        sample_done_out                 => tele_rts_sample_done,
        emi_sig_det_out                 => tele_rts_emi_det,

        last_ram_addr_out               => tele_rts_last_addr,
        read_ram_addr_in                => print_read_ram_addr_reg,
        ram_data_out                    => tele_rts_ram_data
    );

-----------------------------------------------------------------------------------------------------
-- print data log component
-----------------------------------------------------------------------------------------------------
PRINT_LOG_INST: log_print
    generic map(
            uart_clks_pr_bit    => UART_TICKS_PR_BIT
    ) 
    Port map( 
            clk_in               => clk_reg,
            uart_tx_out          => uart_tx_reg,
            print_log_en_in      => print_log_en,
            log_finish_out       => read_finised,
            read_ram_data        => print_read_ram_data_reg,
            read_ram_addr        => print_read_ram_addr_reg,
            ram_data_in          => print_ram_data_reg,
            signal_nr_in         => signal_nr_reg,
            last_ram_addr        => print_last_ram_addr_reg 
           );
    uart_tx_out <= uart_tx_reg;


-----------------------------------------------------------------------------------------------------
-- Clock MMCM high speed clk
-----------------------------------------------------------------------------------------------------
MYCLK_INST: my_clk
    Port map
    ( 
        clk_in                      => clk_in,
        clk_high_speed_out          => clk_x4_gen,
        clk_locked_out              => clk_locked
    );
    
-----------------------------------------------------------------------------------------------------
BUFIO_inst : BUFIO
    port map (
        O               => clk_x4_reg,          -- 1-bit output: Clock output (connect to I/O clock loads).
        I               => clk_x4_gen           -- 1-bit input: Clock input (connect to an IBUFG or BUFMR).
    );
    clk_x4_inv_reg <= not clk_x4_reg;
-----------------------------------------------------------------------------------------------------
BUFR2_inst : BUFR
    generic map (
        BUFR_DIVIDE     => "4",             -- Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8"
        SIM_DEVICE      => "7SERIES"        -- Must be set to "7SERIES"
    )
    port map (
        O               => clk_reg,         -- 1-bit output: Clock output port
        CE              => '1',             -- 1-bit input: Active high, clock enable (Divided modes only)
        CLR             => '0', --reset_clk_div,   -- 1-bit input: Active high, asynchronous clear (Divided modes only)
        I               => clk_x4_gen       -- 1-bit input: Clock buffer input driven by an IBUFG, MMCM or local interconnect
    );

reset_clk_div <= not clk_locked;
-----------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Reset process needed for serializers
-----------------------------------------------------------------------------------------------------
process(clk_reg)
begin 
    if (clk_reg'event and clk_reg = '1') then
        reset_out_ser <= '1';
        
        if((clk_locked = '1') or (reset_out_ser = '0')) then
            reset_out_ser_buf <= '1';
            
        end if;
        
        if(reset_out_ser_buf = '1') then
            reset_out_ser <= '0';        
        end if;
    end if;
end process;


-----------------------------------------------------------------------------------------------------
-- Timestamp counter
-----------------------------------------------------------------------------------------------------
process(clk_reg)
begin 
    if (clk_reg'event and clk_reg = '1') then
        timestamp_cnt_reg <= std_logic_vector( (unsigned(timestamp_cnt_reg) + 1));
        if( pr_state = IDLE_STATE) then
            timestamp_cnt_reg <= (others => '0');
        end if;
    end if;
end process;


-----------------------------------------------------------------------------------------------------
-- LED indicator 
-- READY: GREEN CONSTANT
-- START_DELAY: GREEN BLINK SLOW
-- SAMPLER_STARTED: RED BLINK FAST
-- EMI_DETECTED: RED CONSTANT
-- STOPED: RED BLINK SLOW
-- DATA_TRANSFER: RED GREEN CONSTANT
-----------------------------------------------------------------------------------------------------

process(clk_reg, green_led_buf, red_led_buf)
begin 
green_led <= green_led_buf;
red_led <= red_led_buf;

external_red_led <= green_led_buf;
external_green_led <= red_led_buf;  

    if (clk_reg'event and clk_reg = '1') then

        case led_status is
            when READY =>
                green_led_buf <= '1';
                red_led_buf <= '0';
                
            when START_DELAY =>
                red_led_buf <= '0';
                led_timer_reg <= led_timer_reg +1;

                if(led_timer_reg >= SLOW_BLICK_TICKS) then
                    led_timer_reg <= 0;
                    green_led_buf<= not green_led_buf;
                end if;
    
            when SAMPLER_STARTED =>
                green_led_buf <= '0';
                led_timer_reg <= led_timer_reg +1;

                if(led_timer_reg >= FAST_BLICK_TICKS) then
                    led_timer_reg <= 0;
                    red_led_buf <= not red_led_buf;
                end if;
                                
            when EMI_DETECTED =>
                green_led_buf <= '0';
                red_led_buf <= '1';
    
            when STOPED =>
                green_led_buf <= '0';
                led_timer_reg <= led_timer_reg +1;

                if(led_timer_reg >= SLOW_BLICK_TICKS) then
                    led_timer_reg <= 0;
                    red_led_buf <= not red_led_buf;
                end if;
                                
            when DATA_TRANSFER =>
                green_led_buf <= '1';
                red_led_buf <= '1';
    
        end case;
    end if;
end process;


-----------------------------------------------------------------------------------------------------
-- Btn debounce 
-----------------------------------------------------------------------------------------------------
process(clk_reg, btn_in, btn_cnt)
begin 
    if (clk_reg'event and clk_reg = '1') then
        btn_cnt <= btn_cnt +1;
        pr_btn_in <= btn_in;
        
        if( btn_in /= pr_btn_in) then
            btn_cnt <= 0;
        elsif(btn_cnt = BTN_DB_TIME) then
            btn_reg <= btn_in;
            btn_cnt <= btn_cnt;
        end if;
    end if;
end process;


-----------------------------------------------------------------------------------------------------
-- FSM to log samples and print via uart
-----------------------------------------------------------------------------------------------------
process(clk_reg)
begin 
    if (clk_reg'event and clk_reg = '1') then
        if(nx_state /= pr_state) then
            timer_reg <= 0;
            nx_timer_val_reg <= 1;
            pr_state <= nx_state;
            
        else
            timer_reg <= nx_timer_val_reg; 
            nx_timer_val_reg <= nx_timer_val_reg+1;
            
        end if;        
    end if;
end process;

-----------------------------------------------------------------------------------------------------
-- FSM to log samples and print via uart
-----------------------------------------------------------------------------------------------------
process(pr_state, btn_reg, timer_reg) --, sample_done, read_finised)
begin 

    led_status <= READY;
    
    sample_en <= '0';
    print_en <= '0';
    
    case pr_state is
        when IDLE_STATE =>
            nx_state <= IDLE_STATE;

            if(btn_reg = '0') then
                nx_state <= SAMPLE_DELAY_STATE;
            end if;
            
        when SAMPLE_DELAY_STATE =>                  -- Wait a moment before start sampling
            nx_state <= SAMPLE_DELAY_STATE;            
            led_status <= START_DELAY;
            
            if(timer_reg = SAMPLE_DELAY_TICKS) then
                nx_state <= SAMPLE_STARTED_STATE;
            end if;

        when SAMPLE_STARTED_STATE =>
            nx_state <= SAMPLE_STARTED_STATE;
            led_status <= SAMPLER_STARTED;
            
            sample_en <= '1';

            if((ppm_emi_det = '1')or (esc1_emi_det = '1') or (esc2_emi_det = '1') or (esc3_emi_det = '1') or (esc4_emi_det = '1') or (tele_rx_emi_det = '1') or (tele_cts_emi_det = '1') or (tele_tx_emi_det = '1') or (tele_rts_emi_det = '1')) then
                nx_state <= SAMPLE_STATE;
            elsif(btn_reg = '0') then
                nx_state <= BTN_WAIT_STATE;
            end if;
            
        when SAMPLE_STATE =>
            nx_state <= SAMPLE_STATE;
            led_status <= EMI_DETECTED;
            
            sample_en <= '1';
            if((ppm_sample_done = '1') or (esc1_sample_done = '1') or (esc2_sample_done = '1') or (esc3_sample_done = '1') or (esc4_sample_done = '1') or (tele_rx_sample_done = '1') or (tele_cts_sample_done = '1') or (tele_tx_sample_done = '1') or (tele_rts_sample_done = '1') or (btn_reg = '0')) then
                nx_state <= BTN_WAIT_STATE;
            end if;

        when BTN_WAIT_STATE =>
            nx_state <= BTN_WAIT_STATE;
            led_status <= STOPED;
            
            if(btn_reg = '1') then
                nx_state <= SAMPLE_DONE_STATE;
            end if;
            
        when SAMPLE_DONE_STATE =>
            nx_state <= SAMPLE_DONE_STATE;
            led_status <= STOPED;

            if(btn_reg = '0') then
                nx_state <= POST_SAMPLE_DELAY_STATE;
            end if;

        when POST_SAMPLE_DELAY_STATE =>
            nx_state <= POST_SAMPLE_DELAY_STATE;
            led_status <= DATA_TRANSFER;

            if(timer_reg = SAMPLE_DELAY_TICKS) then
                nx_state <= UPLOAD_STATE;
            end if;
            
        when UPLOAD_STATE =>
            nx_state <= UPLOAD_STATE;
            led_status <= DATA_TRANSFER;

            print_en <= '1';
            if(read_all_data_finised = '1') then
                nx_state <= SAMPLE_DONE_STATE;
            end if; 
    end case;

end process;


-----------------------------------------------------------------------------------------------------
-- FSM to print via uart
-----------------------------------------------------------------------------------------------------
process(clk_reg)
begin 
    if (clk_reg'event and clk_reg = '1') then
        if(nx_print_state /= pr_print_state) then
            pr_print_state <= nx_print_state;
        end if;        
    end if;
end process;
-----------------------------------------------------------------------------------------------------
-- FSM print via uart
-----------------------------------------------------------------------------------------------------
process(pr_print_state, btn_reg, print_en, read_finised) --, sample_done, read_finised)
begin 
    print_log_en <= '0';
    print_last_ram_addr_reg <= ppm_last_addr;
    print_ram_data_reg <= ppm_ram_data;
    read_all_data_finised <= '0';
    signal_nr_reg <= "01000001";

    case pr_print_state is
        when PRINT_IDLE_STATE =>
            nx_print_state <= PRINT_IDLE_STATE;

            if((print_en = '1') and (btn_reg = '0')) then
                nx_print_state <= WAIT_PPM_STATE;
            end if;
-- PPM
        when WAIT_PPM_STATE =>
            nx_print_state <= WAIT_PPM_STATE;
            if(btn_reg = '1') then
                nx_print_state <= PRINT_PPM_STATE;
            end if;
            
        when PRINT_PPM_STATE =>
            nx_print_state <= PRINT_PPM_STATE;
            print_log_en <= '1';

            if(read_finised = '1') then
                nx_print_state <= PPM_DONE_STATE;
            end if;

        when PPM_DONE_STATE =>
            nx_print_state <= PPM_DONE_STATE;
            print_last_ram_addr_reg <= esc1_last_addr;
            print_ram_data_reg <= esc1_ram_data;
            signal_nr_reg <= "01000010";
            
            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_ESC1_STATE;
            end if;
-- ESC 1
        when WAIT_ESC1_STATE =>
            nx_print_state <= WAIT_ESC1_STATE;
            print_last_ram_addr_reg <= esc1_last_addr;
            print_ram_data_reg <= esc1_ram_data;
            signal_nr_reg <= "01000010";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_ESC1_STATE;
            end if;
            
        when PRINT_ESC1_STATE =>
            nx_print_state <= PRINT_ESC1_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= esc1_last_addr;
            print_ram_data_reg <= esc1_ram_data;
            signal_nr_reg <= "01000010";

            if(read_finised = '1') then
                nx_print_state <= ESC1_DONE_STATE;
            end if;

        when ESC1_DONE_STATE =>
            nx_print_state <= ESC1_DONE_STATE;
            print_last_ram_addr_reg <= esc2_last_addr;
            print_ram_data_reg <= esc2_ram_data;
            signal_nr_reg <= "01000011";

            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_ESC2_STATE;
            end if;

-- ESC 2
        when WAIT_ESC2_STATE =>
            nx_print_state <= WAIT_ESC2_STATE;
            print_last_ram_addr_reg <= esc2_last_addr;
            print_ram_data_reg <= esc2_ram_data;
            signal_nr_reg <= "01000011";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_ESC2_STATE;
            end if;
        
        when PRINT_ESC2_STATE =>
            nx_print_state <= PRINT_ESC2_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= esc2_last_addr;
            print_ram_data_reg <= esc2_ram_data;
            signal_nr_reg <= "01000011";

            if(read_finised = '1') then
                nx_print_state <= ESC2_DONE_STATE;
            end if;

        when ESC2_DONE_STATE =>
            nx_print_state <= ESC2_DONE_STATE;
            print_last_ram_addr_reg <= esc3_last_addr;
            print_ram_data_reg <= esc3_ram_data;
            signal_nr_reg <= "01000100";
            
            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_ESC3_STATE;
            end if;

-- ESC 3
        when WAIT_ESC3_STATE =>
            nx_print_state <= WAIT_ESC3_STATE;
            print_last_ram_addr_reg <= esc3_last_addr;
            print_ram_data_reg <= esc3_ram_data;
            signal_nr_reg <= "01000100";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_ESC3_STATE;
            end if;

        when PRINT_ESC3_STATE =>
            nx_print_state <= PRINT_ESC3_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= esc3_last_addr;
            print_ram_data_reg <= esc3_ram_data;
            signal_nr_reg <= "01000100";

            if(read_finised = '1') then
                nx_print_state <= ESC3_DONE_STATE;
            end if;

        when ESC3_DONE_STATE =>
            nx_print_state <= ESC3_DONE_STATE;
            print_last_ram_addr_reg <= esc4_last_addr;
            print_ram_data_reg <= esc4_ram_data;
            signal_nr_reg <= "01000101";
            
            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_ESC4_STATE;
            end if;

-- ESC 4

        when WAIT_ESC4_STATE =>
            nx_print_state <= WAIT_ESC4_STATE;
            print_last_ram_addr_reg <= esc4_last_addr;
            print_ram_data_reg <= esc4_ram_data;
            signal_nr_reg <= "01000101";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_ESC4_STATE;
            end if;

        when PRINT_ESC4_STATE =>
            nx_print_state <= PRINT_ESC4_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= esc4_last_addr;
            print_ram_data_reg <= esc4_ram_data;
            signal_nr_reg <= "01000101";

            if(read_finised = '1') then
                nx_print_state <= ESC4_DONE_STATE;
            end if;

        when ESC4_DONE_STATE =>
            nx_print_state <= ESC4_DONE_STATE;
            print_last_ram_addr_reg <= tele_rx_last_addr;
            print_ram_data_reg <= tele_rx_ram_data;
            signal_nr_reg <= "01000110";

            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_TELE_RX_STATE;
            end if;
    
-- TELE_RX
        when WAIT_TELE_RX_STATE =>
            nx_print_state <= WAIT_TELE_RX_STATE;
            print_last_ram_addr_reg <= tele_rx_last_addr;
            print_ram_data_reg <= tele_rx_ram_data;
            signal_nr_reg <= "01000110";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_TELE_RX_STATE;
            end if;

        when PRINT_TELE_RX_STATE =>
            nx_print_state <= PRINT_TELE_RX_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= tele_rx_last_addr;
            print_ram_data_reg <= tele_rx_ram_data;
            signal_nr_reg <= "01000110";

            if(read_finised = '1') then
                nx_print_state <= TELE_RX_DONE_STATE;
            end if;

        when TELE_RX_DONE_STATE =>
            nx_print_state <= TELE_RX_DONE_STATE;
            print_last_ram_addr_reg <= tele_cts_last_addr;
            print_ram_data_reg <= tele_cts_ram_data;
            signal_nr_reg <= "01000111";

            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_TELE_CTS_STATE;
            end if;

-- TELE_CTS
        when WAIT_TELE_CTS_STATE =>
            nx_print_state <= WAIT_TELE_CTS_STATE;
            print_last_ram_addr_reg <= tele_cts_last_addr;
            print_ram_data_reg <= tele_cts_ram_data;
            signal_nr_reg <= "01000111";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_TELE_CTS_STATE;
            end if;

        when PRINT_TELE_CTS_STATE =>
            nx_print_state <= PRINT_TELE_CTS_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= tele_cts_last_addr;
            print_ram_data_reg <= tele_cts_ram_data;
            signal_nr_reg <= "01000111";

            if(read_finised = '1') then
                nx_print_state <= TELE_CTS_DONE_STATE;
            end if;

        when TELE_CTS_DONE_STATE =>
            nx_print_state <= TELE_CTS_DONE_STATE;
            print_last_ram_addr_reg <= tele_tx_last_addr;
            print_ram_data_reg <= tele_tx_ram_data;
            signal_nr_reg <= "01001000";

            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_TELE_TX_STATE;
            end if;

-- TELE_TX
        when WAIT_TELE_TX_STATE =>
            nx_print_state <= WAIT_TELE_TX_STATE;
            print_last_ram_addr_reg <= tele_tx_last_addr;
            print_ram_data_reg <= tele_tx_ram_data;
            signal_nr_reg <= "01001000";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_TELE_TX_STATE;
            end if;

        when PRINT_TELE_TX_STATE =>
            nx_print_state <= PRINT_TELE_TX_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= tele_tx_last_addr;
            print_ram_data_reg <= tele_tx_ram_data;
            signal_nr_reg <= "01001000";

            if(read_finised = '1') then
                nx_print_state <= TELE_TX_DONE_STATE;
            end if;

        when TELE_TX_DONE_STATE =>
            nx_print_state <= TELE_TX_DONE_STATE;
            print_last_ram_addr_reg <= tele_rts_last_addr;
            print_ram_data_reg <= tele_rts_ram_data;
            signal_nr_reg <= "01001001";

            if((read_finised = '0') and (btn_reg = '0')) then
                nx_print_state <= WAIT_TELE_RTS_STATE;
            end if;

-- TELE_RTS
        when WAIT_TELE_RTS_STATE =>
            nx_print_state <= WAIT_TELE_RTS_STATE;
            print_last_ram_addr_reg <= tele_rts_last_addr;
            print_ram_data_reg <= tele_rts_ram_data;
            signal_nr_reg <= "01001001";
            if(btn_reg = '1') then
                nx_print_state <= PRINT_TELE_RTS_STATE;
            end if;

        when PRINT_TELE_RTS_STATE =>
            nx_print_state <= PRINT_TELE_RTS_STATE;
            print_log_en <= '1';
            print_last_ram_addr_reg <= tele_rts_last_addr;
            print_ram_data_reg <= tele_rts_ram_data;
            signal_nr_reg <= "01001001";

            if(read_finised = '1') then
                nx_print_state <= TELE_RTS_DONE_STATE;
            end if;

        when TELE_RTS_DONE_STATE =>
            nx_print_state <= TELE_RTS_DONE_STATE;
            read_all_data_finised <= '1';
            if(read_finised = '0') then
                nx_print_state <= PRINT_IDLE_STATE;
            end if;

    end case;

end process;
end Behavioral;
