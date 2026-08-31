package cli

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

const version = "0.0.1-dev"

func Run(args []string, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		printUsage(stdout)
		return nil
	}

	switch args[0] {
	case "version":
		fmt.Fprintf(stdout, "upctl %s\n", version)
		return nil
	case "init":
		return runInit(args[1:], stdout, stderr)
	case "doctor":
		return runDoctor(args[1:], stdout, stderr)
	case "help", "-h", "--help":
		printUsage(stdout)
		return nil
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func printUsage(w io.Writer) {
	fmt.Fprintln(w, `upctl manages an UP installation.

Usage:
  upctl version
  upctl init [--path DIRECTORY]
  upctl doctor [--path DIRECTORY]

Commands planned for later increments: plan, apply, rollback, verify, support-bundle.`)
}

func runInit(args []string, stdout, stderr io.Writer) error {
	set := flag.NewFlagSet("init", flag.ContinueOnError)
	set.SetOutput(stderr)
	path := set.String("path", ".", "installation directory")
	if err := set.Parse(args); err != nil {
		return err
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
