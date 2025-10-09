package yab

import dt "core:time/datetime"

yab_utils_scan_digits :: proc(s: string, sep: string, count: int) -> (res: int, ok: bool) {
	needed := count + min(1, len(sep))
	(len(s) >= needed) or_return

	#no_bounds_check for i in 0..<count {
		if v := s[i]; v >= '0' && v <= '9' {
			res = res * 10 + int(v - '0')
		} else {
			return 0, false
		}
	}
	found_sep := len(sep) == 0
	#no_bounds_check for v in sep {
		found_sep |= rune(s[count]) == v
	}
	return res, found_sep
}

yab_utils_extract_date :: proc(iso_date: string) -> (d: dt.Date, ok: bool) {
    year  : int = yab_utils_scan_digits(iso_date[0:], "-",   4) or_return
    month : int = yab_utils_scan_digits(iso_date[5:], "-",   2) or_return
    day   : int = yab_utils_scan_digits(iso_date[8:], "",   2) or_return
    err   : dt.Error
    d, err = dt.components_to_date(year, month, day)
    if err == dt.Error.None {
        return d, true
    }
    return
}

// Returns true if date_a > date_b, false otherwise
yab_utils_compare_dates :: proc(date_a: dt.Date, date_b:dt.Date) -> bool {
	ord_a := dt.unsafe_date_to_ordinal(date_a)
	ord_b := dt.unsafe_date_to_ordinal(date_b)
	return ord_a > ord_b
}