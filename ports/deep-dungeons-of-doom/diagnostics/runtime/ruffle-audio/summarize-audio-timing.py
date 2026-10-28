#!/usr/bin/env python3
"""Summarize opt-in callback wall times; never equate indicators with dropouts."""
import argparse
import json
from pathlib import Path
import re

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
FIELDS = ("callbacks", "frames", "interval_us", "chunk_total_us", "gap_max_us",
          "gap_gt_previous_chunk", "zero_queue_delay", "past_queue_delay")
PHASES = ("callback_work", "instance_lock_wait", "other_lock_wait", "mixing")


def parse(text):
    configs, reports = [], []
    for raw in text.splitlines():
        line = ANSI.sub("", raw)
        if "ddd_audio_timing" not in line:
            continue
        if "Audio timing enabled;" in line:
            fields = {}
            for name in ("channels", "rate"):
                match = re.search(rf"\b{name}=(\d+)\b", line)
                if not match or int(match[1]) <= 0:
                    raise ValueError("Invalid audio configuration: " + line)
                fields[name] = int(match[1])
            match = re.search(r"\bsample_format=(\w+)\b", line)
            if not match:
                raise ValueError("Missing sample format")
            fields["sample_format"] = match[1]
            configs.append(fields)
        elif "Audio callback wall time in microseconds:" in line:
            match = re.search(r"\breport=Report \{ (.+) \}", line)
            if not match:
                raise ValueError("Malformed callback report")
            body = match[1]
            report = {}
            for name in FIELDS:
                match = re.search(rf"\b{name}: (\d+)(?:,|$)", body)
                if not match:
                    raise ValueError("Missing field: " + name)
                report[name] = int(match[1])
            for name in ("totals_us", "maxima_us"):
                match = re.search(rf"\b{name}: \[([\d, ]+)\]", body)
                if not match:
                    raise ValueError("Missing phase array: " + name)
                report[name] = [int(n.strip()) for n in match[1].split(",")]
                if len(report[name]) != 4:
                    raise ValueError("Expected four phases")
            match = re.search(r"\bqueue_delay_min_us: (None|Some\((\d+)\))", body)
            if not match:
                raise ValueError("Missing minimum queue delay")
            report["queue_delay_min_us"] = None if match[1] == "None" else int(match[2])
            if any(report[k] <= 0 for k in ("callbacks", "frames", "interval_us", "chunk_total_us")):
                raise ValueError("Empty callback interval")
            if sum(report["totals_us"][1:]) > report["totals_us"][0]:
                raise ValueError("Mixer phases exceed enclosing callback work")
            if any(m > t for m, t in zip(report["maxima_us"], report["totals_us"])):
                raise ValueError("A phase maximum exceeds its total")
            if report["zero_queue_delay"] + report["past_queue_delay"] > report["callbacks"]:
                raise ValueError("Queue-delay indicators exceed callback count")
            if report["gap_gt_previous_chunk"] > report["callbacks"]:
                raise ValueError("Gap indicators exceed callback count")
            reports.append(report)
    if len(configs) != 1:
        raise ValueError("Expected exactly one audio configuration; split multiple sessions first")
    return configs[0], reports


def summarize(text, skip=1):
    config, reports = parse(text)
    if skip < 0 or len(reports) - skip < 2:
        raise ValueError("Need at least two complete intervals after warmup exclusion")
    selected = reports[skip:]
    callbacks = sum(r["callbacks"] for r in selected)
    frames = sum(r["frames"] for r in selected)
    audio_us = sum(r["chunk_total_us"] for r in selected)
    totals = [sum(r["totals_us"][i] for r in selected) for i in range(4)]
    minima = [r["queue_delay_min_us"] for r in selected if r["queue_delay_min_us"] is not None]
    return {
        "scope": "Callback wall time, including waits/preemption; not CPU utilization, audible dropouts, FPS or sound quality. Main-thread mixer waits and driver write time are not measured.",
        "config": config, "reports_seen": len(reports), "warmup_reports_excluded": skip,
        "reports_used": len(selected), "callbacks": callbacks, "frames": frames,
        "reported_interval_ms": sum(r["interval_us"] for r in selected) / 1000,
        "generated_audio_ms": audio_us / 1000,
        "mean_chunk_frames": frames / callbacks,
        "callback_work_to_generated_audio_ratio": totals[0] / audio_us,
        "phases": {name: {"total_ms": totals[i] / 1000,
                          "mean_callback_ms": totals[i] / callbacks / 1000,
                          "max_callback_ms": max(r["maxima_us"][i] for r in selected) / 1000}
                   for i, name in enumerate(PHASES)},
        "indicators": {name: sum(r[name] for r in selected) for name in
                       ("zero_queue_delay", "past_queue_delay", "gap_gt_previous_chunk")},
        "max_callback_gap_ms": max(r["gap_max_us"] for r in selected) / 1000,
        "min_queue_delay_ms": min(minima) / 1000 if minima else None,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--skip", type=int, default=1)
    args = parser.parse_args()
    print(json.dumps(summarize(args.log.read_text(), args.skip), indent=2, allow_nan=False))
