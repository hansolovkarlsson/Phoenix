int main() { return sizeof "abc" * 10 + sizeof "" + sizeof "a\tb\\c\"d\'e\n" * 100 - sizeof "\nX" - sizeof "X\\"; }
