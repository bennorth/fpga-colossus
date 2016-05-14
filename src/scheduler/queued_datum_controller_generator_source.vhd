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

------------------------------------------------------------------------

-- An iteration worker is driven by a bundle of signals:  A 'reset' req/done
-- pair loads the first value (and it is assumed that iteration is non-empty).
-- A 'next' req/done pair loads subsequent values; furthermore, on the same
-- cycle that 'next_done' is found to be asserted, 'next_ended' is checked and,
-- if '1', the whole iteration has been exhausted.
--
-- Slot-state management and worker triggering is similar to the simple
-- pipeline case.
--
-- For our use-case, this component is connected to a Step_Count_Vector_Unit
-- instance.  What counts as the 'next' vector of step-counts is determined by
-- the stepping configuration.  For a Chi(3)/Chi(4) long run, the Chi(3) wheel
-- is configured to step once per run of the tape ('fast'), and the Chi(4) wheel
-- to step each time the Chi(3) wheel has stepped all the way back to its
-- starting point ('slow').  The 'next_ended' signal is supplied by what on the
-- real Colossus is the 'repeat lamp', which in this case lights when the Chi(4)
-- wheel returns to its starting point.

------------------------------------------------------------------------

entity Queued_Datum_Controller_Generator_Source is
  port (
    clk          : in  std_logic;
    --
    left_rdy_i   : in  std_logic;
    left_bsy_o   : out std_logic;
    right_rdy_o  : out std_logic;
    right_bsy_i  : in  std_logic;
    --
    reset_req_o  : out std_logic;
    reset_done_i : in  std_logic;
    next_req_o   : out std_logic;
    next_done_i  : in  std_logic;
    next_ended_i : in  std_logic);
end entity Queued_Datum_Controller_Generator_Source;


architecture behaviour of Queued_Datum_Controller_Generator_Source is

  signal wbsy : std_logic := '0';

begin
  control : process (clk) is
    type FSM_State_t is (Awaiting_Input_Ready,
                         Awaiting_Input_Acquisition_Acknowledge,
                         Awaiting_Output_Space_Head,
                         Awaiting_Reset_Done,
                         Awaiting_Output_Handover,
                         Awaiting_Output_Space_Tail,
                         Awaiting_Next_Done);
    variable state : FSM_State_t := Awaiting_Input_Ready;
  begin
    if rising_edge(clk) then
      case state is
        when Awaiting_Input_Ready =>
          right_rdy_o <= '0';
          reset_req_o <= '0';
          next_req_o <= '0';
          if left_rdy_i = '1' then
            left_bsy_o <= '1';
            state := Awaiting_Input_Acquisition_Acknowledge;
          else
            left_bsy_o <= '0';
          end if;
        when Awaiting_Input_Acquisition_Acknowledge =>
          if left_rdy_i = '0' then
            state := Awaiting_Output_Space_Head;
          end if;
        when Awaiting_Output_Space_Head =>
          if right_bsy_i = '0' then
            reset_req_o <= '1';
            wbsy <= '1';
            state := Awaiting_Reset_Done;
          end if;
        when Awaiting_Reset_Done =>
          reset_req_o <= '0';
          if reset_done_i = '1' then
            right_rdy_o <= '1';
            wbsy <= '0';
            state := Awaiting_Output_Handover;
          end if;
        when Awaiting_Output_Handover =>
          if right_bsy_i = '1' then
            right_rdy_o <= '0';
            state := Awaiting_Output_Space_Tail;
          end if;
        when Awaiting_Output_Space_Tail =>
          if right_bsy_i = '0' then
            next_req_o <= '1';
            wbsy <= '1';
            state := Awaiting_Next_Done;
          end if;
        when Awaiting_Next_Done =>
          next_req_o <= '0';
          if next_done_i = '1' then
            wbsy <= '0';
            if next_ended_i = '1' then
              state := Awaiting_Input_Ready;
            else
              right_rdy_o <= '1';
              state := Awaiting_Output_Handover;
            end if;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
