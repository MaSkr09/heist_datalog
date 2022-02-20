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
-- Serializer for HEIST
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
-- Ports and generics
-----------------------------------------------------------------------------------------------------
entity serializer_to_bram_logger is
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
        emi_detected_reg        : in  STD_LOGIC;
        
        time_stamp_in           : in std_logic_vector(39 downto 0);

        write_addr_out          : out STD_LOGIC_VECTOR((BRAM_ADDR_WIDTH -1) downto 0);
        write_data_out          : out STD_LOGIC_VECTOR((BRAM_DATA_WIDTH -1) downto 0);
        bram_write_en_out       : out STD_LOGIC;
        last_writen_addr_out    : out STD_LOGIC_VECTOR((BRAM_ADDR_WIDTH -1) downto 0)
    );
end serializer_to_bram_logger;

architecture Behavioral of serializer_to_bram_logger is

-----------------------------------------------------------------------------------------------------
-- Signal for modules connection
-----------------------------------------------------------------------------------------------------
    signal addr_cnt_reg         : std_logic_vector((BRAM_ADDR_WIDTH -1) downto 0) := (others => '0');
    signal bram_write_en_reg    : std_logic := '0';
    signal signal_to_log_reg    : std_logic_vector(7 downto 0) := (others => '0');

    signal time_stamp_buffer    : std_logic_vector(47 downto 0) := (others => '0');
    
    signal pulse_started_flag   : std_logic := '0';
    signal delay_cnt            : integer range 0 to 6;
    
begin

bram_write_en_out <= bram_write_en_reg;
write_addr_out <= addr_cnt_reg;
write_data_out <= signal_to_log_reg;
last_writen_addr_out <= addr_cnt_reg;

-----------------------------------------------------------------------------------------------------
-- Log data
-----------------------------------------------------------------------------------------------------
process(clk_in) begin
    if (clk_in'event and clk_in = '1') then
        signal_to_log_reg <= time_stamp_buffer(7 downto 0);
        sample_done_out <= '0';
        
        if(addr_cnt_reg = LAST_DATA_ADDR) then
            sample_done_out <= '1';
        
        elsif(sample_en_in = '0') then
            bram_write_en_reg <= '0';
            
        elsif((emi_detected_reg = '1') or (pulse_started_flag = '1')) then
            bram_write_en_reg <= '1';
            addr_cnt_reg <= std_logic_vector(unsigned(addr_cnt_reg) +1);
            
        elsif(bram_write_en_reg = '1') then
            if( signal_to_log_reg = PULSE_BREAK_VECTOR) then
                bram_write_en_reg <= '0';
            else
                signal_to_log_reg <= PULSE_BREAK_VECTOR;
                addr_cnt_reg <= std_logic_vector(unsigned(addr_cnt_reg) +1);
            end if;
        end if;
    end if;
end process;

-----------------------------------------------------------------------------------------------------
-- Log timestamp
-----------------------------------------------------------------------------------------------------
process(clk_in) begin
    if (clk_in'event and clk_in = '1') then
        time_stamp_buffer(39 downto 0) <= time_stamp_in;
        time_stamp_buffer(47 downto 40) <= TIMER_BREAK_VECTOR;
        
        if((( emi_detected_reg = '1') or (pulse_started_flag = '1')) and (sample_en_in = '1')) then
            time_stamp_buffer(47 downto 40) <= signal_to_log_in;
            time_stamp_buffer(39 downto 32) <= time_stamp_buffer(47 downto 40);
            time_stamp_buffer(31 downto 24) <= time_stamp_buffer(39 downto 32);
            time_stamp_buffer(23 downto 16) <= time_stamp_buffer(31 downto 24);
            time_stamp_buffer(15 downto 8) <= time_stamp_buffer(23 downto 16);
            time_stamp_buffer(7 downto 0) <= time_stamp_buffer(15 downto 8);
            
            pulse_started_flag <= '1';

            if(emi_detected_reg = '0') then
                delay_cnt <= delay_cnt +1;
                if( delay_cnt = 6) then
                    pulse_started_flag <= '0';
                end if;
            else
                delay_cnt <= 0;
            end if;
        end if;
    end if;
end process;

end Behavioral;
