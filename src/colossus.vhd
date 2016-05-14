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
use work.types.all;
use work.utils.all;

------------------------------------------------------------------------------

entity Colossus is

  port (
    clk    : in  std_logic;
    ctrl_i : in  Ctrl_Bus_To_Target_t;
    ctrl_o : out Ctrl_Bus_Fr_Target_t);

end entity Colossus;

architecture behaviour of Colossus is

  signal body_cmd : Ctrl_Bus_To_Target_t;
  signal body_resp : Ctrl_Bus_Fr_Target_t;
  signal head_tail_cmd : Ctrl_Bus_To_Target_t;
  signal head_tail_resp : Ctrl_Bus_Fr_Target_t;

  constant N_BODIES   : integer := 2;

  constant N_TARGETS   : integer := 4;
  signal target_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to N_TARGETS-1);
  --
  -- 0: step_count_vector_unit
  -- 1: printer_panel
  -- 2: head_scheduler_panel
  -- 3: tail_scheduler_panel

  -- Printer control
  signal printer_write_ctrl : Printer_Write_Ctrl_t;
  signal body_printer_write_ctrl : Printer_Write_Ctrl_Vec_t(0 to N_BODIES-1);

  -- Worker handshaking
  signal step_count_vector_reset : Worker_Handshake_t;
  signal step_count_vector_next  : Generator_Worker_Handshake_t;
  signal assign_stepping_to_body : Indexed_Worker_Handshake_t;
  signal assign_stepping_to_body_done : std_logic_vector(0 to N_BODIES-1);

  -- Set step counts command bus:
  signal set_step_count_cmd : Cam_Wheel_Step_Count_t;

  signal slot_stepping_settings_rdy : std_logic_vector(0 to N_BODIES-1);
  signal slot_stepping_settings_bsy : std_logic_vector(0 to N_BODIES-1);

  signal slot_print_record_rdy : std_logic_vector(0 to N_BODIES-1);
  signal slot_print_record_bsy : std_logic_vector(0 to N_BODIES-1);
  signal maybe_print_record_idx : Cam_Wheel_Step_Count_t;
  signal maybe_print_record_req : std_logic;
  signal maybe_print_record_done : std_logic_vector(0 to N_BODIES-1);

  signal body_idle : std_logic_vector(0 to N_BODIES-1);
  signal tail_idle : std_logic;
  signal bodies_and_tail_idle : std_logic;

  signal body_0_cmd : Ctrl_Bus_To_Target_t;
  signal body_0_resp : Ctrl_Bus_Fr_Target_t;
  signal body_1_cmd : Ctrl_Bus_To_Target_t;
  signal body_1_resp : Ctrl_Bus_Fr_Target_t;

begin

  head_body_cmd_demux : entity work.Head_Body_Cmd_Demux
    port map (
      clk         => clk,
      cmd_i       => ctrl_i,
      resp_o      => ctrl_o,
      head_tail_cmd_o  => head_tail_cmd,
      head_tail_resp_i => head_tail_resp,
      body_cmd_o  => body_cmd,
      body_resp_i => body_resp);

  step_count_vector_unit : entity work.Step_Count_Vector_Unit
    generic map (BASE_ADDR => 224)
    port map (
       clk             => clk,
       reset_req_i     => step_count_vector_reset.req,
       reset_done_o    => step_count_vector_reset.done,
       next_req_i      => step_count_vector_next.req,
       next_done_o     => step_count_vector_next.done,
       next_ended_o    => step_count_vector_next.ended,
       emit_tgt_i      => assign_stepping_to_body.idx,
       emit_req_i      => assign_stepping_to_body.req,
       step_set_cmds_o => set_step_count_cmd,
       --
       cmd_ctrl_i      => head_tail_cmd,
       cmd_ctrl_o      => target_ctrl_o(0));

  replicate_validator : entity work.Replicate_Validator
    port map (
      clk             => clk,
      --
      to_tgt_i        => body_cmd,
      from_tgt_o      => body_resp,
      to_this_tgt_o   => body_0_cmd,
      from_this_tgt_i => body_0_resp,
      to_next_tgt_o   => body_1_cmd,
      from_next_tgt_i => body_1_resp);

  colossus_body_0 : entity work.Colossus_Body
    generic map (
      BODY_ID => Cam_Wheel_Step_Count_f_Int(0))
    port map (
      clk                            => clk,
      set_step_count_cmd_i           => set_step_count_cmd,
      printer_write_ctrl_o           => body_printer_write_ctrl(0),
      idle_o                         => body_idle(0),
      assign_stepping_to_body_done_o => assign_stepping_to_body_done(0),
      slot_stepping_settings_rdy_i   => slot_stepping_settings_rdy(0),
      slot_stepping_settings_bsy_o   => slot_stepping_settings_bsy(0),
      --
      slot_print_record_rdy_o => slot_print_record_rdy(0),
      slot_print_record_bsy_i => slot_print_record_bsy(0),
      --
      maybe_print_idx_i => maybe_print_record_idx,
      maybe_print_req_i => maybe_print_record_req,
      maybe_print_done_o => maybe_print_record_done(0),
      --
      cmd_ctrl_i                     => body_0_cmd,
      cmd_ctrl_o                     => body_0_resp);

  colossus_body_1 : entity work.Colossus_Body
    generic map (
      BODY_ID => Cam_Wheel_Step_Count_f_Int(1))
    port map (
      clk                            => clk,
      set_step_count_cmd_i           => set_step_count_cmd,
      printer_write_ctrl_o           => body_printer_write_ctrl(1),
      idle_o                         => body_idle(1),
      assign_stepping_to_body_done_o => assign_stepping_to_body_done(1),
      slot_stepping_settings_rdy_i   => slot_stepping_settings_rdy(1),
      slot_stepping_settings_bsy_o   => slot_stepping_settings_bsy(1),
      --
      slot_print_record_rdy_o => slot_print_record_rdy(1),
      slot_print_record_bsy_i => slot_print_record_bsy(1),
      --
      maybe_print_idx_i => maybe_print_record_idx,
      maybe_print_req_i => maybe_print_record_req,
      maybe_print_done_o => maybe_print_record_done(1),
      --
      cmd_ctrl_i                     => body_1_cmd,
      cmd_ctrl_o                     => body_1_resp);

  printer_panel : entity work.Printer_Panel
    generic map (
      MAPPED_ADDR => 242)
    port map (
      clk        => clk,
      ctrl_i     => printer_write_ctrl,
      --
      cmd_ctrl_i => head_tail_cmd,
      cmd_ctrl_o => target_ctrl_o(1));

  head_scheduler_panel : entity work.Head_Scheduler_Panel
    generic map (
      MAPPED_ADDR => 240,
      N_BODIES => N_BODIES)
    port map (
      clk                              => clk,
      --
      cam_wheels_stepping_reset_req_o  => step_count_vector_reset.req,
      cam_wheels_stepping_reset_done_i => step_count_vector_reset.done,
      cam_wheels_stepping_next_req_o   => step_count_vector_next.req,
      cam_wheels_stepping_next_done_i  => step_count_vector_next.done,
      cam_wheels_stepping_next_ended_i => step_count_vector_next.ended,
      --
      assign_stepping_to_body_idx_o    => assign_stepping_to_body.idx,
      assign_stepping_to_body_req_o    => assign_stepping_to_body.req,
      assign_stepping_to_body_done_i   => assign_stepping_to_body_done,
      --
      body_stepped_pattern_rdy_o       => slot_stepping_settings_rdy,
      body_stepped_pattern_bsy_i       => slot_stepping_settings_bsy,
      --
      others_idle_i                    => bodies_and_tail_idle,
      --
      cmd_ctrl_i                       => head_tail_cmd,
      cmd_ctrl_o                       => target_ctrl_o(2));

  tail_scheduler_panel : entity work.Tail_Scheduler_Panel
    generic map (
      MAPPED_ADDR => 241,
      N_BODIES    => 2)
    port map (
        clk                       => clk,
        slot_print_record_rdy_i   => slot_print_record_rdy,
        slot_print_record_bsy_o   => slot_print_record_bsy,
        maybe_print_record_idx_o  => maybe_print_record_idx,
        maybe_print_record_req_o  => maybe_print_record_req,
        maybe_print_record_done_i => maybe_print_record_done,
        all_idle_o                => tail_idle,
        cmd_ctrl_i                => head_tail_cmd,
        cmd_ctrl_o                => target_ctrl_o(3));

  reduce_idles : process (body_idle, tail_idle)
  is
    variable idle : std_logic;
  begin
    idle := tail_idle;
    for i in 0 to N_BODIES-1 loop
      idle := idle and body_idle(i);
    end loop;
    bodies_and_tail_idle <= idle;
  end process;

  reduce_printer_write_ctrl : process (body_printer_write_ctrl)
  is
    variable ctrl : Printer_Write_Ctrl_t;
  begin
    ctrl := PRINTER_WRITE_CTRL_ZERO;
    for i in 0 to N_BODIES-1 loop
      ctrl := ctrl or body_printer_write_ctrl(i);
    end loop;
    printer_write_ctrl <= ctrl;
  end process;

  reduce_outputs : process (target_ctrl_o)
  is
    variable v_bus : Ctrl_Bus_Fr_Target_t;
  begin
    v_bus := CTRL_BUS_FR_TARGET_ZERO;

    for i in 0 to N_TARGETS-1 loop
      v_bus := v_bus or target_ctrl_o(i);
    end loop;

    head_tail_resp <= v_bus;
  end process reduce_outputs;

end architecture behaviour;
