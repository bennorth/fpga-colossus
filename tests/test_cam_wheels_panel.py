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

def test_set_steppings(colossus):
    tgt_counts_0 = np.array([(n // 2) for n in colossus.N_CAMS_ALL])
    for offset in [3, 8]:
        tgt_counts = tgt_counts_0 + offset
        colossus.set_step_count_vector_values(tgt_counts)

        colossus.head_scheduler_trigger_transfer(63)

        assert np.all(colossus.read_step_counts_via_wheels() == tgt_counts)
