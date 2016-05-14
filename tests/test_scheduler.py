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
from colossus import WorkerIndex, SetTotalCfg, SetTotalOperation, ColossusTesting, PrintRecord


class TestWorkers(object):
    def test_comparator_copy_settings_zero(self, colossus):
        colossus.reset_all_stepping()
        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Settings)
        assert np.all(colossus.comparator_read_setting_labels() == 0)

    def test_comparator_copy_settings_adv(self, colossus):
        exp_labels = ColossusTesting.establish_sample_stepping_settings(colossus)

        assert np.all(colossus.read_step_counts_via_wheels() == exp_labels)

        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Settings)
        assert np.all(colossus.comparator_read_setting_labels() == exp_labels)

    def test_comparator_maybe_print_yes(self, colossus):
        exp_labels = ColossusTesting.establish_sample_stepping_settings(colossus)
        exp_counts = ColossusTesting.establish_sample_counts(colossus)
        colossus.set_set_total_config(0, SetTotalCfg(0, SetTotalOperation.Always_True))

        colossus.printer_reset()
        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Settings)
        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Counter_Values)
        colossus.tail_scheduler_trigger_print_record(0)
        printed_octets = colossus.printer_read_contents()
        print_record = PrintRecord.from_octets(printed_octets)
        assert np.all(print_record.stepping_settings == exp_labels)
        assert np.all(print_record.counters == exp_counts)

    def test_comparator_maybe_print_no(self, colossus):
        exp_labels = ColossusTesting.establish_sample_stepping_settings(colossus)
        exp_counts = ColossusTesting.establish_sample_counts(colossus)

        never_print_cfg = SetTotalCfg(0, SetTotalOperation.Count_LT_Threshold)
        for i in range(colossus.N_COUNTERS):
            colossus.set_set_total_config(i, never_print_cfg)

        colossus.printer_reset()
        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Settings)
        colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Counter_Values)
        colossus.tail_scheduler_trigger_print_record(0)
        printed_octets = colossus.printer_read_contents()
        assert printed_octets.size == 0
