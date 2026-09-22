int main() {
    char c = 1; char s[7]; char *p = s;
    return sizeof(char) + sizeof(char *) * 2 + sizeof c * 100 + sizeof(c + 1) * 10 + sizeof(c = 2) + sizeof s[0] + sizeof s + sizeof *p + c;
}
