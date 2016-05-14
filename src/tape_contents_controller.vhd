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

entity Tape_Contents_Controller is

  generic (
    BASE_ADDR : integer);

  port (
    clk        : in  std_logic;
    --
    ctrl_i     : in  Ctrl_Bus_To_Target_t;
    ctrl_o     : out Ctrl_Bus_Fr_Target_t;
    --
    ram_ctrl_o : out Ctrl_Bus_To_RAM_t;
    ram_data_i : in  Tape_Loop_RAM_Data_t);

end entity Tape_Contents_Controller;

architecture behaviour of Tape_Contents_Controller is

  constant N_CMDS       : integer := 4;
  signal cmd_ram_ctrl_o : Ctrl_Bus_To_RAM_Vec_t(0 to N_CMDS-1);
  signal cmd_ctrl_o     : Ctrl_Bus_Fr_Target_Vec_t(0 to N_CMDS-1);
  signal rst_write_n    : std_logic;

begin

  clear_tape : entity work.Tape_Contents_Controller_Clear_Tape
    generic map (
      MAPPED_ADDR => ctrl_addr_f_int(BASE_ADDR + CLEAR_TAPE_IDX))
    port map (
      clk        => clk,
      --
      ctrl_i     => ctrl_i,
      ctrl_o     => cmd_ctrl_o(CLEAR_TAPE_IDX),
      ram_ctrl_o => cmd_ram_ctrl_o(CLEAR_TAPE_IDX));

  read_tape : entity work.Tape_Contents_Controller_Read_Tape
    generic map (
      MAPPED_ADDR => ctrl_addr_f_int(BASE_ADDR + READ_TAPE_IDX))
    port map (
      clk           => clk,
      --
      ctrl_i        => ctrl_i,
      ctrl_o        => cmd_ctrl_o(READ_TAPE_IDX),
      ram_ctrl_o    => cmd_ram_ctrl_o(READ_TAPE_IDX),
      ram_data_i => ram_data_i);

  reset_write_ptr : entity work.Tape_Contents_Controller_Reset_Write_Ptr
    generic map (
      MAPPED_ADDR => ctrl_addr_f_int(BASE_ADDR + WRITE_TAPE_0_IDX))
    port map (
      clk         => clk,
      ctrl_i      => ctrl_i,
      ctrl_o      => cmd_ctrl_o(WRITE_TAPE_0_IDX),
      ram_ctrl_o  => cmd_ram_ctrl_o(WRITE_TAPE_0_IDX),
      rst_write_n => rst_write_n);

  write_tape_n : entity work.Tape_Contents_Controller_Write_Tape_N
    generic map (
      MAPPED_ADDR => ctrl_addr_f_int(BASE_ADDR + WRITE_TAPE_N_IDX))
    port map (
      clk         => clk,
      ctrl_i      => ctrl_i,
      ctrl_o      => cmd_ctrl_o(WRITE_TAPE_N_IDX),
      ram_ctrl_o  => cmd_ram_ctrl_o(WRITE_TAPE_N_IDX),
      rst_write_n => rst_write_n);

  output_reduction : process (cmd_ram_ctrl_o,
                              cmd_ctrl_o)
  is
    variable accum_ram_ctrl_o : Ctrl_Bus_To_RAM_t;
    variable accum_ctrl_o     : Ctrl_Bus_Fr_Target_t;
  begin
    accum_ram_ctrl_o := CTRL_BUS_TO_RAM_ZERO;
    accum_ctrl_o     := CTRL_BUS_FR_TARGET_ZERO;

    for i in 0 to N_CMDS-1 loop
      accum_ram_ctrl_o := accum_ram_ctrl_o or cmd_ram_ctrl_o(i);
      accum_ctrl_o     := accum_ctrl_o or cmd_ctrl_o(i);
    end loop;  -- i

    ram_ctrl_o <= accum_ram_ctrl_o;
    ctrl_o     <= accum_ctrl_o;
  end process output_reduction;

end architecture behaviour;
