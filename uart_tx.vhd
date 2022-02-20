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
-- UART for HEIST
--
----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Libraries 
-----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-----------------------------------------------------------------------------------------------------
-- Ports and generics
-----------------------------------------------------------------------------------------------------
-- clk_frq/baud = clk/bit
-- Baud rate 115200: 1736 ticks@ 200MHz
-- Baud rate 115200: 1302 ticks@ 150MHz
entity uart_tx is
    generic (
            clks_pr_bit         : integer := 325-- 1302
    );
    Port ( 
            clk_in               : in STD_LOGIC;
            byte_to_send_in      : in STD_LOGIC_VECTOR (7 downto 0);
            send_byte_in         : in STD_LOGIC;
            uart_busy_out        : out STD_LOGIC;
            uart_tx_out          : out STD_LOGIC);
end uart_tx;

architecture Behavioral of uart_tx is

-----------------------------------------------------------------------------------------------------
-- Signal for uart fsm
-----------------------------------------------------------------------------------------------------
    type uart_tx_fsm is (IDLE_STATE, START_BIT_STATE, DATA_BITS_STATE, STOP_BIT_STATE);
    signal pr_state, nx_state: uart_tx_fsm;
    signal send_byte_reg        : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_no_reg           : integer range 0 to 7 := 0;
    signal timer_reg            : integer range 0 to clks_pr_bit := 0;
    
begin

-----------------------------------------------------------------------------------------------------
-- uart state shift fsm and timer
-----------------------------------------------------------------------------------------------------
process(clk_in)
begin 
    if (clk_in'event and clk_in = '1') then
        if(pr_state /= nx_state) then
            pr_state <= nx_state;
            timer_reg <= 0;
            bit_no_reg <= 0;
            
            if(nx_state = START_BIT_STATE) then -- Stash data to be send
                send_byte_reg <= byte_to_send_in;
            end if;
        
        else 
            timer_reg <= timer_reg +1;

            if(((pr_state = DATA_BITS_STATE) or(pr_state = STOP_BIT_STATE)) and ((timer_reg >= clks_pr_bit-1))) then
                bit_no_reg <= bit_no_reg + 1;
                timer_reg <= 0;
            end if;
        end if;
        
    end if;
end process;

-----------------------------------------------------------------------------------------------------
-- UART FSM
-----------------------------------------------------------------------------------------------------
process(pr_state, send_byte_in, timer_reg, bit_no_reg, send_byte_reg)
begin

    uart_busy_out <= '1';
    uart_tx_out <= '1';

    case pr_state is
        when IDLE_STATE =>
            uart_busy_out <= '0';
            if(send_byte_in = '1') then -- or timer
                nx_state <= START_BIT_STATE;
            else
                nx_state <= IDLE_STATE;
            end if;
            
        when START_BIT_STATE =>
            uart_tx_out <= '0';
            if(timer_reg >= clks_pr_bit-1) then
                nx_state <= DATA_BITS_STATE;
            else
                nx_state <= START_BIT_STATE;
            end if;
            
        when DATA_BITS_STATE =>
            
            uart_tx_out <= send_byte_reg(bit_no_reg);
            if((timer_reg >= clks_pr_bit-1) and (bit_no_reg = 7)) then
                nx_state <= STOP_BIT_STATE;
            else
                nx_state <= DATA_BITS_STATE;
            end if;
            
        when STOP_BIT_STATE =>
            if((timer_reg >= clks_pr_bit-1) and (bit_no_reg = 7)) then
                nx_state <= IDLE_STATE;
            else
                nx_state <= STOP_BIT_STATE;
            end if;

    end case;

end process;


end Behavioral;
