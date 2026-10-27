#!/usr/bin/env python3
"""Offline G-A contract oracle; NOT the Swift implementation or a sensor test.

No dependencies, I/O only in CLI. JSON vectors carry literal expected results.
See CONTRACT.md for units, proposals and intentionally untested integration.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import sys
import uuid


class ContractError(ValueError):
    pass


def number(value, low, high):
    if type(value) not in (int, float) or not low <= value <= high:
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return False


def integer(value, low=0):
    return type(value) is int and low <= value <= 2**63 - 1


class BodyChannel:
    """One already-normalized metric; each real metric owns an independent instance."""

    def __init__(self, max_age_ms=2000, min_quality=0.7):
        if not integer(max_age_ms, 1) or not number(min_quality, 0, 1):
            raise ContractError("policy")
        self.max_age = max_age_ms
        self.min_quality = min_quality
        self.now = 0
        self.source = None
        self.epoch = 0
        self.enabled = False
        self.permission = "unknown"
        self.suspended = False
        self.state = "off"
        self.value = None
        self.captured = None
        self.sequence = -1
        self.last_captured = -1

    def invalidate(self):
        self.epoch += 1
        self.sequence = -1
        self.last_captured = -1
        self.value = None
        self.captured = None

    def availability(self):
        if not self.enabled:
            return "off"
        if self.suspended:
            return "suspended"
        if self.permission == "denied":
            return "denied"
        return "waiting"

    def step(self, event):
        if type(event) is not dict:
            raise ContractError("event")
        now = event.get("now_ms")
        if not integer(now) or now < self.now:
            raise ContractError("clock")
        kind = event.get("kind")
        if kind not in {"start", "stop", "permission", "suspend", "resume", "sample", "tick"}:
            raise ContractError("event")
        if kind in {"start", "permission"}:
            if event.get("permission") not in {"granted", "denied", "unknown"}:
                raise ContractError("permission")
        if kind == "start" and event.get("source") not in {"camera", "ble", "health"}:
            raise ContractError("source")
        self.now = now
        result = "accepted"
        if kind == "start":
            self.invalidate()
            self.enabled = True
            self.source = event["source"]
            self.permission = event["permission"]
            # Suspension is an owner state, not bypassed by selecting another source.
            self.state = self.availability()
        elif kind == "permission" and (
                event.get("source") != self.source
                or type(event.get("epoch")) is not int or event["epoch"] != self.epoch):
            result = "ignored_generation"
        elif kind in {"stop", "permission", "suspend", "resume"}:
            self.invalidate()
            if kind == "stop":
                self.enabled = False
            elif kind == "permission":
                self.permission = event["permission"]
            else:
                self.suspended = kind == "suspend"
            self.state = self.availability()
        elif kind == "sample":
            if (not self.enabled or self.suspended or self.permission == "denied"
                    or (self.permission != "granted" and self.source != "health")):
                result = "ignored_inactive"
            elif (event.get("source") != self.source
                  or type(event.get("epoch")) is not int or event["epoch"] != self.epoch):
                result = "ignored_generation"
            elif (not integer(event.get("sequence"))
                  or not integer(event.get("captured_ms"))):
                self.value = self.captured = None
                self.state = "invalid"
                result = "invalid"
            elif (event["sequence"] <= self.sequence
                  or event["captured_ms"] <= self.last_captured):
                result = "ignored_order"
            elif event["captured_ms"] > now:
                self.value = self.captured = None
                self.state = "invalid"
                result = "invalid"
            else:
                self.sequence = event["sequence"]
                self.last_captured = event["captured_ms"]
                value = event.get("value")
                quality = event.get("quality")
                if (not number(value, 0, 1) or not number(quality, 0, 1)
                        or quality < self.min_quality):
                    self.value = self.captured = None
                    self.state = "invalid"
                    result = "invalid"
                elif now - event["captured_ms"] > self.max_age:
                    self.value = self.captured = None
                    self.state = "stale"
                    result = "stale"
                else:
                    self.value, self.captured = value, event["captured_ms"]
                    self.state = "valid"
        if self.state == "valid" and now - self.captured > self.max_age:
            self.value = self.captured = None
            self.state = "stale"
        return {"state": self.state, "epoch": self.epoch,
                "value": self.value, "result": result}


def validate_routes(routes, targets, limit=64):
    """targets is supplied by the production registry adapter, never guessed here."""
    if not integer(limit, 1) or type(routes) is not list or len(routes) > limit:
        raise ContractError("route_limit")
    ids = set()
    for route in routes:
        if type(route) is not dict:
            raise ContractError("route")
        try:
            identifier = str(uuid.UUID(route["id"]))
        except (KeyError, TypeError, ValueError, AttributeError):
            raise ContractError("route_id") from None
        if identifier in ids:
            raise ContractError("duplicate_id")
        ids.add(identifier)
        if route.get("target") not in targets:
            raise ContractError("target")
        if route.get("source") not in {"body.heartRate", "body.hrv", "body.coherence",
                                       "body.breath", "lfo.1", "macro.1", "midi.cc.1"}:
            raise ContractError("source")
        if not number(route.get("depth"), -1, 1):
            raise ContractError("depth")
        if route.get("curve") not in {"linear", "square"}:
            raise ContractError("curve")
        if route.get("polarity") not in {"unipolar", "bipolar"}:
            raise ContractError("polarity")
        if type(route.get("enabled")) is not bool:
            raise ContractError("enabled")
    return sorted(routes, key=lambda r: str(uuid.UUID(r["id"])))


def modulation(base, routes, sources, target, targets, automation=None):
    if type(sources) is not dict or type(targets) is not list or type(target) is not str:
        raise ContractError("routing_input")
    if target not in targets:
        raise ContractError("target")
    if not number(base, 0, 1) or (automation is not None and not number(automation, 0, 1)):
        raise ContractError("base")
    ordered = validate_routes(routes, targets)
    value = base if automation is None else automation
    for route in ordered:
        source = sources.get(route["source"])
        if not route["enabled"] or route["target"] != target or not number(source, 0, 1):
            continue
        position = source if route["polarity"] == "unipolar" else 2 * source - 1
        curved = position if route["curve"] == "linear" else position * abs(position)
        value += route["depth"] * curved
    return min(1.0, max(0.0, value))


def migrate_envelope(document):
    """Models ONLY version + modRoutes insertion; not ProjectCodec or v1 address migration."""
    if type(document) is not dict:
        raise ContractError("document")
    version = document.get("formatVersion")
    if type(version) is not int or version < 1:
        raise ContractError("format")
    if version > 3:
        raise ContractError("newer_format")
    result = copy.deepcopy(document)
    if version < 3:
        if "modRoutes" in result:
            raise ContractError("legacy_routes")
        result["modRoutes"] = []
    elif type(result.get("modRoutes")) is not list:
        raise ContractError("missing_routes")
    result["formatVersion"] = 3
    return result


def ramp(start, target, duration, count, blocks):
    if (not number(start, 0, 1) or not number(target, 0, 1)
            or not integer(duration, 1) or not integer(count, 1)
            or not blocks or not all(integer(n, 1) for n in blocks)):
        raise ContractError("ramp")
    output = []
    offset = 0
    block = 0
    while offset < count:
        length = min(blocks[block % len(blocks)], count - offset)
        for index in range(offset, offset + length):
            output.append(start + (target - start) * min(index / duration, 1))
        offset += length
        block += 1
    return output


def close(actual, expected):
    if type(expected) is float:
        return type(actual) in (int, float) and math.isclose(actual, expected, abs_tol=1e-12, rel_tol=1e-12)
    if type(expected) is list:
        return type(actual) is list and len(actual) == len(expected) and all(map(lambda pair: close(*pair), zip(actual, expected)))
    if type(expected) is dict:
        return type(actual) is dict and actual.keys() == expected.keys() and all(close(actual[k], expected[k]) for k in expected)
    return type(actual) is type(expected) and actual == expected


def run_vectors(fixtures):
    results = []
    seen = set()
    for group in ("state", "modulation", "migration", "ramp"):
        cases = fixtures.get(group)
        if type(cases) is not list or not cases:
            raise ContractError("empty_fixture_group")
        for case in cases:
            if (type(case) is not dict or type(case.get("id")) is not str
                    or not case["id"] or "expected" not in case):
                raise ContractError("fixture_case")
            identifier = case["id"]
            if identifier in seen:
                raise ContractError("duplicate_case_id")
            seen.add(identifier)
            try:
                if group == "state":
                    model = BodyChannel(**case.get("policy", {}))
                    actual = [model.step(event) for event in case["events"]]
                elif group == "modulation":
                    actual = modulation(**case["input"])
                elif group == "migration":
                    original = copy.deepcopy(case["input"])
                    actual = migrate_envelope(case["input"])
                    if original != case["input"]:
                        raise AssertionError("input mutated")
                else:
                    actual = ramp(**case["input"])
            except ContractError as error:
                actual = {"error": str(error)}
            passed = close(actual, case["expected"])
            results.append({"id": identifier, "passed": passed,
                            **({} if passed else {"expected": case["expected"], "actual": actual})})
    return results


def negative_controls(fixtures):
    """Corrupt explicit expectations; each must produce a failed vector, never a green run."""
    results = []
    for group in ("state", "modulation", "migration", "ramp"):
        broken = copy.deepcopy(fixtures)
        broken[group][0]["expected"] = {"deliberately_wrong": True}
        results.append({"id": "wrong_expected_" + group,
                        "passed": not all(r["passed"] for r in run_vectors(broken))})
    return results


def properties():
    template = {"id": str(uuid.UUID(int=1)), "source": "body.heartRate",
                "target": "master/mixer.pan", "depth": 0.2, "curve": "linear",
                "polarity": "unipolar", "enabled": True}
    route_input = {"base": 0.5, "routes": [template, dict(template, id=str(uuid.UUID(int=2)), depth=-0.1)],
                   "sources": {"body.heartRate": 0.75}, "target": template["target"],
                   "targets": [template["target"]]}
    baseline = modulation(**route_input)
    route_input["routes"].reverse()
    checks = [{"id": "route_order", "passed": close(modulation(**route_input), baseline)}]
    a = ramp(0.8, 0.2, 480, 1025, [1])
    b = ramp(0.8, 0.2, 480, 1025, [127, 64, 256])
    checks.append({"id": "block_partition", "passed": a == b and close(a[480], 0.2)})
    for special in (float("nan"), float("inf"), float("-inf")):
        model = BodyChannel()
        model.step({"kind": "start", "now_ms": 0, "source": "camera", "permission": "granted"})
        result = model.step({"kind": "sample", "now_ms": 1, "source": "camera", "epoch": 1,
                             "sequence": 1, "captured_ms": 1, "value": special, "quality": 1})
        checks.append({"id": "nonfinite_sample_" + str(special),
                       "passed": result["state"] == "invalid" and result["value"] is None})
    # Capacity boundary uses independent, canonical UUIDs and the validator's public limit.
    routes = [dict(template, id=str(uuid.UUID(int=i + 1))) for i in range(64)]
    accepted = len(validate_routes(routes, [template["target"]])) == 64
    rejected = False
    try:
        validate_routes(routes + [dict(template, id=str(uuid.UUID(int=65)))], [template["target"]])
    except ContractError as error:
        rejected = str(error) == "route_limit"
    checks.append({"id": "capacity_64_65", "passed": accepted and rejected})
    checks.append({"id": "huge_integer_is_invalid", "passed": not number(10**400, 0, 1)})
    return checks


def reject_constant(value):
    raise ContractError("nonstandard_json_" + value)


def finite_json_float(value):
    result = float(value)
    if not math.isfinite(result):
        raise ContractError("unrepresentable_json_number")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--fixtures", type=Path, default=Path(__file__).with_name("FIXTURES.json"))
    parser.add_argument("--json", action="store_true", help="structured result on stdout")
    args = parser.parse_args()
    try:
        fixtures = json.loads(args.fixtures.read_text(), parse_constant=reject_constant,
                              parse_float=finite_json_float)
        if type(fixtures) is not dict or fixtures.get("schema") != "echoel.g-a.reference.v1":
            raise ContractError("fixture_schema")
        results = run_vectors(fixtures)
        if args.selftest:
            results += properties() + negative_controls(fixtures)
    except (OSError, ValueError, TypeError, KeyError) as error:
        sys.stderr.write(f"Invalid reference input: {error}\n")
        return 2
    failed = [r for r in results if not r["passed"]]
    report = {"scope": "python_contract_reference_only", "total": len(results),
              "passed": len(results) - len(failed), "failed": len(failed), "results": results}
    sys.stdout.write(json.dumps(report, indent=2, allow_nan=False) + "\n" if args.json else
                     f"G-A reference: {report['passed']}/{report['total']} passed; Swift/device NOT_RUN\n")
    if failed and not args.json:
        sys.stderr.write(json.dumps(failed, indent=2) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
