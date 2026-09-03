i := #0.
{ i:lessThan(#3) }:whileTrue({ i := i:add(#1) }).
i:greaterThan(#1):ifElse({ "big" }, { "small" }):display.
