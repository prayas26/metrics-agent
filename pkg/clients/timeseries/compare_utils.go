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

package timeseries

import (
	"math"
	"sort"
)

const equalFloatTolerance = 0.000001

// EqualFloat64 returns true if a and b are equal (difference is less than equalFloatTolerance)
func EqualFloat64(a, b float64) bool {
	return SimilarFloat64(a, b, equalFloatTolerance)
}

// SimilarFloat64 returns true if the difference between a and b is less than tolerance
func SimilarFloat64(a, b, tolerance float64) bool {
	diff := math.Abs(a - b)
	return diff < tolerance
}

// SimilarFloat64Percentage returns true if the difference between a and b is less than tolerance percentage
func SimilarFloat64Percentage(a, b, percentage, tolerance float64) bool {
	diff := math.Abs(a - b)
	if diff < tolerance {
		return true
	}
	if a == 0 {
		return false
	}
	perctangeDiff := diff / a
	return perctangeDiff < percentage
}

// EqualStringStringMaps returns true if both maps are equal
func EqualStringStringMaps(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		v2, ok := b[k]
		if !ok || v != v2 {
			return false
		}
	}
	return true
}

// EqualStringFloatMaps returns true if both maps are equal
func EqualStringFloatMaps(a, b map[string]float64, tolerance float64) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		v2, ok := b[k]
		if !ok || !SimilarFloat64(v, v2, tolerance) {
			return false
		}
	}
	return true
}

// EqualStringSlices returns true if both string slices are equal
func EqualStringSlices(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// CompareStringsUnordered tests if two slices contain the same elements (in any order).
// If they do not contain the same elements, elements which were exclusively found in a and b will
// be returned.
//
// Example:
// ok, aExtra, union, bExtra := CompareStringsUnordered([]string{"hello", "good", "world"}, []string{"good", "bye"})
// will return:
//   ok -> false
//   aExtra -> []string{"hello", "world"}
//   union -> []string{"good"}
//   bExtra -> []string{"bye"}
func CompareStringsUnordered(a, b []string) (bool, []string, []string, []string) {
	aSorted := make([]string, len(a))
	copy(aSorted, a)
	sort.Strings(aSorted)
	bSorted := make([]string, len(b))
	copy(bSorted, b)
	sort.Strings(bSorted)

	i := 0
	j := 0

	aExtra := []string{}
	union := []string{}
	bExtra := []string{}

	for {
		if i == len(aSorted) {
			for ; j < len(bSorted); j++ {
				bExtra = append(bExtra, bSorted[j])
			}
			break
		}
		if j == len(bSorted) {
			for ; i < len(aSorted); i++ {
				aExtra = append(aExtra, aSorted[i])
			}
			break
		}
		if aSorted[i] == bSorted[j] {
			union = append(union, aSorted[i])
			i++
			j++
		} else if aSorted[i] < bSorted[j] {
			aExtra = append(aExtra, aSorted[i])
			i++
		} else {
			bExtra = append(bExtra, bSorted[j])
			j++
		}
	}
	ok := len(aExtra) == 0 && len(bExtra) == 0
	return ok, aExtra, union, bExtra
}
