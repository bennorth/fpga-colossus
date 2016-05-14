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

from colossus import QPanelBottomUnitCfg, SteppingCfg, SetTotalOperation, SetTotalCfg, Colossus
import wheel_patterns
import pickle


set_total_threshold = 7873


def chi34_results(colossus, both_fast_p):
    with open('sample_PP_Z.pkl', 'rb') as f_in:
        sample_Z = pickle.load(f_in)

    colossus.punch_tape(sample_Z)

    for i, chi in enumerate(wheel_patterns.chi):
        colossus.load_chi_wheel_pattern(i, chi)

    for i, psi in enumerate(wheel_patterns.psi):
        colossus.load_psi_wheel_pattern(i, psi)

    for i, mu in enumerate(wheel_patterns.mu):
        colossus.load_mu_wheel_pattern(i, mu)

    colossus.set_q_selector_cfg(int('111100', 2))

    colossus.reset_all_step_count_vector_configs()

    if both_fast_p:
        # Set CHI-3 and CHI-4 to step fast:
        colossus.set_step_count_vector_config(2, SteppingCfg(True, False, False, False))
        colossus.set_step_count_vector_config(3, SteppingCfg(True, False, False, False))
    else:
        # Set CHI-3 to step fast and trigger slow:
        colossus.set_step_count_vector_config(2, SteppingCfg(True, False, True, False))
        # Set CHI-4 to step slow:
        colossus.set_step_count_vector_config(3, SteppingCfg(False, True, True, False))

    # Count '3+4.' into counter 4:
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_bottom_unit_cfg(0, QPanelBottomUnitCfg(0x06, 0x00, 0x01))

    # Threshold as determined by sample statistics; we seek a deficit in "3+4.":
    set_total_cfg = SetTotalCfg(set_total_threshold, SetTotalOperation.Count_LT_Threshold)
    colossus.set_set_total_config(4, set_total_cfg)

    colossus.printer_reset()

    colossus.initiate_run()

    print_records = colossus.printer_read_records()

    raw_results = [(r.stepping_settings[2], r.stepping_settings[3], r.counters[4])
                   for r in print_records]

    return raw_results


if __name__ == '__main__':
    both_fast_p = False
    try:
        import sys
        if sys.argv[1] == 'both-fast':
            both_fast_p = True
    except IndexError:
        pass

    colossus = Colossus()
    results = chi34_results(colossus, both_fast_p)

    print(' Chi(3)    Chi(4)     Count of')
    print('stepping  stepping  (3)+(4)=dot\n')

    for r in results:
        print('   {:2}        {:2}        {:4}' .format(*r))
