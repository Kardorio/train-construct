#!/usr/bin/env python3
"""Compare accessory-phase replays of the same starting save and duration."""
import json
from pathlib import Path
import re
import statistics

ROOT=Path(__file__).resolve().parents[1]
def measure(path):
    text=path.read_text()
    rows=[json.loads(line.split("CT_DEBUG STATE ",1)[1]) for line in text.splitlines() if "CT_DEBUG STATE " in line]
    ticks=int(re.search(r"Performed (\d+) updates",text).group(1))
    assert rows and not any(row["state"]=="build" for row in rows)
    initial=previous=rows[0]["built"]
    pose=None;gaps=[];last_command=None
    for row in rows:
        if row["built"]>previous:
            pose=row["tick"];previous=row["built"]
        if pose is not None and row["state"]=="travelling" and row.get("arrival")=="accessory":
            command=(row.get("accessory"),row.get("destination"))
            if command!=last_command:
                gaps.append((row["tick"]-pose)/60)
                pose=None;last_command=command
    assert gaps
    return {"initial_tick":rows[0]["tick"],"initial_built":initial,"simulation_ticks":ticks,"accessories_built":rows[-1]["built"]-initial,"selection_gap_median_seconds":statistics.median(gaps),"selection_gap_max_seconds":max(gaps),"gap_samples":len(gaps)}
def main():
    before=measure(ROOT/"docs/accessories-before.txt")
    after=measure(ROOT/"docs/accessories-after.txt")
    for key in ("initial_tick","initial_built","simulation_ticks"):
        assert before[key]==after[key],"Replays do not share a starting point and duration"
    assert after["accessories_built"]>2*before["accessories_built"],"Accessory throughput did not improve"
    assert after["selection_gap_median_seconds"]<1,"Selection still leaves excessive idle time"
    result={"before":before,"after":after}
    (ROOT/"docs/accessory-performance.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))
if __name__=="__main__":main()
