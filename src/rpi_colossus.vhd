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

------------------------------------------------------------------------------

entity RPi_Colossus is

  port (
    clk            : in  std_logic;
    --
    data_addr_muxd : in  RPi_Data_Addr_Muxd_t;
    data_addr_sel  : in  std_logic;
    req            : in  std_logic;
    busy           : out std_logic;
    resp_err       : out std_logic;
    resp           : out RPi_Response_t);

end entity RPi_Colossus;

architecture behaviour of RPi_Colossus is

  -- connections from RPi_Interface to Colossus
  signal ctrl_to_cls : Ctrl_Bus_To_Target_t;
  -- connections from Colossus to RPi_Interface
  signal ctrl_fr_cls : Ctrl_Bus_Fr_Target_t;

begin

  rpi_interface : entity work.RPi_Interface
    port map (
      clk            => clk,
      --
      data_addr_muxd => data_addr_muxd,
      data_addr_sel  => data_addr_sel,
      req            => req,
      busy_out       => busy,
      resp_err_out   => resp_err,
      resp_out       => resp,
      --
      ctrl_o         => ctrl_to_cls,
      ctrl_i         => ctrl_fr_cls);

  colossus : entity work.Colossus
    port map (
      clk    => clk,
      --
      ctrl_i => ctrl_to_cls,
      ctrl_o => ctrl_fr_cls);

end architecture behaviour;
