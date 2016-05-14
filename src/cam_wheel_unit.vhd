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

-- Responds to two adjacent addresses:
--
-- BASE_ADDR --- pattern register: writing to this shifts the data into the
-- least-significant end of the pattern, moving the rest up and losing the top
-- bits.
--
-- (BASE_ADDR + 1) --- control; set-stepping and move-{rst/en}; and also read the
-- step-count output.

entity Cam_Wheel_Unit is

  generic (
    N_CAMS    : natural;
    BASE_ADDR : integer);

  port (
    clk                  : in  std_logic;
    --
    ctrl_i               : in  Cam_Wheel_Ctrl_t;
    step_count_o         : out Cam_Wheel_Step_Count_t;
    step_count_set_o     : out std_logic;
    w_o                  : out std_logic;
    --
    cmd_ctrl_i           : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o           : out Ctrl_Bus_Fr_Target_t);

end entity Cam_Wheel_Unit;

architecture behaviour of Cam_Wheel_Unit is

  signal pattern            : std_logic_vector(N_CAMS-1 downto 0) := (others => '0');
  signal w                  : std_logic;
  signal manual_ctrl        : Cam_Wheel_Ctrl_t;
  signal combined_ctrl      : Cam_Wheel_Ctrl_t;
  signal step_count         : Cam_Wheel_Step_Count_t;
  signal step_count_set     : std_logic;

  signal subcmd_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to 1);

begin

  cam_wheel : entity work.Cam_Wheel
    generic map (
      N_CAMS => N_CAMS)
    port map (
      clk                  => clk,
      pattern_i            => pattern,
      ctrl_i               => combined_ctrl,
      step_count_o         => step_count,
      step_count_set_o     => step_count_set,
      w                    => w);

  cam_wheel_pattern_register : entity work.Cam_Wheel_Pattern_Register
    generic map (
      MAPPED_ADDR => BASE_ADDR,
      N_CAMS      => N_CAMS)
    port map (
      clk       => clk,
      ctrl_i    => cmd_ctrl_i,
      ctrl_o    => subcmd_ctrl_o(0),
      pattern_o => pattern);

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Await_Set_Stepping_Done, Cmd_Done);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          manual_ctrl <= CAM_WHEEL_CTRL_ZERO;
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = (BASE_ADDR + 1) then
              subcmd_ctrl_o(1).busy <= '1';

              -- <0x40   00bbbbbb Set stepping to 'bbbbbb'
              -- 0x40 == 01xxxxx0 Reset movement
              -- 0x41 == 01xxxxx1 Enable movement (one-shot)
              -- 0x80 == 10xxxxxx Read step-count
              -- 0xc0 == 11xxxxxx Read w

              case cmd_ctrl_i.data(7 downto 6) is
                when "00" =>
                  manual_ctrl.step_count <= unsigned(cmd_ctrl_i.data(5 downto 0));
                  manual_ctrl.step_count_set <= '1';
                  state := Await_Set_Stepping_Done;
                when "01" =>
                  if cmd_ctrl_i.data(0) = '0' then
                    manual_ctrl.move_rst <= '1';
                    cmd_success_code := x"32";
                    state := Cmd_Done;
                  else
                    manual_ctrl.move_en <= '1';
                    cmd_success_code := x"33";
                    state := Cmd_Done;
                  end if;
                when "10" =>
                  cmd_success_code := "00" & std_logic_vector(step_count);
                  state := Cmd_Done;
                when "11" =>
                  cmd_success_code := "0000000" & w;
                  state := Cmd_Done;
                when others =>
                  null;
              end case;
            end if;
          else
            subcmd_ctrl_o(1) <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Cmd_Done =>
          manual_ctrl <= CAM_WHEEL_CTRL_ZERO;
          ctrl_cmd_success(subcmd_ctrl_o(1), cmd_success_code);
          state := Idle;
        when Await_Set_Stepping_Done =>
          manual_ctrl.step_count_set <= '0';
          if step_count_set = '1' then
            cmd_success_code := x"30";
            state := Cmd_Done;
          end if;
      end case;
    end if;
  end process command_target;

  combined_ctrl <= ctrl_i or manual_ctrl;
  cmd_ctrl_o <= subcmd_ctrl_o(0) or subcmd_ctrl_o(1);

  step_count_o <= step_count;

  w_o <= w;
  step_count_set_o <= step_count_set;

end architecture behaviour;
