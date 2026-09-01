package cli

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

var (
	Version   = "0.1.0-dev"
	Commit    = "unknown"
	BuildDate = "unknown"
)

type ExitError struct {
	Code int
	Err  error
}

func (e *ExitError) Error() string { return e.Err.Error() }
func (e *ExitError) Unwrap() error { return e.Err }

func ExitCode(err error) int {
	var exitErr *ExitError
	if errors.As(err, &exitErr) {
		return exitErr.Code
	}
	return 1
}

func usageError(err error) error { return &ExitError{Code: 2, Err: err} }

func Run(args []string, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		printUsage(stdout)
		return nil
	}

	switch args[0] {
	case "version":
		if wantsCommandHelp(args[1:]) {
			return printCommandUsage("version", stdout)
		}
		return runVersion(args[1:], stdout, stderr)
	case "--version":
		if len(args) != 1 {
			return usageError(errors.New("--version does not accept arguments"))
		}
		fmt.Fprintf(stdout, "upctl %s\n", Version)
		return nil
	case "init":
		if wantsCommandHelp(args[1:]) {
			return printCommandUsage("init", stdout)
		}
		return runInit(args[1:], stdout, stderr)
	case "doctor":
		if wantsCommandHelp(args[1:]) {
			return printCommandUsage("doctor", stdout)
		}
		return runDoctor(args[1:], stdout, stderr)
	case "help", "-h", "--help":
		if len(args) > 2 {
			return usageError(errors.New("help accepts at most one command"))
		}
		if len(args) == 2 {
			return printCommandUsage(args[1], stdout)
		}
		printUsage(stdout)
		return nil
	default:
		return usageError(fmt.Errorf("unknown command %q; run 'upctl help'", args[0]))
	}
}

func printUsage(w io.Writer) {
	fmt.Fprintln(w, `upctl manages an UP installation.

Usage:
  upctl version [--json]
  upctl --version
  upctl init [--path DIRECTORY]
	upctl doctor [--path DIRECTORY] [--json]
	upctl help [COMMAND]

Commands:
  version  Print version and build metadata
  init     Create a new UP configuration without overwriting files
  doctor   Diagnose an UP workspace or installation`)
}

func wantsCommandHelp(args []string) bool {
	return len(args) == 1 && (args[0] == "-h" || args[0] == "--help")
}

func printCommandUsage(command string, w io.Writer) error {
	switch command {
	case "version":
		fmt.Fprintln(w, "Usage: upctl version [--json]")
	case "init":
		fmt.Fprintln(w, "Usage: upctl init [--path DIRECTORY]")
	case "doctor":
		fmt.Fprintln(w, "Usage: upctl doctor [--path DIRECTORY] [--json]")
	default:
		return usageError(fmt.Errorf("unknown help topic %q", command))
	}
	return nil
}

func runVersion(args []string, stdout, stderr io.Writer) error {
	set := flag.NewFlagSet("version", flag.ContinueOnError)
	set.SetOutput(stderr)
	asJSON := set.Bool("json", false, "emit JSON schema v1")
	if err := set.Parse(args); err != nil {
		return usageError(err)
	}
	if set.NArg() != 0 {
		return usageError(errors.New("version does not accept positional arguments"))
	}
	if *asJSON {
		return json.NewEncoder(stdout).Encode(struct {
			SchemaVersion int    `json:"schemaVersion"`
			Name          string `json:"name"`
			Version       string `json:"version"`
			Commit        string `json:"commit"`
			BuildDate     string `json:"buildDate"`
		}{1, "upctl", Version, Commit, BuildDate})
	}
	fmt.Fprintf(stdout, "upctl %s (commit %s, built %s)\n", Version, Commit, BuildDate)
	return nil
}

func runInit(args []string, stdout, stderr io.Writer) error {
	set := flag.NewFlagSet("init", flag.ContinueOnError)
	set.SetOutput(stderr)
	path := set.String("path", ".", "installation directory")
	if err := set.Parse(args); err != nil {
		return usageError(err)
	}
	if set.NArg() != 0 {
		return usageError(errors.New("init does not accept positional arguments"))
	}

	abs, err := filepath.Abs(*path)
	if err != nil {
		return fmt.Errorf("resolve path: %w", err)
	}
	if err := os.MkdirAll(abs, 0o755); err != nil {
		return fmt.Errorf("create directory: %w", err)
	}

	created := make([]string, 0, 2)
	files := []struct {
		name    string
		content string
	}{
		{"up.toml", defaultConfig},
		{"up.lock.json", defaultLock},
	}

	for _, file := range files {
		target := filepath.Join(abs, file.name)
		if _, err := os.Stat(target); err == nil {
			return fmt.Errorf("refusing to overwrite %s", target)
		} else if !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("inspect %s: %w", target, err)
		}
	}

	for _, file := range files {
		target := filepath.Join(abs, file.name)
		if err := writeExclusive(target, []byte(file.content)); err != nil {
			for _, createdTarget := range created {
				_ = os.Remove(createdTarget)
			}
			return err
		}
		created = append(created, target)
	}

	for _, target := range created {
		fmt.Fprintln(stdout, "created", target)
	}
	return nil
}

func writeExclusive(path string, content []byte) error {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if errors.Is(err, os.ErrExist) {
		return fmt.Errorf("refusing to overwrite %s", path)
	}
	if err != nil {
		return fmt.Errorf("create %s: %w", path, err)
	}

	_, writeErr := file.Write(content)
	closeErr := file.Close()
	if writeErr != nil {
		return fmt.Errorf("write %s: %w", path, writeErr)
	}
	if closeErr != nil {
		return fmt.Errorf("close %s: %w", path, closeErr)
	}
	return nil
}

const defaultConfig = `schema_version = 1
environment = "development"
server_name = "UP Development"
server_data_path = "./server-data"
mysql_host = "127.0.0.1"
mysql_port = 3307
mysql_database = "up"
fxserver_tcp_port = 30120
fxserver_udp_port = 30120
txadmin_port = 40120
`

const defaultLock = `{
  "schemaVersion": 1,
  "release": "0.1.0-dev",
  "dependencies": []
}
`
