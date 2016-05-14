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
use work.types.all;

------------------------------------------------------------------------------

-- The 'tape loop' is implemented as block RAM of 16,384 elements, which is a
-- power-of-two size consistent with a large Colossus, which could work with a
-- 20,000-letter tape.  The command interface for 'punching' the tape consists
-- of 'reset pointer' and 'write and advance', allowing a full tape to be
-- written.  The RAM is 8 bits wide and each teleprinter letter occupies only
-- five bits, so we use a '1' in an unused bit to signify 'end of tape', similar
-- to Colossus's use of a 'stop hole' between the 4th and 5th impulse tracks of
-- the tape.  This does still leave two completely unused bits.  The 'tape' also
-- has 'read' commands for testability:  'reset pointer' and 'read and
-- advance'.
--
-- The command-target implementation is across a few files:
--
-- tape_contents_clear_tape.vhd
-- tape_contents_reset_write_ptr.vhd
-- tape_contents_write_tape_n.vhd
-- tape_contents_read_tape.vhd
-- tape_contents_controller.vhd
-- tape_operational_controller.vhd
--
-- This was the first piece of code I wrote, and really it could do with being
-- re-written.

------------------------------------------------------------------------------

entity Bedstead is

  generic (
    CONTROLLER_BASE_ADDR : integer);

  port (
    clk    : in  std_logic;
    ctrl_i : in  Ctrl_Bus_To_Target_t;
    ctrl_o : out Ctrl_Bus_Fr_Target_t;
    --
    -- Operational interface:
    opr_ctrl : in Ctrl_Bus_To_Bedstead_t := CTRL_BUS_TO_BEDSTEAD_ZERO;
    aug_z    : out Aug_TP_Letter_t
    );

end entity Bedstead;

architecture behaviour of Bedstead is

  signal ram_ctrl     : Ctrl_Bus_To_RAM_t;
  signal cmd_ram_ctrl : Ctrl_Bus_To_RAM_t;
  signal opr_ram_ctrl : Ctrl_Bus_To_RAM_t := CTRL_BUS_TO_RAM_ZERO;
  signal ram_wr_en    : std_logic_vector(0 downto 0);
  signal ram_data_out : Tape_Loop_RAM_Data_t;

begin

  tape_contents_controller : entity work.Tape_Contents_Controller
    generic map (
      BASE_ADDR => CONTROLLER_BASE_ADDR)
    port map (
      clk        => clk,
      ctrl_i     => ctrl_i,
      ctrl_o     => ctrl_o,
      ram_ctrl_o => cmd_ram_ctrl,
      ram_data_i => ram_data_out);

  operational_controller : entity work.Tape_Operational_Controller
    port map (
      clk           => clk,
      ctrl_i        => opr_ctrl,
      aug_z         => aug_z,
      ram_ctrl_o    => opr_ram_ctrl,
      data_from_ram => ram_data_out);

  tape_loop_ram : entity work.Tape_Loop_RAM
    port map (
      clka  => clk,
      wea   => ram_wr_en,
      addra => std_logic_vector(ram_ctrl.addr),
      dina  => ram_ctrl.data,
      douta => ram_data_out);

  arbitrate_ram_bus : process (cmd_ram_ctrl, opr_ram_ctrl)
  is
  begin
    -- give priority to the command target (contents controller)
    if cmd_ram_ctrl.req = '1' then
      ram_ctrl <= cmd_ram_ctrl;
    else
      ram_ctrl <= opr_ram_ctrl;
    end if;
  end process arbitrate_ram_bus;

  ram_wr_en(0) <= ram_ctrl.wr_en;

end architecture behaviour;
