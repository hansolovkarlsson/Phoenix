int count(int n) {
    int k = 0;
    switch (n % 4) {
    case 0: do { k++;
    case 3:      k++;
    case 2:      k++;
    case 1:      k++;
            } while ((n -= 4) > 0);
    }
    return k;
}
int main() { return count(1) + count(2) * 3 + count(7) * 10 + count(12) * 20 % 256; }
