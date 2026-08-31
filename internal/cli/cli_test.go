package cli

import (
	"bytes"
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
	if got := stdout.String(); got != "upctl 0.0.1-dev\n" {
		t.Fatalf("unexpected version output %q", got)
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
