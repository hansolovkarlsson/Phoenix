# Valid awk, and not compiled yet: a range pattern is a rule with a memory,
# and every rule so far has been a question about the record in front of it.
/start/, /end/ { print }
