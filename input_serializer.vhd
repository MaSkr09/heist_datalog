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
-- Deserializer instantiation HEIST
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
entity input_serializer is
    Port ( 
        q_out           : out std_logic_vector(7 downto 0);
        d_in            : in std_logic;
        clk_in          : in std_logic;
        clk_inv_in      : in std_logic;
        rst_in          : in std_logic;
        clkdiv_in       : in std_logic
        
    );
end input_serializer;

architecture Behavioral of input_serializer is
    signal data_in_buf              : std_logic;

begin

IBUF_inst : IBUF
    generic map (
        IBUF_LOW_PWR => TRUE,       -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT")
        port map (
        O => data_in_buf,                     -- Buffer output
        I => d_in                      -- Buffer input (connect directly to top-level port)
    );

ISERDESE2_inst : ISERDESE2
    generic map (
        DATA_RATE => "DDR",             -- DDR, SDR
        DATA_WIDTH => 8,                -- Parallel data width (2-8,10,14)
        DYN_CLKDIV_INV_EN => "FALSE",   -- Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
        DYN_CLK_INV_EN => "FALSE",      -- Enable DYNCLKINVSEL inversion (FALSE, TRUE)
        -- INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
        INIT_Q1 => '0',
        INIT_Q2 => '0',
        INIT_Q3 => '0',
        INIT_Q4 => '0',
        INTERFACE_TYPE => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
        IOBDELAY => "NONE",             -- NONE, BOTH, IBUF, IFD
        NUM_CE => 2,                    -- Number of clock enables (1,2)
        OFB_USED => "FALSE",            -- Select OFB path (FALSE, TRUE)
        SERDES_MODE => "MASTER",        -- MASTER, SLAVE
        -- SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
        SRVAL_Q1 => '0',
        SRVAL_Q2 => '0',
        SRVAL_Q3 => '0',
        SRVAL_Q4 => '0'
    ) 
    port map (
        O => open,                         -- 1-bit output: Combinatorial output
        -- Q1 - Q8: 1-bit (each) output: Registered data outputs
        Q1 => q_out(0),
        Q2 => q_out(1),
        Q3 => q_out(2),
        Q4 => q_out(3),
        Q5 => q_out(4),
        Q6 => q_out(5),
        Q7 => q_out(6),
        Q8 => q_out(7),
        -- SHIFTOUT1-SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
        SHIFTOUT1 => open,
        SHIFTOUT2 => open,
        BITSLIP => '0',       -- 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                                        -- CLKDIV when asserted (active High). Subsequently, the data seen on the
                                        -- Q1 to Q8 output ports will shift, as in a barrel-shifter operation, one
                                        -- position every time Bitslip is invoked (DDR operation is different from
                                        -- SDR).        
        CE1 => '1',                     -- CE1, CE2: 1-bit (each) input: Data register clock enable inputs
        CE2 => '1',
        CLKDIVP => '0',              -- 1-bit input: TBD

        -- Clocks: 1-bit (each) input: ISERDESE2 clock input ports
        CLK => clk_in,               -- 1-bit input: High-speed clock
        CLKB => clk_inv_in,       -- 1-bit input: High-speed secondary clock
        CLKDIV => clkdiv_in,           -- 1-bit input: Divided clock
        OCLK => '0',                   -- 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
        
        -- Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
        DYNCLKDIVSEL => '0',   -- 1-bit input: Dynamic CLKDIV inversion
        DYNCLKSEL => '0',         -- 1-bit input: Dynamic CLK/CLKB inversion
        -- Input Data: 1-bit (each) input: ISERDESE2 data input ports
        D => data_in_buf,                         -- 1-bit input: Data input
        DDLY => '0', --ddly_reg,                   -- 1-bit input: Serial data from IDELAYE2
        OFB => '0',                     -- 1-bit input: Data feedback from OSERDESE2
        OCLKB => '0',                 -- 1-bit input: High speed negative edge output clock
        RST => rst_in,                     -- 1-bit input: Active high asynchronous reset
        -- SHIFTIN1-SHIFTIN2: 1-bit (each) input: Data width expansion input ports
        SHIFTIN1 => '0',
        SHIFTIN2 => '0'
    );

end Behavioral;
