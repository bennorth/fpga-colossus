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

entity Queued_Datum_Controller_Distributor is
  generic (
    N_CONSUMERS     : integer;
    CONSUMER_IDX_WD : integer);

  port (
    clk         : in  std_logic;
    --
    left_rdy_i  : in  std_logic;
    left_bsy_o  : out std_logic;
    right_rdy_o : out std_logic_vector(0 to N_CONSUMERS-1);
    right_bsy_i : in  std_logic_vector(0 to N_CONSUMERS-1);
    --
    work_idx_o  : out unsigned(CONSUMER_IDX_WD-1 downto 0);
    work_req_o  : out std_logic;
    work_done_i : in  std_logic);

end entity Queued_Datum_Controller_Distributor;


architecture behaviour of Queued_Datum_Controller_Distributor is

  signal wbsy : std_logic := '0';

begin

  control : process (clk) is
    type FSM_State_t is (Awaiting_Input_Ready,
                         Awaiting_Input_Acquisition_Acknowledge,
                         Awaiting_Output_Space,
                         Awaiting_Work_Completion,
                         Awaiting_Output_Handover);
    variable state : FSM_State_t := Awaiting_Input_Ready;

    variable probe_idx : integer range 0 to N_CONSUMERS-1;
  begin
    if rising_edge(clk) then
      case state is
        when Awaiting_Input_Ready =>
          right_rdy_o <= (others => '0');
          work_idx_o <= (others => '0');
          work_req_o <= '0';
          if left_rdy_i = '1' then
            left_bsy_o <= '1';
            state := Awaiting_Input_Acquisition_Acknowledge;
          else
            left_bsy_o <= '0';
          end if;
        when Awaiting_Input_Acquisition_Acknowledge =>
          if left_rdy_i = '0' then
            probe_idx := 0;
            state := Awaiting_Output_Space;
          end if;
        when Awaiting_Output_Space =>
          if probe_idx = N_CONSUMERS-1 then
            probe_idx := 0;
          else
            probe_idx := probe_idx + 1;
          end if;
          if right_bsy_i(probe_idx) = '0' then
            work_idx_o <= to_unsigned(probe_idx, CONSUMER_IDX_WD);
            work_req_o <= '1';
            wbsy <= '1';
            state := Awaiting_Work_Completion;
          end if;
        when Awaiting_Work_Completion =>
          work_idx_o <= (others => '0');
          work_req_o <= '0';
          if work_done_i = '1' then
            right_rdy_o(probe_idx) <= '1';
            left_bsy_o <= '0';
            wbsy <= '0';
            state := Awaiting_Output_Handover;
          end if;
        when Awaiting_Output_Handover =>
          if right_bsy_i(probe_idx) = '1' then
            state := Awaiting_Input_Ready;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
