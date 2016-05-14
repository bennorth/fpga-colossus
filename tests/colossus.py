# Copyright 2016 Ben North
#
# This file is part of "FPGA Colossus".
#
# "FPGA Colossus" is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# "FPGA Colossus" is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# "FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.

from collections import namedtuple
import numpy as np
import subprocess
import re
from enum import Enum


class QPanelTopUnitCfg(namedtuple('QPanelTopUnitCfg',
                                  ['match_en', 'match_tgt', 'negate', 'counter_en'])):
    @classmethod
    def from_string(cls, s):
        """
        Format is

            five chars from '01-' to set 'match_en' and 'match_tgt'
            space
            one of '==' or '!=' to set 'negate'
            space
            five chars from '01' to set 'counter_en'
        """
        pcs = s.split(' ')
        match_en_bits = [str(int(c in '01')) for c in pcs[0]]
        match_en = int(''.join(match_en_bits),  2)
        match_tgt_bits = [str(int(c == '1')) for c in pcs[0]]
        match_tgt = int(''.join(match_tgt_bits),  2)
        negate = (pcs[1] == '!=')
        counter_en = int(pcs[2], 2)
        return cls(match_en, match_tgt, negate, counter_en)

    @property
    def cfg_0(self):
        return self.match_en

    @property
    def cfg_1(self):
        return self.match_tgt

    @property
    def cfg_2(self):
        return self.counter_en | (0x80 if self.negate else 0x00)


class QPanelBottomUnitCfg(namedtuple('QPanelBottomUnitCfg',
                                     ['coeff', 'tgt', 'counter_en'])):
    @classmethod
    def from_string(cls, s):
        """
        Format is

            five chars from '1-' to set 'coeff'
            space
            one of '1' or '0' to set 'tgt'
            space
            five chars from '01' to set 'counter_en'
        """
        pcs = s.split(' ')
        coeff_bits = [str(int(c == '1')) for c in pcs[0]]
        coeff = int(''.join(coeff_bits),  2)
        tgt = (pcs[1] == '1')
        counter_en = int(pcs[2], 2)
        return cls(coeff, tgt, counter_en)

    @property
    def cfg_0(self):
        return self.coeff

    @property
    def cfg_1(self):
        return self.counter_en | (0x80 if self.tgt else 0x00)


class QPanelNegatingCfg(namedtuple('QPanelNegatingCfg',
                                   ['top_negates', 'global_negates'])):
    @classmethod
    def from_string(cls, s):
        """
        Format is

            five chars from '1-' to set 'top_negates'
            space
            five chars from '1-' to set 'global_negates'
        """
        pcs = s.split(' ')
        top_negate_bits = [str(int(c == '1')) for c in pcs[0]]
        top_negates = int(''.join(top_negate_bits), 2)
        global_negate_bits = [str(int(c == '1')) for c in pcs[1]]
        global_negates = int(''.join(global_negate_bits), 2)
        return cls(top_negates, global_negates)

    @property
    def cfg_0(self):
        return self.top_negates

    @property
    def cfg_1(self):
        return self.global_negates


class SteppingCfg(namedtuple('SteppingCfg',
                             'fast slow trigger ign_rpt')):
    @property
    def cfg_half_octet(self):
        return (8 * int(self.fast)
                + 4 * int(self.slow)
                + 2 * int(self.trigger)
                + int(self.ign_rpt))


class SetTotalOperation(Enum):
    Count_GT_Threshold = 0
    Count_LT_Threshold = 1
    Always_True = 2


class WorkerIndex(Enum):
    Comparator_Copy_Settings = 0
    Comparator_Copy_Counter_Values = 1
    Movement_Run_Tape_Once = 2
    Counters_Latch_Values = 3


class SetTotalCfg(namedtuple('SetTotalCfg',
                             'threshold operation')):
    @property
    def cfg_0(self):
        return self.threshold % 256

    @property
    def cfg_1(self):
        return (self.threshold // 256) + (self.operation.value << 6)

SetTotalCfg.AlwaysPrint = SetTotalCfg(0, SetTotalOperation.Always_True)
SetTotalCfg.NeverPrint = SetTotalCfg(0, SetTotalOperation.Count_LT_Threshold)


class ColossusResponse(namedtuple('ColossusResponse',
                                  ['cmd', 'error_p', 'response_byte'])):
    @classmethod
    def from_cmd_response(cls, cmd, line):
        s_cmd_echo, s_error_p, s_response_byte = line.rstrip().split()
        if len(s_cmd_echo) == 2:
            cmd_echo = (int(s_cmd_echo, 16),)
        elif len(s_cmd_echo) == 4:
            cmd_echo = (int(s_cmd_echo[:2], 16), int(s_cmd_echo[2:], 16))
        else:
            raise ValueError('expected echo to be of length 2 or 4')
        if cmd_echo != cmd:
            raise ValueError('expected echo to match given cmd')
        if s_error_p == "'0'":
            error_p = False
        elif s_error_p == "'1'":
            error_p = True
        else:
            raise ValueError("expected error-p to be '0' or '1'")
        response_byte = int(s_response_byte)
        return cls(cmd, error_p, response_byte)

    @property
    def cmd_str(self):
        return ''.join('%02x' % x for x in self.cmd)


class Colossus:
    N_WHEELS = 12
    N_COUNTERS = 5
    N_CAMS_CHI = [41, 31, 29, 26, 23]
    N_CAMS_PSI = [43, 47, 51, 53, 59]
    N_CAMS_MU = [61, 37]
    N_CAMS_ALL = N_CAMS_CHI + N_CAMS_PSI + N_CAMS_MU

    Step_Fast_Cfg = SteppingCfg(True, False, False, False)
    No_Stepping_Cfg = SteppingCfg(False, False, False, False)

    def __init__(self):
        self.monitor_process = subprocess.Popen(['./monitor-repl.sh'],
                                                stdout=subprocess.PIPE,
                                                universal_newlines=True)
        self.f_cmd = open('/tmp/repl-input', 'wt')
        self.f_cmd_spool = open('/tmp/repl-input-spool', 'wt')
        self.f_resp = self.monitor_process.stdout
        self.f_spool = open('/tmp/repl-output', 'wt')
        while True:
            if self.f_resp.readline().startswith('READY-FOR-INPUT'):
                break
        self.reset_all_stepping()
        self.reset_all_step_count_vector_configs()
        self.reset_all_set_total_configs()

    def __call__(self, addr_or_data, data=None):
        cmd_tup = (addr_or_data,) + ((data,) if data is not None else ())
        cmd_txt = ('{0:02x}\n'.format(addr_or_data)
                   if data is None
                   else '{0:02x}{1:02x}\n'.format(addr_or_data, data))
        self.f_cmd.write(cmd_txt)
        self.f_cmd.flush()
        self.f_cmd_spool.write(cmd_txt)
        self.f_cmd_spool.flush()
        while True:
            m_resp_line = self.f_resp.readline()
            self.f_spool.write(m_resp_line)
            m_resp_match = re.match('^COLOSSUS-RESPONSE: (.*)', m_resp_line)
            if m_resp_match:
                return ColossusResponse.from_cmd_response(
                    cmd_tup, m_resp_match.group(1))

    def do_cmd(self, addr_or_data, data=None):
        r = self(addr_or_data, data)
        if r.error_p:
            raise RuntimeError('error for %s: %02x' % (r.cmd_str, r.response_byte))
        return r.response_byte

    def punch_tape(self, zs, append_stop_p=True):
        assert self.do_cmd(28, 0) == 0x44
        if len(zs) > 0:
            assert self.do_cmd(29, zs[0]) == 0x55
            for z in zs[1:]:
                assert self.do_cmd(z) == 0x55
        if append_stop_p:
            assert self.do_cmd(29, 0x3f) == 0x55

    def punch_random_tape(self, n_letters, seed=42, value_ub=32):
        np.random.seed(seed)
        zs = np.random.randint(value_ub, size=n_letters)
        self.punch_tape(zs)
        return zs

    def clear_tape(self):
        assert self.do_cmd(26, 0) == 0x33

    def reset_tape_read_pointer(self):
        assert self.do_cmd(27, 0x00) == 0x45

    def read_tape_and_advance_read_pointer(self):
        return self.do_cmd(27, 0x01)

    def read_tape_contents(self, n_sprockets):
        self.reset_tape_read_pointer()
        return np.array([self.read_tape_and_advance_read_pointer()
                         for _ in range(n_sprockets)], dtype=np.uint8)

    def _load_wheel_pattern(self, ctrl_addr, pattern):
        pattern = pattern[::-1]
        n_excess = len(pattern) % 8
        if n_excess:
            pattern = np.concatenate([np.zeros(8 - n_excess, dtype=np.uint8),
                                      pattern])
        assert len(pattern) % 8 == 0
        for i in range(0, len(pattern), 8):
            chunk = int(''.join(str(b) for b in pattern[i:i+8]), 2)
            assert self.do_cmd(ctrl_addr, chunk) == 0x58

    def load_chi_wheel_pattern(self, chi_wheel_idx, pattern):
        self.load_cam_wheel(chi_wheel_idx, pattern)

    def load_psi_wheel_pattern(self, psi_wheel_idx, pattern):
        self.load_cam_wheel(5 + psi_wheel_idx, pattern)

    def load_mu_wheel_pattern(self, mu_wheel_idx, pattern):
        self.load_cam_wheel(10 + mu_wheel_idx, pattern)

    def reset_q_selector(self):
        assert self.do_cmd(22, 0) == 0xb4

    def enable_q_selector_one_shot(self):
        assert self.do_cmd(22, 1) == 0xb5

    def set_q_selector_cfg(self, cfg):
        assert self.do_cmd(23, cfg) == 0x12

    N_Q_PANEL_TOP_UNITS = 10

    def set_q_panel_top_unit_cfg(self, unit_idx, cfg):
        base_addr = 80 + 3 * unit_idx
        self.do_cmd(base_addr, cfg.cfg_0)
        self.do_cmd(base_addr + 1, cfg.cfg_1)
        self.do_cmd(base_addr + 2, cfg.cfg_2)

    N_Q_PANEL_BOTTOM_UNITS = 5

    def set_q_panel_bottom_unit_cfg(self, unit_idx, cfg):
        base_addr = 110 + 2 * unit_idx
        self.do_cmd(base_addr, cfg.cfg_0)
        self.do_cmd(base_addr + 1, cfg.cfg_1)

    def set_q_panel_negating_cfg(self, cfg):
        base_addr = 120
        assert self.do_cmd(base_addr, cfg.cfg_0) == 0x12
        assert self.do_cmd(base_addr + 1, cfg.cfg_1) == 0x12

    def reset_q_panel_cfg(self):
        top_nop_cfg = QPanelTopUnitCfg(0, 0, 0, 0)
        for idx in range(self.N_Q_PANEL_TOP_UNITS):
            self.set_q_panel_top_unit_cfg(idx, top_nop_cfg)
        bottom_nop_cfg = QPanelBottomUnitCfg(0, 0, 0)
        for idx in range(self.N_Q_PANEL_BOTTOM_UNITS):
            self.set_q_panel_bottom_unit_cfg(idx, bottom_nop_cfg)
        negates_nop_cfg = QPanelNegatingCfg(0, 0)
        self.set_q_panel_negating_cfg(negates_nop_cfg)

    def reset_movement(self):
        assert self.do_cmd(24, 0x00) == 0x61

    def move_one_sprocket(self):
        assert self.do_cmd(24, 0x01) == 0x63

    def run_tape_once(self):
        self.scheduler_trigger_manual(WorkerIndex.Movement_Run_Tape_Once)

    def _snoop_x(self, snoop_tgt, post_move_p):
        x = self.do_cmd(25, snoop_tgt)
        if post_move_p:
            self.move_one_sprocket()
        return x

    def snoop_Z(self, post_move_p=False):
        return self._snoop_x(0x00, post_move_p)

    def snoop_Q(self, post_move_p=False):
        return self._snoop_x(0x01, post_move_p)

    def snoop_A(self, post_move_p=False):
        return self._snoop_x(0x05, post_move_p)

    def _snoop_x_vec(self, snoop_tgt, n_sprockets, reset_first_p):
        if reset_first_p:
            self.reset_movement()
        return np.array([self._snoop_x(snoop_tgt, post_move_p=True)
                         for _ in range(n_sprockets)], dtype=np.uint8)

    def snoop_Z_vec(self, n_sprockets, reset_first_p=True):
        return self._snoop_x_vec(0x00, n_sprockets, reset_first_p)

    def snoop_Q_vec(self, n_sprockets, reset_first_p=True):
        return self._snoop_x_vec(0x01, n_sprockets, reset_first_p)

    def snoop_A_vec(self, n_sprockets, reset_first_p=True):
        return self._snoop_x_vec(0x05, n_sprockets, reset_first_p)

    def reset_counters(self):
        assert self.do_cmd(16, 0x80) == 0xa0

    def enable_counters_one_shot(self):
        assert self.do_cmd(16, 0x81) == 0xa1

    def snapshot_counters(self):
        assert self.do_cmd(16, 0x82) == 0xa2

    def read_counter(self, counter_idx):
        counter_lsb = self.do_cmd(16, counter_idx)
        counter_msb = self.do_cmd(16, 0x10 + counter_idx)
        return counter_lsb + (counter_msb << 8)

    def read_all_counters(self):
        return np.array([self.read_counter(i) for i in range(5)])

    def printer_reset(self):
        assert self.do_cmd(243, 0) == 0x11

    def printer_write_1(self, ch):
        assert self.do_cmd(244, ch) == 0x12

    def printer_write_string(self, chs):
        for ch in chs:
            self.printer_write_1(ch)

    def printer_read_contents(self):
        n_chars_low = self.do_cmd(242, 0x00)
        n_chars_high = self.do_cmd(242, 0x01)
        n_chars = n_chars_low + (n_chars_high << 8)
        assert self.do_cmd(242, 0x02) == 0x32
        return np.array([self.do_cmd(242, 0x03) for _ in range(n_chars)],
                        dtype=np.uint8)

    def printer_read_records(self):
        octets = self.printer_read_contents()
        record_len = PrintRecord.Encoded_N_Octets
        assert len(octets) % record_len == 0
        return [PrintRecord.from_octets(octets[idx0 : (idx0 + record_len)])
                for idx0 in range(0, len(octets), record_len)]

    def scheduler_trigger_manual(self, worker_tag):
        assert self.do_cmd(144, worker_tag.value) == 0x12

    def head_scheduler_trigger_transfer(self, body_idx):
        assert self.do_cmd(240, body_idx) == 0x12

    def tail_scheduler_trigger_print_record(self, body_idx):
        assert self.do_cmd(241, body_idx) == 0x19

    def comparator_read_setting_labels(self):
        return np.array([self.do_cmd(128, wheel_idx)
                         for wheel_idx in range(self.N_WHEELS)],
                        dtype=np.uint8)

    def comparator_read_counter_values(self):
        lsbs = np.array([self.do_cmd(128, 0x20 + counter_idx)
                         for counter_idx in range(self.N_COUNTERS)],
                        dtype=np.uint16)
        msbs = np.array([self.do_cmd(128, 0x30 + counter_idx)
                         for counter_idx in range(self.N_COUNTERS)],
                        dtype=np.uint16)
        return (lsbs + msbs * 256)

    def reset_all_set_total_configs(self):
        for i in range(self.N_COUNTERS):
            self.set_set_total_config(i, SetTotalCfg.NeverPrint)

    def set_set_total_config(self, counter_idx, cfg):
        base_addr = 130 + 2 * counter_idx
        self.do_cmd(base_addr, cfg.cfg_0)
        self.do_cmd(base_addr + 1, cfg.cfg_1)

    def read_counter_value_gt_threshold(self):
        return self.do_cmd(128, 0x40)

    def read_counter_value_lt_threshold(self):
        return self.do_cmd(128, 0x41)

    def read_print_required_vec(self):
        return self.do_cmd(128, 0x42)

    def read_print_required(self):
        return self.do_cmd(128, 0x43)

    def initiate_run(self):
        assert self.do_cmd(240, 255) == 0x15

    def load_cam_wheel(self, wheel_idx, pattern):
        self._load_wheel_pattern(170 + 2 * wheel_idx, pattern)

    def reset_all_stepping(self):
        for wh in range(self.N_WHEELS):
            self.set_cam_wheel_stepping(wh, 0)

    def set_cam_wheel_stepping(self, wheel_idx, step_count):
        if step_count >= self.N_CAMS_ALL[wheel_idx]:
            raise ValueError('bad step count')
        assert self.do_cmd(171 + 2 * wheel_idx, step_count) == 0x30

    def reset_all_cam_wheel_ng_movements(self):
        for wh in range(self.N_WHEELS):
            self.reset_cam_wheel_movement(wh)

    def reset_cam_wheel_movement(self, wheel_idx):
        assert self.do_cmd(171 + 2 * wheel_idx, 0x40) == 0x32

    def enable_cam_wheel_movement_one_shot(self, wheel_idx):
        assert self.do_cmd(171 + 2 * wheel_idx, 0x41) == 0x33

    def read_cam_wheel_step_count(self, wheel_idx):
        return self.do_cmd(171 + 2 * wheel_idx, 0x80)

    def read_cam_wheel_w_and_move(self, wheel_idx):
        w = self.do_cmd(171 + 2 * wheel_idx, 0xc0)
        self.enable_cam_wheel_movement_one_shot(wheel_idx)
        return w

    def read_cam_wheel_pattern(self, wheel_idx, step_count):
        self.set_cam_wheel_stepping(wheel_idx, step_count)
        self.reset_cam_wheel_movement(wheel_idx)
        return np.array([self.read_cam_wheel_w_and_move(wheel_idx)
                         for _ in range(self.N_CAMS_ALL[wheel_idx])],
                        dtype=np.uint8)

    def read_step_counts_via_wheels(self):
        return np.array([self.read_cam_wheel_step_count(i)
                         for i in range(self.N_WHEELS)])

    def set_step_count_vector_values(self, tgt_counts):
        # Would not be used like this in real life (altering configs and then using
        # without first resetting), but should allow us to set arbitrary values in
        # the vector.
        self.reset_all_step_count_vector_configs()
        self.reset_step_count_vector()
        for i, n in enumerate(tgt_counts):
            self.set_step_count_vector_config(i, self.Step_Fast_Cfg)
            for _ in range(n):
                self.next_step_count_vector()
            self.set_step_count_vector_config(i, self.No_Stepping_Cfg)

    def read_step_count_vector_values(self):
        return np.array([self.do_cmd(236, i) for i in range(self.N_WHEELS)],
                        dtype=np.uint8)

    def read_step_count_vector_ended(self):
        return self.do_cmd(236, 0x10)

    def reset_step_count_vector(self):
        assert self.do_cmd(236, 0x20) == 0x18

    def next_step_count_vector(self):
        assert self.do_cmd(236, 0x21) == 0x19

    def read_step_count_vector_values_then_step_1(self):
        xs = self.read_step_count_vector_values()
        self.next_step_count_vector()
        return xs

    def read_step_count_vector_values_then_step(self, n=None):
        effective_n = n if n is not None else 1
        counts = [self.read_step_count_vector_values_then_step_1() for _ in range(n)]
        return counts[0] if n is None else np.array(counts)

    def emit_cmds_step_count_vector(self):
        return np.array([self.do_cmd(236, 0x30 + i) for i in range(16)],
                        dtype=np.uint8)

    def set_step_count_vector_config(self, wheel_idx, cfg):
        self.do_cmd(224 + wheel_idx, cfg.cfg_half_octet)

    def reset_all_step_count_vector_configs(self):
        no_stepping_cfg = SteppingCfg(False, False, False, False)
        for i in range(self.N_WHEELS):
            self.set_step_count_vector_config(i, no_stepping_cfg)

    def add_nibbles(self, n0, n1):
        datum = (n1 << 4) | n0;
        return self.do_cmd(8, datum)


class PrintRecord(namedtuple('PrintRecord', 'body_id stepping_settings counters')):
    Encoded_N_Octets = 1 + Colossus.N_WHEELS + 2 * Colossus.N_COUNTERS

    @classmethod
    def from_octets(cls, encoded_record):
        if (encoded_record.shape != (cls.Encoded_N_Octets,)
            or encoded_record.dtype != np.uint8):
            #
            raise ValueError('expected %d-long vector of uint8s' % cls.Encoded_N_Octets)

        body_id = encoded_record[0]
        settings = encoded_record[1 : (Colossus.N_WHEELS + 1)]
        counters = encoded_record[(Colossus.N_WHEELS + 1) : ].view(np.uint16)

        return cls(body_id, settings, counters)


class ColossusTesting:
    SHORT_TAPE_LENGTH = 60

    @staticmethod
    def establish_sample_counts(colossus,
                                tape_length=SHORT_TAPE_LENGTH,
                                run_method='run_tape_once',
                                do_snapshot=True):
        #
        zs = colossus.punch_random_tape(tape_length)
        colossus.reset_q_panel_cfg()
        colossus.set_q_panel_top_unit_cfg(0, QPanelTopUnitCfg(0x01, 0x01, 0x00, 0x05))
        colossus.set_q_panel_top_unit_cfg(1, QPanelTopUnitCfg(0x02, 0x02, 0x00, 0x03))
        colossus.set_q_selector_cfg(0x20)

        if run_method == 'run_tape_once':
            colossus.run_tape_once()
        elif run_method == 'loop_one_shot':
            colossus.reset_movement()
            colossus.reset_counters()

            colossus.snapshot_counters()
            assert np.all(colossus.read_all_counters() == 0)

            colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Counter_Values)
            assert np.all(colossus.comparator_read_counter_values() == 0)

            for _ in range(tape_length):
                colossus.enable_counters_one_shot()
                colossus.move_one_sprocket()
        else:
            raise RuntimeError('bad run_method')

        if do_snapshot:
            colossus.snapshot_counters()

        exp_ctrs = [tape_length,
                    tape_length,
                    np.sum((zs & 0x01) == 0x01),
                    np.sum((zs & 0x02) == 0x02),
                    np.sum((zs & 0x03) == 0x03)]

        return exp_ctrs

    @staticmethod
    def establish_sample_stepping_settings(colossus):
        np.random.seed(42)
        exp_settings = np.random.randint(1, 16, size=(colossus.N_WHEELS,))

        for wheel_idx, n_steps in enumerate(exp_settings):
            colossus.set_cam_wheel_stepping(wheel_idx, n_steps)

        return exp_settings

    parity = [0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
              1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1]
