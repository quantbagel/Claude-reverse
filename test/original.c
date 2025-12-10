// Test binary for decompilation
// Compile with: clang -O2 -o test_binary original.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Simple: pure arithmetic
int add_numbers(int a, int b) {
    return a + b;
}

// Simple: with local variable
int square(int x) {
    int result = x * x;
    return result;
}

// Medium: loop
int sum_array(int *arr, int len) {
    int total = 0;
    for (int i = 0; i < len; i++) {
        total += arr[i];
    }
    return total;
}

// Medium: conditional
int max_of_three(int a, int b, int c) {
    int max = a;
    if (b > max) max = b;
    if (c > max) max = c;
    return max;
}

// Medium: string operation
int string_length(const char *s) {
    int len = 0;
    while (s[len] != '\0') {
        len++;
    }
    return len;
}

// Harder: nested loops
int matrix_sum(int matrix[3][3]) {
    int sum = 0;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            sum += matrix[i][j];
        }
    }
    return sum;
}

// Harder: recursion
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Harder: pointer manipulation
void swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

// Complex: bubble sort
void bubble_sort(int *arr, int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                swap(&arr[j], &arr[j + 1]);
            }
        }
    }
}

int main(int argc, char **argv) {
    printf("Testing decompilation target\n");

    // Test add
    printf("add_numbers(3, 4) = %d\n", add_numbers(3, 4));

    // Test square
    printf("square(5) = %d\n", square(5));

    // Test sum_array
    int arr[] = {1, 2, 3, 4, 5};
    printf("sum_array([1,2,3,4,5]) = %d\n", sum_array(arr, 5));

    // Test max
    printf("max_of_three(3, 7, 2) = %d\n", max_of_three(3, 7, 2));

    // Test fibonacci
    printf("fibonacci(10) = %d\n", fibonacci(10));

    // Test bubble sort
    int to_sort[] = {5, 2, 8, 1, 9};
    bubble_sort(to_sort, 5);
    printf("sorted: %d %d %d %d %d\n",
           to_sort[0], to_sort[1], to_sort[2], to_sort[3], to_sort[4]);

    return 0;
}
