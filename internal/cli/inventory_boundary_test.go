package cli

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFirstPartyInventoryProviderBoundary(t *testing.T) {
	root := filepath.Clean(filepath.Join("..", ".."))
	firstPartyRoots := []string{
		filepath.Join(root, "resources", "[up]"),
		filepath.Join(root, "resources", "[up-scripts]"),
	}
	executableExtensions := map[string]bool{
		".js":  true,
		".jsx": true,
		".lua": true,
		".mjs": true,
		".ts":  true,
		".tsx": true,
	}

	for _, firstPartyRoot := range firstPartyRoots {
		err := filepath.WalkDir(firstPartyRoot, func(path string, entry fs.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() || !executableExtensions[strings.ToLower(filepath.Ext(path))] {
				return nil
			}

			data, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			if strings.Contains(strings.ToLower(string(data)), "ox_inventory") {
				relative, relErr := filepath.Rel(root, path)
				if relErr != nil {
					relative = path
				}
				t.Errorf("first-party executable source %s must depend on up_inventory, never ox_inventory", relative)
			}
			return nil
		})
		if err != nil {
			t.Fatalf("scan first-party inventory boundary: %v", err)
		}
	}
}

func TestInventoryProviderBaselineIsPinnedInSBOM(t *testing.T) {
	root := filepath.Clean(filepath.Join("..", ".."))
	data, err := os.ReadFile(filepath.Join(root, "sbom", "dependencies.json"))
	if err != nil {
		t.Fatal(err)
	}

	var document struct {
		Allowlist []struct {
			Name                string `json:"name"`
			License             string `json:"license"`
			Version             string `json:"version"`
			Commit              string `json:"commit"`
			SHA256              string `json:"sha256"`
			Release             string `json:"release"`
			Artifact            string `json:"artifact"`
			Bundled             bool   `json:"bundled"`
			RepositoryBoundary  string `json:"repositoryBoundary"`
			LegalReviewRequired bool   `json:"legalReviewRequired"`
		} `json:"allowlist"`
	}
	if err := json.Unmarshal(data, &document); err != nil {
		t.Fatalf("decode SBOM: %v", err)
	}

	found := map[string]bool{}
	for _, dependency := range document.Allowlist {
		switch dependency.Name {
		case "ox_lib":
			found[dependency.Name] = true
			if dependency.License != "LGPL-3.0" || dependency.Version != "3.39.0" ||
				dependency.Commit != "08bac37f3b56d4c3c56d6a0b3749ec3d527de9d6" ||
				dependency.SHA256 != "1df6724dfc1d2d287299ff023a29c9e999eb77832cb918a4f1761d5c18a54501" ||
				dependency.Release != "https://github.com/overextended/ox_lib/releases/tag/v3.39.0" ||
				dependency.Artifact != "https://github.com/overextended/ox_lib/releases/download/v3.39.0/ox_lib.zip" || dependency.Bundled {
				t.Errorf("ox_lib baseline differs from ADR-0001: %+v", dependency)
			}
		case "ox_inventory":
			found[dependency.Name] = true
			if dependency.License != "GPL-3.0-or-later" || dependency.Version != "2.47.9" ||
				dependency.Commit != "952c128fdff056fd7506d924faa6c07fb80892e9" ||
				dependency.SHA256 != "c072acd028cd8f75f3fab1a594e85c620a4c77cfb5db77a4ea64bcdefd362ae1" ||
				dependency.Release != "https://github.com/overextended/ox_inventory/releases/tag/v2.47.9" ||
				dependency.Artifact != "https://github.com/overextended/ox_inventory/releases/download/v2.47.9/ox_inventory.zip" || dependency.Bundled {
				t.Errorf("ox_inventory baseline differs from ADR-0001: %+v", dependency)
			}
			if dependency.RepositoryBoundary != "separate-gpl-provider" || !dependency.LegalReviewRequired {
				t.Error("ox_inventory must retain the separate GPL and legal-review gates")
			}
		}
	}

	for _, name := range []string{"ox_lib", "ox_inventory"} {
		if !found[name] {
			t.Errorf("%s is missing from the SBOM", name)
		}
	}
}
