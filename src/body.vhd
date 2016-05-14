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

entity Colossus_Body is

  generic (
    BODY_ID : Cam_Wheel_Step_Count_t);

  port (
    clk                            : in  std_logic;
    --
    set_step_count_cmd_i           : in  Cam_Wheel_Step_Count_t;
    printer_write_ctrl_o           : out Printer_Write_Ctrl_t;
    idle_o                         : out std_logic;
    assign_stepping_to_body_done_o : out std_logic;
    --
    slot_stepping_settings_rdy_i   : in  std_logic;
    slot_stepping_settings_bsy_o   : out std_logic;
    --
    slot_print_record_rdy_o : out std_logic;
    slot_print_record_bsy_i : in  std_logic;
    --
    maybe_print_idx_i : in Cam_Wheel_Step_Count_t;
    maybe_print_req_i : in std_logic;
    maybe_print_done_o : out std_logic;
    --
    cmd_ctrl_i                     : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o                     : out Ctrl_Bus_Fr_Target_t);

end entity Colossus_Body;

architecture behaviour of Colossus_Body is

  constant N_TARGETS   : integer := 10;
  signal target_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to N_TARGETS-1);
  --
  -- 0: bedstead
  -- 1: cam_wheels_panel
  -- 2: q_selector_panel
  -- 3: q_panel
  -- 4: counter_panel
  -- 5: comparator_panel
  -- 6: movement_controller
  -- 7: scheduler_panel
  -- 8: snoop_bus
  -- 9: nibble_adder_panel

  -- Stream buses:
  signal aug_z : Aug_TP_Letter_t;
  signal chi   : TP_Letter_t;
  signal psi   : TP_Letter_t;
  signal mu    : Motor_Wheels_t;
  signal q     : TP_Letter_t;
  signal q_delta : std_logic;  -- does Q involve any delta-ing?

  -- Bedstead operational control:
  signal bedstead_ctrl : Ctrl_Bus_To_Bedstead_t;

  -- Operational control for the Q Selector:
  signal q_sel_ctrl : Q_Selector_Ctrl_t;

  -- Cam wheels panel control
  signal cam_wheel_ctrl : Cam_Wheel_Ctrl_t;

  -- Cam wheel stepping counter file
  signal step_count_sel     : Cam_Wheel_Addr_t;
  signal step_count_val     : Cam_Wheel_Step_Count_t;
  signal step_reset_done    : std_logic;
  signal step_done          : std_logic;

  -- Summands emerging from Q panel
  signal summands : Counter_1b_Vec_t;

  -- Counter panel control
  signal counter_ctrl : Counter_Ctrl_t;

  -- Counter panel counter-value file
  signal counter_sel : Counter_Addr_t;
  signal counter_val : Counter_Value_t;

  -- Worker handshaking
  signal comparator_copy_settings                : Worker_Handshake_t;
  signal comparator_copy_counter_values          : Worker_Handshake_t;
  signal movement_reset_cam_wheels_movement      : Worker_Handshake_t;
  signal movement_reset_cam_wheels_movement_1    : Worker_Handshake_t;
  signal movement_reset_cam_wheels_movement_2    : Worker_Handshake_t;
  signal movement_reset_cam_wheels_stepping      : Worker_Handshake_t;
  signal movement_next_cam_wheels_stepping       : Worker_Handshake_t;
  signal movement_next_cam_wheels_stepping_ended : std_logic;
  signal movement_run_tape_once                  : Worker_Handshake_t;
  signal counters_latch_values                   : Worker_Handshake_t;

  -- Wiring between cmd-responder and cam-wheels-panel:
  signal set_step_count_cmd_selected : Cam_Wheel_Step_Count_t;
  signal set_step_count_adv : std_logic;

begin

  bedstead : entity work.Bedstead
    generic map (
      CONTROLLER_BASE_ADDR => 26)
    port map (
      clk      => clk,
      ctrl_i   => cmd_ctrl_i,
      ctrl_o   => target_ctrl_o(0),
      opr_ctrl => bedstead_ctrl,
      aug_z    => aug_z);

  cam_wheels_panel : entity work.Cam_Wheels_Panel
    generic map (
      BASE_ADDR => 170)
    port map (
      clk                    => clk,
      move_en_i              => cam_wheel_ctrl.move_en,
      --
      move_reset_req_i       => movement_reset_cam_wheels_movement.req,
      move_reset_done_o      => movement_reset_cam_wheels_movement.done,
      --
      step_counts_i          => set_step_count_cmd_selected,
      step_counts_set_adv_i  => set_step_count_adv,
      step_counts_set_done_o => assign_stepping_to_body_done_o,
      --
      step_count_sel_i       => step_count_sel,
      step_count_val_o       => step_count_val,
      --
      chi_o                  => chi,
      psi_o                  => psi,
      mu_o                   => mu,
      --
      cmd_ctrl_i             => cmd_ctrl_i,
      cmd_ctrl_o             => target_ctrl_o(1));

  set_step_command_responder : entity work.Set_Step_Command_Responder
    generic map (
      BODY_ID => BODY_ID)
    port map (
      clk                   => clk,
      step_set_cmd_i        => set_step_count_cmd_i,
      step_counts_o         => set_step_count_cmd_selected,
      step_counts_set_adv_o => set_step_count_adv);

  q_selector_panel : entity work.Q_Selector_Panel
    generic map (
      CONFIG_MAPPED_ADDR  => 23,
      CONTROL_MAPPED_ADDR => 22)
    port map (
      clk          => clk,
      cmd_ctrl_i   => cmd_ctrl_i,
      cmd_ctrl_o   => target_ctrl_o(2),
      z_i          => aug_z.letter,
      chi_i        => chi,
      psi_i        => psi,
      q_delta_o    => q_delta,
      q_o          => q,
      q_sel_ctrl_i => q_sel_ctrl);

  q_panel : entity work.Q_Panel
    generic map (
      BASE_ADDR => 80)
    port map (
      clk      => clk,
      ctrl_i   => cmd_ctrl_i,
      ctrl_o   => target_ctrl_o(3),
      q        => q,
      summands => summands);

  counter_panel : entity work.Counter_Panel
    generic map (
      MAPPED_ADDR   => 16,
      N_COUNTERS    => N_COUNTERS,
      COUNTER_WIDTH => COUNTER_WIDTH)
    port map (
      clk                       => clk,
      counter_sel_i             => counter_sel,
      counter_val_o             => counter_val,
      cmd_ctrl_i                => cmd_ctrl_i,
      cmd_ctrl_o                => target_ctrl_o(4),
      summands                  => summands,
      latch_counter_values_req  => counters_latch_values.req,
      latch_counter_values_done => counters_latch_values.done,
      counter_ctrl_i            => counter_ctrl);

  comparator_panel : entity work.Comparator_Panel
    generic map (
      BASE_ADDR => 128,
      BODY_ID => BODY_ID)
    port map (
      clk                     => clk,
      --
      step_count_sel_o        => step_count_sel,
      step_count_val_i        => step_count_val,
      copy_settings_req       => comparator_copy_settings.req,
      copy_settings_done      => comparator_copy_settings.done,
      --
      counter_sel_o           => counter_sel,
      counter_val_i           => counter_val,
      copy_counter_vals_req   => comparator_copy_counter_values.req,
      copy_counter_vals_done  => comparator_copy_counter_values.done,
      --
      printer_write_en        => printer_write_ctrl_o.write_en,
      printer_write_data      => printer_write_ctrl_o.write_data,
      --
      maybe_print_record_idx  => maybe_print_idx_i,
      maybe_print_record_req  => maybe_print_req_i,
      maybe_print_record_done => maybe_print_done_o,
      --
      cmd_ctrl_i              => cmd_ctrl_i,
      cmd_ctrl_o              => target_ctrl_o(5));

  movement_controller : entity work.Movement_Controller
    generic map (
      MAPPED_ADDR => 24)
    port map (
      clk                          => clk,
      cmd_ctrl_i                   => cmd_ctrl_i,
      cmd_ctrl_o                   => target_ctrl_o(6),
      run_tape_once_req            => movement_run_tape_once.req,
      run_tape_once_done           => movement_run_tape_once.done,
      --
      reset_wheels_movement_req_o  => movement_reset_cam_wheels_movement_2.req,
      reset_wheels_movement_done_i => movement_reset_cam_wheels_movement_2.done,
      --
      q_delta_i                    => q_delta,
      z_stop_i                     => aug_z.stop,
      bedstead_ctrl_o              => bedstead_ctrl,
      cam_wheel_ctrl_o             => cam_wheel_ctrl,
      q_sel_ctrl_o                 => q_sel_ctrl,
      counter_ctrl_o               => counter_ctrl);

  scheduler_panel : entity work.Scheduler_Panel
    generic map (
      MAPPED_ADDR => 144)
    port map (
      clk                              => clk,
      reset_cam_wheels_movement_req_o  => movement_reset_cam_wheels_movement_1.req,
      reset_cam_wheels_movement_done_i => movement_reset_cam_wheels_movement_1.done,
      run_tape_once_req_o              => movement_run_tape_once.req,
      run_tape_once_done_i             => movement_run_tape_once.done,
      latch_counter_values_req_o       => counters_latch_values.req,
      latch_counter_values_done_i      => counters_latch_values.done,
      copy_settings_req_o              => comparator_copy_settings.req,
      copy_settings_done_i             => comparator_copy_settings.done,
      copy_counter_vals_req_o          => comparator_copy_counter_values.req,
      copy_counter_vals_done_i         => comparator_copy_counter_values.done,
      --
      slot_stepping_settings_rdy_i     => slot_stepping_settings_rdy_i,
      slot_stepping_settings_bsy_o     => slot_stepping_settings_bsy_o,
      --
      slot_print_record_rdy_o => slot_print_record_rdy_o,
      slot_print_record_bsy_i => slot_print_record_bsy_i,
      --
      all_idle_o                       => idle_o,
      --
      cmd_ctrl_i                       => cmd_ctrl_i,
      cmd_ctrl_o                       => target_ctrl_o(7));

  snoop_bus : entity work.Snoop_Bus
    generic map (
      MAPPED_ADDR => 25)
    port map (
      clk      => clk,
      ctrl_i   => cmd_ctrl_i,
      ctrl_o   => target_ctrl_o(8),
      aug_z    => aug_z,
      chi      => chi,
      q        => q,
      summands => summands);

  nibble_adder_panel : entity work.Nibble_Adder_Panel
    generic map (
      MAPPED_ADDR => 8)
    port map (
      clk        => clk,
      --
      cmd_ctrl_i => cmd_ctrl_i,
      cmd_ctrl_o => target_ctrl_o(9));

  -- Bit of a hack; two clients both need to be able to request the cam-wheels
  -- panel resets its movement.
  --
  movement_reset_cam_wheels_movement.req
    <= (movement_reset_cam_wheels_movement_1.req
        or movement_reset_cam_wheels_movement_2.req);
  --
  movement_reset_cam_wheels_movement_1.done <= movement_reset_cam_wheels_movement.done;
  movement_reset_cam_wheels_movement_2.done <= movement_reset_cam_wheels_movement.done;

  -----------------------------------------------------------------------------

  reduce_outputs : process (target_ctrl_o)
  is
    variable v_bus : Ctrl_Bus_Fr_Target_t;
  begin
    v_bus := CTRL_BUS_FR_TARGET_ZERO;

    for i in 0 to N_TARGETS-1 loop
      v_bus := v_bus or target_ctrl_o(i);
    end loop;  -- i

    cmd_ctrl_o <= v_bus;
  end process reduce_outputs;

  -- Ground unused inputs.
  printer_write_ctrl_o.erase_en <= '0';

end architecture behaviour;
