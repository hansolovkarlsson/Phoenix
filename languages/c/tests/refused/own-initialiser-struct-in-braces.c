struct s { long v; }; int main(void) { struct s x = { sizeof x }; return (int)x.v; }
