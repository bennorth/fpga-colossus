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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

package types is

  subtype RPi_Data_Addr_Muxd_t is std_logic_vector(7 downto 0);
  subtype RPi_Response_t is std_logic_vector(7 downto 0);

  subtype Ctrl_Addr_t is unsigned(7 downto 0);
  subtype Ctrl_Data_t is std_logic_vector(7 downto 0);
  subtype Ctrl_Response_t is std_logic_vector(7 downto 0);
  constant Ctrl_Response_ZERO : Ctrl_Response_t := (others => '0');

  -- Teleprinter letters
  subtype TP_Letter_t is std_logic_vector(1 to 5);
  --
  constant TP_LETTER_ZERO : TP_Letter_t := (others => '0');
  --
  type Aug_TP_Letter_t is record
    letter : TP_Letter_t;
    stop   : std_logic;
  end record Aug_TP_Letter_t;

  -- Motor wheels 'bus'
  subtype Motor_Wheels_t is std_logic_vector(1 downto 0);

  -- Tape Loop RAM
  subtype Tape_Loop_RAM_Addr_t is unsigned(13 downto 0);
  subtype Tape_Loop_RAM_Data_t is std_logic_vector(7 downto 0);
  --
  type Ctrl_Bus_To_RAM_t is record
    req  : std_logic;
    addr : Tape_Loop_RAM_Addr_t;
    data : Tape_Loop_RAM_Data_t;
    wr_en : std_logic;
  end record Ctrl_Bus_To_RAM_t;
  --
  type Ctrl_Bus_To_RAM_Vec_t
    is array (natural range <>) of Ctrl_Bus_To_RAM_t;
  --
  constant CTRL_BUS_TO_RAM_ZERO : Ctrl_Bus_To_RAM_t
    := (req => '0',
        addr => (others => '0'),
        data => (others => '0'),
        wr_en => '0');

  constant CLEAR_TAPE_IDX : integer := 0;
  constant Tape_Loop_RAM_NO_LETTER : Tape_Loop_RAM_Data_t := x"a5";
  constant Tape_Loop_Clear_OK : Ctrl_Response_t := x"33";

  constant READ_TAPE_IDX : integer := 1;

  constant WRITE_TAPE_0_IDX : integer := 2;
  constant Tape_Loop_Write_0_OK : Ctrl_Response_t := x"44";

  constant WRITE_TAPE_N_IDX : integer := 3;
  constant Tape_Loop_Write_N_OK : Ctrl_Response_t := x"55";

  -- Printer RAM
  subtype Printer_RAM_Addr_t is unsigned(11 downto 0);
  subtype Printer_RAM_Data_t is std_logic_vector(7 downto 0);
  --
  constant PRINTER_RAM_ADDR_ZERO : Printer_RAM_Addr_t
    := (others => '0');
  constant PRINTER_RAM_ADDR_MAX_VALUE : Printer_RAM_Addr_t
    := to_unsigned(2**Printer_RAM_Addr_t'length - 1, Printer_RAM_Addr_t'length);
  constant PRINTER_RAM_DATA_ZERO : Printer_RAM_Data_t
    := (others => '0');
  --
  type Printer_Write_Ctrl_t is record
    erase_en   : std_logic;
    write_en   : std_logic;
    write_data : Printer_RAM_Data_t;
  end record Printer_Write_Ctrl_t;
  --
  constant PRINTER_WRITE_CTRL_ZERO : Printer_Write_Ctrl_t
    := (erase_en   => '0',
        write_en   => '0',
        write_data => (others => '0'));
  --
  type Printer_Write_Ctrl_Vec_t
    is array (natural range <>) of Printer_Write_Ctrl_t;

  -----------------------------------------------------------------------------
  -- Operational interface to bedstead

  type Ctrl_Bus_To_Bedstead_t is record
    mv_rst : std_logic;
    mv_en  : std_logic;
  end record Ctrl_Bus_To_Bedstead_t;
  --
  type Ctrl_Bus_To_Bedstead_Vec_t
    is array (natural range <>) of Ctrl_Bus_To_Bedstead_t;
  --
  constant CTRL_BUS_TO_BEDSTEAD_ZERO : Ctrl_Bus_To_Bedstead_t
    := (mv_rst => '0',
        mv_en => '0');

  -----------------------------------------------------------------------------
  -- Configuration of Q Selector panel

  type Q_Selector_Cfg_t is record
    z_en, z_delta     : std_logic;
    chi_en, chi_delta : std_logic;
    psi_en, psi_delta : std_logic;
  end record;

  -----------------------------------------------------------------------------
  -- Control of Q Selector

  type Q_Selector_Ctrl_t is record
    -- Reset 'one back' storage to all-bits-zero:
    rst : std_logic;
    -- Enable processing (delta and calculation of Q):
    en  : std_logic;
  end record Q_Selector_Ctrl_t;
  --
  type Q_Selector_Ctrl_Vec_t
    is array (natural range <>) of Q_Selector_Ctrl_t;
  --
  constant Q_SELECTOR_CTRL_ZERO : Q_Selector_Ctrl_t
    := (others => '0');

  -----------------------------------------------------------------------------
  -- Cam-wheel control

  constant N_WHEELS : integer := 12;
  --
  subtype Cam_Wheel_Step_Count_t is unsigned(5 downto 0);
  constant CAM_WHEEL_STEP_COUNT_ZERO : Cam_Wheel_Step_Count_t := (others => '0');
  type Cam_Wheel_Step_Count_Vec_t
    is array (integer range <>) of Cam_Wheel_Step_Count_t;
  --
  -- Command preamble (0x2d when right-aligned into a u8):
  constant STEP_SET_CMD_PREAMBLE : Cam_Wheel_Step_Count_t := "101101";
  --
  -- Reserved body-id for 'broadcast':
  constant BODY_ID_BROADCAST : Cam_Wheel_Step_Count_t := "111111";
  --
  type Cam_Wheel_Ctrl_t is record
    move_rst       : std_logic;
    move_en        : std_logic;
    step_count     : Cam_Wheel_Step_Count_t;
    step_count_set : std_logic;
  end record Cam_Wheel_Ctrl_t;
  --
  constant CAM_WHEEL_CTRL_ZERO : Cam_Wheel_Ctrl_t
    := (step_count => CAM_WHEEL_STEP_COUNT_ZERO, others => '0');
  --
  type Cam_Wheel_Ctrl_Vec_t
    is array (integer range <>) of Cam_Wheel_Ctrl_t;

  -- Cam wheel sizes [p.11]
  type Integer_Vec_t is array (natural range <>) of integer;
  constant N_CAMS_CHI : Integer_Vec_t(1 to 5) := (41, 31, 29, 26, 23);
  constant N_CAMS_PSI : Integer_Vec_t(1 to 5) := (43, 47, 51, 53, 59);
  constant N_CAMS_MU : Integer_Vec_t(1 to 2) := (61, 37);
  --
  constant N_CAMS_ALL : Integer_Vec_t(0 to 11) := (41, 31, 29, 26, 23,
                                                   43, 47, 51, 53, 59,
                                                   61, 37);

  subtype Cam_Wheel_Addr_t is unsigned(3 downto 0);
  --
  constant CAM_WHEEL_ADDR_ZERO : Cam_Wheel_Addr_t := (others => '0');

  type Cam_Wheel_Step_Cfg_t is record
    fast    : std_logic;
    slow    : std_logic;
    trigger : std_logic;
    ign_rpt : std_logic;
  end record Cam_Wheel_Step_Cfg_t;
  --
  type Cam_Wheel_Step_Cfg_Vec_t
    is array (integer range <>) of Cam_Wheel_Step_Cfg_t;

  -----------------------------------------------------------------------------
  -- Counters

  constant N_COUNTERS : integer := 5;
  constant COUNTER_WIDTH : integer := 14;
  --
  subtype Counter_1b_Vec_t
    is std_logic_vector(0 to N_COUNTERS-1);
  type Counter_1b_Vec_Vec_t
    is array (natural range <>) of Counter_1b_Vec_t;
  --
  constant COUNTER_1B_VEC_ZERO : Counter_1b_Vec_t
    := (others => '0');

  subtype Counter_Addr_t is unsigned(2 downto 0);
  subtype Counter_Value_t is unsigned(COUNTER_WIDTH-1 downto 0);
  constant COUNTER_VALUE_ZERO : Counter_Value_t := (others => '0');
  type Counter_Value_Vec_t
    is array (natural range <>) of Counter_Value_t;

  -- Config fits into 16 bits: 14 for the count and 2 for the operation.
  --
  -- Encoded as 00 : GT, 01 : LT, 1x : True
  type Comparison_t is (Count_GT_Threshold, Count_LT_Threshold, Always_True);
  --
  type Set_Total_Cfg_t is record
    threshold : Counter_Value_t;
    operation : Comparison_t;
  end record Set_Total_Cfg_t;
  --
  type Set_Total_Cfg_Vec_t
    is array (integer range <>) of Set_Total_Cfg_t;

  -- Control of individual counters and also counter panel

  type Counter_Ctrl_t is record
    count_rst : std_logic;
    count_en  : std_logic;
    output_en : std_logic;
  end record Counter_Ctrl_t;
  --
  type Counter_Ctrl_Vec_t
    is array (natural range <>) of Counter_Ctrl_t;
  --
  constant COUNTER_CTRL_ZERO : Counter_Ctrl_t := (others => '0');

  -----------------------------------------------------------------------------
  -- Q Panel top units

  constant N_Q_PANEL_TOP_UNITS : integer := 10;
  --
  type Q_Panel_Top_Unit_Cfg_t is record
    match_en   : TP_Letter_t;
    match_tgt  : TP_Letter_t;
    negate     : std_logic;
    counter_en : Counter_1b_Vec_t;
  end record Q_Panel_Top_Unit_Cfg_t;
  --
  type Q_Panel_Top_Unit_Cfg_Vec_t
    is array (natural range <>) of Q_Panel_Top_Unit_Cfg_t;
  --
  constant Q_PANEL_TOP_UNIT_CFG_ZERO : Q_Panel_Top_Unit_Cfg_t
    := (match_en => TP_LETTER_ZERO,
        match_tgt => TP_LETTER_ZERO,
        negate => '0',
        counter_en => COUNTER_1B_VEC_ZERO);

  -----------------------------------------------------------------------------
  -- Q Panel bottom units

  constant N_Q_PANEL_BOTTOM_UNITS : integer := 5;
  --
  type Q_Panel_Bottom_Unit_Cfg_t is record
    coeff      : TP_Letter_t;
    tgt        : std_logic;
    counter_en : Counter_1b_Vec_t;
  end record Q_Panel_Bottom_Unit_Cfg_t;
  --
  type Q_Panel_Bottom_Unit_Cfg_Vec_t
    is array (natural range <>) of Q_Panel_Bottom_Unit_Cfg_t;
  --
  constant Q_PANEL_BOTTOM_UNIT_CFG_ZERO : Q_Panel_Bottom_Unit_Cfg_t
    := (coeff      => TP_LETTER_ZERO,
        tgt        => '0',
        counter_en => COUNTER_1B_VEC_ZERO);

  -----------------------------------------------------------------------------
  -- Q Panel top-level config

  type Q_Panel_Cfg_t is record
    top_negates : Counter_1b_Vec_t;
    global_negates : Counter_1b_Vec_t;
  end record Q_Panel_Cfg_t;

  -----------------------------------------------------------------------------
  -- Pipeline stage handshake

  type Pipeline_Connector_t is record
    rdy  : std_logic;
    bsy : std_logic;
  end record Pipeline_Connector_t;

  -----------------------------------------------------------------------------
  -- Worker handshake

  type Worker_Handshake_t is record
    req  : std_logic;
    done : std_logic;
  end record Worker_Handshake_t;

  -----------------------------------------------------------------------------
  -- Generator worker handshake

  type Generator_Worker_Handshake_t is record
    req  : std_logic;
    done : std_logic;
    ended : std_logic;
  end record Generator_Worker_Handshake_t;

  -----------------------------------------------------------------------------
  -- Indexed worker handshake

  type Indexed_Worker_Handshake_t is record
    idx : Cam_Wheel_Step_Count_t;
    req : std_logic;
    done : std_logic;
  end record Indexed_Worker_Handshake_t;

  -----------------------------------------------------------------------------

  -- Record types for the bundle of interface->target control lines and
  -- for the target->interface bundle.
  --
  type Ctrl_Bus_To_Target_t is record
    addr  : Ctrl_Addr_t;
    data  : Ctrl_Data_t;
    wr_en : std_logic;
  end record Ctrl_Bus_To_Target_t;
  --
  constant CTRL_BUS_TO_TARGET_ZERO : Ctrl_Bus_To_Target_t
    := (addr => x"00", data => x"00", wr_en => '0');
  --
  type Ctrl_Bus_Fr_Target_t is record
    busy : std_logic;
    err  : std_logic;
    resp : Ctrl_Response_t;
  end record Ctrl_Bus_Fr_Target_t;
  --
  type Ctrl_Bus_Fr_Target_Vec_t
    is array (natural range <>) of Ctrl_Bus_Fr_Target_t;
  --
  constant CTRL_BUS_FR_TARGET_ZERO : Ctrl_Bus_Fr_Target_t
    := (busy => '0',
        err => '0',
        resp => Ctrl_Response_ZERO);

end types;
