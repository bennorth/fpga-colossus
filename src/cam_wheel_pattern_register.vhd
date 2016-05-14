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

-- To configure a pattern in a particular cam-wheel, the user writes a data
-- octet to that wheel's command address.  Those eight bits are shifted in from
-- the least-significant end of the pattern.  To configure an entire wheel,
-- then, multiple writes to this command are necessary, starting with the most
-- significant bits and ending with the least.
--
-- The least-significant bit of the pattern is the first 'w' output from the
-- un-stepped wheel.

------------------------------------------------------------------------------

entity Cam_Wheel_Pattern_Register is

  generic (
    MAPPED_ADDR : integer;
    N_CAMS      : positive);

  port (
    clk       : in  std_logic;
    --
    ctrl_i    : in  Ctrl_Bus_To_Target_t;
    ctrl_o    : out Ctrl_Bus_Fr_Target_t;
    --
    pattern_o : out std_logic_vector(N_CAMS-1 downto 0));

end entity Cam_Wheel_Pattern_Register;

architecture behaviour of Cam_Wheel_Pattern_Register is
begin

  control : process (clk)
  is
    type FSM_State_t is (Idle, Cfg_Set);
    variable state : FSM_State_t := Idle;
    variable pattern : std_logic_vector(N_CAMS-1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            if ctrl_i.addr = MAPPED_ADDR then
              ctrl_o.busy <= '1';
              pattern := (pattern(N_CAMS-9 downto 0)
                          & std_logic_vector(ctrl_i.data));
              state := Cfg_Set;
            end if;
          else
            ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Cfg_Set =>
          ctrl_cmd_success(ctrl_o, x"58");
          state := Idle;
      end case;

      pattern_o <= pattern;
    end if;
  end process control;

end architecture behaviour;
