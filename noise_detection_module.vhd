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
-- Noise detection for HEIST
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity noise_detection_module is
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
end noise_detection_module;

architecture Behavioral of noise_detection_module is

-----------------------------------------------------------------------------------------------------
-- Signals 
-----------------------------------------------------------------------------------------------------
signal data_shft_reg                        : std_logic_vector((SHIFT_REG_X8_LEN*8)-1 downto 0) := (others => '0');

type emi_det_fsm is (IDLE_STATE, SIG_LOW_STATE, SIG_HIGH_STATE);
signal pr_state, nx_state: emi_det_fsm      := IDLE_STATE;

signal sig_change_timer_reg                 : integer range 0 to SIG_STEADY_X8_TICKS_MIN := 0;

signal emi_detected_reg                     : STD_LOGIC := '0';

signal emi_counter_en                       : STD_LOGIC := '0';
signal emi_shift_reg_delay_cnt_reg          : integer range 0 to (SHIFT_REG_X8_LEN) := 0;

signal signal_steady_timer_reg              : integer range 0 to (SHIFT_REG_X8_LEN) := 0;
begin

data_out <= data_in;
log_data_out <= data_shft_reg((SHIFT_REG_X8_LEN*8)-1 downto (SHIFT_REG_X8_LEN*8)-8);
emi_detected_out <= emi_detected_reg;

-----------------------------------------------------------------------------------------------------
-- Shift register process
-----------------------------------------------------------------------------------------------------
process(clk_in)
begin
    if (clk_in'event and clk_in = '1') then   
        data_shft_reg <= (data_shft_reg((SHIFT_REG_X8_LEN*8)-9 downto 0) & data_in);
    end if;
end process;

-----------------------------------------------------------------------------------------------------
-- EMI detection process fsm 
-----------------------------------------------------------------------------------------------------
process(clk_in) 
begin
    if (clk_in'event and clk_in = '1') then

        if(nx_state /= pr_state) then
            pr_state <= nx_state;
            
            sig_change_timer_reg <= 0;                     -- Has the signal changed timer?  
            emi_shift_reg_delay_cnt_reg <= 0;
            signal_steady_timer_reg <= 0;
            emi_counter_en <= '0';
            
        else
            if(pr_state = SIG_LOW_STATE) then            
                -- steady timer
                if(data_in = "00000000") then
                    if(signal_steady_timer_reg < (SHIFT_REG_X8_LEN-1)) then
                        signal_steady_timer_reg <= signal_steady_timer_reg +1;
                    else
                        emi_counter_en <= '0';
                    end if;
                else
                    signal_steady_timer_reg <= 0;
                    -- Has the signal changed?
                    if(data_in = "11111111") then
                        sig_change_timer_reg <= sig_change_timer_reg +1;
                    else
                        sig_change_timer_reg <= 0;
                    end if;
                -- Timer for detecting emi
                    emi_counter_en <= '1';
                end if;

            elsif(pr_state = SIG_HIGH_STATE) then
    
                -- steady timer
                if(data_in = "11111111") then
                    if(signal_steady_timer_reg < (SHIFT_REG_X8_LEN-1)) then
                        signal_steady_timer_reg <= signal_steady_timer_reg +1;
                    else
                        emi_counter_en <= '0';
                    end if;
                else
                    signal_steady_timer_reg <= 0;
                    -- Has the signal changed?
                    if(data_in = "00000000") then
                        sig_change_timer_reg <= sig_change_timer_reg +1;
                    else
                        sig_change_timer_reg <= 0;
                    end if;
                    -- Timer for detecting emi
                    emi_counter_en <= '1';
                end if;
            end if;

            if(emi_counter_en = '1') then
                if(emi_shift_reg_delay_cnt_reg /= SHIFT_REG_X8_LEN -2) then
                    emi_shift_reg_delay_cnt_reg <= emi_shift_reg_delay_cnt_reg + 1;
                end if;
            else
                emi_shift_reg_delay_cnt_reg <= 0;
            end if;
                    
        end if;
    end if;

end process;

-----------------------------------------------------------------------------------------------------
-- EMI detection process fsm comb
-----------------------------------------------------------------------------------------------------
process(pr_state, data_in, sig_change_timer_reg, emi_shift_reg_delay_cnt_reg) 
begin
    nx_state <= nx_state;
    emi_detected_reg <= '0';
    
    case pr_state is
        when IDLE_STATE =>
            nx_state <= IDLE_STATE;
            if(data_in = "00000000") then
                nx_state <= SIG_LOW_STATE;
            elsif(data_in = "11111111") then
                nx_state <= SIG_HIGH_STATE;
            end if;
             
        when SIG_LOW_STATE =>
            nx_state <= SIG_LOW_STATE;

            if(sig_change_timer_reg = SIG_STEADY_X8_TICKS_MIN) then
                nx_state <= SIG_HIGH_STATE;
            end if;
            
            if(emi_shift_reg_delay_cnt_reg = SHIFT_REG_X8_LEN-2) then
                emi_detected_reg <= '1';
            end if;
            
        when SIG_HIGH_STATE => 
            nx_state <= SIG_HIGH_STATE;
            
            if(sig_change_timer_reg = SIG_STEADY_X8_TICKS_MIN) then
                nx_state <= SIG_LOW_STATE;
            end if;
            
            if(emi_shift_reg_delay_cnt_reg = SHIFT_REG_X8_LEN-2) then
                emi_detected_reg <= '1';
            end if;
            
    end case;
  end process;
end Behavioral;
