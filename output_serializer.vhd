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
-- Output serializer for HEIST
--
----------------------------------------------------------------------------------
 
-----------------------------------------------------------------------------------------------------
-- Libraries 
-----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM; 
use UNISIM.VComponents.all; 

-----------------------------------------------------------------------------------------------------
-- Top level ports 
-----------------------------------------------------------------------------------------------------
entity output_serializer is
    Port ( 
        reset_in            : in STD_LOGIC;
        clk_x4_in           : in STD_LOGIC;
        clk_sys_in          : in STD_LOGIC;
        q_data_out          : out STD_LOGIC;
        parallel_data_in    : in STD_LOGIC_VECTOR(7 downto 0)
    );
end output_serializer;

architecture Behavioral of output_serializer is
    signal dummy                        : std_logic := '0';
    
begin
    
-----------------------------------------------------------------------------------------------------
-- Output serializer instantiation
-----------------------------------------------------------------------------------------------------
OSERDESE2_inst : OSERDESE2
    generic map (
        DATA_RATE_OQ => "DDR",          -- DDR, SDR 
        DATA_RATE_TQ => "SDR",          -- DDR, BUF, SDR
        DATA_WIDTH => 8,                -- Parallel data width (2-8,10,14)
        INIT_OQ => '0',                 -- Initial value of OQ output (1'b0,1'b1)
        INIT_TQ => '0',                 -- Initial value of TQ output (1'b0,1'b1)
        SERDES_MODE => "MASTER",        -- MASTER, SLAVE
        SRVAL_OQ => '0',                -- OQ output value when SR is used (1'b0,1'b1)
        SRVAL_TQ => '0',                -- TQ output value when SR is used (1'b0,1'b1)
        TBYTE_CTL => "FALSE",           -- Enable tristate byte operation (FALSE, TRUE)
        TBYTE_SRC => "FALSE",           -- Tristate byte source (FALSE, TRUE)
        TRISTATE_WIDTH => 1             -- 3-state converter width (1,4)
    )

    port map ( 
--        OFB => OFB,                     -- 1-bit output: Feedback path for data
        OQ => q_data_out,                       -- 1-bit output: Data path output
        CLK => clk_x4_in,                 -- 1-bit input: High speed clock
        CLKDIV => clk_sys_in,             -- 1-bit input: Divided clock

        D1 => parallel_data_in(7),
        D2 => parallel_data_in(6),
        D3 => parallel_data_in(5),
        D4 => parallel_data_in(4),
        D5 => parallel_data_in(3),
        D6 => parallel_data_in(2),
        D7 => parallel_data_in(1),
        D8 => parallel_data_in(0),

        OCE => dummy, --'1',                     -- 1-bit input: Output data clock enable
        RST => reset_in,                      -- 1-bit input: Reset
        -- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
        SHIFTIN1 => '0',
        SHIFTIN2 => '0',
        
        -- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
        T1 => '0',
        T2 => '0',
        T3 => '0',
        T4 => '0',
        TBYTEIN => '0',             -- 1-bit input: Byte group tristate
        TCE => '1'                      -- 1-bit input: 3-state clock enable
    );
    dummy <= not reset_in;


end Behavioral;
