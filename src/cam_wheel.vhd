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

------------------------------------------------------------------------------

-- Requests to set our step-count are handled by processing each bit in turn,
-- rotating the 'stepped_pattern' the appropriate amount if that bit is set.
-- When all bits have been processed, 'step_count_set_o' is asserted.
--
-- The per-body data-slot 'stepped patterns & counts' is implemented here, in
-- the 'stepped_pattern' and 'step_count' registers respectively.  The base
-- un-stepped pattern is provided to us in the configuration input 'pattern_i',
-- and stepping is relative to this pattern.  When the Cam_Wheel is instantiated
-- within a Cam_Wheel_Unit, this input comes from a configuration register.
--
-- The per-body data-slot 'active pattern' is implemented here, held in the
-- 'pattern' variable of the 'movement' process.  Only the [0] element of the
-- pattern is output, as 'w'.  The 'run tape once' worker mutates the 'pattern'
-- via the 'ctrl_i.move_en' input.

------------------------------------------------------------------------------

entity Cam_Wheel is

  generic (
    N_CAMS : natural);

  port (
    clk                  : in  std_logic;
    pattern_i            : in  std_logic_vector(N_CAMS-1 downto 0);
    ctrl_i               : in  Cam_Wheel_Ctrl_t;
    step_count_o         : out Cam_Wheel_Step_Count_t;
    step_count_eq_zero_o : out std_logic;
    step_count_set_o     : out std_logic;
    w                    : out std_logic);

end entity Cam_Wheel;

architecture behaviour of Cam_Wheel is

  signal step_count      : Cam_Wheel_Step_Count_t;
  signal stepped_pattern : std_logic_vector(N_CAMS-1 downto 0);

  constant ROTATE_5 : natural := 32 mod N_CAMS;
  constant ROTATE_4 : natural := 16 mod N_CAMS;
  constant ROTATE_3 : natural := 8 mod N_CAMS;
  constant ROTATE_2 : natural := 4 mod N_CAMS;
  constant ROTATE_1 : natural := 2 mod N_CAMS;
  constant ROTATE_0 : natural := 1 mod N_CAMS;

begin

  movement : process (clk)
  is
    variable pattern : std_logic_vector(N_CAMS-1 downto 0);
  begin
    if rising_edge(clk) then
      if ctrl_i.move_rst = '1' then
        pattern := stepped_pattern;
      elsif ctrl_i.move_en = '1' then
        pattern := pattern(0) & pattern(N_CAMS-1 downto 1);
      end if;

      w <= pattern(0);
    end if;
  end process movement;

  stepping : process (clk)
  is
    type FSM_State_t is (Idle,
                         Enacting_Bit_5, Enacting_Bit_4, Enacting_Bit_3,
                         Enacting_Bit_2, Enacting_Bit_1, Enacting_Bit_0,
                         Notify_Done);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          step_count_set_o <= '0';
          if ctrl_i.step_count_set = '1' then
            step_count <= ctrl_i.step_count;
            stepped_pattern <= pattern_i;
            state := Enacting_Bit_5;
          end if;
        when Enacting_Bit_5 =>
          if step_count(5) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_5-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_5));
          end if;
          state := Enacting_Bit_4;
        when Enacting_Bit_4 =>
          if step_count(4) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_4-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_4));
          end if;
          state := Enacting_Bit_3;
        when Enacting_Bit_3 =>
          if step_count(3) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_3-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_3));
          end if;
          state := Enacting_Bit_2;
        when Enacting_Bit_2 =>
          if step_count(2) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_2-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_2));
          end if;
          state := Enacting_Bit_1;
        when Enacting_Bit_1 =>
          if step_count(1) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_1-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_1));
          end if;
          state := Enacting_Bit_0;
        when Enacting_Bit_0 =>
          if step_count(0) = '1' then
            stepped_pattern <= (stepped_pattern(ROTATE_0-1 downto 0)
                                & stepped_pattern(N_CAMS-1 downto ROTATE_0));
          end if;
          state := Notify_Done;
        when Notify_Done =>
          step_count_set_o <= '1';
          state := Idle;
      end case;
    end if;
  end process stepping;

  update_outputs : process (step_count)
  is
  begin
    step_count_o <= step_count;

    if step_count = 0 then
      step_count_eq_zero_o <= '1';
    else
      step_count_eq_zero_o <= '0';
    end if;
  end process update_outputs;

end architecture behaviour;
