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

import numpy as np
import pytest
from colossus import SteppingCfg

no_stepping_cfg = SteppingCfg(False, False, False, False)
step_fast_cfg = SteppingCfg(True, False, False, False)
step_fast_and_trigger_cfg = SteppingCfg(True, False, True, False)
step_slow_cfg = SteppingCfg(False, True, False, False)
step_slow_ign_cfg = SteppingCfg(False, True, False, True)


def _stepping_pretest(colossus):
    colossus.reset_all_step_count_vector_configs()
    colossus.reset_step_count_vector()
    assert np.all(colossus.read_step_count_vector_values() == 0)


def test_reset(colossus):
    _stepping_pretest(colossus)


@pytest.mark.parametrize('fast_idx, slow_idx',
                         [(4, 3), (3, 2), (4, 2), (2, 0)])
def test_long_run_stepping(colossus, fast_idx, slow_idx):
    _stepping_pretest(colossus)

    colossus.set_step_count_vector_config(fast_idx, step_fast_and_trigger_cfg)
    colossus.set_step_count_vector_config(slow_idx, step_slow_cfg)

    n_steps = 100
    step_counts = colossus.read_step_count_vector_values_then_step(n_steps)

    exp_step_counts = np.zeros_like(step_counts)

    fast_wheel_size = colossus.N_CAMS_CHI[fast_idx]
    slow_wheel_size = colossus.N_CAMS_CHI[slow_idx]
    exp_step_counts[:, fast_idx] = np.arange(n_steps) % fast_wheel_size
    n_triggers = int(np.ceil(n_steps / fast_wheel_size))
    exp_slow = np.repeat(np.arange(n_triggers) % slow_wheel_size,
                         fast_wheel_size)[:n_steps]
    exp_step_counts[:, slow_idx] = exp_slow

    assert np.all(step_counts == exp_step_counts)


@pytest.mark.parametrize('fast_idx, slow_idx',
                         [(4, 3), (3, 2), (4, 2), (2, 0)])
def test_untriggered_long_run_stepping(colossus, fast_idx, slow_idx):
    _stepping_pretest(colossus)

    colossus.set_step_count_vector_config(fast_idx, step_fast_cfg)
    colossus.set_step_count_vector_config(slow_idx, step_slow_cfg)

    n_steps = 100
    step_counts = colossus.read_step_count_vector_values_then_step(n_steps)

    exp_step_counts = np.zeros_like(step_counts)
    fast_wheel_size = colossus.N_CAMS_CHI[fast_idx]
    exp_step_counts[:, fast_idx] = np.arange(n_steps) % fast_wheel_size

    assert np.all(step_counts == exp_step_counts)


def test_frenzied_fantasy_stepping(colossus):
    _stepping_pretest(colossus)

    colossus.set_step_count_vector_config(4, step_fast_and_trigger_cfg)
    colossus.set_step_count_vector_config(3, step_fast_and_trigger_cfg)
    colossus.set_step_count_vector_config(2, step_slow_cfg)

    n_steps = 500
    step_counts = colossus.read_step_count_vector_values_then_step(n_steps)

    exp_step_counts = np.zeros_like(step_counts)
    exp_step_counts[:, 4] = np.arange(n_steps) % colossus.N_CAMS_CHI[4]
    exp_step_counts[:, 3] = np.arange(n_steps) % colossus.N_CAMS_CHI[3]

    step_p = (exp_step_counts[:, 4] == 0) | (exp_step_counts[:, 3] == 0)
    step_p[0] = 0
    exp_step_counts[:, 2] = np.cumsum(step_p.astype(np.int64)) % colossus.N_CAMS_CHI[2]

    assert np.all(step_counts == exp_step_counts)


def test_command_stream(colossus):
    _stepping_pretest(colossus)

    tgt_counts = [(n // 2) for n in colossus.N_CAMS_ALL]
    colossus.set_step_count_vector_values(tgt_counts)

    # Sanity check:
    assert np.all(colossus.read_step_count_vector_values() == tgt_counts)

    # Expect a one-cycle latency.
    exp_cmd_bus_history = np.zeros(16, dtype=np.uint8)
    exp_cmd_bus_history[1] = 0x2d  # preamble
    exp_cmd_bus_history[2] = 0x3f  # body-id (broadcast)
    exp_cmd_bus_history[3:15] = tgt_counts

    cmd_bus_history = colossus.emit_cmds_step_count_vector()
    assert np.all(cmd_bus_history == exp_cmd_bus_history)


def _nzat(*idxs):
    counts = [0] * 12
    for idx in idxs:
        counts[idx] = 3
    return counts

def _ignat(*idxs):
    ignore_ps = [False] * 12
    for idx in idxs:
        ignore_ps[idx] = True
    return ignore_ps

@pytest.mark.parametrize(
    'tgt_counts, ignore_ps, exp_ended',
    [(_nzat(), _ignat(), 1),
     (_nzat(), [True]*12, 1),
     (_nzat(11), _ignat(), 0),
     (_nzat(6), _ignat(), 0),
     (_nzat(11), _ignat(11), 1),
     (_nzat(11), _ignat(3), 0),
     (_nzat(6, 11), _ignat(6), 0),
     (_nzat(6, 11), _ignat(8), 0),
     (_nzat(6, 11), _ignat(11), 0),
     (_nzat(6, 11), _ignat(6, 11), 1)],
    ids=['all-zero-all-noted',
         'all-zero-all-ignored',
         'nonzero-11',
         'nonzero-6',
         'nonzero-11-ignored-11',
         'nonzero-11-ignored-03',
         'nonzero-06-11-ignored-06',
         'nonzero-06-11-ignored-08',
         'nonzero-06-11-ignored-11',
         'nonzero-06-11-ignored-06-11'])
#
def test_next_ended(colossus, tgt_counts, ignore_ps, exp_ended):
    colossus.set_step_count_vector_values(tgt_counts)
    for i, ignore_p in enumerate(ignore_ps):
        cfg = SteppingCfg(False, False, False, ignore_p)
        colossus.set_step_count_vector_config(i, cfg)
    got_ended = colossus.read_step_count_vector_ended()
    assert got_ended == exp_ended
