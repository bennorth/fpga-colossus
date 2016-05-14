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

def test_pattern(colossus):
    # wheel 5 is PSI-1
    wheel_idx = 5

    pattern = np.random.randint(2, size=43)
    colossus.load_cam_wheel(wheel_idx, pattern)

    for sc in range(colossus.N_CAMS_ALL[wheel_idx]):
        got_pattern = colossus.read_cam_wheel_pattern(wheel_idx, sc)
        exp_pattern = np.concatenate([pattern[sc:], pattern[:sc]])
        assert np.all(got_pattern == exp_pattern)

        # read_cam_wheel_pattern() has set stepping count.
        assert colossus.read_cam_wheel_step_count(wheel_idx) == sc
