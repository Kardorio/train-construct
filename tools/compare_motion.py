#!/usr/bin/env python3
"""Compare completed native-engine construction runs, including the stopped control."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def result(scenario):
    text = (ROOT / "tests" / f"last-{scenario}.log").read_text()
    assert "CT_TEST SUCCESS lifecycle" in text, f"Incomplete scenario: {scenario}"
    entries = [json.loads(line.split("CT_TEST loop-and-requests ", 1)[1])
               for line in text.splitlines() if "CT_TEST loop-and-requests " in line]
    assert entries, f"No completion measurement: {scenario}"
    assert all(entry == entries[0] for entry in entries), "Reload changed the completion measurement"
    return entries[0]


def main():
    moving, north, stopped = [result(name) for name in ("engine", "engine-north", "engine-stop")]
    assert stopped["stopped"] and stopped["moving_rails"] == 0
    for entry in (moving, north):
        assert not entry["stopped"] and entry["moving_rails"] == 52
        assert entry["moving_signals"] == 2 and entry["moving_accessories"] == 3
        assert entry["built"] == stopped["built"] == 55
    assert moving["tick"] < stopped["tick"], "Moving construction did not improve completion time"
    report = {
        "moving_south": moving, "moving_north": north, "stopped_south": stopped,
        "time_reduction_percent": round(100 * (1 - moving["tick"] / stopped["tick"]), 2),
        "scope": "Boucle native de 52 rails et trois accessoires, deux ravitaillements et interruptions manuelles de sécurité. Le témoin conserve la pose mobile des accessoires mais arrête le train pour chaque rail. Ces mesures ne qualifient pas tous les réseaux.",
    }
    (ROOT / "docs" / "motion-performance.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"CT_MOTION SUCCESS {stopped['tick']} -> {moving['tick']} ticks, {report['time_reduction_percent']} % de temps en moins")


if __name__ == "__main__":
    main()
