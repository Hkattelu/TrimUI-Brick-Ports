import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("summary", Path(__file__).with_name("summarize-audio-timing.py"))
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)
CONFIG = "INFO ddd_audio_timing: Audio timing enabled; wall time only; channels=2 rate=48000 sample_format=F32 buffer=Default\n"


def report(total=10000):
    return ("INFO ddd_audio_timing: Audio callback wall time in microseconds: phases report=Report { "
            f"callbacks: 2, frames: 960, interval_us: 20000, totals_us: [{total}, 2000, 1000, 6000], "
            "maxima_us: [9000, 1000, 500, 3000], chunk_total_us: 20000, gap_max_us: 12000, "
            "gap_gt_previous_chunk: 1, zero_queue_delay: 1, past_queue_delay: 1, queue_delay_min_us: Some(0) }\n")


class SummaryTests(unittest.TestCase):
    def test_excludes_startup_and_preserves_wall_time_interpretation(self):
        result = summary.summarize(CONFIG + report(90000) + report() * 2)
        self.assertEqual(result["callbacks"], 4)
        self.assertEqual(result["generated_audio_ms"], 40)
        self.assertEqual(result["callback_work_to_generated_audio_ratio"], 0.5)
        self.assertEqual(result["phases"]["mixing"]["mean_callback_ms"], 3)
        self.assertEqual(result["indicators"]["past_queue_delay"], 2)

    def test_rejects_truncated_corrupt_or_combined_logs(self):
        for text in (CONFIG + report() * 2, CONFIG + report().replace("frames: 960, ", "") * 3,
                     CONFIG + report(8000) * 3, CONFIG * 2 + report() * 3):
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    summary.summarize(text)

    def test_ansi_and_unrelated_logs_do_not_change_results(self):
        plain = CONFIG + report() * 3
        colored = "\x1b[32m" + plain.replace("\n", "\x1b[0m\n\x1b[32m")
        self.assertEqual(summary.summarize(plain), summary.summarize(colored + "unrelated line\n"))


if __name__ == "__main__":
    unittest.main()
