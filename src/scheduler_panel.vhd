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

entity Scheduler_Panel is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk                  : in  std_logic;
    --
    reset_cam_wheels_movement_req_o  : out std_logic;
    reset_cam_wheels_movement_done_i : in  std_logic;
    run_tape_once_req_o  : out std_logic;
    run_tape_once_done_i : in  std_logic;
    latch_counter_values_req_o  : out std_logic;
    latch_counter_values_done_i : in std_logic;
    copy_settings_req_o  : out std_logic;
    copy_settings_done_i : in  std_logic;
    copy_counter_vals_req_o  : out  std_logic;
    copy_counter_vals_done_i : in std_logic;
    --
    slot_stepping_settings_rdy_i : in std_logic;
    slot_stepping_settings_bsy_o : out std_logic;
    --
    slot_print_record_rdy_o : out std_logic;
    slot_print_record_bsy_i : in std_logic;
    --
    all_idle_o : out std_logic;
    --
    cmd_ctrl_i           : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o           : out Ctrl_Bus_Fr_Target_t);

end entity Scheduler_Panel;

architecture behaviour of Scheduler_Panel is

  constant N_WORKERS : integer := 5;
  -- 0x00 Trigger 'copy settings' of Comparator
  -- 0x01 Trigger 'copy counter values' of Comparator
  -- 0x02 Trigger 'run tape once' of Movement
  -- 0x03 Trigger 'latch live counters to output' of Counters
  -- 0x04 Trigger 'reset cam wheels movement' of Counters

  signal auto_worker_req_o : std_logic_vector(0 to N_WORKERS-1) := (others => '0');
  signal manual_worker_req_o : std_logic_vector(0 to N_WORKERS-1) := (others => '0');
  signal worker_done_i : std_logic_vector(0 to N_WORKERS-1);
  signal all_idle : std_logic := '0';

  signal slot_counter_comparands : Pipeline_Connector_t := (others => '0');
  signal slot_latched_ctrs : Pipeline_Connector_t := (others => '0');
  signal slot_live_ctrs : Pipeline_Connector_t := (others => '0');
  signal slot_active_pattern : Pipeline_Connector_t := (others => '0');
  signal slot_stepping_settings : Pipeline_Connector_t := (others => '0');
  signal slot_stepping_settings_1 : Pipeline_Connector_t := (others => '0');
  signal slot_stepping_settings_2 : Pipeline_Connector_t := (others => '0');
  signal slot_stepping_labels : Pipeline_Connector_t := (others => '0');

begin

  slot_stepping_settings.rdy <= slot_stepping_settings_rdy_i;
  slot_stepping_settings_bsy_o <= slot_stepping_settings.bsy;

  tee_slot_stepping_settings : entity work.Queued_Datum_Controller_Tee
    port map (
      clk           => clk,
      left_rdy_i    => slot_stepping_settings.rdy,
      left_bsy_o    => slot_stepping_settings.bsy,
      right_1_rdy_o => slot_stepping_settings_1.rdy,
      right_1_bsy_i => slot_stepping_settings_1.bsy,
      right_2_rdy_o => slot_stepping_settings_2.rdy,
      right_2_bsy_i => slot_stepping_settings_2.bsy);

  pipe_stepping_settings_1_to_active_pattern : entity work.Queued_Datum_Controller_Pipe
    port map (
      clk         => clk,
      left_rdy_i  => slot_stepping_settings_1.rdy,
      left_bsy_o  => slot_stepping_settings_1.bsy,
      right_rdy_o => slot_active_pattern.rdy,
      right_bsy_i => slot_active_pattern.bsy,
      work_req_o  => auto_worker_req_o(4),  -- reset_cam_wheels_movement
      work_done_i => worker_done_i(4));

  pipe_active_pattern_to_live_ctrs : entity work.Queued_Datum_Controller_Pipe
    port map (
      clk         => clk,
      left_rdy_i  => slot_active_pattern.rdy,
      left_bsy_o  => slot_active_pattern.bsy,
      right_rdy_o => slot_live_ctrs.rdy,
      right_bsy_i => slot_live_ctrs.bsy,
      work_req_o  => auto_worker_req_o(2),  -- run_tape_once
      work_done_i => worker_done_i(2));

  pipe_live_ctrs_to_latched_ctrs : entity work.Queued_Datum_Controller_Pipe
    port map (
      clk         => clk,
      left_rdy_i  => slot_live_ctrs.rdy,
      left_bsy_o  => slot_live_ctrs.bsy,
      right_rdy_o => slot_latched_ctrs.rdy,
      right_bsy_i => slot_latched_ctrs.bsy,
      work_req_o  => auto_worker_req_o(3),  -- latch_counter_values
      work_done_i => worker_done_i(3));

  pipe_latched_ctrs_to_ctr_comparands : entity work.Queued_Datum_Controller_Pipe
    port map (
      clk         => clk,
      left_rdy_i  => slot_latched_ctrs.rdy,
      left_bsy_o  => slot_latched_ctrs.bsy,
      right_rdy_o => slot_counter_comparands.rdy,
      right_bsy_i => slot_counter_comparands.bsy,
      work_req_o  => auto_worker_req_o(1),  -- copy_counter_vals
      work_done_i => worker_done_i(1));

  pipe_stepping_settings_2_to_step_labels : entity work.Queued_Datum_Controller_Pipe
    port map (
      clk         => clk,
      left_rdy_i  => slot_stepping_settings_2.rdy,
      left_bsy_o  => slot_stepping_settings_2.bsy,
      right_rdy_o => slot_stepping_labels.rdy,
      right_bsy_i => slot_stepping_labels.bsy,
      work_req_o  => auto_worker_req_o(0),  -- copy_settings
      work_done_i => worker_done_i(0));

  join_ctr_comparands_step_labels : entity work.Queued_Datum_Controller_Join
    port map (
      clk          => clk,
      left_1_rdy_i => slot_counter_comparands.rdy,
      left_1_bsy_o => slot_counter_comparands.bsy,
      left_2_rdy_i => slot_stepping_labels.rdy,
      left_2_bsy_o => slot_stepping_labels.bsy,
      right_rdy_o  => slot_print_record_rdy_o,
      right_bsy_i  => slot_print_record_bsy_i);

  command_target : process (clk)
  is
    type FSM_State_t is (Idle,
                         Request_Work_0, Request_Work_1,
                         Awaiting_Work_Completion,
                         Work_Completed,
                         Cmd_Done,
                         Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable worker_idx : integer;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              worker_idx := to_integer(unsigned(cmd_ctrl_i.data));
              if worker_idx < N_WORKERS then
                state := Request_Work_0;
              else
                state := Bad_Sub_Cmd;
              end if;
            end if;
          else
            cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Request_Work_0 =>
          manual_worker_req_o(worker_idx) <= '1';
          state := Request_Work_1;
        when Request_Work_1 =>
          manual_worker_req_o(worker_idx) <= '0';
          state := Awaiting_Work_Completion;
        when Awaiting_Work_Completion =>
          if worker_done_i(worker_idx) = '1' then
            state := Work_Completed;
          end if;
        when Work_Completed =>
          cmd_success_code := x"12";
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

  emit_req_o : process (manual_worker_req_o, auto_worker_req_o)
  is
    variable combined_worker_req_o : std_logic_vector(0 to N_WORKERS-1);
  begin
    combined_worker_req_o := manual_worker_req_o or auto_worker_req_o;
    copy_settings_req_o <= combined_worker_req_o(0);
    copy_counter_vals_req_o <= combined_worker_req_o(1);
    run_tape_once_req_o <= combined_worker_req_o(2);
    latch_counter_values_req_o <= combined_worker_req_o(3);
    reset_cam_wheels_movement_req_o <= combined_worker_req_o(4);
  end process emit_req_o;

  worker_done_i(0) <= copy_settings_done_i;
  worker_done_i(1) <= copy_counter_vals_done_i;
  worker_done_i(2) <= run_tape_once_done_i;
  worker_done_i(3) <= latch_counter_values_done_i;
  worker_done_i(4) <= reset_cam_wheels_movement_done_i;

  all_idle <= not ((slot_stepping_settings.rdy or slot_stepping_settings.bsy)
                   or (slot_stepping_settings_1.rdy or slot_stepping_settings_1.bsy)
                   or (slot_stepping_settings_2.rdy or slot_stepping_settings_2.bsy)
                   or (slot_stepping_labels.rdy or slot_stepping_labels.bsy)
                   or (slot_active_pattern.rdy or slot_active_pattern.bsy)
                   or (slot_live_ctrs.rdy or slot_live_ctrs.bsy)
                   or (slot_latched_ctrs.rdy or slot_latched_ctrs.bsy)
                   or (slot_counter_comparands.rdy or slot_counter_comparands.bsy));

  all_idle_o <= all_idle;

end architecture behaviour;
