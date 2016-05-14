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

import pytest

# For unknown body command, the first replicator/validator should come
# back with 'neither "this" nor "next" responded', i.e., 0x06.
@pytest.mark.parametrize(
    'addr, exp_err_code',
    [(0xfe, 0x09), (0x01, 0x06)],
    ids=['head', 'body'])
#
def test_unknown_target_address(colossus, addr, exp_err_code):
    r = colossus(addr, 1)
    assert r.error_p
    assert r.response_byte == exp_err_code
