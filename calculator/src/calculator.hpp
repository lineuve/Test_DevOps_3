#ifndef CALCULATOR_HPP
#define CALCULATOR_HPP

#include <stdexcept>

template <typename T>
class Calculator {
 public:
  Calculator(T n1, T n2) : number1(n1), number2(n2) {}

  T add() { return number1 + number2; }

  T subtract() { return number1 - number2; }

  T multiply() { return number1 * number2; }

  T divide() {
    // AQUI ESTA O FIX DO CRASH:
    if (number2 == 0) {
      throw std::invalid_argument("Division by zero");
    }
    return number1 / number2;
  }

 private:
  T number1;
  T number2;
};

#endif
