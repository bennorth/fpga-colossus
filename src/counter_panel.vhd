------------------------------------------------------------------------------
--
-- Copyright 2016 Ben North
--
-- This file is part of "FPGA Colossus".
--
-- "FPGA Colossus" is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- "FPGA Colossus" is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- "FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.
--
------------------------------------------------------------------------------

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.utils.all;

------------------------------------------------------------------------------

-- The 'latch counter values' worker is implemented here; it just has to assert
-- 'output_en' of the control signal to all of the actual Counter instances and
-- provide the 'req'/'done' protocol.
--
-- We provide a memory-like interface to the latched counter values via
-- 'counter_sel_i' and 'counter_val_o'.

------------------------------------------------------------------------------

entity Counter_Panel is

  generic (
    MAPPED_ADDR   : integer;
    N_COUNTERS    : integer;
    COUNTER_WIDTH : integer);

  port (
    -- clock:
    clk            : in  std_logic;
    -- 'memory-mapped' counter file:
    counter_sel_i  : in  Counter_Addr_t;
    counter_val_o  : out Counter_Value_t;
    -- command interface:
    cmd_ctrl_i     : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o     : out Ctrl_Bus_Fr_Target_t;
    -- summand vector input:
    summands       : in  Counter_1b_Vec_t;
    -- worker to latch live counters to output:
    latch_counter_values_req  : in  std_logic;
    latch_counter_values_done : out std_logic;
    -- automatic counter control:
    counter_ctrl_i : in  Counter_Ctrl_t);

end entity Counter_Panel;

architecture behaviour of Counter_Panel is

  subtype Counter_Value_t is unsigned(COUNTER_WIDTH-1 downto 0);
  type Counter_Value_Vec_t is array (natural range <>) of Counter_Value_t;

  signal count : Counter_Value_Vec_t(N_COUNTERS-1 downto 0);
  signal manual_ctrl : Counter_Ctrl_t;
  signal worker_ctrl : Counter_Ctrl_t := COUNTER_CTRL_ZERO;

  signal combined_ctrl : Counter_Ctrl_t;

begin

  counter : for i in 0 to (N_COUNTERS - 1) generate
  begin
    counter : entity work.Counter
      generic map (
        WIDTH => COUNTER_WIDTH)
      port map (
        clk     => clk,
        summand => summands(i),
        ctrl_i  => combined_ctrl,
        count_o => count(i));
  end generate;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
    variable counter_idx : natural range 0 to N_COUNTERS-1;
  begin  -- process command_target
    if rising_edge(clk) then
      cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
      case state is
        when Idle =>
          manual_ctrl <= COUNTER_CTRL_ZERO;
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              case cmd_ctrl_i.data is
                -- 0x80 Reset counters
                -- 0x81 Accumulate summand vector elts (one-shot)
                -- 0x82 Snapshot counters
                -- 0x0n Read counter snapshot n low octet
                -- 0x1n Read counter snapshot n high (part-)octet
                when x"80" =>
                  manual_ctrl.count_rst <= '1';
                  cmd_success_code := x"a0";
                  state := Cmd_Done;
                when x"81" =>
                  manual_ctrl.count_en <= '1';
                  cmd_success_code := x"a1";
                  state := Cmd_Done;
                when x"82" =>
                  manual_ctrl.output_en <= '1';
                  cmd_success_code := x"a2";
                  state := Cmd_Done;
                when others =>
                  counter_idx := to_integer(
                    unsigned(cmd_ctrl_i.data(3 downto 0)));
                  if cmd_ctrl_i.data(7 downto 4) = x"0" then
                    cmd_success_code
                      := std_logic_vector(count(counter_idx)(7 downto 0));
                    state := Cmd_Done;
                  elsif cmd_ctrl_i.data(7 downto 4) = x"1" then
                    cmd_success_code
                      := std_logic_vector(
                           resize(count(counter_idx)(COUNTER_WIDTH-1 downto 8),
                                  Ctrl_Response_t'length));
                    state := Cmd_Done;
                  else
                    state := Bad_Sub_Cmd;
                  end if;
              end case;
            end if;
          end if;
        when Cmd_Done =>
          manual_ctrl <= COUNTER_CTRL_ZERO;
          ctrl_cmd_success(cmd_ctrl_o, cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(cmd_ctrl_o, x"52");
          state := Idle;
      end case;
    end if;
  end process command_target;

  latch_values_worker : process (clk)
  is
    type FSM_State_t is (Idle, Delay, Latch, End_Pulse);
    variable state : FSM_State_t := Idle;
    variable n_wait_cycles_remaining : integer range 0 to 3 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          latch_counter_values_done <= '0';
          if latch_counter_values_req = '1' then
            n_wait_cycles_remaining := 3;
            state := Delay;
          end if;
        when Delay =>
          -- Leave time for requesters to start watching 'done'.
          if n_wait_cycles_remaining = 0 then
            state := Latch;
          else
            n_wait_cycles_remaining := n_wait_cycles_remaining - 1;
          end if;
        when Latch =>
          worker_ctrl.output_en <= '1';
          state := End_Pulse;
        when End_Pulse =>
          worker_ctrl.output_en <= '0';
          latch_counter_values_done <= '1';
          state := Idle;
      end case;
    end if;
  end process latch_values_worker;

  combined_ctrl <= counter_ctrl_i or manual_ctrl or worker_ctrl;

  access_counter_values : process(clk)
  is
    variable int_counter_sel : integer;
  begin
    if rising_edge(clk) then
      int_counter_sel := to_integer(counter_sel_i);

      if int_counter_sel < N_COUNTERS then
        counter_val_o <= count(int_counter_sel);
      else
        counter_val_o <= (others => '0');
      end if;
    end if;
  end process access_counter_values;

  -- Ground unused inputs
  worker_ctrl.count_en <= '0';
  worker_ctrl.count_rst <= '0';

end architecture behaviour;
