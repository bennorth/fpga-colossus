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

entity Step_Count_Vector_Unit is

  generic (
    BASE_ADDR : integer);

  port (
    clk             : in  std_logic;
    --
    reset_req_i     : in  std_logic;
    reset_done_o    : out std_logic;
    next_req_i      : in  std_logic;
    next_done_o     : out std_logic;
    next_ended_o    : out std_logic;
    --
    emit_tgt_i      : in  Cam_Wheel_Step_Count_t;
    emit_req_i      : in  std_logic;
    step_set_cmds_o : out Cam_Wheel_Step_Count_t;
    --
    cmd_ctrl_i      : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o      : out Ctrl_Bus_Fr_Target_t);

end entity Step_Count_Vector_Unit;

architecture behaviour of Step_Count_Vector_Unit is

  signal manual_reset_req   : std_logic        := '0';
  signal manual_next_req    : std_logic        := '0';
  signal manual_emit_tgt    : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal manual_emit_req    : std_logic        := '0';
  signal manual_element_sel : Cam_Wheel_Addr_t := CAM_WHEEL_ADDR_ZERO;

  signal combined_reset_req   : std_logic        := '0';
  signal combined_next_req    : std_logic        := '0';
  signal combined_emit_tgt    : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal combined_emit_req    : std_logic        := '0';

  signal reset_done    : std_logic              := '0';
  signal next_done     : std_logic              := '0';
  signal next_ended    : std_logic              := '0';
  signal step_set_cmds : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
  signal element_data  : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;

  signal raw_cfg : std_logic_vector((N_WHEELS * 8 - 1) downto 0);
  signal cfg : Cam_Wheel_Step_Cfg_Vec_t(0 to N_WHEELS-1);

  -- (0): config register (occupies 12 address starting at BASE_ADDR)
  -- (1): command (BASE_ADDR + 12)
  signal subcmd_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to 1);

begin

  step_count_vector : entity work.Step_Count_Vector
    port map (
      clk             => clk,
      reset_req_i     => combined_reset_req,
      reset_done_o    => reset_done,
      next_req_i      => combined_next_req,
      next_done_o     => next_done,
      next_ended_o    => next_ended,
      cfg             => cfg,
      emit_tgt_i      => combined_emit_tgt,
      emit_req_i      => combined_emit_req,
      step_set_cmds_o => step_set_cmds,
      element_sel_i   => manual_element_sel,
      element_data_o  => element_data);

  combined_reset_req <= manual_reset_req or reset_req_i;
  combined_next_req <= manual_next_req or next_req_i;
  combined_emit_req <= manual_emit_req or emit_req_i;
  combined_emit_tgt <= manual_emit_tgt or emit_tgt_i;

  reset_done_o <= reset_done;
  next_done_o <= next_done;
  next_ended_o <= next_ended;
  step_set_cmds_o <= step_set_cmds;

  cmd_ctrl_o <= subcmd_ctrl_o(0) or subcmd_ctrl_o(1);

  cfg_reg : entity work.Generic_Config_Register
    generic map (BASE_ADDR => BASE_ADDR, N_OCTETS => N_WHEELS)
    port map (clk => clk,
              ctrl_i => cmd_ctrl_i, ctrl_o => subcmd_ctrl_o(0),
              cfg_o => raw_cfg);

  unpack_cfg : process (raw_cfg)
  is
    variable bit_idx : integer;
  begin
    for i in 0 to N_WHEELS-1 loop
      bit_idx := 8 * i;
      cfg(i).ign_rpt <= raw_cfg(bit_idx);
      cfg(i).trigger <= raw_cfg(bit_idx + 1);
      cfg(i).slow <= raw_cfg(bit_idx + 2);
      cfg(i).fast <= raw_cfg(bit_idx + 3);
    end loop;
  end process unpack_cfg;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle,
                         Await_Element_Data,
                         Read_Element_Data,
                         Await_Reset_Done,
                         Await_Next_Done,
                         Delay_Then_Snoop,
                         Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
    variable i_wheel_idx : integer;
    variable snoop_delay : unsigned(3 downto 0);
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = BASE_ADDR + N_WHEELS then
              --
              -- 0x0n --- read value of element[n]
              -- 0x10 --- read 'next ended'
              -- 0x20 --- pulse reset-request
              -- 0x21 --- pulse next-request
              -- 0x3n --- emit stream; snoop after delay of n
              --
              subcmd_ctrl_o(1).busy <= '1';
              case cmd_ctrl_i.data(7 downto 4) is
                when x"0" =>
                  manual_element_sel <= unsigned(cmd_ctrl_i.data(3 downto 0));
                  state := Await_Element_Data;
                when x"1" =>
                  case cmd_ctrl_i.data(3 downto 0) is
                    when x"0" =>
                      cmd_success_code := "0000000" & next_ended;
                      state := Cmd_Done;
                    when others =>
                      state := Bad_Sub_Cmd;
                  end case;
                when x"2" =>
                  case cmd_ctrl_i.data(3 downto 0) is
                    when x"0" =>
                      manual_reset_req <= '1';
                      state := Await_Reset_Done;
                    when x"1" =>
                      manual_next_req <= '1';
                      state := Await_Next_Done;
                    when others =>
                      state := Bad_Sub_Cmd;
                  end case;
                when x"3" =>
                  manual_emit_tgt <= BODY_ID_BROADCAST;
                  manual_emit_req <= '1';
                  snoop_delay := unsigned(cmd_ctrl_i.data(3 downto 0));
                  state := Delay_Then_Snoop;
                when others =>
                  state := Bad_Sub_Cmd;
              end case;
            end if;
          else
            subcmd_ctrl_o(1) <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Await_Element_Data =>
          state := Read_Element_Data;
        when Read_Element_Data =>
          manual_element_sel <= CAM_WHEEL_ADDR_ZERO;
          cmd_success_code := "00" & std_logic_vector(element_data);
          state := Cmd_Done;
        when Await_Reset_Done =>
          manual_reset_req <= '0';
          if reset_done = '1' then
            cmd_success_code := x"18";
            state := Cmd_Done;
          end if;
        when Await_Next_Done =>
          manual_next_req <= '0';
          if next_done = '1' then
            cmd_success_code := x"19";
            state := Cmd_Done;
          end if;
        when Delay_Then_Snoop =>
          manual_emit_tgt <= CAM_WHEEL_STEP_COUNT_ZERO;
          manual_emit_req <= '0';
          if snoop_delay = "0000" then
            cmd_success_code := "00" & std_logic_vector(step_set_cmds);
            state := Cmd_Done;
          else
            snoop_delay := snoop_delay - 1;
          end if;
        when Cmd_Done =>
          ctrl_cmd_success(subcmd_ctrl_o(1), cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(subcmd_ctrl_o(1), x"2f");
          state := Idle;
      end case;
    end if;
  end process command_target;

end architecture behaviour;
