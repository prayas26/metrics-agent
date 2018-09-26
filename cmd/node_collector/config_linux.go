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

func init() {
	registerFilesystemFlags()
	disableCollectors("arp", "bcache", "bonding", "buddyinfo", "conntrack",
		"drbd", "edac", "entropy", "filefd", "hwmon", "infiniband",
		"interrupts", "ipvs", "ksmd", "logind", "mdadm", "meminfo_numa",
		"mountstats", "netclass", "netdev", "nfs", "nfsd", "ntp", "qdisc",
		"runit", "sockstat", "supervisord", "systemd", "tcpstat",
		"textfile", "time", "timex", "wifi", "xfs", "zfs",
	)
}
