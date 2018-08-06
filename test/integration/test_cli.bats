#!/usr/bin/env bats
# Copyright (c) 2018 John Dewey

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

setup() {
  GILT_CLONED_ETCD_REPO=~/.gilt/clone/cache/https---github.com-retr0h-ansible-etcd.git-77a95b7
  GILT_DST_ETCD_REPO=/tmp/retr0h.ansible-etcd

  rm -rf ${GILT_CLONED_ETCD_REPO}
  rm -rf ${GILT_DST_ETCD_REPO}
}

@test "invoke gilt without arguments prints usage" {
	run go run main.go

	[ "$status" -eq 0 ]
	echo "${output}" | grep "GIT layering command line tool."
}

@test "invoke gilt version subcommand" {
	run go run main.go version

	[ "$status" -eq 0 ]
	echo "${output}" | grep "Date:"
	echo "${output}" | grep "Build:"
	echo "${output}" | grep "Version:"
	echo "${output}" | grep "Git Hash:"
}

@test "invoke gilt overlay subcommand" {
	run bash -c 'cd test; go run ../main.go overlay'

	[ "$status" -eq 0 ]

	run stat ${GILT_CLONED_ETCD_REPO}

	[ "$status" = 0 ]

	run stat ${GILT_DST_ETCD_REPO}

	[ "$status" = 0 ]
}

@test "invoke gilt overlay subcommand with filename flag" {
	run go run main.go overlay --filename test/gilt.yml

	[ "$status" -eq 0 ]
}

@test "invoke gilt overlay subcommand with f flag" {
	run go run main.go overlay -f test/gilt.yml

	[ "$status" -eq 0 ]
}

@test "invoke gilt overlay subcommand with debug flag" {
	run go run main.go --debug overlay --filename test/gilt.yml

	[ "$status" -eq 0 ]
	echo "${output}" | grep "[https://github.com/retr0h/ansible-etcd.git@77a95b7]"
	echo "${output}" | grep -E ".*Cloning to.*https---github.com-retr0h-ansible-etcd.git-77a95b7"
}
