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

TAPE_LENGTH = 320


def test_q_selector(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.set_q_selector_cfg(int('100000', 2))
    got_qs = colossus.snoop_Q_vec(TAPE_LENGTH, reset_first_p=True)
    exp_qs = [(z & 31) for z in zs]
    assert np.all(got_qs == exp_qs)


def test_q_selector_delta(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.set_q_selector_cfg(int('110000', 2))

    # Ensure that, if the 'reset' is not working, the 'one back'
    # registers are filled with junk.
    warm_up_qs = colossus.snoop_Q_vec(5, reset_first_p=True)

    got_qs = colossus.snoop_Q_vec(TAPE_LENGTH, reset_first_p=True)
    bare_zs = np.array([(z & 31) for z in zs])
    exp_qs_tail = bare_zs[:-1] ^ bare_zs[1:]
    assert np.all(got_qs[1:] == exp_qs_tail)
    assert got_qs[0] == bare_zs[0]


@pytest.mark.parametrize('cfg_str', ['000000', '010001', '000101'])
def test_q_selector_zero(colossus, cfg_str):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.set_q_selector_cfg(int(cfg_str, 2))
    got_qs = colossus.snoop_Q_vec(TAPE_LENGTH, reset_first_p=True)
    assert np.all(got_qs == 0)


def test_command_target(colossus):
    colossus.set_q_selector_cfg(int('100000', 2))
    colossus.reset_movement()
    colossus.reset_q_selector()
    assert colossus.snoop_Q() == 0x00
    # This is a bit hacky.  It relies on the fact that the [0] tape
    # letter remains on the z bus, because we have reset the movement.
    colossus.punch_tape([31])
    colossus.enable_q_selector_one_shot()
    for z in range(32):
        colossus.punch_tape([z])
        assert colossus.snoop_Q() == (z - 1) % 32
        colossus.enable_q_selector_one_shot()
        assert colossus.snoop_Q() == z
