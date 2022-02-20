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
-- BRAM driver for HEIST
--
----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Libraries 
-----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-----------------------------------------------------------------------------------------------------
-- Ports 
-----------------------------------------------------------------------------------------------------
entity true_dual_bram_driver is
    Port ( 
        clk_a_in            : in STD_LOGIC;
        addr_a_in           : in STD_LOGIC_VECTOR(11 downto 0);
        data_a_in           : in STD_LOGIC_VECTOR(7 downto 0);
        write_en_a_in       : in STD_LOGIC;
        
        clk_b_in            : in STD_LOGIC;
        data_b_out          : out STD_LOGIC_VECTOR(7 downto 0);
        addr_b_in           : in STD_LOGIC_VECTOR(11 downto 0)
    );
end true_dual_bram_driver;

architecture Behavioral of true_dual_bram_driver is

-----------------------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------------------
component true_dual_port_bram_inst is
    generic (
        mem_size            : string := "36Kb"; -- Target BRAM, "18Kb" or "36Kb"
        read_width_a        : integer := 8;     -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        read_width_b        : integer := 8;     -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        write_width_a       : integer := 8;     -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        write_width_b       : integer := 8;     -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        addr_width_a        : integer := 12;    -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        addr_width_b        : integer := 12;    -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        write_en_width_a    : integer := 1;     -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
        write_en_width_b    : integer := 1      -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
    );
    Port ( 
        CLKA_in             : in STD_LOGIC;           -- 1-bit input port-A clock
        DOA_out             : out STD_LOGIC_VECTOR((read_width_a-1) downto 0);      -- Output port-A data, width defined by READ_WIDTH_A parameter
        ADDRA_in            : in STD_LOGIC_VECTOR((addr_width_a-1) downto 0);       -- Input port-A address, width defined by Port A depth
        DIA_in              : in STD_LOGIC_VECTOR((write_width_a-1) downto 0);      -- Input port-A data, width defined by WRITE_WIDTH_A parameter
        ENA_in              : in STD_LOGIC;                                         -- 1-bit input port-A enable
--        REGCEA_in           : in STD_LOGIC;                                         -- 1-bit input port-A output register enable
        RSTA_in             : in STD_LOGIC;                                         -- 1-bit input port-A reset
        WEA_in              : in STD_LOGIC_VECTOR((write_en_width_a-1) downto 0);   -- Input port-A write enable, width defined by Port A depth

        CLKB_in             : in STD_LOGIC;           -- 1-bit input port-B clock
        DOB_out             : out STD_LOGIC_VECTOR((read_width_b-1) downto 0);      -- Output port-B data, width defined by READ_WIDTH_B parameter
        ADDRB_in            : in STD_LOGIC_VECTOR((addr_width_b-1) downto 0);       -- Input port-B address, width defined by Port B depth
        DIB_in              : in STD_LOGIC_VECTOR((write_width_b-1) downto 0);                 -- Input port-B data, width defined by WRITE_WIDTH_B parameter
        ENB_in              : in STD_LOGIC;                                         -- 1-bit input port-B enable
--        REGCEB_in           : in STD_LOGIC;                                         -- 1-bit input port-B output register enable
        RSTB_in             : in STD_LOGIC;                                         -- 1-bit input port-B reset
        WEB_in              : in STD_LOGIC_VECTOR((write_en_width_b-1) downto 0)    -- Input port-B write enable, width defined by Port B depth

    );
end component;

begin

-----------------------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------------------
BRAM: true_dual_port_bram_inst
     port map (
        CLKA_in             => clk_a_in,            -- 1-bit input port-A clock
        DOA_out             => open,                -- Output port-A data, width defined by READ_WIDTH_A parameter
        ADDRA_in            => addr_a_in,           -- Input port-A address, width defined by Port A depth
        DIA_in              => data_a_in,           -- Input port-A data, width defined by WRITE_WIDTH_A parameter
        ENA_in              => '1',                 -- 1-bit input port-A enable
--        REGCEA_in           => '0',               -- 1-bit input port-A output register enable
        RSTA_in             => '0',                 -- 1-bit input port-A reset
        WEA_in(0)           => write_en_a_in,       -- Input port-A write enable, width defined by Port A depth

        CLKB_in             => clk_b_in,            -- 1-bit input port-B clock
        DOB_out             => data_b_out,          -- Output port-B data, width defined by READ_WIDTH_B parameter
        ADDRB_in            => addr_b_in,           -- Input port-B address, width defined by Port B depth
        DIB_in              => (others => '0'),     -- Input port-B data, width defined by WRITE_WIDTH_B parameter
        ENB_in              => '1',                 -- 1-bit input port-B enable
--        REGCEB_in           => ,                  -- 1-bit input port-B output register enable
        RSTB_in             => '0',                 -- 1-bit input port-B reset
        WEB_in              => (others => '0')      -- Input port-B write enable, width defined by Port B depth
    );

end Behavioral;
