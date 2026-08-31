package cli

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPermanentUPNamingContract(t *testing.T) {
	root := filepath.Clean(filepath.Join("..", ".."))
	required := []string{
		"up.toml",
		"up.lock.json",
		filepath.Join("cmd", "upctl", "main.go"),
		filepath.Join("resources", "[system]", "up_core", "fxmanifest.lua"),
	}
	for _, relative := range required {
		if _, err := os.Stat(filepath.Join(root, relative)); err != nil {
			t.Fatalf("required UP path %s: %v", relative, err)
		}
	}

	forbidden := []string{"city" + "core", "city" + "_core", "city" + "ctl"}
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			if entry.Name() == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(path) == ".exe" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		lower := strings.ToLower(string(data))
		for _, legacy := range forbidden {
			if strings.Contains(lower, legacy) {
				t.Errorf("legacy identifier %q remains in %s", legacy, path)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
