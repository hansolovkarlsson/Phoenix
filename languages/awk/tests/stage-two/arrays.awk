# Valid awk, and not stage one. Arrays are the next thing the runtime needs.
BEGIN { a["x"] = 1; print a["x"] }
