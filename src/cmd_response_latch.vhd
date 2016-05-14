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

------------------------------------------------------------------------------

entity Response_Latch is

  port (
    clk            : in  std_logic;
    tgt_response_i : in  Ctrl_Bus_Fr_Target_t;
    tgt_response_o : out Ctrl_Bus_Fr_Target_t := CTRL_BUS_FR_TARGET_ZERO);

end entity Response_Latch;

architecture behaviour of Response_Latch is
begin

  latch : process (clk)
  is
    type FSM_State_t is (Idle, Awaiting_Response);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if tgt_response_i.busy = '1' then
            tgt_response_o.busy <= '1';
            state := Awaiting_Response;
          else
            tgt_response_o.busy <= '0';
          end if;
        --
        when Awaiting_Response =>
          if tgt_response_i.busy = '0' then
            tgt_response_o.busy <= '0';
            tgt_response_o.err <= tgt_response_i.err;
            tgt_response_o.resp <= tgt_response_i.resp;
            state := Idle;
          end if;
      end case;
    end if;
  end process;

end architecture behaviour;
