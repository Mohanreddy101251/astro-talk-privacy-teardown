"""Summarise a PCAPdroid CSV export per destination host.

Usage: python -I 04_analyze_capture.py evidence/pcapdroid_capture.csv
The capture is metadata only (no payloads): host, ports, protocol, bytes, timing.
"""
import csv
import sys
from collections import defaultdict

rows = [r for r in csv.DictReader(open(sys.argv[1], encoding="utf-8")) if r["Proto"] != "DNS"]
agg = defaultdict(lambda: {"sent": 0, "rcvd": 0, "conns": 0, "ports": set(), "first": None})
for r in rows:
    a = agg[r["Info"] or r["DstIp"]]
    a["sent"] += int(r["BytesSent"])
    a["rcvd"] += int(r["BytesRcvd"])
    a["conns"] += 1
    a["ports"].add(f'{r["Proto"]}:{r["DstPort"]}')
    a["first"] = min(filter(None, [a["first"], r["FirstSeen"]]))

print(f'{"host":45} {"conns":>5} {"sent(B)":>9} {"rcvd(B)":>10}  first seen / protocols')
for host, a in sorted(agg.items(), key=lambda kv: -kv[1]["sent"]):
    print(f'{host:45} {a["conns"]:5} {a["sent"]:9} {a["rcvd"]:10}  {a["first"][11:23]} {sorted(a["ports"])}')

cleartext = [r for r in rows if r["Proto"] == "HTTP" or r["DstPort"] == "80"]
print(f"\nflows: {len(rows)}; cleartext HTTP (port 80) flows: {len(cleartext)}; "
      f"cleartext bytes received: {sum(int(r['BytesRcvd']) for r in cleartext)}")
print("window:", min(r["FirstSeen"] for r in rows), "->", max(r["LastSeen"] for r in rows))
