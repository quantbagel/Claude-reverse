// Simple TypeScript test for Bun compilation

interface User {
  name: string;
  age: number;
}

function greet(user: User): string {
  return `Hello, ${user.name}! You are ${user.age} years old.`;
}

function fibonacci(n: number): number {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

function isPrime(n: number): boolean {
  if (n <= 1) return false;
  for (let i = 2; i * i <= n; i++) {
    if (n % i === 0) return false;
  }
  return true;
}

// Main
const user: User = { name: "Dwarf", age: 150 };
console.log(greet(user));
console.log(`Fibonacci(10) = ${fibonacci(10)}`);
console.log(`Is 17 prime? ${isPrime(17)}`);

// Some secret data to look for when reversing
const SECRET_KEY = "dwarves-dig-deep-2024";
console.log(`Secret length: ${SECRET_KEY.length}`);
