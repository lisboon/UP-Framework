package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDeploymentContract(t *testing.T) {
	root := filepath.Clean(filepath.Join("..", ".."))
	assertContains := func(relative string, expected ...string) {
		t.Helper()
		data, err := os.ReadFile(filepath.Join(root, relative))
		if err != nil {
			t.Fatalf("read %s: %v", relative, err)
		}
		for _, value := range expected {
			if !strings.Contains(string(data), value) {
				t.Errorf("%s must contain %q", relative, value)
			}
		}
	}

	assertContains("server.cfg", "{{serverEndpoints}}", "{{svLicense}}", "{{dbConnectionString}}", "{{addPrincipalsMaster}}", "exec common.cfg")
	assertContains("server.local.cfg.example", "endpoint_add_tcp", "identifier.fivem:replace-me", "exec common.cfg")
	assertContains("common.cfg", "ensure oxmysql", "ensure [up]", "ensure [up-scripts]", "exec permissions.cfg")
	assertContains("recipe.yaml", "$engine: 3", "connect_database", "query_database", "resources/[up]", "resources/[up-scripts]")
	assertContains("recipe.yaml", "0001_core.sql", "0002_character_lifecycle.sql")
}
