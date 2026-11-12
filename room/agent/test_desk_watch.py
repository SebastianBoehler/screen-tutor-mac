"""Run: .venv/bin/python -m unittest test_desk_watch.py"""

import unittest

import numpy as np

from desk_watch import ChangeGate, changed_fraction, parse_observation


def page(changed: int = 0, value: int = 200) -> np.ndarray:
    pixels = np.full(64 * 48, 120, dtype=np.int16)
    pixels[:changed] = value
    return pixels.reshape(48, 64)


class ChangeGateTests(unittest.TestCase):
    def test_changed_fraction_ignores_noise(self):
        self.assertEqual(changed_fraction(page(), page(300, 130)), 0)
        self.assertAlmostEqual(changed_fraction(page(), page(300, 40)), 300 / 3072)

    def test_writing_is_analyzed_after_hand_settles(self):
        gate = ChangeGate()
        self.assertEqual(gate.evaluate(page(), 0, True), "first_look")
        gate.record_analysis(page(), 0)
        self.assertIsNone(gate.evaluate(page(900, 10), 5, True))
        self.assertIsNone(gate.evaluate(page(40, 20), 5.5, True))
        self.assertIsNone(gate.evaluate(page(40, 20), 6, True))
        self.assertEqual(gate.evaluate(page(40, 20), 7.1, True), "page_changed")

    def test_stall_reported_once_with_task_only(self):
        gate = ChangeGate(stall_seconds=60)
        gate.evaluate(page(), 0, True)
        gate.record_analysis(page(), 0)
        self.assertEqual(gate.evaluate(page(), 61, True), "no_visible_progress")
        gate.record_analysis(page(), 61)
        self.assertIsNone(gate.evaluate(page(), 300, True))
        other = ChangeGate(stall_seconds=60)
        other.evaluate(page(), 0, False)
        other.record_analysis(page(), 0)
        self.assertIsNone(other.evaluate(page(), 300, False))


class ParseTests(unittest.TestCase):
    def test_parses_fenced_json(self):
        data = parse_observation('```json\n{"summary": "x", "issue": {"kind": "error", "location": "l2", "description": "d"}}\n```')
        self.assertEqual(data["progress"], "unclear")
        self.assertEqual(data["issue"]["location"], "l2")

    def test_rejects_prose(self):
        with self.assertRaises(ValueError):
            parse_observation("I cannot see the desk.")


if __name__ == "__main__":
    unittest.main()
