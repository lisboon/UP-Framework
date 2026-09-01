package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestVersion(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if err := Run([]string{"version"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := stdout.String(); got != "upctl 0.1.0-dev (commit unknown, built unknown)\n" {
		t.Fatalf("unexpected version output %q", got)
	}

	stdout.Reset()
	if err := Run([]string{"--version"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() alias error = %v", err)
	}
	if got := stdout.String(); got != "upctl 0.1.0-dev\n" {
		t.Fatalf("unexpected alias output %q", got)
	}
}

func TestVersionJSON(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if err := Run([]string{"version", "--json"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	var result struct {
		SchemaVersion int    `json:"schemaVersion"`
		Name          string `json:"name"`
		Version       string `json:"version"`
	}
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if result.SchemaVersion != 1 || result.Name != "upctl" || result.Version != Version {
		t.Fatalf("unexpected version report: %+v", result)
	}
}

func TestHelpAndUsageErrors(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if err := Run([]string{"help", "doctor"}, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(stdout.String(), "doctor [--path DIRECTORY] [--json]") {
		t.Fatalf("unexpected help: %q", stdout.String())
	}
	stdout.Reset()
	if err := Run([]string{"doctor", "--help"}, &stdout, &stderr); err != nil {
		t.Fatalf("command help should succeed: %v", err)
	}
	if !strings.Contains(stdout.String(), "doctor [--path DIRECTORY] [--json]") {
		t.Fatalf("unexpected flag help: %q", stdout.String())
	}
	if err := Run([]string{"plan"}, &stdout, &stderr); err == nil || ExitCode(err) != 2 {
		t.Fatalf("unknown command should use exit 2, got %v", err)
	}
}

func TestInitCreatesFilesAndRefusesOverwrite(t *testing.T) {
	dir := t.TempDir()
	var stdout, stderr bytes.Buffer

	if err := Run([]string{"init", "--path", dir}, &stdout, &stderr); err != nil {
		t.Fatalf("first init error = %v", err)
	}
	for _, name := range []string{"up.toml", "up.lock.json"} {
		if _, err := os.Stat(filepath.Join(dir, name)); err != nil {
			t.Fatalf("expected %s: %v", name, err)
		}
	}

	if err := Run([]string{"init", "--path", dir}, &stdout, &stderr); err == nil {
		t.Fatal("second init should refuse to overwrite")
	}
}

func TestInitDoesNotPartiallyWriteWhenTargetExists(t *testing.T) {
	dir := t.TempDir()
	lockPath := filepath.Join(dir, "up.lock.json")
	if err := os.WriteFile(lockPath, []byte("owned by operator"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	if err := Run([]string{"init", "--path", dir}, &stdout, &stderr); err == nil {
		t.Fatal("init should refuse an existing target")
	}
	if _, err := os.Stat(filepath.Join(dir, "up.toml")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("up.toml should not have been created: %v", err)
	}
}

func TestDoctorValidatesInitializedDirectory(t *testing.T) {
	dir := t.TempDir()
	var stdout, stderr bytes.Buffer
	if err := Run([]string{"init", "--path", dir}, &stdout, &stderr); err != nil {
		t.Fatalf("init error = %v", err)
	}

	stdout.Reset()
	err := Run([]string{"doctor", "--path", dir}, &stdout, &stderr)
	if err != nil && !strings.Contains(err.Error(), "doctor found") {
		t.Fatalf("unexpected doctor error = %v", err)
	}
	if !strings.Contains(stdout.String(), "[PASS] configuration") {
		t.Fatalf("missing config result in %q", stdout.String())
	}
	if !strings.Contains(stdout.String(), "[PASS] release lock") {
		t.Fatalf("missing lock result in %q", stdout.String())
	}
}

func TestDoctorRejectsMalformedConfig(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "up.toml"), []byte("broken"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "up.lock.json"), []byte(defaultLock), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	if err := Run([]string{"doctor", "--path", dir}, &stdout, &stderr); err == nil {
		t.Fatal("doctor should reject malformed config")
	}
	if !strings.Contains(stdout.String(), "[FAIL] configuration") {
		t.Fatalf("missing failed configuration check in %q", stdout.String())
	}
}

func TestDoctorJSONAndDevelopmentWarnings(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "path with spaces")
	var stdout, stderr bytes.Buffer
	if err := Run([]string{"init", "--path", dir}, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	stdout.Reset()
	if err := Run([]string{"doctor", "--path", dir, "--json"}, &stdout, &stderr); err != nil {
		t.Fatalf("development warning should not fail: %v", err)
	}
	var report doctorReport
	if err := json.Unmarshal(stdout.Bytes(), &report); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if !report.OK || report.SchemaVersion != 1 || report.Mode != "installation" || report.Summary.Warn < 1 {
		t.Fatalf("unexpected doctor report: %+v", report)
	}
}

func TestDoctorFailsMissingServerDataInRelease(t *testing.T) {
	dir := t.TempDir()
	config := strings.Replace(defaultConfig, `environment = "development"`, `environment = "production"`, 1)
	if err := os.WriteFile(filepath.Join(dir, "up.toml"), []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "up.lock.json"), []byte(defaultLock), 0o644); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	err := Run([]string{"doctor", "--path", dir, "--json"}, &stdout, &stderr)
	if err == nil || ExitCode(err) != 1 {
		t.Fatalf("release should fail with exit 1, got %v", err)
	}
	var report doctorReport
	if decodeErr := json.Unmarshal(stdout.Bytes(), &report); decodeErr != nil {
		t.Fatalf("failure must still emit valid JSON: %v", decodeErr)
	}
	if report.OK || report.Summary.Fail == 0 {
		t.Fatalf("unexpected doctor report: %+v", report)
	}
}

func TestRecipePinsWarnInDevelopmentAndFailInRelease(t *testing.T) {
	path := filepath.Join(t.TempDir(), "recipe.yaml")
	if err := os.WriteFile(path, []byte("tasks:\n  - ref: feat/up-foundation\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := checkRecipe(path, "workspace", false); got.Status != statusWarn {
		t.Fatalf("mutable development ref should warn: %+v", got)
	}
	if got := checkRecipe(path, "workspace", true); got.Status != statusFail {
		t.Fatalf("mutable release ref should fail: %+v", got)
	}
	if err := os.WriteFile(path, []byte("tasks:\n  - ref: 32d98e7524b952faf8b220d719615b0346b0a6cc\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := checkRecipe(path, "workspace", true); got.Status != statusPass {
		t.Fatalf("immutable release ref should pass: %+v", got)
	}
}

func TestConfigParserSupportsTOMLStringsAndSections(t *testing.T) {
	dir := t.TempDir()
	config := defaultConfig + `
description = "UP # Universo Paralelo"

[metadata]
tags = ["roleplay", "brasil"]
notes = """linha um
linha dois"""
`
	path := filepath.Join(dir, "up.toml")
	if err := os.WriteFile(path, []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	result := checkConfig(path)
	if !result.OK {
		t.Fatalf("valid TOML rejected: %s", result.Message)
	}
}
