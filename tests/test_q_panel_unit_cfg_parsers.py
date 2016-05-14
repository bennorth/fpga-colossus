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
from colossus import QPanelTopUnitCfg, QPanelBottomUnitCfg, QPanelNegatingCfg


@pytest.mark.parametrize(
    'str, m_en, m_tgt, neg, c_en',
    [('101-- == 10000', 0x1c, 0x14, False, 0x10),
     ('11-1- != 01000', 0x1a, 0x1a, True,  0x08),
     ('00-0- != 01000', 0x1a, 0x00, True,  0x08)],
    ids=['1x2.2x', '1=2=4a', '1=2=4b'])
#
def test_top_unit_example(str, m_en, m_tgt, neg, c_en):
    cfg = QPanelTopUnitCfg.from_string(str)
    assert cfg.match_en == m_en
    assert cfg.match_tgt == m_tgt
    assert cfg.negate == neg
    assert cfg.counter_en == c_en


@pytest.mark.parametrize(
    'str, coeff, tgt, c_en',
    [('11--- 0 00100', 0x18, 0, 0x04),
     ('1---1 0 00100', 0x11, 0, 0x04)],
    ids=['1=2=4a', '1=2=4b'])
#
def test_bottom_unit_example(str, coeff, tgt, c_en):
    cfg = QPanelBottomUnitCfg.from_string(str)
    assert cfg.coeff == coeff
    assert cfg.tgt == tgt
    assert cfg.counter_en == c_en


@pytest.mark.parametrize(
    'str, top, glb',
    [('-1--- -----', 0x08, 0x00),
     ('1--11 -111-', 0x13, 0x0e)],
    ids=['top-2', 'top-145-glb-234'])
#
def test_negating_example(str, top, glb):
    cfg = QPanelNegatingCfg.from_string(str)
    assert cfg.top_negates == top
    assert cfg.global_negates == glb
