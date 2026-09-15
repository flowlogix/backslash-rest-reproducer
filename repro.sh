#!/usr/bin/env bash
# Reproducer for payara/Payara#8142 and eclipse-ee4j/glassfish-grizzly#2028.
#
#   3. ./repro.sh [base-url]                     (default http://localhost:8080/backslash-rest-reproducer-1.x-SNAPSHOT)
#
# Exit status is non-zero if any expectation fails.
# Expectations are the *fixed* behaviour, i.e. server started with
# asadmin create-system-property com.sun.enterprise.web.allowBackslash=true
# Unfixed/default Payara fails the first two cases with "400 Invalid URI".

set -u
BASE="${1:-http://localhost:8080/backslash-rest-reproducer-1.x-SNAPSHOT}"
BODY=$(mktemp); trap 'rm -f "$BODY"' EXIT
fail=0

check() {  # check <raw path> <expected status> [<expected body>]
    local path="$1" want_status="$2" want_body="${3-}" status body
    # --path-as-is: stop curl from squashing "/../" itself; the server must see it.
    status=$(curl -sS --path-as-is -o "$BODY" -w '%{http_code}' "$BASE$path")
    body=$(<"$BODY")
    if [[ "$status" == "$want_status" && ( -z "$want_body" || "$body" == "$want_body" ) ]]; then
        printf '  ok   %-28s -> %s %s\n' "$path" "$status" "$body"
    else
        printf '  FAIL %-28s -> %s %q   (wanted %s %q)\n' "$path" "$status" "$body" "$want_status" "$want_body"
        fail=1
    fi
}

echo "Against $BASE"
# The bug: %5C is a valid pct-encoded octet and must decode to a literal backslash inside the segment.
check '/echo/foo%5Cbar'          200 'foo\bar'
# It must stay *data*: not a separator, so "..\" does not climb and the segment reaches JAX-RS intact.
check '/echo/a%5C..%5Cb'         200 'a\..\b'
# But the Payara valve reads '\' as '/' for the restricted-directory guard (as FileDirContext does on
# Windows), so a backslash traversal that would land in WEB-INF/META-INF is refused before any servlet.
check '/echo/..%5C..%5CWEB-INF'  404
# Control.
check '/echo/foobar'             200 'foobar'
# A literal, un-encoded backslash is not a URI character at all; 400 is correct before AND after the fix.
check '/echo/foo\bar'            400
# Real traversal through ordinary separators is still normalized away (maps to /WEB-INF -> 404), never served.
check '/echo/../WEB-INF/web.xml' 404

exit $fail
