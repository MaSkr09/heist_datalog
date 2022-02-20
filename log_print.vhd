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
-- UART print for HEIST
--
----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Libraries 
-----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity log_print is
    generic(
            uart_clks_pr_bit        : integer := 325
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
end log_print;

architecture Behavioral of log_print is
 
-----------------------------------------------------------------------------------------------------
-- UART component
-----------------------------------------------------------------------------------------------------
component uart_tx is
    generic (
        clks_pr_bit             : integer := uart_clks_pr_bit
    );
    Port ( 
        clk_in                  : in STD_LOGIC;
        byte_to_send_in         : in STD_LOGIC_VECTOR (7 downto 0);
        send_byte_in            : in STD_LOGIC;
        uart_busy_out           : out STD_LOGIC;
        uart_tx_out             : out STD_LOGIC
    );
end component;


-----------------------------------------------------------------------------------------------------
-- Signals and type for uart and fsm
-----------------------------------------------------------------------------------------------------

    type print_log_fsm is (IDLE_STATE, TRANS_SIG_NR_STATE, WAIT_UART_BUSY_SIG_NR, COPY_DATA_TO_REG_STATE, TRANS_DATA_STATE, WAIT_UART_BUSY, TRANS_CR_STATE, WAIT_UART_BUSY_CR, TRANS_LF_STATE, WAIT_UART_BUSY_LF);
    signal pr_state, nx_state   : print_log_fsm := IDLE_STATE;
    signal ram_data_reg         : std_logic_vector(7 downto 0) := (others => '0');
    constant data_lenght        : integer := 8;
    signal data_reg_offset      : integer range 0 to data_lenght := 0;
    signal read_data_buffer     : std_logic_vector(7 downto 0) := (others => '0');
    signal get_new_data         : std_logic:= '0';
    signal byte_to_send_reg     : std_logic_vector(7 downto 0);
    signal send_byte_reg        : std_logic;
    signal uart_busy_reg        : std_logic;
    signal addr_cnt_reg         : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal nx_addr_cnt_reg      : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal print_finished       : std_logic := '0';

    constant char_0_cons        : STD_LOGIC_VECTOR(7 downto 0) := "00110000";
    constant char_1_cons        : STD_LOGIC_VECTOR(7 downto 0) := "00110001";
    constant char_cr_cons       : STD_LOGIC_VECTOR(7 downto 0) := "00001101";
    constant char_lf_cons       : STD_LOGIC_VECTOR(7 downto 0) := "00001010";

begin
-----------------------------------------------------------------------------------------------------
-- Reader BRAM component
-----------------------------------------------------------------------------------------------------
read_ram_data <= get_new_data;
read_ram_addr <= addr_cnt_reg;
ram_data_reg <= ram_data_in;

-----------------------------------------------------------------------------------------------------
-- UART instantiation
-----------------------------------------------------------------------------------------------------
UART_TX_INST: uart_tx
    generic map (
            clks_pr_bit         => uart_clks_pr_bit
    )
    port map (
            clk_in              => clk_in,
            byte_to_send_in     => byte_to_send_reg,
            send_byte_in        => send_byte_reg,
            uart_busy_out       => uart_busy_reg,
            uart_tx_out         => uart_tx_out
    );

-----------------------------------------------------------------------------------------------------
-- Print process fsm sync
-----------------------------------------------------------------------------------------------------
process(clk_in) begin
    if (clk_in'event and clk_in = '1') then
        if(nx_state /= pr_state) then
            pr_state <= nx_state;

            if(nx_state = IDLE_STATE) then
                addr_cnt_reg <= nx_addr_cnt_reg;
                print_finished <= '0';
                byte_to_send_reg <= signal_nr_in;

            elsif(nx_state = WAIT_UART_BUSY_SIG_NR) then
                byte_to_send_reg <= char_cr_cons;
                
            elsif(nx_state = COPY_DATA_TO_REG_STATE) then
                read_data_buffer <= ram_data_reg;           -- add new data to buffer to send
                data_reg_offset <= 0;                       -- Make ready to read first bit again

            elsif(nx_state = TRANS_DATA_STATE) then
                data_reg_offset <= data_reg_offset + 1;
                
                if(read_data_buffer(7-data_reg_offset) = '0') then
                    byte_to_send_reg <= char_0_cons;        -- transmit char 0
                else
                    byte_to_send_reg <= char_1_cons;        -- transmit char 1
                end if;
                
            elsif((nx_state = TRANS_CR_STATE) and (pr_state = WAIT_UART_BUSY)) then
                addr_cnt_reg <= nx_addr_cnt_reg;
                byte_to_send_reg <= char_cr_cons;           -- transmit char CR
                if(addr_cnt_reg = last_ram_addr) then 
                    print_finished <= '1';
                end if;
    
            elsif(nx_state = TRANS_LF_STATE) then
                byte_to_send_reg <= char_lf_cons;           -- transmit char LF
            end if;
        end if;
    end if;
end process;

-----------------------------------------------------------------------------------------------------
-- Print process fsm comb
-----------------------------------------------------------------------------------------------------
process(pr_state, data_reg_offset, read_data_buffer, print_log_en_in, uart_busy_reg) begin
    get_new_data <= '0';
    send_byte_reg <= '0';
    log_finish_out <= '0';
    
    nx_state <= nx_state;
    
    case pr_state is
    
        when IDLE_STATE =>
            nx_state <= IDLE_STATE;
            get_new_data <= '1';
            
            if(print_log_en_in = '1') then
                nx_state <= TRANS_SIG_NR_STATE;
            end if;

        when TRANS_SIG_NR_STATE =>            
            nx_state <= TRANS_SIG_NR_STATE;
            
            send_byte_reg <= '1';
            if(uart_busy_reg = '1') then
                nx_state <= WAIT_UART_BUSY_SIG_NR;
            end if;
            
        when WAIT_UART_BUSY_SIG_NR =>
            nx_state <= WAIT_UART_BUSY_SIG_NR;
            if(uart_busy_reg = '0') then
                nx_state <= TRANS_CR_STATE;
            end if;
    
        when COPY_DATA_TO_REG_STATE =>
            nx_state <= TRANS_DATA_STATE;
    
        when TRANS_DATA_STATE =>
            nx_state <= TRANS_DATA_STATE;
            send_byte_reg <= '1';
            if(uart_busy_reg = '1') then
                nx_state <= WAIT_UART_BUSY;
            end if;

        when WAIT_UART_BUSY =>
            nx_state <= WAIT_UART_BUSY;
            nx_addr_cnt_reg <= std_logic_vector((unsigned(addr_cnt_reg)+1));
            
            if(uart_busy_reg = '0') then
                if(data_reg_offset = 8) then
                    nx_state <= TRANS_CR_STATE;
                else
                    nx_state <= TRANS_DATA_STATE;
                end if;
            end if;

        when TRANS_CR_STATE =>            
            nx_state <= TRANS_CR_STATE;
            
            send_byte_reg <= '1';
            if(uart_busy_reg = '1') then
                nx_state <= WAIT_UART_BUSY_CR;
            end if;
            
        when WAIT_UART_BUSY_CR =>
            nx_state <= WAIT_UART_BUSY_CR;
            if(uart_busy_reg = '0') then
                nx_state <= TRANS_LF_STATE;
            end if;

        when TRANS_LF_STATE =>
            nx_state <= TRANS_LF_STATE;

            send_byte_reg <= '1';
            if(uart_busy_reg = '1') then
                nx_state <= WAIT_UART_BUSY_LF;
            end if;

        when WAIT_UART_BUSY_LF =>
            nx_state <= WAIT_UART_BUSY_LF;
            
            if(uart_busy_reg = '0') then
                if(print_finished = '1') then
                    nx_state <= IDLE_STATE;
                    log_finish_out <= '1';
                    nx_addr_cnt_reg <= (others => '0');
                else
                    nx_state <= COPY_DATA_TO_REG_STATE;
                end if;
            end if;
    end case;
  end process;

end Behavioral;
