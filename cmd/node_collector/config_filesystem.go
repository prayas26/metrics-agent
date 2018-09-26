// Copyright 2018 DigitalOcean
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"strings"
	"sync"
)

const (
	ignoredMountPointFlag = "--collector.filesystem.ignored-mount-points"
	ignoredFSTypesFlag    = "--collector.filesystem.ignored-fs-types"
)

var (
	ignoredMountPoints = strings.Join([]string{
		"fusectl", "lxcfs", "mqueue", "none", "rootfs", "sunrpc",
		"systemd", "udev",
	}, `|`)

	ignoredFSTypes = strings.Join([]string{
		"aufs", "autofs", "binfmt_misc", "cifs", "cgroup", "debugfs",
		"devpts", "devtmpfs", "ecryptfs", "efivarfs", "fuse",
		"hugetlbfs", "mqueue", "nfs", "overlayfs", "proc", "pstore",
		"rpc_pipefs", "securityfs", "smb", "sysfs", "tmpfs", "tracefs",
	}, `|`)

	onceRegisterFilesystemFlags = new(sync.Once)
)

// registerFilesystemFlags registers filesystem cli flags.
// This should be called from within OS-specific builds since the underlying
// collectors will not be registered otherwise.
// This func can be called multiple times.
func registerFilesystemFlags() {
	onceRegisterFilesystemFlags.Do(func() {
		additionalParams = append(additionalParams, ignoredFSTypesFlag, ignoredFSTypes)
		additionalParams = append(additionalParams, ignoredMountPointFlag, ignoredMountPoints)
	})
}
