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
-- MMCME2 clk for HEIST
--
----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Libraries 
-----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

-----------------------------------------------------------------------------------------------------
-- Ports
-----------------------------------------------------------------------------------------------------
entity my_clk is
    Port ( 
        clk_in                      : in STD_LOGIC;
        clk_high_speed_out          : out STD_LOGIC;
        clk_locked_out              : out STD_LOGIC
    );
end my_clk;

architecture Behavioral of my_clk is

    signal feedback_clk                 : std_logic;

begin
-----------------------------------------------------------------------------------------------------
-- Clk instantiation
-----------------------------------------------------------------------------------------------------
-- input clk 50 MHz
-- Multiply 4.0
-----------------------------------------------------------------------------------------------------
MMCME2_BASE_inst : MMCME2_BASE
    generic map (
        BANDWIDTH => "OPTIMIZED",               -- Jitter programming (OPTIMIZED, HIGH, LOW)
        CLKFBOUT_MULT_F => 6.0,                 -- 8* 100M = 800MHZ -- 6* 100M = 600MHZ -- Multiply value for all CLKOUT (2.000-64.000). (600-1200MHz)
        CLKFBOUT_PHASE => 0.0,                  -- Phase offset in degrees of CLKFB (-360.000-360.000).
        CLKIN1_PERIOD => 10.000,                -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
        -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
        CLKOUT1_DIVIDE => 2,--2,                    -- 800MHz
        CLKOUT2_DIVIDE => 4,--8,                    -- 200MHz
        CLKOUT3_DIVIDE => 24,                   -- 50MHz
        CLKOUT4_DIVIDE => 1,
        CLKOUT5_DIVIDE => 1,
        CLKOUT6_DIVIDE => 1,
        CLKOUT0_DIVIDE_F => 1.000,--2.000, --              -- 800 M -- Divide amount for CLKOUT0 (1.000-128.000).
        -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
        CLKOUT0_DUTY_CYCLE => 0.5,
        CLKOUT1_DUTY_CYCLE => 0.5,
        CLKOUT2_DUTY_CYCLE => 0.5,
        CLKOUT3_DUTY_CYCLE => 0.5,
        CLKOUT4_DUTY_CYCLE => 0.5,
        CLKOUT5_DUTY_CYCLE => 0.5,
        CLKOUT6_DUTY_CYCLE => 0.5,              -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
        CLKOUT0_PHASE => 0.0,
        CLKOUT1_PHASE => 180.000,
        CLKOUT2_PHASE => 0.0,
        CLKOUT3_PHASE => 0.0,
        CLKOUT4_PHASE => 0.0,
        CLKOUT5_PHASE => 0.0,
        CLKOUT6_PHASE => 0.0,
        CLKOUT4_CASCADE => FALSE,               -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
        DIVCLK_DIVIDE => 1,                     -- Master division value (1-106)
        REF_JITTER1 => 0.0,                     -- Reference input jitter in UI (0.000-0.999).
        STARTUP_WAIT => TRUE                   -- Delays DONE until MMCM is locked (FALSE, TRUE)
    )
    port map (
        -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
        CLKOUT0 => clk_high_speed_out,                   -- 1-bit output: CLKOUT0
--        CLKOUT0B => clk800M_180deg_out,           -- 1-bit output: Inverted CLKOUT0
--        CLKOUT1 => clk800M_180deg_out, --clk800M_90deg_out,             -- 1-bit output: CLKOUT1
--        CLKOUT1B => clk800M_270deg_out,           -- 1-bit output: Inverted CLKOUT1
--        CLKOUT2 => clk200M_out,                   -- 1-bit output: CLKOUT2
--        CLKOUT2B => clk200M_180deg_out,           -- 1-bit output: Inverted CLKOUT2
--        CLKOUT3 => clk_2div_out,                  -- 1-bit output: CLKOUT3
--        CLKOUT3B => CLKOUT3B,                   -- 1-bit output: Inverted CLKOUT3
--        CLKOUT4 => CLKOUT4,                     -- 1-bit output: CLKOUT4
--        CLKOUT5 => CLKOUT5,                     -- 1-bit output: CLKOUT5
--        CLKOUT6 => CLKOUT6,                     -- 1-bit output: CLKOUT6
        -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
        CLKFBOUT => feedback_clk,                  -- 1-bit output: Feedback clock
--        CLKFBOUTB => CLKFBOUTB,                 -- 1-bit output: Inverted CLKFBOUT
        -- Status Ports: 1-bit (each) output: MMCM status ports
        LOCKED => clk_locked_out,                       -- 1-bit output: LOCK
        -- Clock Inputs: 1-bit (each) input: Clock input
        CLKIN1 => clk_in,                       -- 1-bit input: Clock
        -- Control Ports: 1-bit (each) input: MMCM control ports
        PWRDWN => '0',                       -- 1-bit input: Power-down
        RST => '0',                             -- 1-bit input: Reset
        -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
        CLKFBIN => feedback_clk                 -- 1-bit input: Feedback clock
    );

end Behavioral;
