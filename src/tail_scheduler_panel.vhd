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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.utils.all;

-------------------------------------------------------------------------------

entity Tail_Scheduler_Panel is

  generic (
    MAPPED_ADDR : integer;
    N_BODIES : integer);

  port (
    clk                  : in  std_logic;
    --
    slot_print_record_rdy_i : in std_logic_vector(0 to N_BODIES-1);
    slot_print_record_bsy_o : out std_logic_vector(0 to N_BODIES-1);
    --
    maybe_print_record_idx_o  : out  Cam_Wheel_Step_Count_t;
    maybe_print_record_req_o  : out  std_logic;
    maybe_print_record_done_i : in std_logic_vector(0 to N_BODIES-1);
    --
    all_idle_o : out std_logic;
    --
    cmd_ctrl_i           : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o           : out Ctrl_Bus_Fr_Target_t);

end entity Tail_Scheduler_Panel;

architecture behaviour of Tail_Scheduler_Panel is

  signal auto_idx : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal auto_req : std_logic := '0';
  signal manual_idx : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal manual_req : std_logic := '0';
  signal worker_done : std_logic;

  signal slot_print_record_rdy : std_logic_vector(0 to N_BODIES-1);
  signal slot_print_record_bsy : std_logic_vector(0 to N_BODIES-1);

begin

  connect_slot_signals : process (slot_print_record_rdy_i,
                                  slot_print_record_bsy)
  is
  begin
    for i in 0 to N_BODIES-1 loop
      slot_print_record_rdy(i) <= slot_print_record_rdy_i(i);
      slot_print_record_bsy_o(i) <= slot_print_record_bsy(i);
    end loop;
  end process;

  maybe_print_record_idx_o <= auto_idx or manual_idx;
  maybe_print_record_req_o <= auto_req or manual_req;

  reduce_worker_done : process (maybe_print_record_done_i)
  is
    variable tmp_done : std_logic;
  begin
    tmp_done := '0';
    for i in 0 to N_BODIES-1 loop
      tmp_done := tmp_done or maybe_print_record_done_i(i);
    end loop;
    worker_done <= tmp_done;
  end process;

  collect_print_records : entity work.Queued_Datum_Controller_Collector_Sink
    generic map (
      N_PRODUCERS     => N_BODIES,
      PRODUCER_IDX_WD => Cam_Wheel_Step_Count_t'length)
    port map (
      clk         => clk,
      left_rdy_i  => slot_print_record_rdy,
      left_bsy_o  => slot_print_record_bsy,
      work_idx_o  => auto_idx,
      work_req_o  => auto_req,
      work_done_i => worker_done);

  command_target : process (clk)
  is
    type FSM_State_t is (Idle,
                         Request_Work_0, Request_Work_1,
                         Awaiting_Work_Completion,
                         Work_Completed,
                         Cmd_Done,
                         Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable body_idx : Cam_Wheel_Step_Count_t;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              body_idx := unsigned(cmd_ctrl_i.data(5 downto 0));
              if cmd_ctrl_i.data(7 downto 6) = "00" then
                state := Request_Work_0;
              else
                state := Bad_Sub_Cmd;
              end if;
            end if;
          else
            cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Request_Work_0 =>
          manual_idx <= body_idx;
          manual_req <= '1';
          state := Request_Work_1;
        when Request_Work_1 =>
          manual_idx <= CAM_WHEEL_STEP_COUNT_ZERO;
          manual_req <= '0';
          state := Awaiting_Work_Completion;
        when Awaiting_Work_Completion =>
          if worker_done = '1' then
            state := Work_Completed;
          end if;
        when Work_Completed =>
          cmd_success_code := x"19";
          state := Cmd_Done;
        when Cmd_Done =>
          ctrl_cmd_success(cmd_ctrl_o, cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(cmd_ctrl_o, x"ad");
          state := Idle;
      end case;
    end if;
  end process command_target;

  assess_all_idle : process (slot_print_record_rdy, slot_print_record_bsy)
  is
    variable busy : std_logic;
  begin
    busy := '0';
    for i in 0 to N_BODIES-1 loop
      busy := busy or slot_print_record_rdy(i) or slot_print_record_bsy(i);
    end loop;
    all_idle_o <= not busy;
  end process;

end architecture behaviour;
