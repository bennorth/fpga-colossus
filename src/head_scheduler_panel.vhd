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

entity Head_Scheduler_Panel is

  generic (
    MAPPED_ADDR : integer;
    N_BODIES : integer);

  port (
    clk                  : in  std_logic;
    --
    cam_wheels_stepping_reset_req_o : out std_logic;
    cam_wheels_stepping_reset_done_i : in std_logic;
    cam_wheels_stepping_next_req_o : out std_logic;
    cam_wheels_stepping_next_done_i : in std_logic;
    cam_wheels_stepping_next_ended_i : in std_logic;
    --
    assign_stepping_to_body_idx_o : out Cam_Wheel_Step_Count_t;
    assign_stepping_to_body_req_o : out std_logic;
    assign_stepping_to_body_done_i : in std_logic_vector(0 to N_BODIES-1);
    --
    body_stepped_pattern_rdy_o : out std_logic_vector(0 to N_BODIES-1);
    body_stepped_pattern_bsy_i : in std_logic_vector(0 to N_BODIES-1);
    --
    others_idle_i  : in std_logic;
    --
    cmd_ctrl_i           : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o           : out Ctrl_Bus_Fr_Target_t);

end entity Head_Scheduler_Panel;

architecture behaviour of Head_Scheduler_Panel is

  signal slot_initiate_run : Pipeline_Connector_t := (others => '0');
  signal slot_step_count_vector : Pipeline_Connector_t := (others => '0');

  signal slot_body_stepped_pattern_rdy : std_logic_vector(0 to N_BODIES-1);
  signal slot_body_stepped_pattern_bsy : std_logic_vector(0 to N_BODIES-1);

  constant N_WORKERS : integer := 1;
  -- 0x00 Transfer step counts to body's stepped pattern
  --
  -- Because there is only one worker, there is some laziness below in
  -- handling various 'vector's of signals.

  signal auto_body_idx_o : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal auto_worker_req_o : std_logic_vector(0 to N_WORKERS-1) := (others => '0');
  signal manual_body_idx_o : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal manual_worker_req_o : std_logic_vector(0 to N_WORKERS-1) := (others => '0');
  signal worker_done_i : std_logic_vector(0 to N_WORKERS-1);
  signal all_idle : std_logic := '0';

begin

  generate_stepping_settings : entity work.Queued_Datum_Controller_Generator_Source
    port map (
      clk          => clk,
      left_rdy_i   => slot_initiate_run.rdy,
      left_bsy_o   => slot_initiate_run.bsy,
      right_rdy_o  => slot_step_count_vector.rdy,
      right_bsy_i  => slot_step_count_vector.bsy,
      reset_req_o  => cam_wheels_stepping_reset_req_o,
      reset_done_i => cam_wheels_stepping_reset_done_i,
      next_req_o   => cam_wheels_stepping_next_req_o,
      next_done_i  => cam_wheels_stepping_next_done_i,
      next_ended_i => cam_wheels_stepping_next_ended_i);

  -- Distribute 'Step Count Vector' to each body's 'Stepped Pattern':
  distribute_scv_to_stepped_pattern : entity work.Queued_Datum_Controller_Distributor
    generic map (
      N_CONSUMERS     => N_BODIES,
      CONSUMER_IDX_WD => Cam_Wheel_Step_Count_t'length)
    port map (
      clk         => clk,
      left_rdy_i  => slot_step_count_vector.rdy,
      left_bsy_o  => slot_step_count_vector.bsy,
      right_rdy_o => slot_body_stepped_pattern_rdy,
      right_bsy_i => slot_body_stepped_pattern_bsy,
      work_idx_o  => auto_body_idx_o,
      work_req_o  => auto_worker_req_o(0),
      work_done_i => worker_done_i(0));

  emit_req_o : process (manual_worker_req_o, auto_worker_req_o,
                        manual_body_idx_o, auto_body_idx_o)
  is
    variable combined_worker_req_o : std_logic_vector(0 to N_WORKERS-1);
  begin
    combined_worker_req_o := manual_worker_req_o or auto_worker_req_o;
    assign_stepping_to_body_req_o <= combined_worker_req_o(0);

    assign_stepping_to_body_idx_o <= manual_body_idx_o or auto_body_idx_o;
  end process emit_req_o;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle,
                         Request_Work_0, Request_Work_1,
                         Awaiting_Work_Completion,
                         Work_Completed,
                         Manual_Signal_Ready,
                         Manual_Await_Acq_Ack,
                         Manual_Await_All_Idle,
                         Cmd_Done,
                         Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable worker_idx : integer;
    variable body_idx : Cam_Wheel_Step_Count_t;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              worker_idx := to_integer(unsigned(cmd_ctrl_i.data(7 downto 6)));
              body_idx := unsigned(cmd_ctrl_i.data(5 downto 0));
              if worker_idx < N_WORKERS then
                state := Request_Work_0;
              elsif worker_idx = 3 then
                state := Manual_Signal_Ready;
              else
                state := Bad_Sub_Cmd;
              end if;
            end if;
          else
            cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Request_Work_0 =>
          manual_body_idx_o <= body_idx;
          manual_worker_req_o(worker_idx) <= '1';
          state := Request_Work_1;
        when Request_Work_1 =>
          manual_body_idx_o <= CAM_WHEEL_STEP_COUNT_ZERO;
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
        when Manual_Signal_Ready =>
          slot_initiate_run.rdy <= '1';
          state := Manual_Await_Acq_Ack;
        when Manual_Await_Acq_Ack =>
          if slot_initiate_run.bsy = '1' then
            slot_initiate_run.rdy <= '0';
            state := Manual_Await_All_Idle;
          end if;
        when Manual_Await_All_Idle =>
          if (all_idle and others_idle_i) = '1' then
            cmd_success_code := x"15";
            state := Cmd_Done;
          end if;
      end case;
    end if;
  end process command_target;

  -- Feed through, but we also need to be able to determine 'all idle'.
  body_stepped_pattern_rdy_o <= slot_body_stepped_pattern_rdy;
  slot_body_stepped_pattern_bsy <= body_stepped_pattern_bsy_i;

  reduce_worker_done : process (assign_stepping_to_body_done_i)
  is
    variable any_done : std_logic;
  begin
    any_done := '0';
    for i in 0 to N_BODIES-1 loop
      any_done := any_done or assign_stepping_to_body_done_i(i);
    end loop;

    worker_done_i(0) <= any_done;
  end process reduce_worker_done;

  reduce_all_idle : process (slot_initiate_run,
                             slot_step_count_vector,
                             slot_body_stepped_pattern_rdy,
                             slot_body_stepped_pattern_bsy)
  is
    variable any_busy : std_logic;
  begin
    any_busy := ((slot_initiate_run.rdy or slot_initiate_run.bsy)
                 or (slot_step_count_vector.rdy or slot_step_count_vector.bsy));
    for i in 0 to N_BODIES-1 loop
      any_busy := (any_busy
                   or slot_body_stepped_pattern_rdy(i)
                   or slot_body_stepped_pattern_bsy(i));
    end loop;
    all_idle <= not any_busy;
  end process;

end architecture behaviour;
