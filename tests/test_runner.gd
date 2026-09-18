extends SceneTree
## Self-contained headless test runner — no GUT addon download needed.
## Usage (from repo root):
##   godot --headless --script tests/test_runner.gd
## Discovers tests/test_*.gd suites (excluding this runner), calls each suite's
## static run() -> {"passed": int, "failed": int}, prints per-suite PASS/FAIL
## plus a totals line, then quit()s with exit code 0 (all green) or 1.

const TESTS_DIR := "res://tests"
const RUNNER_FILE := "test_runner.gd"


func _init() -> void:
	var total_passed := 0
	var total_failed := 0
	var suites_run := 0
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		printerr("FAIL test_runner: cannot open ", TESTS_DIR, " (run from repo root).")
		quit(2)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("test_") and fname.ends_with(".gd") and fname != RUNNER_FILE:
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	if files.is_empty():
		printerr("FAIL test_runner: no test_*.gd suites found in ", TESTS_DIR)
		quit(2)
		return
	for f in files:
		var suite = load(TESTS_DIR + "/" + f)
		if suite == null:
			printerr("FAIL ", f, ": load() returned null")
			total_failed += 1
			continue
		var outcome: Variant = suite.run()
		if not (outcome is Dictionary):
			printerr("FAIL ", f, ": run() did not return a Dictionary")
			total_failed += 1
			continue
		var p := int((outcome as Dictionary).get("passed", 0))
		var fl := int((outcome as Dictionary).get("failed", 0))
		suites_run += 1
		total_passed += p
		total_failed += fl
		if fl == 0:
			print("PASS ", f, " (", p, " checks)")
		else:
			printerr("FAIL ", f, " (", p, " passed, ", fl, " failed)")
	print("----")
	print("Suites: ", suites_run, "  Checks passed: ", total_passed, "  failed: ", total_failed)
	if total_failed == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("TESTS FAILED")
		quit(1)
