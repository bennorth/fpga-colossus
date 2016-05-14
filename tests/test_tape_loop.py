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

TAPE_LENGTH = 320


def test_clear_tape(colossus):
    colossus.clear_tape()
    got_zs = colossus.read_tape_contents(TAPE_LENGTH)
    assert np.all(got_zs == 0xa5)


def test_write_tape_pattern(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH, value_ub=256)
    round_trip_zs = colossus.read_tape_contents(TAPE_LENGTH)
    assert np.all(round_trip_zs == zs)


def test_snoop_z(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH, value_ub=256)
    aug_zs = colossus.snoop_Z_vec(TAPE_LENGTH)
    exp_aug_zs = (128 * ((zs & 32) == 32)) + (zs & 31)
    assert np.all(aug_zs == exp_aug_zs)
