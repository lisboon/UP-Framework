package cli

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/pelletier/go-toml/v2"
)

const (
	statusPass = "pass"
	statusWarn = "warn"
	statusFail = "fail"
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
	ID      string `json:"id"`
	Name    string `json:"name"`
	Status  string `json:"status"`
	Message string `json:"message"`
	OK      bool   `json:"-"`
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

type doctorSummary struct {
	Pass int `json:"pass"`
	Warn int `json:"warn"`
	Fail int `json:"fail"`
}

type doctorReport struct {
	SchemaVersion int           `json:"schemaVersion"`
	OK            bool          `json:"ok"`
	Path          string        `json:"path"`
	Mode          string        `json:"mode"`
	Checks        []check       `json:"checks"`
	Summary       doctorSummary `json:"summary"`
}

func runDoctor(args []string, stdout, stderr io.Writer) error {
	set := flag.NewFlagSet("doctor", flag.ContinueOnError)
	set.SetOutput(stderr)
	path := set.String("path", ".", "UP workspace or installation directory")
	asJSON := set.Bool("json", false, "emit JSON schema v1")
	if err := set.Parse(args); err != nil {
		return usageError(err)
	}
	if set.NArg() != 0 {
		return usageError(errors.New("doctor does not accept positional arguments"))
	}

	abs, err := filepath.Abs(*path)
	if err != nil {
		return fmt.Errorf("resolve path: %w", err)
	}

	config, configResult := loadConfig(filepath.Join(abs, "up.toml"))
	release := isReleaseEnvironment(config.Environment)
	mode := detectMode(abs)
	checks := []check{
		configResult,
		checkLock(filepath.Join(abs, "up.lock.json")),
		checkSourceLayout(abs, mode),
		checkServerData(abs, config.ServerDataPath, release),
		checkRecipe(filepath.Join(abs, "recipe.yaml"), mode, release),
		checkCommand("git"),
		checkCommand("docker"),
	}

	report := doctorReport{SchemaVersion: 1, OK: true, Path: abs, Mode: mode, Checks: checks}
	for _, result := range checks {
		switch result.Status {
		case statusPass:
			report.Summary.Pass++
		case statusWarn:
			report.Summary.Warn++
		case statusFail:
			report.Summary.Fail++
			report.OK = false
		}
	}

	if *asJSON {
		if err := json.NewEncoder(stdout).Encode(report); err != nil {
			return fmt.Errorf("encode doctor report: %w", err)
		}
	} else {
		fmt.Fprintf(stdout, "UP Doctor\nPath: %s\nMode: %s\n\n", report.Path, report.Mode)
		for _, result := range report.Checks {
			fmt.Fprintf(stdout, "[%s] %s: %s\n", strings.ToUpper(result.Status), result.Name, result.Message)
		}
		fmt.Fprintf(stdout, "\nSummary: %d passed, %d warnings, %d failed\n", report.Summary.Pass, report.Summary.Warn, report.Summary.Fail)
	}

	if !report.OK {
		return &ExitError{Code: 1, Err: errors.New("doctor found one or more blocking problems")}
	}
	return nil
}

func makeCheck(id, name, status, message string) check {
	return check{ID: id, Name: name, Status: status, Message: message, OK: status != statusFail}
}

func loadConfig(path string) (configFile, check) {
	var config configFile
	data, err := os.ReadFile(path)
	if err != nil {
		return config, makeCheck("configuration", "configuration", statusFail, err.Error())
	}
	if err := toml.Unmarshal(data, &config); err != nil {
		return config, makeCheck("configuration", "configuration", statusFail, err.Error())
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
			return config, makeCheck("configuration", "configuration", statusFail, "missing "+field.name)
		}
	}
	if config.SchemaVersion != 1 {
		return config, makeCheck("configuration", "configuration", statusFail, "unsupported schema_version")
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
			return config, makeCheck("configuration", "configuration", statusFail, "invalid "+port.name)
		}
	}
	return config, makeCheck("configuration", "configuration", statusPass, "schema v1 is valid")
}

func checkConfig(path string) check {
	_, result := loadConfig(path)
	return result
}

func checkLock(path string) check {
	data, err := os.ReadFile(path)
	if err != nil {
		return makeCheck("release-lock", "release lock", statusFail, err.Error())
	}
	var lock lockFile
	if err := json.Unmarshal(data, &lock); err != nil {
		return makeCheck("release-lock", "release lock", statusFail, err.Error())
	}
	if lock.SchemaVersion != 1 || lock.Release == "" {
		return makeCheck("release-lock", "release lock", statusFail, "unsupported or incomplete lockfile")
	}
	for _, dependency := range lock.Dependencies {
		if dependency.Name == "" || dependency.Version == "" || len(dependency.SHA256) != 64 {
			return makeCheck("release-lock", "release lock", statusFail, "dependency is not immutably pinned")
		}
	}
	return makeCheck("release-lock", "release lock", statusPass, fmt.Sprintf("release %s, %d dependencies", lock.Release, len(lock.Dependencies)))
}

func detectMode(root string) string {
	if exists(filepath.Join(root, "go.mod")) && exists(filepath.Join(root, "recipe.yaml")) {
		return "workspace"
	}
	return "installation"
}

func checkSourceLayout(root, mode string) check {
	if mode != "workspace" {
		return makeCheck("source-layout", "source layout", statusPass, "installation mode; source layout is not required")
	}
	required := []string{
		filepath.Join("resources", "[up]", "up_core", "fxmanifest.lua"),
		filepath.Join("resources", "[up]", "up_entry", "fxmanifest.lua"),
		filepath.Join("database", "migrations", "0001_core.sql"),
		filepath.Join("database", "migrations", "0002_character_lifecycle.sql"),
	}
	for _, relative := range required {
		if !exists(filepath.Join(root, relative)) {
			return makeCheck("source-layout", "source layout", statusFail, "missing "+relative)
		}
	}
	return makeCheck("source-layout", "source layout", statusPass, "core manifests and migrations are present")
}

func checkServerData(root, configuredPath string, release bool) check {
	if configuredPath == "" {
		return makeCheck("server-data", "server data", statusFail, "server_data_path is not configured")
	}
	resolved := configuredPath
	if !filepath.IsAbs(resolved) {
		resolved = filepath.Join(root, resolved)
	}
	resolved = filepath.Clean(resolved)
	if exists(resolved) {
		return makeCheck("server-data", "server data", statusPass, resolved)
	}
	status := statusWarn
	if release {
		status = statusFail
	}
	return makeCheck("server-data", "server data", status, "not found: "+resolved)
}

var immutableRef = regexp.MustCompile(`^(?:[0-9a-fA-F]{40}|v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$`)

func checkRecipe(path, mode string, release bool) check {
	if mode != "workspace" {
		return makeCheck("recipe-pins", "recipe pins", statusPass, "installation mode; recipe is not required")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return makeCheck("recipe-pins", "recipe pins", statusFail, err.Error())
	}
	mutable := make([]string, 0)
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		line = strings.TrimPrefix(line, "- ")
		if !strings.HasPrefix(line, "ref:") {
			continue
		}
		ref := strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "ref:")), `"'`)
		if !immutableRef.MatchString(ref) {
			mutable = append(mutable, ref)
		}
	}
	if len(mutable) == 0 {
		return makeCheck("recipe-pins", "recipe pins", statusPass, "all refs are immutable")
	}
	status := statusWarn
	if release {
		status = statusFail
	}
	return makeCheck("recipe-pins", "recipe pins", status, "mutable refs: "+strings.Join(mutable, ", "))
}

func checkCommand(name string) check {
	path, err := exec.LookPath(name)
	if err != nil {
		return makeCheck("command-"+name, name, statusWarn, "not found on PATH")
	}
	return makeCheck("command-"+name, name, statusPass, path)
}

func isReleaseEnvironment(environment string) bool {
	switch strings.ToLower(strings.TrimSpace(environment)) {
	case "release", "production":
		return true
	default:
		return false
	}
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
