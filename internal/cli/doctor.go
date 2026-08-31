package cli

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
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
	file, err := os.Open(path)
	if err != nil {
		return check{"configuration", false, err.Error()}
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			return check{"configuration", false, "invalid TOML assignment: " + line}
		}
		values[strings.TrimSpace(parts[0])] = strings.Trim(strings.TrimSpace(parts[1]), `"`)
	}
	if err := scanner.Err(); err != nil {
		return check{"configuration", false, err.Error()}
	}

	required := []string{
		"schema_version", "environment", "server_name", "server_data_path",
		"mysql_host", "mysql_port", "mysql_database",
		"fxserver_tcp_port", "fxserver_udp_port", "txadmin_port",
	}
	for _, key := range required {
		if values[key] == "" {
			return check{"configuration", false, "missing " + key}
		}
	}

	if values["schema_version"] != "1" {
		return check{"configuration", false, "unsupported schema_version"}
	}
	for _, key := range []string{"mysql_port", "fxserver_tcp_port", "fxserver_udp_port", "txadmin_port"} {
		port, err := strconv.Atoi(values[key])
		if err != nil || port < 1 || port > 65535 {
			return check{"configuration", false, "invalid " + key}
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
