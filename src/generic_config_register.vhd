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

entity Generic_Config_Register is

  generic (
    BASE_ADDR : integer;
    N_OCTETS  : integer);

  port (
    clk    : in  std_logic;
    --
    ctrl_i : in  Ctrl_Bus_To_Target_t;
    ctrl_o : out Ctrl_Bus_Fr_Target_t;
    --
    cfg_o  : out std_logic_vector(((N_OCTETS * 8) - 1) downto 0));

end entity Generic_Config_Register;

architecture behaviour of Generic_Config_Register is

  constant N_BITS : integer := N_OCTETS * 8;
  signal cfg : std_logic_vector(N_BITS-1 downto 0) := (others => '0');

begin

  control : process (clk)
  is
    type FSM_State_t is (Idle, Cfg_Set);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            for addr_offset in 0 to N_OCTETS-1 loop
              if ctrl_i.addr = BASE_ADDR + addr_offset then
                ctrl_o.busy <= '1';
                cfg((addr_offset * 8 + 7) downto (addr_offset * 8)) <= ctrl_i.data;
                state := Cfg_Set;
              end if;
            end loop;  -- addr_offset
          end if;
        when Cfg_Set =>
          ctrl_cmd_success(ctrl_o, x"12");
          state := Idle;
      end case;
    end if;
  end process control;

  cfg_o <= cfg;

end architecture behaviour;
