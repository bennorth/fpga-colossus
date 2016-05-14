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
library std;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;


package utils is

  subtype Validated_Nibble_t is std_logic_vector(4 downto 0);
  function validated_nibble(constant chr : character)
    return Validated_Nibble_t;

  function ctrl_addr_f_int (constant addr : integer) return Ctrl_Addr_t;
  function ram_addr_f_int (constant addr : integer) return Tape_Loop_RAM_Addr_t;
  function cam_wheel_addr_f_int (constant addr : integer) return Cam_Wheel_Addr_t;
  function counter_addr_f_int (constant addr : integer) return Counter_Addr_t;
  function cam_wheel_step_count_f_int (constant x : integer)
    return Cam_Wheel_Step_Count_t;

  function "or" (constant x : Ctrl_Bus_Fr_Target_t;
                 constant y : Ctrl_Bus_Fr_Target_t)
    return Ctrl_Bus_Fr_Target_t;

  function "or" (constant x : Ctrl_Bus_To_RAM_t;
                 constant y : Ctrl_Bus_To_RAM_t)
    return Ctrl_Bus_To_RAM_t;

  function "or" (constant x : Counter_Ctrl_t;
                 constant y : Counter_Ctrl_t)
    return Counter_Ctrl_t;

  function "or" (constant x : Q_Selector_Ctrl_t;
                 constant y : Q_Selector_Ctrl_t)
    return Q_Selector_Ctrl_t;

  function "or" (constant x : Cam_Wheel_Ctrl_t;
                 constant y : Cam_Wheel_Ctrl_t)
    return Cam_Wheel_Ctrl_t;

  function "or" (constant x : Printer_Write_Ctrl_t;
                 constant y : Printer_Write_Ctrl_t)
    return Printer_Write_Ctrl_t;

  function "or" (constant x : Ctrl_Bus_To_Bedstead_t;
                 constant y : Ctrl_Bus_To_Bedstead_t)
    return Ctrl_Bus_To_Bedstead_t;

  procedure ctrl_cmd_success (
    signal ctrl_o : out Ctrl_Bus_Fr_Target_t;
    constant resp : Ctrl_Response_t);

  procedure ctrl_cmd_failure (
    signal ctrl_o : out Ctrl_Bus_Fr_Target_t;
    constant resp : Ctrl_Response_t);

end package utils;

package body utils is

  function validated_nibble(constant chr : character)
    return Validated_Nibble_t
  is
  begin
    case chr is
      when '0'     => return "00000";
      when '1'     => return "00001";
      when '2'     => return "00010";
      when '3'     => return "00011";
      when '4'     => return "00100";
      when '5'     => return "00101";
      when '6'     => return "00110";
      when '7'     => return "00111";
      when '8'     => return "01000";
      when '9'     => return "01001";
      when 'a'|'A' => return "01010";
      when 'b'|'B' => return "01011";
      when 'c'|'C' => return "01100";
      when 'd'|'D' => return "01101";
      when 'e'|'E' => return "01110";
      when 'f'|'F' => return "01111";
      --
      when others  => return "11111";
    end case;
  end function validated_nibble;

  function ctrl_addr_f_int (constant addr : integer) return Ctrl_Addr_t
  is
  begin
    return to_unsigned(addr, Ctrl_Addr_t'length);
  end function ctrl_addr_f_int;

  function ram_addr_f_int (constant addr : integer) return Tape_Loop_RAM_Addr_t
  is
  begin
    return to_unsigned(addr, Tape_Loop_RAM_Addr_t'length);
  end function ram_addr_f_int;

  function cam_wheel_addr_f_int (constant addr : integer) return Cam_Wheel_Addr_t
  is
  begin
    return to_unsigned(addr, Cam_Wheel_Addr_t'length);
  end function cam_wheel_addr_f_int;

  function counter_addr_f_int (constant addr : integer) return Counter_Addr_t
  is
  begin
    return to_unsigned(addr, Counter_Addr_t'length);
  end function counter_addr_f_int;

  function cam_wheel_step_count_f_int (constant x : integer)
    return Cam_Wheel_Step_Count_t
  is
  begin
    return to_unsigned(x, Cam_Wheel_Step_Count_t'length);
  end function cam_wheel_step_count_f_int;

  function "or" (constant x : Ctrl_Bus_Fr_Target_t;
                 constant y : Ctrl_Bus_Fr_Target_t)
    return Ctrl_Bus_Fr_Target_t
  is
  begin
    return (busy => x.busy or y.busy,
            err => x.err or y.err,
            resp => x.resp or y.resp);
  end function "or";

  function "or" (constant x : Ctrl_Bus_To_RAM_t;
                 constant y : Ctrl_Bus_To_RAM_t)
    return Ctrl_Bus_To_RAM_t
  is
  begin
    return (req => x.req or y.req,
            addr => x.addr or y.addr,
            data => x.data or y.data,
            wr_en => x.wr_en or y.wr_en);
  end function "or";

  function "or" (constant x : Counter_Ctrl_t;
                 constant y : Counter_Ctrl_t)
    return Counter_Ctrl_t
  is
  begin
    return (count_rst => x.count_rst or y.count_rst,
            count_en => x.count_en or y.count_en,
            output_en => x.output_en or y.output_en);
  end function "or";

  function "or" (constant x : Q_Selector_Ctrl_t;
                 constant y : Q_Selector_Ctrl_t)
    return Q_Selector_Ctrl_t
  is
  begin
    return (rst => x.rst or y.rst, en => x.en or y.en);
  end function "or";

  function "or" (constant x : Cam_Wheel_Ctrl_t;
                 constant y : Cam_Wheel_Ctrl_t)
    return Cam_Wheel_Ctrl_t
  is
  begin
    return (step_count => x.step_count or y.step_count,
            step_count_set => x.step_count_set or y.step_count_set,
            move_rst => x.move_rst or y.move_rst,
            move_en => x.move_en or y.move_en);
  end function "or";

  function "or" (constant x : Printer_Write_Ctrl_t;
                 constant y : Printer_Write_Ctrl_t)
    return Printer_Write_Ctrl_t
  is
  begin
    return (erase_en => x.erase_en or y.erase_en,
            write_en => x.write_en or y.write_en,
            write_data => x.write_data or y.write_data);
  end function "or";

  function "or" (constant x : Ctrl_Bus_To_Bedstead_t;
                 constant y : Ctrl_Bus_To_Bedstead_t)
    return Ctrl_Bus_To_Bedstead_t
  is
  begin
    return (mv_rst => x.mv_rst or y.mv_rst,
            mv_en => x.mv_en or y.mv_en);
  end function "or";

  procedure ctrl_cmd_success (
    signal ctrl_o : out Ctrl_Bus_Fr_Target_t;
    constant resp : Ctrl_Response_t)
  is
  begin
    ctrl_o.busy <= '0';
    ctrl_o.err  <= '0';
    ctrl_o.resp <= resp;
  end procedure ctrl_cmd_success;

  procedure ctrl_cmd_failure (
    signal ctrl_o : out Ctrl_Bus_Fr_Target_t;
    constant resp : Ctrl_Response_t)
  is
  begin
    ctrl_o.busy <= '0';
    ctrl_o.err  <= '1';
    ctrl_o.resp <= resp;
  end procedure ctrl_cmd_failure;

end package body utils;
