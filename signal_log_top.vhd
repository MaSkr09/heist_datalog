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
-- Signal to log top HEIST
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity signal_log_top is
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
end signal_log_top;

architecture Behavioral of signal_log_top is

    
    signal log_data_reg                 : std_logic_vector(7 downto 0) := (others => '0');
    signal emi_sig_det                  : std_logic := '0';
    signal write_addr_reg               : STD_LOGIC_VECTOR(11 downto 0);
    signal write_data_reg               : STD_LOGIC_VECTOR(7 downto 0);
    signal write_en                     : STD_LOGIC;    
    signal data_in_ser_reg              : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out_ser_reg             : std_logic_vector(7 downto 0) := (others => '0');


-----------------------------------------------------------------------------------------------------
-- Input serializer 
-----------------------------------------------------------------------------------------------------
component input_serializer is
    Port ( 
        q_out           : out std_logic_vector(7 downto 0);
        d_in            : in std_logic;
        clk_in          : in std_logic;
        clk_inv_in      : in std_logic;
        rst_in          : in std_logic;
        clkdiv_in       : in std_logic
        );
end component; 

-----------------------------------------------------------------------------------------------------
-- Output serializer
-----------------------------------------------------------------------------------------------------
component output_serializer is
    Port ( 
        reset_in            : in STD_LOGIC;
        clk_x4_in           : in STD_LOGIC;
        clk_sys_in          : in STD_LOGIC;
        q_data_out          : out STD_LOGIC;
        parallel_data_in    : in STD_LOGIC_VECTOR(7 downto 0)
    );
end component;

-----------------------------------------------------------------------------------------------------
-- EMI detection circuit
-----------------------------------------------------------------------------------------------------
component noise_detection_module is
    generic 
    ( 
        SHIFT_REG_X8_LEN        : integer := 8;
        SIG_STEADY_X8_TICKS_MIN : integer := 5
    );
    
    Port 
    ( 
        clk_in                  : in STD_LOGIC;
        data_in                 : in STD_LOGIC_VECTOR (7 downto 0);
        data_out                : out STD_LOGIC_VECTOR (7 downto 0);
        log_data_out            : out STD_LOGIC_VECTOR (7 downto 0);
        emi_detected_out        : out STD_LOGIC

    );
end component;

-----------------------------------------------------------------------------------------------------
-- BRAM component
-----------------------------------------------------------------------------------------------------
component true_dual_bram_driver is
    Port ( 
        clk_a_in            : in STD_LOGIC;
        addr_a_in           : in STD_LOGIC_VECTOR(11 downto 0);
        data_a_in           : in STD_LOGIC_VECTOR(7 downto 0);
        write_en_a_in       : in STD_LOGIC;
        
        clk_b_in            : in STD_LOGIC;
        data_b_out          : out STD_LOGIC_VECTOR(7 downto 0);
        addr_b_in           : in STD_LOGIC_VECTOR(11 downto 0)
    );
end component;

-----------------------------------------------------------------------------------------------------
-- Data log using serializer and BRAM
-----------------------------------------------------------------------------------------------------
component serializer_to_bram_logger is
    generic
    (
        BRAM_ADDR_WIDTH         : integer := 12;
        BRAM_DATA_WIDTH         : integer := 8;
        LAST_DATA_ADDR          : std_logic_vector(11 downto 0) := "000000001000";
        PULSE_BREAK_VECTOR      : std_logic_vector := "10101010";
        TIMER_BREAK_VECTOR      : std_logic_vector := "01010101"
    );
    Port
    ( 
        clk_in                  : in STD_LOGIC;
        
        signal_to_log_in        : in STD_LOGIC_VECTOR(7 downto 0);
        sample_en_in            : in STD_LOGIC;
        sample_done_out         : out STD_LOGIC;
        emi_detected_reg        : in STD_LOGIC;
        time_stamp_in           : in std_logic_vector(39 downto 0);
        
        write_addr_out          : out STD_LOGIC_VECTOR((BRAM_ADDR_WIDTH -1) downto 0);
        write_data_out          : out STD_LOGIC_VECTOR((BRAM_DATA_WIDTH -1) downto 0);
        bram_write_en_out       : out STD_LOGIC;
        last_writen_addr_out    : out STD_LOGIC_VECTOR((BRAM_ADDR_WIDTH -1) downto 0)
    );
end component;

begin

    emi_sig_det_out <= emi_sig_det;
    
-----------------------------------------------------------------------------------------------------
-- Input serializer inst.
-----------------------------------------------------------------------------------------------------
PPM_INP_SER_INST: input_serializer
    PORT MAP (
        q_out           => data_in_ser_reg,
        d_in            => data_in,
        clk_in          => clk_x4_in, 
        clk_inv_in      => clk_x4_inv_in, 
        rst_in          => reset_in,
        clkdiv_in       => sys_clk_in 
    ); 

-----------------------------------------------------------------------------------------------------
-- Output serializer inst
-----------------------------------------------------------------------------------------------------
PPM_SER_INST: output_serializer
    Port map( 
        reset_in                => reset_in,
        clk_x4_in               => clk_x4_in,
        clk_sys_in              => sys_clk_in,
        q_data_out              => data_out,
        parallel_data_in        => data_out_ser_reg
    );

-----------------------------------------------------------------------------------------------------
-- EMI detection circuit
-----------------------------------------------------------------------------------------------------
PPM_NOISE_DET_INST: noise_detection_module
    generic map(
        SHIFT_REG_X8_LEN        => SHIFT_REG_X8_LEN,
        SIG_STEADY_X8_TICKS_MIN => SIG_STEADY_X8_TICKS_MIN
    ) 
    Port map
    ( 
        clk_in                  => sys_clk_in,
        data_in                 => data_in_ser_reg,
        data_out                => data_out_ser_reg,
        log_data_out            => log_data_reg,
        emi_detected_out        => emi_sig_det
    );   
    
-----------------------------------------------------------------------------------------------------
-- BRAM component
-----------------------------------------------------------------------------------------------------
PPM_BRAM_INST: true_dual_bram_driver
    Port map( 
        clk_a_in            => sys_clk_in,
        addr_a_in           => write_addr_reg,
        data_a_in           => write_data_reg,
        write_en_a_in       => write_en,
        
        clk_b_in            => sys_clk_in,
        addr_b_in           => read_ram_addr_in,
        data_b_out          => ram_data_out
    );
       
-----------------------------------------------------------------------------------------------------
-- print data log component 
-----------------------------------------------------------------------------------------------------
PPM_SER_TO_BRAM_LOG_INST: serializer_to_bram_logger
    generic map(
        BRAM_ADDR_WIDTH         => BRAM_ADDR_WIDTH,
        BRAM_DATA_WIDTH         => BRAM_DATA_WIDTH,
        LAST_DATA_ADDR          => LAST_DATA_ADDR,
        PULSE_BREAK_VECTOR      => PULSE_BREAK_VECTOR,
        TIMER_BREAK_VECTOR      => TIMER_BREAK_VECTOR
    )
    Port map( 
        clk_in                  => sys_clk_in,
        signal_to_log_in        => log_data_reg,
        time_stamp_in           => time_in,
        
        sample_en_in            => sample_en_in,
        sample_done_out         => sample_done_out,
        emi_detected_reg        => emi_sig_det,
        write_addr_out          => write_addr_reg,
        write_data_out          => write_data_reg,
        bram_write_en_out       => write_en,
        last_writen_addr_out    => last_ram_addr_out
   );
   
end Behavioral;
