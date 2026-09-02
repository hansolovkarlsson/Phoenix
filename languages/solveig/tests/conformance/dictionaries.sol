d := dictionary:new.
d:atPut("port", #8080):print.
d:at("port"):print.
d:at("host", "any"):display.
d:includes("port"):print.
d:includes("host"):print.
d:size:print.
dictionary:of("a", #1, "b", #2):size:print.
d:remove("port"):print.
d:size:print.
{ dictionary:new:at("missing") }:onError({ e | "absent":display }).
