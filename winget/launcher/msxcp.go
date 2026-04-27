// MSXCP portable launcher
//
// Winget's portable installer type requires a real PE executable as the
// aliased entry point. This tiny launcher is shipped alongside msxcp.cmd /
// msxcp.ps1 inside the release zip. It just delegates to msxcp.cmd so all
// real logic stays in PowerShell (see ../../msxcp.ps1).
package main

import (
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	exe, err := os.Executable()
	if err != nil {
		os.Exit(1)
	}
	root := filepath.Dir(exe)
	cmdPath := filepath.Join(root, "msxcp.cmd")

	comspec := os.Getenv("ComSpec")
	if comspec == "" {
		comspec = "cmd.exe"
	}
	args := append([]string{"/c", cmdPath}, os.Args[1:]...)
	c := exec.Command(comspec, args...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		os.Exit(1)
	}
}
