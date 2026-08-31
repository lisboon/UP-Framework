package cli

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/pelletier/go-toml/v2"
)

type lockFile struct {
	SchemaVersion int    `json:"schemaVersion"`
	Release       string `json:"release"`
	Dependencies  []struct {
		Name    string `json:"name"`
		Version string `json:"version"`
		SHA256  string `json:"sha256"`
	} `json:"dependencies"`
}

type check struct {
	Name    string
	OK      bool
	Message string
}

type configFile struct {
	SchemaVersion   int    `toml:"schema_version"`
	Environment     string `toml:"environment"`
	ServerName      string `toml:"server_name"`
	ServerDataPath  string `toml:"server_data_path"`
	MySQLHost       string `toml:"mysql_host"`
	MySQLPort       int    `toml:"mysql_port"`
	MySQLDatabase   string `toml:"mysql_database"`
	FXServerTCPPort int    `toml:"fxserver_tcp_port"`
	FXServerUDPPort int    `toml:"fxserver_udp_port"`
	TxAdminPort     int    `toml:"txadmin_port"`
}

func runDoctor(args []string, stdout, stderr io.Writer) error {
	set := flag.NewFlagSet("doctor", flag.ContinueOnError)
	set.SetOutput(stderr)
	path := set.String("path", ".", "installation directory")
	if err := set.Parse(args); err != nil {
		return err
	}

	abs, err := filepath.Abs(*path)
	if err != nil {
		return fmt.Errorf("resolve path: %w", err)
	}

	checks := []check{
		checkConfig(filepath.Join(abs, "up.toml")),
		checkLock(filepath.Join(abs, "up.lock.json")),
		checkCommand("git"),
		checkCommand("docker"),
	}

	failed := false
	for _, result := range checks {
		status := "PASS"
		if !result.OK {
			status = "FAIL"
			failed = true
		}
		fmt.Fprintf(stdout, "[%s] %s: %s\n", status, result.Name, result.Message)
	}

	if failed {
		return fmt.Errorf("doctor found one or more blocking problems")
	}
	return nil
}

func checkConfig(path string) check {
	data, err := os.ReadFile(path)
	if err != nil {
		return check{"configuration", false, err.Error()}
	}

	var config configFile
	if err := toml.Unmarshal(data, &config); err != nil {
		return check{"configuration", false, err.Error()}
	}

	required := []struct {
		name  string
		value string
	}{
		{"environment", config.Environment},
		{"server_name", config.ServerName},
		{"server_data_path", config.ServerDataPath},
		{"mysql_host", config.MySQLHost},
		{"mysql_database", config.MySQLDatabase},
	}
	for _, field := range required {
		if field.value == "" {
			return check{"configuration", false, "missing " + field.name}
		}
	}

	if config.SchemaVersion != 1 {
		return check{"configuration", false, "unsupported schema_version"}
	}
	ports := []struct {
		name  string
		value int
	}{
		{"mysql_port", config.MySQLPort},
		{"fxserver_tcp_port", config.FXServerTCPPort},
		{"fxserver_udp_port", config.FXServerUDPPort},
		{"txadmin_port", config.TxAdminPort},
	}
	for _, port := range ports {
		if port.value < 1 || port.value > 65535 {
			return check{"configuration", false, "invalid " + port.name}
		}
	}

	return check{"configuration", true, "schema v1 is valid"}
}

func checkLock(path string) check {
	data, err := os.ReadFile(path)
	if err != nil {
		return check{"release lock", false, err.Error()}
	}

	var lock lockFile
	if err := json.Unmarshal(data, &lock); err != nil {
		return check{"release lock", false, err.Error()}
	}
	if lock.SchemaVersion != 1 || lock.Release == "" {
		return check{"release lock", false, "unsupported or incomplete lockfile"}
	}

	for _, dependency := range lock.Dependencies {
		if dependency.Name == "" || dependency.Version == "" || len(dependency.SHA256) != 64 {
			return check{"release lock", false, "dependency is not immutably pinned"}
		}
	}
	return check{"release lock", true, fmt.Sprintf("release %s, %d dependencies", lock.Release, len(lock.Dependencies))}
}

func checkCommand(name string) check {
	path, err := exec.LookPath(name)
	if err != nil {
		return check{name, false, "not found on PATH"}
	}
	return check{name, true, path}
}
